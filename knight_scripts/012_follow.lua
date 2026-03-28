-- [INICIO] 012_follow.lua
--
-- Objetivo: com macro “Follow PVP” ligada, o último player que atacaste vira líder;
--   persegue com autoWalk; em mudanças de posição do líder tenta pisar/use e exani
--   quando há salto de floor.

-- Segue lider escolhido por ataque com macro ligada; troca de andar usa exani + use em tiles.
storage = storage or {}
if knightEnsureStorage then
  knightEnsureStorage({
    followLeader = "",
    lastAttacked = "",
    _followEnabled = false,
  })
end

local flashBtn = knightFlashBtn

-- Usa objeto interativo do topo do tile (escada, alavanca, etc.).
local function useTopThing(x, y, z)
  local tile = g_map.getTile({x = x, y = y, z = z})
  local top = tile and tile:getTopUseThing()
  if top then g_game.use(top) end
end

-- Varre vizinhanca tentando ativar saida de mapa apos troca de floor.
local function useSurroundingTiles()
  for i = -1, 1 do
    for j = -1, 1 do
      useTopThing(posx() + i, posy() + j, posz())
    end
  end
end

local lastExaniTeraAt = 0
local lastFollowWalkAt = 0
-- Exani com throttle para nao gastar exhaust em loop.
local function tryExaniTera()
  if now - lastExaniTeraAt < 900 then return end
  say("exani tera")
  lastExaniTeraAt = now
end

-- Macro vazia: serve só como interruptor (isOn) para o resto da lógica.
local followMacro = macro(50, "Follow PVP", "3", function() end)

-- Com follow ligado, o player atacado vira lider automaticamente.
onAttackingCreatureChange(function(creature)
  if not followMacro or not followMacro:isOn() then return end
  if not creature or not creature:isPlayer() then return end
  storage.lastAttacked = creature:getName()
  storage.followLeader = creature:getName()
end)

macro(250, function()
  if not followMacro or not followMacro:isOn() then return end
  if storage.followLeader == "" then return end
  local leader = getPlayerByName(storage.followLeader, true)
  if not leader then return end
  local lp = leader:getPosition()
  -- Diferente de andar nao persegue (evita path louco entre floors).
  if not lp or lp.z ~= posz() then return end
  -- Autowalk throttled quando nao esta adjacente ao lider.
  if getDistanceBetween(pos(), lp) > 1 then
    if now - lastFollowWalkAt >= 170 then
      autoWalk(lp, 20, { ignoreNonPathable = true, precision = 1 })
      lastFollowWalkAt = now
    end
  end
end)

-- Reage ao líder (e a ti) mudando de tile: mesmo floor rasto, floor novo usa agendamentos.
onCreaturePositionChange(function(creature, newPos, oldPos)
  if not followMacro or followMacro:isOff() then return end
  if not creature or not oldPos then return end
  local cname = creature:getName()

  if cname == storage.followLeader then
    -- Líder desapareceu do mapa (teleport/subsolo): última pos + varrer tiles.
    if not newPos then
      -- Lider sumiu do mapa: tenta ultima posicao e depois usa tiles ao redor.
      schedule(200, function() autoWalk(oldPos) end)
      schedule(1000, useSurroundingTiles)
    elseif oldPos.z == newPos.z then
      -- Mesmo andar: pisa no rastro e usa o tile que ele deixou (portas/escadas).
      autoWalk({x = oldPos.x, y = oldPos.y, z = oldPos.z})
      schedule(300, function() useTopThing(oldPos.x, oldPos.y, oldPos.z) end)
    else
      -- Outro Z: vários autoWalk para oldPos; se colado no degrau e sem ver líder, exani tera.
      for i = 1, 6 do
        schedule(i * 200, function()
          autoWalk(oldPos)
          if getDistanceBetween(pos(), oldPos) == 0 and posz() > newPos.z
            and not getCreatureByName(storage.followLeader) then
            tryExaniTera()
          end
        end)
      end
      useTopThing(newPos.x, newPos.y - 1, newPos.z)
    end
  end

  -- Voce subiu e perdeu visao do lider: exani + use ao redor.
  if newPos and cname == player:getName() and newPos.z > oldPos.z then
    local targetName = storage.followLeader
    if targetName and targetName ~= "" and not getCreatureByName(targetName) then
      tryExaniTera()
      useSurroundingTiles()
    end
  end
end)

local btnClearFollow
-- Zera lider e cancela follow pendente no cliente.
local function clearFollow()
  storage.followLeader = ""
  g_game.cancelAttackAndFollow()
  flashBtn(btnClearFollow)
end

btnClearFollow = addButton("btn_clear_follow", "Clear Follow [1]", clearFollow)
hotkey("1", clearFollow)

macro(150, function()
  -- Publica flag de follow para HUD e outros modulos.
  storage._followEnabled = followMacro:isOn()
end)

-- [FIM] 012_follow.lua
