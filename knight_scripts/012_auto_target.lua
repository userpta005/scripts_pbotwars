--[[
  012_auto_target.lua — PVP: Auto Target + Auto Chase (mantém lock e ataca ao colar no alvo).

  - Auto Target (Shift+Q): mantém `g_game.attack` no jogador lockado no mesmo piso.
  - Auto Chase (2): chase mode 1; mesma lógica vertical que Auto Follow (escadas, buracos, etc.)
    via `knightCreateVerticalEngine` (002).

  Auto Follow está em 013: só seguir alguém sem atacar (uso típico PvE). Nunca usar 012 e 013 juntos;
  o pack desliga um quando o outro entra em conflito.
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

local CHASE_POLL_MS = 85
-- Manter igual ao 013 (autoWalk + vertical colados ao líder/alvo).
local SAME_FLOOR_COMFORT_DIST = 1
local REATTACK_GAP_MS = 120
local CHASE_ATTACK_GAP_MS = 50
local LADDER_USE_GAP_MS = 280
local LADDER_ACTION_DIST = 4

local trim = knightTrim or function(s)
  if type(s) ~= "string" then return "" end
  return s:match("^%s*(.-)%s*$") or ""
end
local chatOpen = function()
  return knightChatOpen and knightChatOpen() or false
end
local macroIsOn = knightMacroIsOn or function(m)
  if not m then return false end
  local ok, on = pcall(function() return m:isOn() end)
  if ok and on then return true end
  ok, on = pcall(function() return m:isEnabled() end)
  return ok and on or false
end
local nameMatch = knightNameMatchLock or function(a, b)
  return trim(a) ~= "" and trim(a) == trim(b)
end

local chaseEngine = knightCreateVerticalEngine("_chase")
local chaseWalkMem = knightCreateWalkMemory(100, 260)

local throttleAt = {}
local function throttle(key, ms)
  if (now - (throttleAt[key] or 0)) < ms then return false end
  throttleAt[key] = now
  return true
end

local lastChaseLadderUseAt = 0
local chaseWasOn = false

local autoTargetMacro
local autoChaseMacro

local function safeSetOff(m)
  if not m or not m.setOff then return end
  pcall(function() m:setOff() end)
end

local function disableFollowIfNeeded()
  if macroIsOn(knightFollowMacro) then
    safeSetOff(knightFollowMacro)
    storage.followLeader = ""
  end
end

onAttackingCreatureChange(function(creature, oldCreature)
  if not creature or not creature.isPlayer or not creature:isPlayer() then return end
  local nOk, name = pcall(function() return creature:getName() end)
  if not nOk or type(name) ~= "string" or name == "" then return end
  name = trim(name)
  if macroIsOn(autoTargetMacro) or macroIsOn(autoChaseMacro) then
    storage._target = name
    storage.followLeader = ""
  end
end)

onCreaturePositionChange(function(creature, newPos, oldPos)
  if not autoChaseMacro or autoChaseMacro:isOff() then return end
  local tname = knightTrim(storage._target or "")
  chaseEngine.onTargetMoved(creature, newPos, oldPos, tname)
  chaseEngine.onLocalPlayerAscend(creature, newPos, oldPos, tname)
end)

autoTargetMacro = macro(100, "Auto Target", "Shift+Q", function()
  disableFollowIfNeeded()
  if chatOpen() then return end
  if not knightGameAttackReady() then return end

  local tname = trim(storage._target or "")
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
    if cnOk and type(cn) == "string" then curName = trim(cn) end
  end
  local attacking = false
  pcall(function() attacking = g_game.isAttacking() end)
  if not nameMatch(tname, curName) or not attacking then
    if throttle("reattack", REATTACK_GAP_MS) then knightGameAttack(target) end
  end
end)

autoChaseMacro = macro(CHASE_POLL_MS, "Auto Chase", "2", function()
  if not autoChaseMacro or autoChaseMacro:isOff() then return end
  disableFollowIfNeeded()
  if chatOpen() then return end

  local tname = trim(storage._target or "")
  if tname == "" then
    chaseEngine.clear()
    chaseWalkMem.clear()
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

  local ffx, ffy = chaseEngine.ladderFootXY(lz)

  if lpOk and lp.z == lz then
    chaseEngine.clear()
    local sameDist = getDistanceBetween(mp, lp)
    if sameDist <= SAME_FLOOR_COMFORT_DIST then return end
    if not chaseWalkMem.shouldWalk(lp.x, lp.y, lp.z) then return end
    pcall(function()
      autoWalk(lp, 20, { ignoreNonPathable = true, precision = 1 })
    end)
    chaseWalkMem.remember(lp.x, lp.y, lp.z)
    return
  end

  chaseEngine.checkOffPlane(lpOk, lp, lz, ffx)

  local function doChaseOtherPlaneWalkUse(wx, wy)
    if not chaseEngine.armed() then return end
    local dest = { x = wx, y = wy, z = lz }
    local dist = getDistanceBetween(mp, dest)
    if dist <= LADDER_ACTION_DIST then
      if now - lastChaseLadderUseAt >= LADDER_USE_GAP_MS then
        chaseEngine.tryLadderUsesAtFoot(wx, wy, lz)
        lastChaseLadderUseAt = now
      end
      return
    end
    if not chaseWalkMem.shouldWalk(wx, wy, lz) then return end
    pcall(function()
      autoWalk(dest, 20, { ignoreNonPathable = true, precision = 1 })
    end)
    chaseWalkMem.remember(wx, wy, lz)
  end

  if ffx and chaseEngine.armed() then
    doChaseOtherPlaneWalkUse(ffx, ffy)
    return
  end

  if lpOk and lp and lp.z ~= lz and chaseEngine.armed() then
    doChaseOtherPlaneWalkUse(lp.x, lp.y)
  end
end)

local btnClear
local function doClear()
  storage._target = ""
  storage._targetId = 0
  chaseEngine.clear()
  chaseWalkMem.clear()
  if g_game and g_game.cancelAttackAndFollow then
    pcall(function() g_game.cancelAttackAndFollow() end)
  end
  knightFlashBtn(btnClear)
end
btnClear = addButton("btn_clear", "Clear Target [4]", doClear)
hotkey("4", doClear)

local btnRecover
local function doRecover()
  if chatOpen() then return end
  local name = trim(storage.lastAttacked or "")
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
    chaseEngine.clear()
    chaseWalkMem.clear()
  elseif not on and chaseWasOn then
    chaseEngine.clear()
    chaseWalkMem.clear()
  end
  chaseWasOn = on and true or false
  storage._targetEnabled = macroIsOn(autoTargetMacro)
  storage._chaseEnabled = on
end)

knightAutoTargetMacro = autoTargetMacro
knightAutoChaseMacro = autoChaseMacro
