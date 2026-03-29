--[[
  017_anti_push.lua — Encher o tile do pé com moedas (alterna gold/platinum) ou usar crystal coin.

  Objectivo: reduz empurrões em alguns servidores. Limite de stacks visíveis no tile para evitar
  spam. Só corre quando parado; inventário via `getContainers()` do bot.

  Depende de: 002_storage_init.lua (`knightChatOpen`, `knightIsWalking`).
  PVP: ATENÇÃO — deixa lixo no chão e gasta recursos; avalia risco.
]]

local ITEM_GOLD, ITEM_PLAT, ITEM_CRYSTAL = 3031, 3035, 3043
local TILE_MAX_STACKS = 8

local dropGold = true

macro(420, "Anti Push", "Shift+G", function()
  if knightChatOpen and knightChatOpen() then return end
  if knightIsWalking and knightIsWalking() then return end
  if not g_map or not g_map.getTile or not g_game or not g_game.move or not g_game.use then return end

  local mp = pos and pos() or nil
  if not mp then return end

  local ok, tile = pcall(function() return g_map.getTile(mp) end)
  if not ok or not tile then return end
  local items = tile.getItems and tile:getItems() or {}
  if #items >= TILE_MAX_STACKS then return end

  local gold, plat, crystal
  if getContainers then
    local cOk, containers = pcall(getContainers)
    if cOk and type(containers) == "table" then
      for _, c in pairs(containers) do
        if c and c.getItems then
          for _, item in ipairs(c:getItems() or {}) do
            local idOk, id = pcall(function() return item:getId() end)
            if idOk and type(id) == "number" then
              if id == ITEM_GOLD and not gold then gold = item
              elseif id == ITEM_PLAT and not plat then plat = item
              elseif id == ITEM_CRYSTAL and not crystal then crystal = item
              end
            end
          end
        end
      end
    end
  end

  local function moveOne(it, nextDropGold)
    pcall(function() g_game.move(it, mp, 1) end)
    dropGold = nextDropGold
  end

  if dropGold then
    if gold then moveOne(gold, false) return end
    if plat then pcall(function() g_game.use(plat) end) return end
    if crystal then pcall(function() g_game.use(crystal) end) return end
  else
    if plat then moveOne(plat, true) return end
    if crystal then pcall(function() g_game.use(crystal) end) return end
  end
end)
