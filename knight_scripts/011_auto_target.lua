--[[
  011_auto_target.lua — Lock PVP (`storage._target`) + Auto Chase.

  Auto Target: reataca jogador lock no mesmo andar.
  Auto Chase: chase mode 1, reattack frequente, `autoWalk` em direcção ao alvo; lógica de
  escadas / portas / “exani tera” alinhada à ideia do 012_follow (rastro + use em volta).

  Requer 001. Estados espelhados em `storage._targetEnabled` / `storage._chaseEnabled` (HUD).
]]

storage = (type(storage) == "table" and storage) or {}
if knightEnsureStorage then
  knightEnsureStorage({
    _target = "",
    _targetId = 0,
    lastAttacked = "",
    _targetEnabled = false,
    _chaseEnabled = false,
  })
end

local REATTACK_GAP_MS = 120
local CHASE_ATTACK_GAP_MS = 50
local CHASE_WALK_GAP_MS = 100

--- Throttle genérico por chave (usa `now` do bot).
local throttleAt = {}
local function throttle(key, ms)
  if (now - (throttleAt[key] or 0)) < ms then return false end
  throttleAt[key] = now
  return true
end

local function gameAttackReady()
  return g_game and g_game.isAttacking and g_game.getAttackingCreature and g_game.attack
end

local function safeAttack(creature)
  if not creature or not gameAttackReady() then return end
  pcall(function() g_game.attack(creature) end)
end

local function useTopThing(x, y, z)
  if not g_map or not g_map.getTile then return end
  pcall(function()
    local tile = g_map.getTile({ x = x, y = y, z = z })
    local top = tile and tile:getTopUseThing()
    if top and g_game and g_game.use then g_game.use(top) end
  end)
end

local function useSurroundingChase()
  for i = -1, 1 do
    for j = -1, 1 do
      useTopThing(posx() + i, posy() + j, posz())
    end
  end
end

local lastExaniChaseAt = 0
local function tryExaniChase()
  if now - lastExaniChaseAt < 900 then return end
  if say then say("exani tera") end
  lastExaniChaseAt = now
end

local function chaseResolveTargetAnyFloor(tname)
  local c = knightFindLockedPlayer(tname, false)
  if c then return c end
  if getCreatureByName then
    local ok, x = pcall(function() return getCreatureByName(tname) end)
    if ok and x then return x end
  end
  return nil
end

--- Rastro: alvo lock mudou de posição (Auto Chase ligado).
local function onChaseTargetMoved(creature, newPos, oldPos)
  if not creature or not oldPos then return end
  local nOk, cname = pcall(function() return creature:getName() end)
  if not nOk or type(cname) ~= "string" then return end
  local tname = knightTrim(storage._target or "")
  if tname == "" or not knightNameMatchLock(tname, cname) then return end

  if not newPos then
    schedule(200, function()
      if autoWalk then autoWalk(oldPos) end
    end)
    schedule(1000, useSurroundingChase)
  elseif oldPos.z == newPos.z then
    if autoWalk then autoWalk({ x = oldPos.x, y = oldPos.y, z = oldPos.z }) end
    schedule(300, function() useTopThing(oldPos.x, oldPos.y, oldPos.z) end)
  else
    for i = 1, 6 do
      schedule(i * 200, function()
        if autoWalk then autoWalk(oldPos) end
        if getDistanceBetween(pos(), oldPos) == 0 and posz() > newPos.z then
          local see = chaseResolveTargetAnyFloor(tname)
          if not see then tryExaniChase() end
        end
      end)
    end
    useTopThing(newPos.x, newPos.y - 1, newPos.z)
  end
end

--- Jogador local subiu andar: tentar recuperar alvo (exani + use ao redor).
local function onLocalPlayerAscend(creature, newPos, oldPos)
  if not newPos or not oldPos or not creature then return end
  local nOk, cname = pcall(function() return creature:getName() end)
  local pOk, pname = pcall(function() return player:getName() end)
  if not nOk or not pOk or type(cname) ~= "string" or type(pname) ~= "string" or cname ~= pname then return end
  if newPos.z <= oldPos.z then return end
  local tname = knightTrim(storage._target or "")
  if tname == "" then return end
  local see = chaseResolveTargetAnyFloor(tname)
  if not see then
    tryExaniChase()
    useSurroundingChase()
  end
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
  if not knightMacroIsOn(autoChaseMacro) then return end
  onChaseTargetMoved(creature, newPos, oldPos)
  onLocalPlayerAscend(creature, newPos, oldPos)
end)

autoTargetMacro = macro(100, "Auto Target", "Shift+Q", function()
  if knightChatOpen() then return end
  if not gameAttackReady() then return end

  local tname = knightTrim(storage._target or "")
  local target = knightFindLockedPlayer(tname, true)
  if not target then
    if tname ~= "" then storage._targetId = 0 end
    return
  end

  storage._targetId = knightSafeCreatureId(target)

  local cur = g_game.getAttackingCreature()
  local curName = ""
  if cur and cur.isPlayer and cur:isPlayer() then
    local cnOk, cn = pcall(function() return cur:getName() end)
    if cnOk and type(cn) == "string" then curName = knightTrim(cn) end
  end
  if not knightNameMatchLock(tname, curName) or not g_game.isAttacking() then
    if throttle("reattack", REATTACK_GAP_MS) then safeAttack(target) end
  end
end)

local btnClear
local function doClear()
  storage._target = ""
  storage._targetId = 0
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
  if c then safeAttack(c) end
  knightFlashBtn(btnRecover)
end
btnRecover = addButton("btn_recover", "Recover Target [Shift+E]", doRecover)
hotkey("Shift+E", doRecover)

autoChaseMacro = macro(100, "Auto Chase", "2", function()
  if knightChatOpen() then return end
  if knightTrim(storage._target or "") == "" then return end

  if g_game and g_game.getChaseMode and g_game.setChaseMode then
    local okMode, m = pcall(function() return g_game.getChaseMode() end)
    if okMode and m ~= 1 then pcall(function() g_game.setChaseMode(1) end) end
  end

  local target = knightFindLockedPlayer(storage._target, false)
  if not target then
    storage._targetId = 0
    return
  end

  storage._targetId = knightSafeCreatureId(target)

  if gameAttackReady() and throttle("chase_attack", CHASE_ATTACK_GAP_MS) then
    safeAttack(target)
  end

  local tpOk, tp = pcall(function() return target:getPosition() end)
  if not tpOk or not tp or not autoWalk then return end

  local mp = pos()
  if not mp then return end
  local sameZ = (tp.z == mp.z)
  local dist = sameZ and getDistanceBetween(mp, tp) or 999
  if (not sameZ or dist > 1) and throttle("chase_walk", CHASE_WALK_GAP_MS) then
    pcall(function()
      autoWalk(tp, 20, { ignoreNonPathable = true, precision = 1 })
    end)
  end
end)

macro(150, function()
  storage._targetEnabled = knightMacroIsOn(autoTargetMacro)
  storage._chaseEnabled = knightMacroIsOn(autoChaseMacro)
end)
