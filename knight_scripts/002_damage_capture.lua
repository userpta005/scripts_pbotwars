--[[
  002_damage_capture.lua — Actualiza `storage` para HUD / rotas que precisam de nomes.

  - `lastAttackedMe`: quem originou dano recebido (log do cliente, vários idiomas).
  - `lastAttacked`: nome da criatura que passou a ser alvo de ataque.

  Dependência: 001_storage_init.lua (`knightEnsureStorage`, `knightTrim`).
]]

storage = (type(storage) == "table" and storage) or {}
if knightEnsureStorage then
  knightEnsureStorage({ lastAttackedMe = "", lastAttacked = "" })
end

--- Modo de mensagem “dano recebido” (`modules/gamelib/const.lua` / MessageModes).
local MSG_DMG = (MessageModes and MessageModes.DamageReceived) or 22

--- Ordem: padrões mais específicos primeiro (evita captura ambígua).
local DMG_NAME_PATTERNS = {
  "due to an attack by (.+)%.$",
  "due to an attack by (.+)$",
  "^(.+) hits you for",
  "hit by (.+) for",
  "devido a um ataque de (.+)%.$",
  "por um ataque de (.+)%.$",
}

local function setAttackedMe(name)
  if type(storage) ~= "table" or type(name) ~= "string" or name == "" then return end
  storage.lastAttackedMe = knightTrim(name)
end

local function setLastAttacked(creature)
  if type(storage) ~= "table" or not creature then return end
  local ok, n = pcall(function() return creature:getName() end)
  if ok and type(n) == "string" and n ~= "" then storage.lastAttacked = knightTrim(n) end
end

onTextMessage(function(mode, text)
  if mode ~= MSG_DMG or type(text) ~= "string" or text == "" then return end
  for _, pat in ipairs(DMG_NAME_PATTERNS) do
    local name = text:match(pat)
    if name then setAttackedMe(name) break end
  end
end)

onAttackingCreatureChange(function(creature, oldCreature)
  setLastAttacked(creature)
end)
