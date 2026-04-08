--[[
  009_anti_kick.lua - Rotacao periodica do facing (N->E->S->W).

  Em alguns OTs reduz efeito de "kick"/empurrao posicional.
  Pausa se o chat de texto estiver ativo.

  Depende de: 002_storage_init.lua (`knightChatOpen`) quando disponivel.
]]

local ROTATE_MS = 680
local dirIndex = 0 -- 0=N, 1=E, 2=S, 3=W

macro(ROTATE_MS, "Anti Kick", "Shift+4", function()
  if knightChatOpen and knightChatOpen() then return end
  if not turn then return end
  pcall(function() turn(dirIndex) end)
  dirIndex = (dirIndex + 1) % 4
end)
