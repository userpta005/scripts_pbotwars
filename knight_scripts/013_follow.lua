--[[
  013_follow.lua — Follow PVP (só caminha; não mantém attack no líder).

  Com a macro ligada, o próximo player atacado passa a ser `followLeader`. Perseguição por
  `autoWalk`; mudança de Z via motor partilhado (`knightCreateVerticalEngine` de 002).
  Uses em sqm adjacentes via `knightMapUseTopThing` (002).

  Exclusão mútua automática com 012 Auto Chase.
  Depende de: 002_storage_init.lua
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

local FOLLOW_POLL_MS = 85
local SAME_FLOOR_COMFORT_DIST = 2
local INTERRUPTOR_MS = 500
local LADDER_USE_GAP_MS = 280
local LADDER_ACTION_DIST = 4

local followEngine = knightCreateVerticalEngine("_follow")
local followWalkMem = knightCreateWalkMemory(145, 320)

local lastLadderUseAt = 0
local followWasOn = false

local function safeCancelAttack()
  if g_game and g_game.cancelAttack then
    pcall(function() g_game.cancelAttack() end)
  end
end

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

local followMacro = macro(INTERRUPTOR_MS, "Follow PVP", "3", function() end)

onAttackingCreatureChange(function(creature)
  if not followMacro or not followMacro:isOn() then return end
  if knightChatOpen and knightChatOpen() then return end
  if not creature or not creature.isPlayer or not creature:isPlayer() then return end
  local nOk, name = pcall(function() return creature:getName() end)
  if not nOk or type(name) ~= "string" then return end
  name = knightTrim(name)
  if name == "" then return end
  storage.followLeader = name
  storage._target = ""
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

  local ffx, ffy = followEngine.ladderFootXY(lz)

  if lpOk and lp.z == lz then
    followEngine.clear()
    local sameDist = getDistanceBetween(mp, lp)
    if sameDist <= SAME_FLOOR_COMFORT_DIST then return end
    if not followWalkMem.shouldWalk(lp.x, lp.y, lp.z) then return end
    pcall(function()
      autoWalk(lp, 20, { ignoreNonPathable = true, precision = 2 })
    end)
    followWalkMem.remember(lp.x, lp.y, lp.z)
    return
  end

  followEngine.checkOffPlane(lpOk, lp, lz, ffx)

  local function doOtherPlaneWalkUse(wx, wy)
    if not followEngine.armed() then return end
    local target = { x = wx, y = wy, z = lz }
    local dist = getDistanceBetween(mp, target)
    if dist <= LADDER_ACTION_DIST then
      if now - lastLadderUseAt >= LADDER_USE_GAP_MS then
        followEngine.tryLadderUsesAtFoot(wx, wy, lz)
        lastLadderUseAt = now
      end
      return
    end
    if not followWalkMem.shouldWalk(wx, wy, lz) then return end
    pcall(function()
      autoWalk(target, 20, { ignoreNonPathable = true, precision = 2 })
    end)
    followWalkMem.remember(wx, wy, lz)
  end

  if ffx and followEngine.armed() then
    doOtherPlaneWalkUse(ffx, ffy)
    return
  end

  if lpOk and lp and lp.z ~= lz and followEngine.armed() then
    doOtherPlaneWalkUse(lp.x, lp.y)
  end
end)

onCreaturePositionChange(function(creature, newPos, oldPos)
  if not followMacro or followMacro:isOff() then return end
  local lname = knightTrim(storage.followLeader or "")
  if lname == "" then return end
  followEngine.onTargetMoved(creature, newPos, oldPos, lname)
  followEngine.onLocalPlayerAscend(creature, newPos, oldPos, lname)
end)

local btnClearFollow

local function clearFollow()
  storage.followLeader = ""
  followEngine.clear()
  followWalkMem.clear()
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
    followEngine.clear()
    followWalkMem.clear()
  end
  followWasOn = on
  storage._followEnabled = on
end)
