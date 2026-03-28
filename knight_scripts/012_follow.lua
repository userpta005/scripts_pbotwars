--[[
  012_follow.lua — Follow PVP (só caminha; não mantém attack no líder).

  Com a macro ligada, o próximo player atacado passa a ser `followLeader`. Perseguição por
  `autoWalk`; mudança de Z só após `onCreaturePositionChange` do líder (pé guardado em
  `storage._followLadder*`). Uses em sqm adjacentes ao follower via `knightMapUseTopThing` (001).
  Não abre portas no mesmo plano por design.

  Não usar com 011 Auto Chase activo (lógica duplicada: _follow* vs _chase*).
  Depende de: 001_storage_init.lua
]]
storage = (type(storage) == "table" and storage) or {}
if knightEnsureStorage then
  knightEnsureStorage({
    followLeader = "",
    lastAttacked = "",
    _followEnabled = false,
    _followVerticalUntil = 0,
    _followLadderFx = nil,
    _followLadderFy = nil,
    _followLadderFz = nil,
  })
end

-- Poll: mesmo andar com “zona de conforto” evita re-path a cada tick (oscila à volta do líder).
local FOLLOW_POLL_MS = 85
local FOLLOW_WALK_GAP_MS = 145
local SAME_FLOOR_COMFORT_DIST = 2
local SAME_DEST_REWALK_MS = 320
local LADDER_USE_GAP_MS = 280
--- Varre o pé ± este raio, mas só dá use em tiles a ≤1 do jogador (evita “cannot use this object” em SQM longe).
local LADDER_SCAN_RADIUS = 2
--- Distância até ao pé para começar a tentar use (líder diagonal/lateral à escada).
local LADDER_ACTION_DIST = 4
local EXANI_GAP_MS = 900
local INTERRUPTOR_MS = 500
local VANISH_WALK_DELAY_MS = 90
local VANISH_SURROUND_DELAY_MS = 750
local FLOOR_CHASE_STEPS = 4
local FLOOR_CHASE_STEP_MS = 115
local LADDER_FOOT_RETRY_MS = { 60, 160 }
--- Após o líder mudar de andar: janela curta reduz use espúrio se o follower for mais rápido.
local FOLLOW_VERTICAL_WINDOW_MS = 4800
--- Sem callback de troca de Z: exige discrepância de plano estável antes de armar.
local VERTICAL_MISMATCH_ARM_MS = 550

local lastExaniTeraAt = 0
local lastFollowWalkAt = 0
local lastLadderUseAt = 0
local ladderAdjIndex = 0
local followWasOn = false
local offPlaneSince = nil
local lastWalkDestX, lastWalkDestY, lastWalkDestZ = nil, nil, nil

local function clearWalkDestMemory()
  lastWalkDestX, lastWalkDestY, lastWalkDestZ = nil, nil, nil
end

--- Novo destino ou passou tempo → vale mandar outro autoWalk (evita spam no mesmo tile).
local function shouldIssueWalk(tx, ty, tz)
  if lastWalkDestX ~= tx or lastWalkDestY ~= ty or lastWalkDestZ ~= tz then
    return true
  end
  return (now - lastFollowWalkAt) >= SAME_DEST_REWALK_MS
end

local function rememberWalkDest(tx, ty, tz)
  lastWalkDestX, lastWalkDestY, lastWalkDestZ = tx, ty, tz
end

local function verticalFollowArmed()
  local u = storage._followVerticalUntil
  return type(u) == "number" and u > now
end

local function armVerticalFollow()
  storage._followVerticalUntil = now + FOLLOW_VERTICAL_WINDOW_MS
  clearWalkDestMemory()
end

local function clearVerticalFollow()
  storage._followVerticalUntil = 0
  offPlaneSince = nil
  storage._followLadderFx = nil
  storage._followLadderFy = nil
  storage._followLadderFz = nil
  ladderAdjIndex = 0
end

--- Pé real da transição (tile onde o líder estava antes de mudar de Z), não a coluna do lp em cima.
local function setLadderFootFromOldPos(oldPos)
  if not oldPos then return end
  storage._followLadderFx = oldPos.x
  storage._followLadderFy = oldPos.y
  storage._followLadderFz = oldPos.z
  ladderAdjIndex = 0
end

local function ladderFootXYOnPlane(lz)
  local fx = storage._followLadderFx
  local fy = storage._followLadderFy
  local fz = storage._followLadderFz
  if type(fx) ~= "number" or type(fy) ~= "number" or type(fz) ~= "number" then return nil, nil end
  if fz ~= lz then return nil, nil end
  return fx, fy
end

local function safeCancelAttack()
  if g_game and g_game.cancelAttack then
    pcall(function() g_game.cancelAttack() end)
  end
end

--- Com follow activo, não deixar o cliente em modo atacar o líder (só caminhar até ele).
local function cancelAttackIfTargetingLeader(lname)
  if not lname or lname == "" then return end
  if not g_game or not g_game.isAttacking or not g_game.getAttackingCreature then return end
  local attacking, cur
  local ok = pcall(function()
    attacking = g_game.isAttacking()
    cur = attacking and g_game.getAttackingCreature() or nil
  end)
  if not ok or not cur then return end
  local nOk, n = pcall(function() return cur:getName() end)
  if nOk and type(n) == "string" and knightNameMatchLock(lname, n) then
    safeCancelAttack()
  end
end

local function useSurroundingTiles()
  for i = -1, 1 do
    for j = -1, 1 do
      knightMapUseTopThing(posx() + i, posy() + j, posz())
    end
  end
end

--- Tenta subir/descer: candidatos num quadrado em torno do pé, filtrados a adjacência ao local player.
local function tryLadderUsesAtFoot(wx, wy, lz)
  local mp = pos and pos() or nil
  if not mp or mp.z ~= lz then return end
  local cands = {}
  for dx = -LADDER_SCAN_RADIUS, LADDER_SCAN_RADIUS do
    for dy = -LADDER_SCAN_RADIUS, LADDER_SCAN_RADIUS do
      local x, y = wx + dx, wy + dy
      local t = { x = x, y = y, z = lz }
      if getDistanceBetween(mp, t) <= 1 then
        local df = getDistanceBetween({ x = wx, y = wy, z = lz }, t)
        cands[#cands + 1] = { x = x, y = y, df = df }
      end
    end
  end
  table.sort(cands, function(a, b) return a.df < b.df end)
  if #cands == 0 then return end
  ladderAdjIndex = (ladderAdjIndex % #cands) + 1
  local c = cands[ladderAdjIndex]
  knightMapUseTopThing(c.x, c.y, lz)
end

local function tryExaniTera()
  if now - lastExaniTeraAt < EXANI_GAP_MS then return end
  lastExaniTeraAt = now
  if say then pcall(function() say("exani tera") end) end
end

local function seeLeaderAnywhere(lockName)
  if knightSeePlayerByNameAnywhere then return knightSeePlayerByNameAnywhere(lockName) end
  return nil
end

-- Macro leve: só interruptor (isOn); intervalo mínimo evita callback vazio a cada 50 ms.
local followMacro = macro(INTERRUPTOR_MS, "Follow PVP", "3", function() end)

onAttackingCreatureChange(function(creature)
  if not followMacro or not followMacro:isOn() then return end
  if knightChatOpen and knightChatOpen() then return end
  if not creature or not creature.isPlayer or not creature:isPlayer() then return end
  local nOk, name = pcall(function() return creature:getName() end)
  if not nOk or type(name) ~= "string" then return end
  name = knightTrim(name)
  if name == "" then return end
  storage.lastAttacked = name
  storage.followLeader = name
  safeCancelAttack()
end)

macro(FOLLOW_POLL_MS, function()
  if not followMacro or not followMacro:isOn() then return end
  if knightChatOpen and knightChatOpen() then return end
  local lname = knightTrim(storage.followLeader or "")
  if lname == "" then return end
  cancelAttackIfTargetingLeader(lname)
  if not autoWalk then return end

  local lzOk, lz = pcall(function() return posz() end)
  if not lzOk then return end
  local mp = pos and pos() or nil
  if not mp then return end

  local leader = knightFindLockedPlayer and knightFindLockedPlayer(lname, false) or nil
  if not leader and getPlayerByName then
    for _, multi in ipairs({ true, false }) do
      local ok, p = pcall(function() return getPlayerByName(lname, multi) end)
      if ok and p then leader = p break end
    end
  end

  local lp, lpOk = nil, false
  if leader then
    local a, b = pcall(function() return leader:getPosition() end)
    lpOk = a and b ~= nil
    lp = b
  end

  local ffx, ffy = ladderFootXYOnPlane(lz)

  -- Mesmo plano que o líder ainda visível: follow normal.
  if lpOk and lp.z == lz then
    clearVerticalFollow()
    offPlaneSince = nil
    local sameDist = getDistanceBetween(mp, lp)
    if sameDist <= SAME_FLOOR_COMFORT_DIST then return end
    if now - lastFollowWalkAt < FOLLOW_WALK_GAP_MS then return end
    if not shouldIssueWalk(lp.x, lp.y, lp.z) then return end
    pcall(function()
      autoWalk(lp, 20, { ignoreNonPathable = true, precision = 2 })
    end)
    lastFollowWalkAt = now
    rememberWalkDest(lp.x, lp.y, lp.z)
    return
  end

  -- Líder noutro Z visível, ou sumiu do stack (subiu e o cliente já não o lista neste andar).
  if lpOk and lp and lp.z ~= lz then
    if not offPlaneSince then offPlaneSince = now end
    if not verticalFollowArmed() and (now - offPlaneSince) >= VERTICAL_MISMATCH_ARM_MS then
      armVerticalFollow()
    end
  elseif ffx and (not lpOk or not lp) then
    if not offPlaneSince then offPlaneSince = now end
    if not verticalFollowArmed() and (now - offPlaneSince) >= VERTICAL_MISMATCH_ARM_MS then
      armVerticalFollow()
    end
  end

  local function doOtherPlaneWalkUse(wx, wy)
    if not verticalFollowArmed() then return end
    local target = { x = wx, y = wy, z = lz }
    local dist = getDistanceBetween(mp, target)
    if dist <= LADDER_ACTION_DIST then
      if now - lastLadderUseAt >= LADDER_USE_GAP_MS then
        tryLadderUsesAtFoot(wx, wy, lz)
        lastLadderUseAt = now
      end
      return
    end
    if now - lastFollowWalkAt < FOLLOW_WALK_GAP_MS then return end
    if not shouldIssueWalk(wx, wy, lz) then return end
    pcall(function()
      autoWalk(target, 20, { ignoreNonPathable = true, precision = 2 })
    end)
    lastFollowWalkAt = now
    rememberWalkDest(wx, wy, lz)
  end

  if ffx and verticalFollowArmed() then
    doOtherPlaneWalkUse(ffx, ffy)
    return
  end

  if lpOk and lp and lp.z ~= lz and verticalFollowArmed() then
    doOtherPlaneWalkUse(lp.x, lp.y)
  end
end)

onCreaturePositionChange(function(creature, newPos, oldPos)
  if not followMacro or followMacro:isOff() then return end
  if not creature or not oldPos then return end
  local nOk, cname = pcall(function() return creature:getName() end)
  if not nOk or type(cname) ~= "string" then return end

  local lname = knightTrim(storage.followLeader or "")
  if lname == "" then return end

  if knightNameMatchLock(lname, cname) then
    if not newPos then
      armVerticalFollow()
      setLadderFootFromOldPos(oldPos)
      schedule(VANISH_WALK_DELAY_MS, function()
        if autoWalk then pcall(function() autoWalk(oldPos) end) end
      end)
      schedule(VANISH_SURROUND_DELAY_MS, function()
        if verticalFollowArmed() then useSurroundingTiles() end
      end)
    elseif oldPos.z ~= newPos.z then
      armVerticalFollow()
      setLadderFootFromOldPos(oldPos)
      local leaderWentUp = newPos.z < oldPos.z
      if autoWalk then pcall(function() autoWalk(oldPos) end) end
      if leaderWentUp then
        knightMapUseTopThing(oldPos.x, oldPos.y, oldPos.z)
        for _, d in ipairs(LADDER_FOOT_RETRY_MS) do
          schedule(d, function() knightMapUseTopThing(oldPos.x, oldPos.y, oldPos.z) end)
        end
        schedule(LADDER_FOOT_RETRY_MS[#LADDER_FOOT_RETRY_MS] + 80, function()
          tryLadderUsesAtFoot(oldPos.x, oldPos.y, oldPos.z)
        end)
        knightMapUseTopThing(newPos.x, newPos.y - 1, newPos.z)
      else
        schedule(40, function() knightMapUseTopThing(oldPos.x, oldPos.y, oldPos.z) end)
        schedule(130, function() knightMapUseTopThing(oldPos.x, oldPos.y, oldPos.z) end)
        schedule(220, function() tryLadderUsesAtFoot(oldPos.x, oldPos.y, oldPos.z) end)
      end
      for i = 1, FLOOR_CHASE_STEPS do
        schedule(i * FLOOR_CHASE_STEP_MS, function()
          if not verticalFollowArmed() then return end
          if autoWalk and getDistanceBetween(pos(), oldPos) > 1 then
            pcall(function() autoWalk(oldPos) end)
          end
          if getDistanceBetween(pos(), oldPos) == 0 and posz() > newPos.z and not seeLeaderAnywhere(lname) then
            tryExaniTera()
          end
        end)
      end
    end
  end

  if not newPos or not player then return end
  local pOk, pname = pcall(function() return player:getName() end)
  if not pOk or type(pname) ~= "string" or cname ~= pname then return end
  if newPos.z <= oldPos.z then return end
  if lname ~= "" and verticalFollowArmed() and not seeLeaderAnywhere(lname) then
    tryExaniTera()
    useSurroundingTiles()
  end
end)

local btnClearFollow

local function clearFollow()
  storage.followLeader = ""
  clearVerticalFollow()
  clearWalkDestMemory()
  if g_game and g_game.cancelAttackAndFollow then
    pcall(function() g_game.cancelAttackAndFollow() end)
  end
  knightFlashBtn(btnClearFollow)
end

btnClearFollow = addButton("btn_clear_follow", "Clear Follow [1]", clearFollow)
hotkey("1", clearFollow)

macro(150, function()
  local on = followMacro:isOn()
  if on and not followWasOn then
    storage.followLeader = ""
    clearVerticalFollow()
    clearWalkDestMemory()
  end
  followWasOn = on
  storage._followEnabled = on
end)

