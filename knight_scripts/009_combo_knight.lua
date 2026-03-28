--[[
  009_combo_knight.lua — Mas Exori Hur com alinhamento ao alvo em ataque (mesmo Z).

  Se estiveres na diagonal “cruz” a um sqm, tenta passo lateral com `autoWalk` para ganhar
  linha reta; caso contrário `turn` + pequeno atraso antes do cast. Regista prioridade
  `mas_exori_hur` em 001.

  Depende de: 001_storage_init.lua, g_map para tiles livres.
  PVE/PVP: mesmo algoritmo; evita cast quando ainda há passo lateral pendente.
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "mas exori hur"
local MIN_MANA = 1400
local GAP_MS = 2200
local TURN_DELAY_MS = 80
local SIDE_STEP_GAP_MS = 280

local lastCast = 0
local lastSideStep = 0
--- Após `turn(want)`: espera até `now >= pendingUntil` com o mesmo `pendingId` de criatura.
local pendingUntil, pendingId = 0, 0

local function dirToTarget(dx, dy)
  if dx == 0 and dy == 0 then return nil end
  if dx == 0 then return dy > 0 and 2 or 0 end
  if dy == 0 then return dx > 0 and 1 or 3 end
  if math.abs(dx) >= math.abs(dy) then return dx > 0 and 1 or 3 end
  return dy > 0 and 2 or 0
end

local function turnSteps(cur, want)
  if cur == nil or want == nil then return 99 end
  local d = math.abs(want - cur)
  return math.min(d, 4 - d)
end

--- Casa lateral livre para passo em “L” (diagonal ao alvo).
local function tileOkForSideStep(p)
  if not g_map or not g_map.getTile then return false end
  local pid = player and knightSafeCreatureId(player) or 0
  local ok, walk = pcall(function()
    local tile = g_map.getTile(p)
    if not tile or not tile:isWalkable() then return false end
    for _, c in ipairs(tile:getCreatures() or {}) do
      if knightSafeCreatureId(c) ~= pid then return false end
    end
    return true
  end)
  return ok and walk == true
end

local function pickSideStep(mp, tp)
  local dx, dy = tp.x - mp.x, tp.y - mp.y
  if math.abs(dx) ~= 1 or math.abs(dy) ~= 1 then return nil end
  local a = { x = tp.x, y = mp.y, z = mp.z }
  local b = { x = mp.x, y = tp.y, z = mp.z }
  local okA, okB = tileOkForSideStep(a), tileOkForSideStep(b)
  if not okA and not okB then return nil end
  if okA and not okB then return a end
  if okB and not okA then return b end
  local cur
  pcall(function() cur = player:getDirection() end)
  local dirA = dirToTarget(tp.x - a.x, tp.y - a.y)
  local dirB = dirToTarget(tp.x - b.x, tp.y - b.y)
  local sa, sb = turnSteps(cur, dirA), turnSteps(cur, dirB)
  if sa < sb then return a end
  if sb < sa then return b end
  return a
end

--- Condicões de cast direito (sem estado pendente de turn).
local function hurAlignedAndReady(t, tp, mp)
  if not t or not tp or not mp or tp.z ~= mp.z then return false end
  if not mana or mana() < MIN_MANA then return false end
  if not knightSupportTimingAndSpellOk(SPELL, lastCast, GAP_MS, MIN_MANA) then return false end
  if pickSideStep(mp, tp) then return false end
  local want = dirToTarget(tp.x - mp.x, tp.y - mp.y)
  if want ~= nil and turn then
    local cur
    pcall(function() cur = player:getDirection() end)
    if cur == nil or cur ~= want then return false end
  end
  return true
end

local function hurClaimsSupportSlot()
  local t = knightAttackingCreature()
  if not t then return false end
  local tp, mp = knightTargetPosPair(t)

  if pendingUntil > 0 then
    if now < pendingUntil then return false end
    if knightSafeCreatureId(t) ~= pendingId then return false end
    if canCast and not canCast(SPELL) then return false end
    return true
  end

  return hurAlignedAndReady(t, tp, mp)
end

local function clearTurnPending()
  pendingUntil, pendingId = 0, 0
end

onAttackingCreatureChange(function()
  clearTurnPending()
end)

knightMasExoriHurMacro = macro(180, "Mas Exori Hur", "Shift+5", function()
  if knightChatOpen() then return end
  if knightSupportShouldDefer("mas_exori_hur") then return end

  local t = knightAttackingCreature()
  if not t then return end
  local tp, mp = knightTargetPosPair(t)
  if not tp or not mp or tp.z ~= mp.z then return end
  if not mana or mana() < MIN_MANA then return end

  if pendingUntil > 0 then
    if now < pendingUntil then return end
    if knightSafeCreatureId(t) ~= pendingId then clearTurnPending() return end
    if canCast and not canCast(SPELL) then clearTurnPending() return end
    say(SPELL)
    lastCast = now
    knightTouchSupportCast()
    clearTurnPending()
    return
  end

  if knightMsSinceSupportCast() < knightSupportGap() then return end
  if (now - lastCast) < GAP_MS then return end

  local side = pickSideStep(mp, tp)
  if side then
    if knightIsWalking and knightIsWalking() then return end
    if (now - lastSideStep) < SIDE_STEP_GAP_MS then return end
    if autoWalk then
      autoWalk(side, 20, { ignoreNonPathable = true, precision = 1 })
      lastSideStep = now
    end
    return
  end

  local want = dirToTarget(tp.x - mp.x, tp.y - mp.y)
  if want ~= nil and turn then
    local cur
    pcall(function() cur = player:getDirection() end)
    if cur == nil or cur ~= want then
      pcall(function() turn(want) end)
      local tid = knightSafeCreatureId(t)
      if tid ~= 0 then
        pendingUntil = now + TURN_DELAY_MS
        pendingId = tid
      end
      return
    end
  end

  if canCast and not canCast(SPELL) then return end
  say(SPELL)
  lastCast = now
  knightTouchSupportCast()
end)

knightSupportPriorityRegister("mas_exori_hur", function()
  if not knightSupportMacroEnabled(knightMasExoriHurMacro) then return false end
  if knightChatOpen() then return false end
  return hurClaimsSupportSlot()
end)
