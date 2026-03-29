--[[
  016_pull_items.lua — Puxar itens dos 8 sqm vizinhos para o pé (2 direções por tick).

  Considera pickupable ou não “NotMoveable” (API do item). Usa `g_game.move`; só quando parado.

  Depende de: 002_storage_init.lua (`knightChatOpen`, `knightIsWalking`).
  PVE: útil para loot no chão; PVP: pode ser lento — desliga se não quiseres o ruído.
]]

local PD = {
  { -1, -1 }, { 0, -1 }, { 1, -1 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 },
}
local pullTick = 0

local function itemCanPull(item)
  if not item then return false end
  local ok, pick = pcall(function() return item:isPickupable() end)
  if ok and pick then return true end
  ok, pick = pcall(function()
    return item.isNotMoveable and not item:isNotMoveable()
  end)
  return ok and pick == true
end

macro(260, "Puxar Itens", "Shift+F", function()
  if knightChatOpen and knightChatOpen() then return end
  if knightIsWalking and knightIsWalking() then return end
  if not g_map or not g_map.getTile or not g_game or not g_game.move then return end

  local mp = pos and pos() or nil
  if not mp then return end

  pullTick = pullTick + 1
  for off = 0, 1 do
    local idx = ((pullTick - 1 + off) % #PD) + 1
    local d = PD[idx]
    local ok, tile = pcall(function()
      return g_map.getTile({ x = mp.x + d[1], y = mp.y + d[2], z = mp.z })
    end)
    if ok and tile then
      local items = tile.getItems and tile:getItems() or {}
      for _, item in ipairs(items) do
        if itemCanPull(item) then
          local cnt = 1
          pcall(function() cnt = item:getCount() end)
          pcall(function() g_game.move(item, mp, cnt) end)
          return
        end
      end
    end
  end
end)
