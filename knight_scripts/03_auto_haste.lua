-- [INICIO] 03_auto_haste.lua

-- Necessario para lastSupportCastAt compartilhado com utamo/exeta.
storage = storage or {}

-- Ultimo utani tempo hur lancado com sucesso.
local lastHasteAt = 0
-- Tempo entre dois haste quando o buff ja caiu.
local HASTE_CAST_GAP = 3200
-- Pausa apos qualquer spell que gravou lastSupportCastAt (alinhar com 02b).
local SUPPORT_CAST_GAP = 1500
-- Mana minima para utani knights.
local MIN_MANA = 60
-- Texto exato da spell no cliente.
local HASTE_SPELL = "utani tempo hur"

macro(500, "Auto Haste", "Shift+2", function()
  -- Mana insuficiente para utani.
  if mana and mana() < MIN_MANA then return end
  -- Buff de velocidade ja ativo.
  if hasHaste and hasHaste() then return end
  -- Espacamento compartilhado com utamo/exeta.
  if now - (storage.lastSupportCastAt or 0) < SUPPORT_CAST_GAP then return end
  -- Anti-flood entre dois utani deste macro.
  if now - lastHasteAt < HASTE_CAST_GAP then return end
  say(HASTE_SPELL)
  lastHasteAt = now
  storage.lastSupportCastAt = now
end)

-- [FIM] 03_auto_haste.lua
