--[[
  019_exiva.lua — Exiva, etiqueta de estado e grelha de runa (direcção).

  Dispara `say('exiva "nome"')` a partir do nome manual em storage ou do último alvo player
  (003_damage_capture / criatura em attack). `onTextMessage` filtra Game + Look, cruza com lastExivaName e
  janela temporal para preencher storage + UI.

  No pack ordenado: penúltimo script antes do HUD (`020_status_hud.lua`).
  Depende de: 002_storage_init.lua, 003 recomendado.
  PVE/PVP: Exiva útil sobretudo em PVP; parsing tolera EN e PT comuns.
]]

storage = (type(storage) == "table" and storage) or {}
if knightEnsureStorage then
  knightEnsureStorage({
    lastExivaName = "",
    lastExivaMessage = "",
    lastExivaDist = "",
    exivaManualName = "",
    lastExivaTime = 0,
  })
end

local trim = knightTrim
local flashBtn = knightFlashBtn

local MSG_GAME = (MessageModes and MessageModes.Game) or 18
local MSG_LOOK = (MessageModes and MessageModes.Look) or 20

local EX_DIRS = {
  { "south%-west", "SW", "sudoeste" }, { "south%-east", "SE", "sudeste" },
  { "north%-west", "NW", "noroeste" }, { "north%-east", "NE", "nordeste" },
  { "south", "S", "sul" }, { "north", "N", "norte" },
  { "east", "E", "leste" }, { "west", "W", "oeste" },
}

local EX_PH = {}
for _, p in ipairs({
  { "is on a higher level to the ", "+", "acima " },
  { "is on a lower level to the ", "-", "abaixo " },
  { "is very far to the ", "", "muito longe " },
  { "is far to the ", "", "longe " },
  { "is to the ", "", "" },
}) do
  for _, d in ipairs(EX_DIRS) do
    local tag = p[2] ~= "" and (p[2] .. d[2]) or d[2]
    EX_PH[#EX_PH + 1] = { p[1] .. d[1], "[" .. tag .. "] " .. p[3] .. d[3] }
  end
end
-- PT comum (cliente/servidor)
for _, s in ipairs({
  { "está no andar de cima", "[+] acima" },
  { "esta no andar de cima", "[+] acima" },
  { "está no andar de baixo", "[-] abaixo" },
  { "esta no andar de baixo", "[-] abaixo" },
  { "muito longe a ", "", "muito longe " },
  { "longe a ", "", "longe " },
}) do
  EX_PH[#EX_PH + 1] = s
end
-- Direcções escritas por extenso em PT (ex.: "a nordeste")
for _, d in ipairs(EX_DIRS) do
  if d[3] and d[3] ~= "" then
    EX_PH[#EX_PH + 1] = { "a " .. d[3], "[" .. d[2] .. "] ", d[3] }
  end
end
for _, s in ipairs({
  { "is standing next to you", "[~] ao seu lado" }, { "standing next to you", "[~] ao lado" },
  { "next to you", "[~] ao lado" }, { "is above you", "[+] acima" }, { "is below you", "[-] abaixo" },
  { "above you", "[+] acima" }, { "below you", "[-] abaixo" },
  { "está ao seu lado", "[~] ao lado" }, { "esta ao seu lado", "[~] ao lado" },
  { "ao seu lado", "[~] ao lado" }, { "ao lado de ti", "[~] ao lado" },
}) do
  EX_PH[#EX_PH + 1] = s
end

local function translateExiva(msg)
  if type(msg) ~= "string" or msg == "" then return msg end
  local out = msg:lower()
  for _, ph in ipairs(EX_PH) do
    out = out:gsub(ph[1], ph[2])
  end
  out = out:gsub("%[~%]%s*%[~%]", "[~]")
  return out
end

local function parseExivaDist(msg)
  if type(msg) ~= "string" or msg == "" then return end
  local txt = msg:lower()
  local d = txt:match("(%d+)%s*sqms?")
      or txt:match("(%d+)%s*square%s*meters?")
      or txt:match("(%d+)%s*metros?")
  if d then
    local n = tonumber(d)
    if n and n >= 0 and n <= 999 then return n .. " sqm" end
  end
  if txt:find("next to you", 1, true) or txt:find("ao seu lado", 1, true) or txt:find("ao lado de ti", 1, true) then
    return "0-4 sqm"
  end
  if txt:find("very far", 1, true) or txt:find("muito longe", 1, true) then return "251+ sqm" end
  if txt:find("far to the", 1, true) or txt:find("está longe", 1, true) or txt:find("esta longe", 1, true) then
    return "101-250 sqm"
  end
  if txt:find("to the", 1, true) or txt:find(" a nor", 1, true) or txt:find(" a sul", 1, true)
      or txt:find(" a leste", 1, true) or txt:find(" a oeste", 1, true) then
    return "5-100 sqm"
  end
end

local function parseExivaDirKey(translated)
  if type(translated) ~= "string" then return end
  local tag = translated:match("%[([%+%-]?%u%u?)%]") or translated:match("%[(~)%]")
  if not tag then return end
  if tag == "~" then return "C" end
  return (tag:gsub("^[%+%-]", ""))
end

onTextMessage(function(mode, text)
  if mode ~= MSG_LOOK and mode ~= MSG_GAME then return end
  if type(text) ~= "string" or text == "" then return end
  local exName = trim(storage.lastExivaName or "")
  if exName == "" then return end
  if not text:lower():find(exName:lower(), 1, true) then return end
  if now - (storage.lastExivaTime or 0) > 4000 then return end
  storage.lastExivaMessage = text
  local dist = parseExivaDist(text)
  if dist then storage.lastExivaDist = dist end
end)

local btnExivaNome, btnExivaLast

local function castExiva(name, btn)
  name = trim(name or "")
  if name == "" then return end
  if knightChatOpen and knightChatOpen() then return end
  storage.lastExivaTime = now
  storage.lastExivaName = name
  if say then pcall(function() say('exiva "' .. name .. '"') end) end
  flashBtn(btn)
end

local function exivaNome()
  castExiva(storage.exivaManualName, btnExivaNome)
end

local function exivaLast()
  local name = trim(storage.lastAttacked or "")
  if name == "" and knightAttackingCreature then
    local t = knightAttackingCreature()
    if t and t.isPlayer and t:isPlayer() then
      local nOk, n = pcall(function() return t:getName() end)
      if nOk and type(n) == "string" then name = trim(n) end
    end
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

--- Ordem: botões → texto Exiva → grelha (layout por âncoras + `grid_wrap` centrado — mesmo padrão do script
--- monolítico antigo; evita `layout: grid` com células que sumiam no teu OTC).
local statusLabel = addLabel("knight_exiva_status", "Exiva: -")
pcall(function() statusLabel:setColor("#dddddd") end)
pcall(function() statusLabel:setTextWrap(true) end)

local RUNE_OFF, RUNE_ON = 3148, 3156
local gridItems = {}
local lastGridDir = nil
local GRID_ORDER = { "NW", "N", "NE", "W", "C", "E", "SW", "S", "SE" }

pcall(function()
  local parent = statusLabel:getParent()
  if not parent then return end
  local grid = setupUI([[
Panel
  id: exiva_rune_grid
  margin-top: 6
  height: 170

  Panel
    id: grid_wrap
    width: 114
    height: 170
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter

    Label
      id: lbl_nw
      text: NW
      anchors.top: parent.top
      anchors.left: parent.left
      margin-top: 6
      margin-left: 6
      font: verdana-11px-rounded
      text-align: center
      width: 34
      height: 14
      color: #aaaaaa

    Label
      id: lbl_n
      text: N
      anchors.top: parent.top
      anchors.left: lbl_nw.right
      margin-top: 6
      margin-left: 2
      font: verdana-11px-rounded
      text-align: center
      width: 34
      height: 14
      color: #aaaaaa

    Label
      id: lbl_ne
      text: NE
      anchors.top: parent.top
      anchors.left: lbl_n.right
      margin-top: 6
      margin-left: 2
      font: verdana-11px-rounded
      text-align: center
      width: 34
      height: 14
      color: #aaaaaa

    BotItem
      id: exr_nw
      &selectable: false
      &editable: false
      anchors.top: lbl_nw.bottom
      anchors.left: parent.left
      margin-left: 6

    BotItem
      id: exr_n
      &selectable: false
      &editable: false
      anchors.top: lbl_n.bottom
      anchors.left: exr_nw.right
      margin-left: 2

    BotItem
      id: exr_ne
      &selectable: false
      &editable: false
      anchors.top: lbl_ne.bottom
      anchors.left: exr_n.right
      margin-left: 2

    Label
      id: lbl_w
      text: W
      anchors.top: exr_nw.bottom
      anchors.left: parent.left
      margin-left: 6
      margin-top: 2
      font: verdana-11px-rounded
      text-align: center
      width: 34
      height: 14
      color: #aaaaaa

    Label
      id: lbl_c
      text: C
      anchors.top: exr_n.bottom
      anchors.left: lbl_w.right
      margin-left: 2
      margin-top: 2
      font: verdana-11px-rounded
      text-align: center
      width: 34
      height: 14
      color: #aaaaaa

    Label
      id: lbl_e
      text: E
      anchors.top: exr_ne.bottom
      anchors.left: lbl_c.right
      margin-left: 2
      margin-top: 2
      font: verdana-11px-rounded
      text-align: center
      width: 34
      height: 14
      color: #aaaaaa

    BotItem
      id: exr_w
      &selectable: false
      &editable: false
      anchors.top: lbl_w.bottom
      anchors.left: parent.left
      margin-left: 6

    BotItem
      id: exr_c
      &selectable: false
      &editable: false
      anchors.top: lbl_c.bottom
      anchors.left: exr_w.right
      margin-left: 2

    BotItem
      id: exr_e
      &selectable: false
      &editable: false
      anchors.top: lbl_e.bottom
      anchors.left: exr_c.right
      margin-left: 2

    Label
      id: lbl_sw
      text: SW
      anchors.top: exr_w.bottom
      anchors.left: parent.left
      margin-left: 6
      margin-top: 2
      font: verdana-11px-rounded
      text-align: center
      width: 34
      height: 14
      color: #aaaaaa

    Label
      id: lbl_s
      text: S
      anchors.top: exr_c.bottom
      anchors.left: lbl_sw.right
      margin-left: 2
      margin-top: 2
      font: verdana-11px-rounded
      text-align: center
      width: 34
      height: 14
      color: #aaaaaa

    Label
      id: lbl_se
      text: SE
      anchors.top: exr_e.bottom
      anchors.left: lbl_s.right
      margin-left: 2
      margin-top: 2
      font: verdana-11px-rounded
      text-align: center
      width: 34
      height: 14
      color: #aaaaaa

    BotItem
      id: exr_sw
      &selectable: false
      &editable: false
      anchors.top: lbl_sw.bottom
      anchors.left: parent.left
      margin-left: 6

    BotItem
      id: exr_s
      &selectable: false
      &editable: false
      anchors.top: lbl_s.bottom
      anchors.left: exr_sw.right
      margin-left: 2

    BotItem
      id: exr_se
      &selectable: false
      &editable: false
      anchors.top: lbl_se.bottom
      anchors.left: exr_s.right
      margin-left: 2
]], parent)
  if not grid then return end
  local wrap = grid:getChildById("grid_wrap") or grid
  for _, key in ipairs(GRID_ORDER) do
    local w = wrap:getChildById("exr_" .. string.lower(key))
    if w then
      w:setItemId(RUNE_OFF)
      gridItems[key] = w
    end
  end
end)

local function refreshGrid(dirKey)
  if dirKey == lastGridDir then return end
  lastGridDir = dirKey
  for key, w in pairs(gridItems) do
    local on = dirKey and key == dirKey
    pcall(function()
      w:setItemId(on and RUNE_ON or RUNE_OFF)
      local p = w:getParent()
      local lbl = p and p:getChildById("lbl_" .. string.lower(key))
      if lbl then lbl:setColor(on and "#00bcd4" or "#aaaaaa") end
    end)
  end
end

local cachedExMsg, cachedExTr, cachedExDir, cachedExDist = "", "-", nil, "-"

macro(200, function()
  if not statusLabel then return end
  local msg = storage.lastExivaMessage or ""
  local d = storage.lastExivaDist or "-"
  if msg ~= cachedExMsg or d ~= cachedExDist then
    cachedExMsg, cachedExDist = msg, d
    cachedExTr = msg ~= "" and translateExiva(msg) or "-"
    cachedExDir = cachedExTr ~= "-" and parseExivaDirKey(cachedExTr) or nil
  end
  local line = "Exiva: " .. cachedExTr
  if cachedExDist ~= "" and cachedExDist ~= "-" then line = line .. " (" .. cachedExDist .. ")" end
  pcall(function() statusLabel:setText(line) end)
  refreshGrid(cachedExDir or nil)
end)
