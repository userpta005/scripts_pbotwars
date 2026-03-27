-- [INICIO] 02b_auto_utamo_tempo.lua

-- Necessario para lastSupportCastAt compartilhado com haste/exeta.
storage = storage or {}

-- Ultimo utamo bem-sucedido.
local lastUtamoAt = 0
-- Intervalo entre recasts de utamo mantendo o shield.
local UTAMO_CAST_GAP = 2300
-- Espacamento com outros spells que usam lastSupportCastAt (igual ao 03).
local SUPPORT_CAST_GAP = 1500
-- Mana minima absoluta para tentar o cast.
local MIN_MANA = 40

macro(250, "Auto Utamo Tempo", "Shift+1", function()
  -- Sem haste ativo o buff de suporte prioriza utani (outro script).
  if hasHaste and not hasHaste() then return end
  -- Ja protegido por shield ou buff equivalente.
  if (hasManaShield and hasManaShield()) or (hasPartyBuff and hasPartyBuff()) then return end
  -- Mana insuficiente para utamo.
  if not mana or mana() < MIN_MANA then return end
  -- Nao encostar no ultimo suporte/exeta registrado em storage.
  if now - (storage.lastSupportCastAt or 0) < SUPPORT_CAST_GAP then return end
  -- Intervalo proprio entre utamos.
  if now - lastUtamoAt < UTAMO_CAST_GAP then return end
  say("utamo tempo")
  lastUtamoAt = now
  storage.lastSupportCastAt = now
end)

-- [FIM] 02b_auto_utamo_tempo.lua
