-- [INICIO] 018_push_control.lua
--
-- Objetivo: defines tile destino (cursor), vítima (target ou last attacked), ativas “push”
--   e o macro aproxima em melee e faz `move` da criatura tile a tile até ao destino.

-- Push assistido: destino sob cursor, vitima por target, aproxima e empurra ate o tile.
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
-- Estado local de runtime.
local pushDest, pushActive, lastPushAt = nil, false, 0
local lastPushWalkAt = 0
local btnPushDest, btnPushMark, btnPushGo, btnPushStop

local function setPushDest()
  pcall(function()
    -- Lendo tile sob cursor no map panel.
    local tile = getTileUnderCursor()
    if tile then
      -- Salva destino local e espelha em storage para HUD.
      pushDest = tile:getPosition()
      storage._pushDest = pushDest
      flashBtn(btnPushDest)
    end
  end)
end

-- Marca vitima pelo target atual; fallback para ultimo atacado.
local function markPushVictim()
  local t = g_game.getAttackingCreature()
  if t and t:isPlayer() then
    storage.pushVictimName = trim(t:getName())
    flashBtn(btnPushMark)
    return
  end
  local fallback = trim(storage.lastAttacked)
  if fallback ~= "" then
    storage.pushVictimName = fallback
    flashBtn(btnPushMark)
  end
end

local function stopPush()
  -- Desliga runtime local e estado publico.
  pushActive = false
  storage._pushActive = false
  flashBtn(btnPushStop)
end
local function startPush()
  -- Se nao houver vitima, tenta marcar automaticamente.
  if trim(storage.pushVictimName) == "" then markPushVictim() end
  -- So inicia com vitima e destino definidos.
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

-- Runtime do push: aproxima, valida tile destino e move criatura com intervalo seguro.
macro(220, function()
  -- Sai se automacao nao estiver ativa.
  if not pushActive or not pushDest then return end
  local vname = trim(storage.pushVictimName)
  -- Sem vitima valida, encerra o push.
  if vname == "" then pushActive = false; return end

  -- Resolve a criatura alvo no espectro atual.
  local creature = getPlayerByName(vname, true)
  if not creature then return end
  local cp = creature:getPosition()
  if not cp then return end

  -- Alvo ja chegou no destino: encerra.
  if cp.x == pushDest.x and cp.y == pushDest.y and cp.z == pushDest.z then
    pushActive = false
    storage._pushActive = false
    return
  end

  -- Se ainda nao esta em range para empurrar, aproxima.
  local mp = pos()
  if mp.z ~= cp.z or getDistanceBetween(mp, cp) > 1 then
    if not player:isWalking() and (now - lastPushWalkAt) >= 170 then
      autoWalk(cp, 20, { ignoreNonPathable = true, precision = 1 })
      lastPushWalkAt = now
    end
    return
  end

  if player:isWalking() then return end
  -- Se player e vitima estao no mesmo tile, evita self-collision de move.
  if mp.x == cp.x and mp.y == cp.y then return end
  -- Respeita intervalo minimo entre pushes.
  if now - lastPushAt < PUSH_INTERVAL then return end

  -- Proximo passo da vitima na direcao do destino.
  local dx, dy = pushDest.x - cp.x, pushDest.y - cp.y
  local sx = dx == 0 and 0 or (dx > 0 and 1 or -1)
  local sy = dy == 0 and 0 or (dy > 0 and 1 or -1)
  local np = { x = cp.x + sx, y = cp.y + sy, z = cp.z }
  -- Nao empurra para cima do proprio player.
  if np.x == mp.x and np.y == mp.y then return end

  -- Destino precisa ser walkable e sem bloquear por outra criatura.
  local destTile = g_map.getTile(np)
  if not destTile or not destTile:isWalkable() then return end
  local cr = destTile:getCreatures()
  if cr then for _, c in ipairs(cr) do if c ~= creature then return end end end

  lastPushAt = now
  g_game.move(creature, np)
end)

-- [FIM] 018_push_control.lua
