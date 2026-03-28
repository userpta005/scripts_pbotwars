--[[
  008_anti_kick.lua — Rotação N→E→S→W para reduzir acumulação de kicks (PVP/OT).

  Pausa quando o chat está aberto. `turn(dir)` vem do contexto game_bot (`player.lua`).
]]

local ROTATE_MS = 680
--- Direcção actual na rotação 0=N, 1=E, 2=S, 3=W.
local dirIndex = 0

macro(ROTATE_MS, "Anti Kick", "Shift+4", function()
  if knightChatOpen() then return end
  if not turn then return end
  pcall(function() turn(dirIndex) end)
  dirIndex = (dirIndex + 1) % 4
end)
