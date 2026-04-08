--[[
  018_push_control.lua — Push assistido: destino sob cursor, vítima por target,
  aproxima e empurra até o tile destino.

  Depende de: 002_storage_init.lua (`knightTrim`, `knightFlashBtn`, `knightIsWalking`,
  `knightEnsureStorage`).
]]

storage = storage or {}
if knightEnsureStorage then
  knightEnsureStorage({
    pushVictimName = "",
    lastAttacked = "",
    _pushActive = false,
    _pushDest = nil,
  })
end

local trim = knightTrim
local flashBtn = knightFlashBtn

local PUSH_INTERVAL = 480
local pushDest, pushActive, lastPushAt = nil, false, 0
local lastPushWalkAt = 0
local btnPushDest, btnPushMark, btnPushGo, btnPushStop

local function setPushDest()
  pcall(function()
    local tile = getTileUnderCursor()
    if tile then
      pushDest = tile:getPosition()
      storage._pushDest = pushDest
      flashBtn(btnPushDest)
    end
  end)
end

local function markPushVictim()
  local ok, t = pcall(function() return g_game.getAttackingCreature() end)
  if ok and t then
    local pOk, isP = pcall(function() return t:isPlayer() end)
    if pOk and isP then
      local nOk, n = pcall(function() return t:getName() end)
      if nOk and type(n) == "string" and n ~= "" then
        storage.pushVictimName = trim(n)
        flashBtn(btnPushMark)
        return
      end
    end
  end
  local fallback = trim(storage.lastAttacked or "")
  if fallback ~= "" then
    storage.pushVictimName = fallback
    flashBtn(btnPushMark)
  end
end

local function stopPush()
  pushActive = false
  storage._pushActive = false
  flashBtn(btnPushStop)
end

local function startPush()
  if trim(storage.pushVictimName) == "" then markPushVictim() end
  if trim(storage.pushVictimName) == "" or not pushDest then return end
  pushActive = true
  storage._pushActive = true
  flashBtn(btnPushGo)
end

btnPushDest = addButton("btn_push_dest", "Push Dest [Shift+V]", setPushDest)
btnPushMark = addButton("btn_push_mark", "Marcar alvo [Shift+B]", markPushVictim)
btnPushGo   = addButton("btn_push_go",   "Ir empurrar [Shift+X]", startPush)
btnPushStop = addButton("btn_push_stop", "Parar push [Shift+Z]",  stopPush)

hotkey("Shift+V", setPushDest)
hotkey("Shift+B", markPushVictim)
hotkey("Shift+X", startPush)
hotkey("Shift+Z", stopPush)

macro(220, function()
  if not pushActive or not pushDest then return end
  local vname = trim(storage.pushVictimName)
  if vname == "" then pushActive = false; return end

  local ok, creature = pcall(function() return getPlayerByName(vname, true) end)
  if not ok or not creature then return end
  local cpOk, cp = pcall(function() return creature:getPosition() end)
  if not cpOk or not cp then return end

  if cp.x == pushDest.x and cp.y == pushDest.y and cp.z == pushDest.z then
    pushActive = false
    storage._pushActive = false
    return
  end

  local mp = pos and pos() or nil
  if not mp then return end
  if mp.z ~= cp.z or getDistanceBetween(mp, cp) > 1 then
    if not knightIsWalking() and (now - lastPushWalkAt) >= 170 then
      pcall(function() autoWalk(cp, 20, { ignoreNonPathable = true, precision = 1 }) end)
      lastPushWalkAt = now
    end
    return
  end

  if knightIsWalking() then return end
  if mp.x == cp.x and mp.y == cp.y then return end
  if now - lastPushAt < PUSH_INTERVAL then return end

  local dx, dy = pushDest.x - cp.x, pushDest.y - cp.y
  local sx = dx == 0 and 0 or (dx > 0 and 1 or -1)
  local sy = dy == 0 and 0 or (dy > 0 and 1 or -1)
  local np = { x = cp.x + sx, y = cp.y + sy, z = cp.z }
  if np.x == mp.x and np.y == mp.y then return end

  local tOk, destTile = pcall(function() return g_map.getTile(np) end)
  if not tOk or not destTile then return end
  local wOk, walkable = pcall(function() return destTile:isWalkable() end)
  if not wOk or not walkable then return end
  local crOk, cr = pcall(function() return destTile:getCreatures() end)
  if crOk and cr then
    for _, c in ipairs(cr) do if c ~= creature then return end end
  end

  lastPushAt = now
  pcall(function() g_game.move(creature, np) end)
end)
