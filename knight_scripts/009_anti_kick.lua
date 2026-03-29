--[[
  009_anti_kick.lua — Rotação periódica do facing (N→E→S→W).

  Em alguns OTs reduz efeito de “kick”/empurrão posicional. Usa `turn` (= g_game.turn do bot).
  Pausa se o chat de texto estiver activo.

  Depende de: 002_storage_init.lua (`knightChatOpen`)
  PVP: mais relevante; PVE: inofensivo se preferires desligar.
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
