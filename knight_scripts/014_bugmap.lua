--[[
  014_bugmap.lua — “Bug map”: use em linha na direcção das teclas WASD/QEZC.

  Lê teclas via `modules.corelib.g_keyboard` (isKeyPressed). Usa `knightMapUseTopThing` no pé e
  ao longo do vector até ao comprimento do offset (máx 5 passos por eixo).

  Depende de: 001_storage_init.lua (`knightChatOpen`, `knightMapUseTopThing`).
  PVE/PVP: cuidado em PVP (uses visíveis); mesmo comportamento técnico.
]]

local BUG_DIRS = {
  w = { 0, -5 }, e = { 3, -3 }, d = { 5, 0 }, c = { 3, 3 },
  s = { 0, 5 }, z = { -3, 3 }, a = { -5, 0 }, q = { -3, -3 },
}

macro(50, "BugMap", "Shift+T", function()
  if knightChatOpen and knightChatOpen() then return end
  local k = modules.corelib and modules.corelib.g_keyboard
  if not k or not k.isKeyPressed then return end

  local dx, dy
  for key, dir in pairs(BUG_DIRS) do
    if k.isKeyPressed(key) then
      dx, dy = dir[1], dir[2]
      break
    end
  end
  if not dx then return end

  local mp = pos and pos() or nil
  if not mp then return end

  knightMapUseTopThing(mp.x, mp.y, mp.z)
  local steps = math.max(math.abs(dx), math.abs(dy))
  local sx = dx == 0 and 0 or (dx > 0 and 1 or -1)
  local sy = dy == 0 and 0 or (dy > 0 and 1 or -1)
  for i = 1, steps do
    knightMapUseTopThing(mp.x + sx * i, mp.y + sy * i, mp.z)
  end
end)
