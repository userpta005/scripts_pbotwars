-- [INICIO] 02_auto_exori_gauge.lua

-- Ultimo cast de exori gauge (evita flood no macro).
local lastGaugeAt = 0
-- Espacamento minimo entre casts consecutivos.
local GAUGE_CAST_GAP = 2300
-- Mana minima para nao falar a spell no ar.
local MIN_MANA = 90

macro(300, "Auto Exori Gauge", "Shift+0", function()
  -- Buff de party ja cobre o efeito; nao recasta.
  if hasPartyBuff and hasPartyBuff() then return end
  -- Corta se mana() inexistente ou pool baixo.
  if not mana or mana() < MIN_MANA then return end
  -- Anti-flood proprio do gauge.
  if now - lastGaugeAt < GAUGE_CAST_GAP then return end
  say("exori gauge")
  -- Marca tick para o proximo cast permitido.
  lastGaugeAt = now
end)

-- [FIM] 02_auto_exori_gauge.lua
