--[[
  012_auto_target.lua — Lock de alvo PVP + Auto Chase.

  - Auto Target (Shift+Q): mantém `g_game.attack` no jogador lockado no mesmo piso.
  - Auto Chase (2): força chase mode 1 e replica a lógica vertical de 013_follow (passos, escadas,
    `knightMapUseTopThing`, janela `_chaseVerticalUntil`, exani tera). Estado em `storage._chase*`.

  Não ligar em simultâneo com 013 Follow PVP (_chase* vs _follow*).
  Depende de: 002_storage_init.lua, 003 recomendado (lastAttacked).
]]

storage = (type(storage) == "table" and storage) or {}
if knightEnsureStorage then
  knightEnsureStorage({
    _target = "",
    _targetId = 0,
    lastAttacked = "",
    _targetEnabled = false,
    _chaseEnabled = false,
    _chaseVerticalUntil = 0,
    _chaseLadderFx = nil,
    _chaseLadderFy = nil,
    _chaseLadderFz = nil,
  })
end

-- Mesmos valores que 013_follow.lua (manter alinhados ao mudar um dos ficheiros).
local CHASE_POLL_MS = 85
local CHASE_WALK_GAP_MS = 145
local SAME_FLOOR_COMFORT_DIST = 2
local SAME_DEST_REWALK_MS = 320
local LADDER_USE_GAP_MS = 280
local LADDER_SCAN_RADIUS = 2
local LADDER_ACTION_DIST = 4
local EXANI_GAP_MS = 900
local VANISH_WALK_DELAY_MS = 90
local VANISH_SURROUND_DELAY_MS = 750
local FLOOR_CHASE_STEPS = 4
local FLOOR_CHASE_STEP_MS = 115
local LADDER_FOOT_RETRY_MS = { 60, 160 }
local CHASE_VERTICAL_WINDOW_MS = 4800
local VERTICAL_MISMATCH_ARM_MS = 550

local REATTACK_GAP_MS = 120
local CHASE_ATTACK_GAP_MS = 50

local throttleAt = {}
local function throttle(key, ms)
  if (now - (throttleAt[key] or 0)) < ms then return false end
  throttleAt[key] = now
  return true
end

local lastExaniChaseAt = 0
local lastChaseWalkAt = 0
local lastChaseLadderUseAt = 0
local chaseLadderAdjIndex = 0
local chaseWasOn = false
local chaseOffPlaneSince = nil
local lastChaseWalkDestX, lastChaseWalkDestY, lastChaseWalkDestZ = nil, nil, nil

local function clearChaseWalkDest()
  lastChaseWalkDestX, lastChaseWalkDestY, lastChaseWalkDestZ = nil, nil, nil
end

local function shouldIssueChaseWalk(tx, ty, tz)
  if lastChaseWalkDestX ~= tx or lastChaseWalkDestY ~= ty or lastChaseWalkDestZ ~= tz then
    return true
  end
  return (now - lastChaseWalkAt) >= SAME_DEST_REWALK_MS
end

local function rememberChaseWalk(tx, ty, tz)
  lastChaseWalkDestX, lastChaseWalkDestY, lastChaseWalkDestZ = tx, ty, tz
end

local function verticalChaseArmed()
  local u = storage._chaseVerticalUntil
  return type(u) == "number" and u > now
end

local function armVerticalChase()
  storage._chaseVerticalUntil = now + CHASE_VERTICAL_WINDOW_MS
  clearChaseWalkDest()
end

local function clearVerticalChase()
  storage._chaseVerticalUntil = 0
  chaseOffPlaneSince = nil
  storage._chaseLadderFx = nil
  storage._chaseLadderFy = nil
  storage._chaseLadderFz = nil
  chaseLadderAdjIndex = 0
end

local function setChaseLadderFootFromOldPos(oldPos)
  if not oldPos then return end
  storage._chaseLadderFx = oldPos.x
  storage._chaseLadderFy = oldPos.y
  storage._chaseLadderFz = oldPos.z
  chaseLadderAdjIndex = 0
end

local function chaseLadderFootXYOnPlane(lz)
  local fx, fy = storage._chaseLadderFx, storage._chaseLadderFy
  local fz = storage._chaseLadderFz
  if type(fx) ~= "number" or type(fy) ~= "number" or type(fz) ~= "number" then return nil, nil end
  if fz ~= lz then return nil, nil end
  return fx, fy
end

local function useSurroundingChase()
  for i = -1, 1 do
    for j = -1, 1 do
      knightMapUseTopThing(posx() + i, posy() + j, posz())
    end
  end
end

local function tryChaseLadderUsesAtFoot(wx, wy, lz)
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
  chaseLadderAdjIndex = (chaseLadderAdjIndex % #cands) + 1
  local c = cands[chaseLadderAdjIndex]
  knightMapUseTopThing(c.x, c.y, lz)
end

local function tryExaniChaseTera()
  if now - lastExaniChaseAt < EXANI_GAP_MS then return end
  lastExaniChaseAt = now
  if say then pcall(function() say("exani tera") end) end
end

--- Alvo lock: mesma ideia que `onCreaturePositionChange` do 013_follow (sem ramo same-Z).
local function onChaseTargetMoved(creature, newPos, oldPos)
  if not creature or not oldPos then return end
  local nOk, cname = pcall(function() return creature:getName() end)
  if not nOk or type(cname) ~= "string" then return end
  local tname = knightTrim(storage._target or "")
  if tname == "" or not knightNameMatchLock(tname, cname) then return end

  if not newPos then
    armVerticalChase()
    setChaseLadderFootFromOldPos(oldPos)
    schedule(VANISH_WALK_DELAY_MS, function()
      if autoWalk then pcall(function() autoWalk(oldPos) end) end
    end)
    schedule(VANISH_SURROUND_DELAY_MS, function()
      if verticalChaseArmed() then useSurroundingChase() end
    end)
  elseif oldPos.z ~= newPos.z then
    armVerticalChase()
    setChaseLadderFootFromOldPos(oldPos)
    local targetWentUp = newPos.z < oldPos.z
    if autoWalk then pcall(function() autoWalk(oldPos) end) end
    if targetWentUp then
      knightMapUseTopThing(oldPos.x, oldPos.y, oldPos.z)
      for _, d in ipairs(LADDER_FOOT_RETRY_MS) do
        schedule(d, function() knightMapUseTopThing(oldPos.x, oldPos.y, oldPos.z) end)
      end
      schedule(LADDER_FOOT_RETRY_MS[#LADDER_FOOT_RETRY_MS] + 80, function()
        tryChaseLadderUsesAtFoot(oldPos.x, oldPos.y, oldPos.z)
      end)
      knightMapUseTopThing(newPos.x, newPos.y - 1, newPos.z)
    else
      schedule(40, function() knightMapUseTopThing(oldPos.x, oldPos.y, oldPos.z) end)
      schedule(130, function() knightMapUseTopThing(oldPos.x, oldPos.y, oldPos.z) end)
      schedule(220, function() tryChaseLadderUsesAtFoot(oldPos.x, oldPos.y, oldPos.z) end)
    end
    for i = 1, FLOOR_CHASE_STEPS do
      schedule(i * FLOOR_CHASE_STEP_MS, function()
        if not verticalChaseArmed() then return end
        if autoWalk and getDistanceBetween(pos(), oldPos) > 1 then
          pcall(function() autoWalk(oldPos) end)
        end
        if getDistanceBetween(pos(), oldPos) == 0 and posz() > newPos.z and not knightSeePlayerByNameAnywhere(tname) then
          tryExaniChaseTera()
        end
      end)
    end
  end
end

local function onLocalPlayerAscendChase(creature, newPos, oldPos)
  if not newPos or not oldPos or not creature then return end
  local nOk, cname = pcall(function() return creature:getName() end)
  local pOk, pname = pcall(function() return player:getName() end)
  if not nOk or not pOk or type(cname) ~= "string" or type(pname) ~= "string" or cname ~= pname then return end
  if newPos.z <= oldPos.z then return end
  local tname = knightTrim(storage._target or "")
  if tname == "" or not verticalChaseArmed() then return end
  if knightSeePlayerByNameAnywhere(tname) then return end
  tryExaniChaseTera()
  useSurroundingChase()
end

local autoTargetMacro
local autoChaseMacro

onAttackingCreatureChange(function(creature, oldCreature)
  if not creature or not creature.isPlayer or not creature:isPlayer() then return end
  local nOk, name = pcall(function() return creature:getName() end)
  if not nOk or type(name) ~= "string" or name == "" then return end
  name = knightTrim(name)
  storage.lastAttacked = name
  if knightMacroIsOn(autoTargetMacro) or knightMacroIsOn(autoChaseMacro) then
    storage._target = name
  end
end)

onCreaturePositionChange(function(creature, newPos, oldPos)
  if not autoChaseMacro or autoChaseMacro:isOff() then return end
  onChaseTargetMoved(creature, newPos, oldPos)
  onLocalPlayerAscendChase(creature, newPos, oldPos)
end)

autoTargetMacro = macro(100, "Auto Target", "Shift+Q", function()
  if knightChatOpen() then return end
  if not knightGameAttackReady() then return end

  local tname = knightTrim(storage._target or "")
  local target = knightFindLockedPlayer(tname, true)
  if not target then
    if tname ~= "" then storage._targetId = 0 end
    return
  end

  storage._targetId = knightSafeCreatureId(target)

  local cur = nil
  pcall(function() cur = g_game.getAttackingCreature() end)
  local curName = ""
  if cur and cur.isPlayer and cur:isPlayer() then
    local cnOk, cn = pcall(function() return cur:getName() end)
    if cnOk and type(cn) == "string" then curName = knightTrim(cn) end
  end
  local attacking = false
  pcall(function() attacking = g_game.isAttacking() end)
  if not knightNameMatchLock(tname, curName) or not attacking then
    if throttle("reattack", REATTACK_GAP_MS) then knightGameAttack(target) end
  end
end)

autoChaseMacro = macro(CHASE_POLL_MS, "Auto Chase", "2", function()
  if not autoChaseMacro or autoChaseMacro:isOff() then return end
  if knightChatOpen() then return end

  local tname = knightTrim(storage._target or "")
  if tname == "" then
    clearVerticalChase()
    clearChaseWalkDest()
    return
  end

  if g_game and g_game.getChaseMode and g_game.setChaseMode then
    local okMode, m = pcall(function() return g_game.getChaseMode() end)
    if okMode and m ~= 1 then pcall(function() g_game.setChaseMode(1) end) end
  end

  local target = knightFindLockedPlayer(tname, false)
  if not target and getPlayerByName then
    for _, multi in ipairs({ true, false }) do
      local ok, p = pcall(function() return getPlayerByName(tname, multi) end)
      if ok and p then target = p break end
    end
  end

  if target then
    storage._targetId = knightSafeCreatureId(target)
  else
    storage._targetId = 0
  end

  if target and knightGameAttackReady() and throttle("chase_attack", CHASE_ATTACK_GAP_MS) then
    knightGameAttack(target)
  end

  if not autoWalk then return end

  local lzOk, lz = pcall(function() return posz() end)
  if not lzOk then return end
  local mp = pos and pos() or nil
  if not mp then return end

  local lp, lpOk = nil, false
  if target then
    local a, b = pcall(function() return target:getPosition() end)
    lpOk = a and b ~= nil
    lp = b
  end

  local ffx, ffy = chaseLadderFootXYOnPlane(lz)

  if lpOk and lp.z == lz then
    clearVerticalChase()
    chaseOffPlaneSince = nil
    local sameDist = getDistanceBetween(mp, lp)
    if sameDist <= SAME_FLOOR_COMFORT_DIST then return end
    if now - lastChaseWalkAt < CHASE_WALK_GAP_MS then return end
    if not shouldIssueChaseWalk(lp.x, lp.y, lp.z) then return end
    pcall(function()
      autoWalk(lp, 20, { ignoreNonPathable = true, precision = 2 })
    end)
    lastChaseWalkAt = now
    rememberChaseWalk(lp.x, lp.y, lp.z)
    return
  end

  if lpOk and lp and lp.z ~= lz then
    if not chaseOffPlaneSince then chaseOffPlaneSince = now end
    if not verticalChaseArmed() and (now - chaseOffPlaneSince) >= VERTICAL_MISMATCH_ARM_MS then
      armVerticalChase()
    end
  elseif ffx and (not lpOk or not lp) then
    if not chaseOffPlaneSince then chaseOffPlaneSince = now end
    if not verticalChaseArmed() and (now - chaseOffPlaneSince) >= VERTICAL_MISMATCH_ARM_MS then
      armVerticalChase()
    end
  end

  local function doChaseOtherPlaneWalkUse(wx, wy)
    if not verticalChaseArmed() then return end
    local dest = { x = wx, y = wy, z = lz }
    local dist = getDistanceBetween(mp, dest)
    if dist <= LADDER_ACTION_DIST then
      if now - lastChaseLadderUseAt >= LADDER_USE_GAP_MS then
        tryChaseLadderUsesAtFoot(wx, wy, lz)
        lastChaseLadderUseAt = now
      end
      return
    end
    if now - lastChaseWalkAt < CHASE_WALK_GAP_MS then return end
    if not shouldIssueChaseWalk(wx, wy, lz) then return end
    pcall(function()
      autoWalk(dest, 20, { ignoreNonPathable = true, precision = 2 })
    end)
    lastChaseWalkAt = now
    rememberChaseWalk(wx, wy, lz)
  end

  if ffx and verticalChaseArmed() then
    doChaseOtherPlaneWalkUse(ffx, ffy)
    return
  end

  if lpOk and lp and lp.z ~= lz and verticalChaseArmed() then
    doChaseOtherPlaneWalkUse(lp.x, lp.y)
  end
end)

local btnClear
local function doClear()
  storage._target = ""
  storage._targetId = 0
  clearVerticalChase()
  clearChaseWalkDest()
  if g_game and g_game.cancelAttackAndFollow then
    pcall(function() g_game.cancelAttackAndFollow() end)
  end
  knightFlashBtn(btnClear)
end
btnClear = addButton("btn_clear", "Clear Target [4]", doClear)
hotkey("4", doClear)

local btnRecover
local function doRecover()
  if knightChatOpen() then return end
  local name = knightTrim(storage.lastAttacked or "")
  if name == "" then return end
  storage._target = name
  local c = knightFindLockedPlayer(name, true)
  storage._targetId = knightSafeCreatureId(c)
  if c then knightGameAttack(c) end
  knightFlashBtn(btnRecover)
end
btnRecover = addButton("btn_recover", "Recover Target [Shift+E]", doRecover)
hotkey("Shift+E", doRecover)

macro(150, function()
  local on = autoChaseMacro and autoChaseMacro:isOn()
  if on and not chaseWasOn then
    clearVerticalChase()
    clearChaseWalkDest()
  elseif not on and chaseWasOn then
    clearVerticalChase()
    clearChaseWalkDest()
  end
  chaseWasOn = on and true or false
  storage._targetEnabled = knightMacroIsOn(autoTargetMacro)
  storage._chaseEnabled = on
end)

--- Referências para `001_pvp_manual_mode.lua` (ligar macros por código).
knightAutoTargetMacro = autoTargetMacro
knightAutoChaseMacro = autoChaseMacro
