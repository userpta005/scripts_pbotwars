-- [INICIO] 05_anti_paralyze.lua

-- Ultimo utani usado so para quebrar paralyze.
local lastAntiParaAt = 0
-- Debounce curto mas suficiente para nao spammar utani em paralyze.
local ANTI_PARA_CAST_GAP = 1700

macro(100, "Anti Paralyze", "Shift+3", function()
  -- Fora de paralyze nao gasta mana nem exhaust.
  if not isParalyzed() then return end
  -- Evita spammar utani enquanto o servidor ainda nega cast.
  if now - lastAntiParaAt < ANTI_PARA_CAST_GAP then return end
  say("utani tempo hur")
  lastAntiParaAt = now
end)

-- [FIM] 05_anti_paralyze.lua
