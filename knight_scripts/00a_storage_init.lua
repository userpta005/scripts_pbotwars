-- [INICIO] 00a_storage_init.lua

-- Garante tabela global antes de registrar defaults.
storage = storage or {}

-- Preenche chaves faltantes em storage sem sobrescrever valores ja definidos.
function knightEnsureStorage(defaults)
  if type(defaults) ~= "table" then return end
  -- So define chave ausente; nunca sobrescreve valor ja existente em storage.
  for key, value in pairs(defaults) do
    if storage[key] == nil then
      storage[key] = value
    end
  end
end

-- Remove espacos no inicio e fim da string (uso em nomes digitados).
function knightTrim(s)
  return s and s:match("^%s*(.-)%s*$") or ""
end

-- Feedback visual rapido em botoes do painel do bot.
function knightFlashBtn(b)
  if not b then return end
  pcall(function() b:setImageColor("green") end)
  schedule(500, function() pcall(function() b:setImageColor("white") end) end)
end

-- Chaves compartilhadas pelo pacote; ausencia aqui evita nil em outros arquivos.
knightEnsureStorage({
  lastAttackedMe = "",
  lastAttacked = "",
  _target = "",
  _targetId = 0,
  _targetEnabled = false,
  _chaseEnabled = false,
  followLeader = "",
  _followEnabled = false,
  pushVictimName = "",
  _pushActive = false,
  _pushDest = nil,
  lastExivaName = "",
  lastExivaMessage = "",
  lastExivaDist = "",
  exivaManualName = "",
  lastExivaTime = 0,
  lastSupportCastAt = 0,
})

-- [FIM] 00a_storage_init.lua
