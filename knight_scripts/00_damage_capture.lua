-- [INICIO] 00_damage_capture.lua

-- Atualiza lastAttackedMe (quem te bateu) e lastAttacked (ultimo player que voce atacou).
storage = storage or {}
if knightEnsureStorage then
  knightEnsureStorage({ lastAttackedMe = "", lastAttacked = "" })
end

-- Modo de mensagem do cliente equivalente a dano recebido.
local MSG_DMG = (MessageModes and MessageModes.DamageReceived) or 22

-- Mesmo trim do pacote para normalizar nomes extraidos do log.
local trim = knightTrim

onTextMessage(function(mode, text)
  -- So processa linhas de dano recebido.
  if mode ~= MSG_DMG or not text then return end
  -- Parser tolerante a formatos comuns de log de dano.
  local name = text:match("due to an attack by (.+)%.$")
    or text:match("^(.+) hits you for")
    or text:match("hit by (.+) for")
  -- Guarda nome limpo para HUD e rotinas que reagem a ameaca.
  if name and name ~= "" then storage.lastAttackedMe = trim(name) end
end)

onAttackingCreatureChange(function(creature)
  -- Registra apenas players como ultimo alvo ofensivo.
  if not creature or not creature:isPlayer() then return end
  storage.lastAttacked = creature:getName()
end)

-- [FIM] 00_damage_capture.lua
