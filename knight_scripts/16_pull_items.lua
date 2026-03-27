-- [INICIO] 16_pull_items.lua

-- Offsets em anel ao redor do player; pullTick rotaciona qual lado checa neste tick.
local PD = {{-1,-1},{0,-1},{1,-1},{1,0},{1,1},{0,1},{-1,1},{-1,0}}
local pullTick = 0

macro(260, "Puxar Itens", "Shift+F", function()
  -- Nao tenta puxar durante deslocamento.
  if player:isWalking() then return end
  -- Posicao do player.
  local mp = pos()
  -- Avanca fase da varredura circular.
  pullTick = pullTick + 1
  -- Checa 2 direcoes por tick para manter custo baixo.
  for off = 0, 1 do
    local idx = ((pullTick - 1 + off) % #PD) + 1
    local d = PD[idx]
    -- Tile candidato ao redor.
    local tile = g_map.getTile({ x = mp.x + d[1], y = mp.y + d[2], z = mp.z })
    if tile then
      -- Percorre itens do tile procurando algo movivel/pickup.
      for _, item in ipairs(tile:getItems() or {}) do
        local can = false
        pcall(function()
          can = item:isPickupable() or (item.isNotMoveable and not item:isNotMoveable())
        end)
        -- Ao achar item valido, move para o pe do player e encerra tick.
        if can then g_game.move(item, mp, item:getCount()); return end
      end
    end
  end
end)

-- [FIM] 16_pull_items.lua
