-- [INICIO] 04_exeta_res.lua

-- Tabela compartilhada com haste/utamo (lastSupportCastAt).
storage = storage or {}

-- Ultimo exeta bem-sucedido; throttle substitui delay() no macro.
local lastExetaAt = 0
-- Pausa minima entre dois "exeta res" (CD longo da spell).
local EXETA_CAST_GAP = 5500
-- Pausa apos haste/utamo/exeta; manter igual aos scripts 02b e 03.
local SUPPORT_CAST_GAP = 1500
-- Mana absoluta minima para o custo tipico de exeta res.
local MIN_MANA = 100
-- Limite por percentual se a API existir no cliente.
local MIN_MANA_PERCENT = 30

-- Tick 200ms; Shift+6 opcional no cliente.
macro(200, "Exeta Res", "Shift+6", function()
  -- So com sessao de ataque ativa.
  if not g_game or not g_game.isAttacking or not g_game.isAttacking() then return end
  -- Alvo que o jogo associa ao ataque.
  local t = g_game.getAttackingCreature and g_game.getAttackingCreature()
  -- Sem criatura de ataque nao ha exeta.
  if not t then return end
  -- Posicao do alvo para distancia; nil ao trocar de alvo.
  local tp = t.getPosition and t:getPosition()
  -- Sem coordenada segura para medir range.
  if not tp then return end
  -- Exeta so em melee (adjacente).
  if getDistanceBetween(pos(), tp) > 1 then return end
  -- Corte por mana absoluta.
  if mana and mana() < MIN_MANA then return end
  -- Corte por percentual de mana.
  if manapercent and manapercent() <= MIN_MANA_PERCENT then return end
  -- Nao colar no ultimo cast de suporte (haste/utamo/outro exeta).
  if now - (storage.lastSupportCastAt or 0) < SUPPORT_CAST_GAP then return end
  -- Nao spammar exeta alem do intervalo proprio.
  if now - lastExetaAt < EXETA_CAST_GAP then return end
  -- API opcional do bot antes de falar a spell.
  if canCast and not canCast("exeta res") then return end
  -- Cast no servidor.
  say("exeta res")
  -- Atualiza anti-flood local deste macro.
  lastExetaAt = now
  -- Propaga tick para os outros spells que usam lastSupportCastAt.
  storage.lastSupportCastAt = now
end)

-- [FIM] 04_exeta_res.lua
