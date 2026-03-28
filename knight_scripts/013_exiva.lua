-- [INICIO] 013_exiva.lua
--
-- Objetivo: cast `exiva "nome"` (manual ou último alvo), guarda resposta do servidor,
--   traduz trechos EN para etiquetas curtas, extrai distância aproximada e mostra HUD + grade de runa.

-- Exiva por nome/ultimo alvo, captura da mensagem, traducao e HUD com runa direcional.
storage = storage or {}
if knightEnsureStorage then
  knightEnsureStorage({
    lastExivaName = "",
    lastExivaMessage = "",
    lastExivaDist = "",
    exivaManualName = "",
    lastExivaTime = 0,
    lastAttacked = "",
  })
end

local trim = knightTrim
local flashBtn = knightFlashBtn

local MSG_GAME = (MessageModes and MessageModes.Game) or 18
local MSG_LOOK = (MessageModes and MessageModes.Look) or 20

local EX_DIRS = {
  {"south%-west","SW","sudoeste"}, {"south%-east","SE","sudeste"},
  {"north%-west","NW","noroeste"}, {"north%-east","NE","nordeste"},
  {"south","S","sul"}, {"north","N","norte"},
  {"east","E","leste"}, {"west","W","oeste"},
}

-- Pares (padrão regex na mensagem bruta, texto curto para HUD).
local EX_PH = {}
-- Expande templates EN (“is to the north-west” etc.) × direções → frases PT resumidas.
for _, p in ipairs({
  {"is on a higher level to the ", "+", "acima "},
  {"is on a lower level to the ",  "-", "abaixo "},
  {"is very far to the ",          "",  "muito longe "},
  {"is far to the ",               "",  "longe "},
  {"is to the ",                   "",  ""},
}) do
  for _, d in ipairs(EX_DIRS) do
    local tag = p[2] ~= "" and (p[2] .. d[2]) or d[2]
    EX_PH[#EX_PH + 1] = { p[1] .. d[1], "[" .. tag .. "] " .. p[3] .. d[3] }
  end
end
for _, s in ipairs({
  {"is standing next to you","[~] ao seu lado"}, {"standing next to you","[~] ao lado"},
  {"next to you","[~] ao lado"}, {"is above you","[+] acima"}, {"is below you","[-] abaixo"},
  {"above you","[+] acima"}, {"below you","[-] abaixo"},
}) do EX_PH[#EX_PH + 1] = s end

-- Normaliza mensagem bruta para leitura rapida no HUD.
local function translateExiva(msg)
  if not msg or msg == "" then return msg end
  local out = msg:lower()
  for _, ph in ipairs(EX_PH) do out = out:gsub(ph[1], ph[2]) end
  return out
end

-- Tenta extrair faixa de sqm quando o servidor envia numero ou palavras-chave.
local function parseExivaDist(msg)
  if not msg or msg == "" then return end
  local txt = msg:lower()
  local d = txt:match("(%d+)%s*sqms?") or txt:match("(%d+)%s*square%s*meters?") or txt:match("(%d+)%s*metros?")
  if d then local n = tonumber(d); if n and n >= 0 and n <= 999 then return n .. " sqm" end end
  if txt:find("next to you") then return "0-4 sqm" end
  if txt:find("very far")    then return "251+ sqm" end
  if txt:find("far to the")  then return "101-250 sqm" end
  if txt:find("to the")      then return "5-100 sqm" end
end

-- Converte tag [NE], [+S], [~] etc. em chave unica para a runa da UI.
local function parseExivaDirKey(translated)
  if not translated then return end
  local tag = translated:match("%[([%+%-]?%u%u?)%]") or translated:match("%[(~)%]")
  if not tag then return end
  if tag == "~" then return "C" end
  return tag:gsub("^[%+%-]", "")
end

onTextMessage(function(mode, text)
  if mode ~= MSG_LOOK and mode ~= MSG_GAME then return end
  local exName = storage.lastExivaName
  if not exName or exName == "" then return end
  if not text:lower():find(exName:lower(), 1, true) then return end
  -- Descarta respostas antigas fora da janela do ultimo cast.
  if now - (storage.lastExivaTime or 0) > 4000 then return end
  storage.lastExivaMessage = text
  local d = parseExivaDist(text)
  if d then storage.lastExivaDist = d end
end)

local statusLabel = addLabel("knight_exiva_status", "Exiva: -")
pcall(function() statusLabel:setColor("#dddddd") end)

local btnExivaNome, btnExivaLast

local function castExiva(name, btn)
  if not name or name == "" then return end
  -- Timestamp e nome alimentam o parser de onTextMessage abaixo.
  storage.lastExivaTime = now
  storage.lastExivaName = name
  say('exiva "' .. name .. '"')
  flashBtn(btn)
end

local function exivaNome()
  castExiva(trim(storage.exivaManualName), btnExivaNome)
end

local function exivaLast()
  local name = storage.lastAttacked or ""
  -- Fallback: alvo atualmente em modo ataque no cliente.
  if name == "" then
    local t = g_game.getAttackingCreature()
    if t and t:isPlayer() then name = t:getName() end
  end
  castExiva(name, btnExivaLast)
end

btnExivaNome = addButton("btn_exiva_nome", "Exiva Nome [5]", exivaNome)
addTextEdit("exivaName", storage.exivaManualName or "", function(_, text)
  storage.exivaManualName = trim(text)
end)
btnExivaLast = addButton("btn_exiva_last", "Exiva Last [Shift+R]", exivaLast)
hotkey("5", exivaNome)
hotkey("Shift+R", exivaLast)

local RUNE_OFF, RUNE_ON = 3148, 3156
local gridItems = {}
local lastGridDir = nil

pcall(function()
  -- Painel opcional: um BotItem (runa) para indicar direção “N” no HUD; falha silenciosa se a UI não suportar.
  local grid = setupUI([[
Panel
  id: exiva_rune_grid
  height: 40
  BotItem
    id: exr_n
    &selectable: false
    &editable: false
]], statusLabel:getParent())
  if not grid then return end
  local w = grid:getChildById("exr_n")
  if w then w:setItemId(RUNE_OFF); gridItems["N"] = w end
end)

local function refreshGrid(dirKey)
  -- Evita piscar itens quando a direcao parseada nao mudou.
  if dirKey == lastGridDir then return end
  lastGridDir = dirKey
  for key, w in pairs(gridItems) do
    local on = key == dirKey
    pcall(function() w:setItemId(on and RUNE_ON or RUNE_OFF) end)
  end
end

local cachedExMsg, cachedExTr, cachedExDir, cachedExDist = "", "-", nil, "-"

macro(200, function()
  if not statusLabel then return end
  local msg = storage.lastExivaMessage or ""
  local d = storage.lastExivaDist or "-"
  -- Recalcula traducao e direcao somente quando a mensagem ou distancia mudou.
  if msg ~= cachedExMsg or d ~= cachedExDist then
    cachedExMsg, cachedExDist = msg, d
    cachedExTr = msg ~= "" and translateExiva(msg) or "-"
    cachedExDir = cachedExTr ~= "-" and parseExivaDirKey(cachedExTr) or nil
  end
  local line = "Exiva: " .. cachedExTr
  if cachedExDist ~= "" and cachedExDist ~= "-" then line = line .. " (" .. cachedExDist .. ")" end
  pcall(function() statusLabel:setText(line) end)
  refreshGrid(cachedExDir)
end)

-- [FIM] 013_exiva.lua
