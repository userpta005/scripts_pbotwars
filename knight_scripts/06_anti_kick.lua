-- [INICIO] 06_anti_kick.lua

-- Indice 0..3 do proximo turn() no ciclo N-E-S-O.
local antiKickDir = 0

macro(680, "Anti Kick", "Shift+4", function()
  -- Gira o personagem na direcao corrente do ciclo.
  turn(antiKickDir)
  -- Avanca N->E->S->O e volta ao norte.
  antiKickDir = (antiKickDir + 1) % 4
end)

-- [FIM] 06_anti_kick.lua
