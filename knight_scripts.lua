setDefaultTab("Main")

-- Config
local UTAMO_SPELL  = "utamo tempo"
local HASTE_SPELL  = "utani tempo hur"
local STRIKE_SPELL = "exori strike"
local MAS_HUR      = "mas exori hur"
local COMBO_CD     = 1750
local PUSH_INTERVAL = 480

-- Helpers
local function trim(s) return s and s:match("^%s*(.-)%s*$") or "" end

local function flashBtn(b)
  if not b then return end
  pcall(function() b:setImageColor("green") end)
  schedule(500, function() pcall(function() b:setImageColor("white") end) end)
end

local _ts = {}
local function throttle(key, ms)
  if (now - (_ts[key] or 0)) < ms then return false end
  _ts[key] = now
  return true
end

local MSG_GAME = (MessageModes and MessageModes.Game) or 18
local MSG_LOOK = (MessageModes and MessageModes.Look) or 20
local MSG_DMG  = (MessageModes and MessageModes.DamageReceived) or 22

-- Storage
storage = storage or {}
for k, v in pairs({
  followLeader = "", lastAttacked = "", lastAttackedMe = "",
  _target = nil, _targetId = 0, pushVictimName = "",
  lastExivaName = "", lastExivaMessage = "", lastExivaDist = "",
  exivaManualName = "", lastExivaTime = 0,
}) do
  if storage[k] == nil then storage[k] = v end
end

-- State
lockMacro, chaseMacro, followMacro = nil, nil, nil

local function lockIsOn()   return lockMacro  and lockMacro:isOn() end
local function chaseIsOn()  return chaseMacro and chaseMacro:isOn() end
local function followIsOn() return followMacro and followMacro:isOn() and storage.followLeader ~= "" end

local comboStep, comboLastTargetId = 1, 0
local pushDest, pushActive, lastPushAt = nil, false, 0

-- Events
onTextMessage(function(mode, text)
  if mode ~= MSG_DMG or not text then return end
  local name = text:match("due to an attack by (.+)%.$")
    or text:match("^(.+) hits you for")
    or text:match("hit by (.+) for")
  if name and name ~= "" then storage.lastAttackedMe = trim(name) end
end)

onAttackingCreatureChange(function(creature)
  if not creature or not creature:isPlayer() then return end
  local n, id = creature:getName(), creature:getId()
  storage.lastAttacked = n

  if id ~= comboLastTargetId then comboStep = 1; comboLastTargetId = id end
  if lockIsOn() then storage._target = n; storage._targetId = id end

  if followMacro and followMacro:isOn() and storage.followLeader ~= n then
    storage.followLeader = n
    storage._target, storage._targetId = nil, 0
    if lockIsOn()  then lockMacro:setOff() end
    if chaseIsOn() then chaseMacro:setOff() end
    g_game.setChaseMode(0)
    g_game.cancelAttackAndFollow()
  end
end)

-- Combate
addSeparator("sep_combate")
addLabel("lbl_combate", "--- COMBATE ---")

local utamoMacro

local gaugeMacro = macro(1000, "Auto Exori Gauge", "", function()
  if utamoMacro and utamoMacro:isOn() then utamoMacro:setOff() end
  if hasPartyBuff and hasPartyBuff() then return end
  say("exori gauge")
end)

utamoMacro = macro(700, "Auto Utamo Tempo", "Shift+1", function()
  if gaugeMacro:isOn() then gaugeMacro:setOff() end
  if (hasManaShield and hasManaShield()) or (hasPartyBuff and hasPartyBuff()) then return end
  if mana() < 40 then return end
  say(UTAMO_SPELL)
end)

macro(500, "Auto Haste", "Shift+2", function()
  if hasHaste() then return end
  say(HASTE_SPELL)
end)

macro(200, "Exeta Res", function()
  if not g_game.isAttacking() then return end
  local t = g_game.getAttackingCreature()
  if not t or getDistanceBetween(pos(), t:getPosition()) > 1 then return end
  if manapercent() <= 30 then return end
  say("exeta res")
  delay(5000)
end)

macro(100, "Anti Paralyze", "Shift+3", function()
  if not isParalyzed() then return end
  say(HASTE_SPELL)
end)

local antiKickDir = 0
macro(680, "Anti Kick", "Shift+4", function()
  turn(antiKickDir)
  antiKickDir = (antiKickDir + 1) % 4
end)

local lastComboEnd, lastStrikeAt = 0, 0

macro(85, "Combo Knight", "Shift+5", function()
  local t = g_game.getAttackingCreature()
  if not t or not t:isPlayer() then return end
  local tp, mp = t:getPosition(), pos()
  if not tp or not mp or tp.z ~= mp.z then return end

  if comboStep <= 2 then
    if comboStep == 1 and lastComboEnd > 0 and (now - lastComboEnd) < COMBO_CD then return end
    if comboStep == 2 and (now - lastStrikeAt) < 100 then return end
    say(STRIKE_SPELL)
    lastStrikeAt = now
    comboStep = comboStep + 1
  elseif comboStep == 3 then
    local dx, dy = tp.x - mp.x, tp.y - mp.y
    if dx ~= 0 or dy ~= 0 then
      turn(math.abs(dx) >= math.abs(dy) and (dx > 0 and 1 or 3) or (dy > 0 and 2 or 0))
    end
    say(MAS_HUR)
    comboStep = 1
    lastComboEnd = now
  end
end)

-- Alvo
addSeparator("sep_alvo")
addLabel("lbl_alvo", "--- ALVO ---")

lockMacro = macro(100, "Auto Target", "Shift+Q", function()
  local tname = storage._target
  if not tname or tname == "" then return end
  local target = getPlayerByName(tname, true)
  if not target then return end
  local tp = target:getPosition()
  if not tp or tp.z ~= posz() then return end

  local cur = g_game.getAttackingCreature()
  if (cur and cur:isPlayer() and cur:getName() or "") ~= tname or not g_game.isAttacking() then
    if throttle("reattack", 120) then g_game.attack(target) end
  end
end)

local btnClear
local function doClear()
  storage._target, storage._targetId = nil, 0
  g_game.cancelAttackAndFollow()
  flashBtn(btnClear)
end
btnClear = addButton("btn_clear", "Clear Target [4]", doClear)
hotkey("4", doClear)

local btnRecover
local function doRecover()
  local name = storage.lastAttacked
  if not name or name == "" then return end
  storage._target = name
  local c = getPlayerByName(name, true)
  storage._targetId = c and c:getId() or 0
  if c then g_game.attack(c) end
  flashBtn(btnRecover)
end
btnRecover = addButton("btn_recover", "Recover Target [Shift+E]", doRecover)
hotkey("Shift+E", doRecover)

chaseMacro = macro(100, "Auto Chase", "2", function()
  if not lockIsOn() then return end
  g_game.setChaseMode(1)
  local target = getPlayerByName(storage._target, true)
  if not target then return end
  local tp = target:getPosition()
  if not tp or tp.z ~= posz() then return end

  if throttle("chase_attack", 150) then g_game.attack(target) end
  if getDistanceBetween(pos(), tp) > 1 then
    autoWalk(tp, 20, { ignoreNonPathable = true, precision = 1 })
  end
end)

followMacro = macro(50, "Follow PVP", "3", function() end)

macro(200, function()
  if not followIsOn() then return end
  local target = getPlayerByName(storage.followLeader, true)
  if not target then return end
  if g_game.isFollowing and g_game.isFollowing() then return end
  g_game.cancelAttackAndFollow()
  g_game.follow(target)
end)

local btnClearFollow
local function clearFollow()
  storage.followLeader = ""
  g_game.cancelAttackAndFollow()
  flashBtn(btnClearFollow)
end
btnClearFollow = addButton("btn_clear_follow", "Clear Follow [1]", clearFollow)
hotkey("1", clearFollow)

local prevLock, prevChase, prevFollow = false, false, false
macro(100, function()
  local lk, ch, fl = lockIsOn(), chaseIsOn(), followMacro and followMacro:isOn()
  if (lk and not prevLock) or (ch and not prevChase) then storage.followLeader = "" end
  if not ch and prevChase then g_game.setChaseMode(0) end
  if not fl and prevFollow then storage.followLeader = ""; g_game.cancelAttackAndFollow() end
  prevLock, prevChase, prevFollow = lk, ch, fl
end)

-- Exiva
addSeparator("sep_exiva")
addLabel("lbl_exiva", "--- EXIVA ---")

local EX_DIRS = {
  {"south%-west","SW","sudoeste"}, {"south%-east","SE","sudeste"},
  {"north%-west","NW","noroeste"}, {"north%-east","NE","nordeste"},
  {"south","S","sul"}, {"north","N","norte"},
  {"east","E","leste"}, {"west","W","oeste"},
}

local EX_PH = {}
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

local function translateExiva(msg)
  if not msg or msg == "" then return msg end
  local out = msg:lower()
  for _, ph in ipairs(EX_PH) do out = out:gsub(ph[1], ph[2]) end
  return out
end

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
  local grid = setupUI([[
Panel
  id: exiva_rune_grid
  height: 170

  Panel
    id: grid_wrap
    width: 114
    height: 170
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter

    Label
      id: lbl_nw
      text: NO
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
      text: O
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
      text: L
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
      text: SO
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
]], statusLabel:getParent())
  if not grid then return end
  local wrap = grid:getChildById("grid_wrap") or grid
  for _, key in ipairs({"NW","N","NE","W","C","E","SW","S","SE"}) do
    local w = wrap:getChildById("exr_" .. key:lower())
    if w then w:setItemId(RUNE_OFF); gridItems[key] = w end
  end
end)

local function refreshGrid(dirKey)
  if dirKey == lastGridDir then return end
  lastGridDir = dirKey
  for key, w in pairs(gridItems) do
    local on = key == dirKey
    pcall(function()
      w:setItemId(on and RUNE_ON or RUNE_OFF)
      local lbl = w:getParent():getChildById("lbl_" .. key:lower())
      if lbl then lbl:setColor(on and "#00bcd4" or "#aaaaaa") end
    end)
  end
end

refreshGrid(nil)

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
  refreshGrid(cachedExDir)
end)

-- Util
addSeparator("sep_util")
addLabel("lbl_util", "--- UTIL ---")

local BUG_DIRS = {
  w={0,-5}, e={3,-3}, d={5,0}, c={3,3},
  s={0,5}, z={-3,3}, a={-5,0}, q={-3,-3},
}

macro(50, "BugMap", "Shift+T", function()
  if modules.game_console and modules.game_console:isChatEnabled() then return end
  local k = modules.corelib and modules.corelib.g_keyboard
  if not k then return end

  local dx, dy
  for key, dir in pairs(BUG_DIRS) do
    if k.isKeyPressed(key) then dx, dy = dir[1], dir[2]; break end
  end
  if not dx then return end

  local mp = pos()
  local function useTile(tp)
    local tile = g_map.getTile(tp)
    local top = tile and tile:getTopUseThing()
    if top then g_game.use(top) end
  end

  useTile(mp)
  local steps = math.max(math.abs(dx), math.abs(dy))
  local sx = dx == 0 and 0 or (dx > 0 and 1 or -1)
  local sy = dy == 0 and 0 or (dy > 0 and 1 or -1)
  for i = 1, steps do
    useTile({ x = mp.x + sx * i, y = mp.y + sy * i, z = mp.z })
  end
end)

singlehotkey("Shift+Y", "ID cursor mapa", function()
  if modules.game_console and modules.game_console:isChatEnabled() then return end
  local gm = modules.game_interface and modules.game_interface.gameMapPanel
  if not gm or not gm.mousePos then return end
  local tile = gm:getTile(gm.mousePos)
  if not tile then return end
  local tpos = tile:getPosition()
  local pstr = string.format("%d,%d,%d", tpos.x, tpos.y, tpos.z)
  local msg = ""
  pcall(function()
    local offset = gm:getPositionOffset(gm.mousePos)
    local c = tile:getTopCreatureEx(offset)
    if c then
      msg = string.format("[ID] %s id=%s | %s", c:getName() or "?", tostring(c:getId()), pstr)
      return
    end
    local lt = tile:getTopLookThingEx(offset) or tile:getTopLookThing()
    if lt and lt.getId then
      msg = string.format("[ID] clientId=%s | %s", tostring(lt:getId()), pstr)
    end
  end)
  if msg == "" then
    local ids = {}
    pcall(function()
      for _, item in pairs(tile:getItems() or {}) do
        if item.getId then ids[#ids + 1] = tostring(item:getId()) end
      end
    end)
    msg = string.format("[ID] %s | stack [%s]", pstr, #ids > 0 and table.concat(ids, ", ") or "-")
  end
  print(msg)
  if info then info(msg) end
end)

local PD = {{-1,-1},{0,-1},{1,-1},{1,0},{1,1},{0,1},{-1,1},{-1,0}}
local pullTick = 0

macro(260, "Puxar Itens", "Shift+F", function()
  if player:isWalking() then return end
  local mp = pos()
  pullTick = pullTick + 1
  for off = 0, 1 do
    local idx = ((pullTick - 1 + off) % #PD) + 1
    local d = PD[idx]
    local tile = g_map.getTile({ x = mp.x + d[1], y = mp.y + d[2], z = mp.z })
    if tile then
      for _, item in ipairs(tile:getItems() or {}) do
        local can = false
        pcall(function()
          can = item:isPickupable() or (item.isNotMoveable and not item:isNotMoveable())
        end)
        if can then g_game.move(item, mp, item:getCount()); return end
      end
    end
  end
end)

local dropGold = true

macro(420, "Anti Push", "Shift+G", function()
  if player:isWalking() then return end
  local mp = pos()
  local tile = g_map.getTile(mp)
  if tile and #(tile:getItems() or {}) >= 8 then return end

  local gold, plat, crystal
  for _, c in pairs(getContainers()) do
    for _, item in ipairs(c:getItems()) do
      local id = item:getId()
      if     id == 3031 and not gold    then gold = item
      elseif id == 3035 and not plat    then plat = item
      elseif id == 3043 and not crystal then crystal = item end
    end
  end

  if dropGold then
    if gold    then g_game.move(gold, mp, 1); dropGold = false; return end
    if plat    then g_game.use(plat); return end
    if crystal then g_game.use(crystal); return end
  else
    if plat    then g_game.move(plat, mp, 1); dropGold = true; return end
    if crystal then g_game.use(crystal); return end
  end
end)

local btnPushDest, btnPushMark, btnPushGo, btnPushStop

local function setPushDest()
  pcall(function()
    local tile = getTileUnderCursor()
    if tile then pushDest = tile:getPosition(); flashBtn(btnPushDest) end
  end)
end

local function markPushVictim()
  local t = g_game.getAttackingCreature()
  if t and t:isPlayer() then
    storage.pushVictimName = trim(t:getName())
    flashBtn(btnPushMark)
  end
end

local function stopPush()  pushActive = false; flashBtn(btnPushStop) end
local function startPush()
  if trim(storage.pushVictimName) == "" then markPushVictim() end
  if trim(storage.pushVictimName) == "" or not pushDest then return end
  pushActive = true
  flashBtn(btnPushGo)
end

btnPushDest = addButton("btn_push_dest", "Push Dest [Shift+V]", setPushDest)
btnPushMark = addButton("btn_push_mark", "Marcar alvo [Shift+B]", markPushVictim)
btnPushGo   = addButton("btn_push_go",   "Ir empurrar [Shift+X]", startPush)
btnPushStop = addButton("btn_push_stop", "Parar push [Shift+Z]",  stopPush)

hotkey("Shift+V", setPushDest)
hotkey("Shift+B", markPushVictim)
hotkey("Shift+X", startPush)
hotkey("Shift+Z", stopPush)

macro(300, function()
  if not pushActive or not pushDest then return end
  local vname = trim(storage.pushVictimName)
  if vname == "" then pushActive = false; return end

  local creature = getPlayerByName(vname, true)
  if not creature then return end
  local cp = creature:getPosition()
  if not cp then return end

  if cp.x == pushDest.x and cp.y == pushDest.y and cp.z == pushDest.z then
    pushActive = false; return
  end

  local mp = pos()

  if mp.z ~= cp.z or getDistanceBetween(mp, cp) > 1 then
    if not player:isWalking() then
      autoWalk(cp, 20, { ignoreNonPathable = true, precision = 1 })
    end
    return
  end

  if player:isWalking() then return end
  if mp.x == cp.x and mp.y == cp.y then return end
  if now - lastPushAt < PUSH_INTERVAL then return end

  local dx, dy = pushDest.x - cp.x, pushDest.y - cp.y
  local sx = dx == 0 and 0 or (dx > 0 and 1 or -1)
  local sy = dy == 0 and 0 or (dy > 0 and 1 or -1)
  local np = { x = cp.x + sx, y = cp.y + sy, z = cp.z }

  if np.x == mp.x and np.y == mp.y then return end

  local destTile = g_map.getTile(np)
  if not destTile or not destTile:isWalkable() then return end
  local cr = destTile:getCreatures()
  if cr then for _, c in ipairs(cr) do if c ~= creature then return end end end

  lastPushAt = now
  g_game.move(creature, np)
end)

-- HUD
addSeparator("sep_hud")
addLabel("lbl_hud", "--- STATUS ---")

local hud = {
  addLabel("k_h1", "Atacou-me: -"),
  addLabel("k_h2", "Ataquei: -"),
  addLabel("k_h3", "Alvo: -"),
  addLabel("k_h4", "Chase: -"),
  addLabel("k_h5", "Follow: -"),
  addLabel("k_h6", "Push: -"),
  addLabel("k_h7", "Mode: idle"),
}

local function setHud(i, text, color)
  pcall(function()
    hud[i]:setText(text)
    hud[i]:setColor(color or "#aaaaaa")
  end)
end

macro(280, function()
  local am  = storage.lastAttackedMe or ""
  local la  = storage.lastAttacked or ""
  local tgt = storage._target or ""
  local chOn = chaseIsOn() and lockIsOn() and tgt ~= ""
  local fOn  = followIsOn()
  local fl   = storage.followLeader or ""
  local pv   = trim(storage.pushVictimName or "")

  local function v(s) return s ~= "" and s or "-" end

  setHud(1, "Atacou-me: " .. v(am), am  ~= "" and "#ff6666" or "red")
  setHud(2, "Ataquei: "   .. v(la), la  ~= "" and "#66ff66" or "red")
  setHud(3, "Alvo: "     .. v(tgt), tgt ~= "" and "green"   or "red")
  setHud(4, "Chase: " .. (chOn and tgt or "-"), chOn and "green" or "red")
  setHud(5, "Follow: " .. (fOn and fl or "-"),  fOn  and "green" or "red")

  if pv ~= "" and pushDest then
    setHud(6, "Push: [" .. pv .. "] > " .. pushDest.x .. "," .. pushDest.y .. (pushActive and " [ON]" or ""),
      pushActive and "#88ff88" or "#ffaa00")
  elseif pv ~= "" then
    setHud(6, "Push: [" .. pv .. "]", "#ffaa00")
  else
    setHud(6, "Push: -", "red")
  end

  local mode, mc = "Mode: idle", "#aaaaaa"
  if     pushActive               then mode, mc = "Mode: push",   "#ffaa00"
  elseif fOn                      then mode, mc = "Mode: follow", "#66ccff"
  elseif chOn                     then mode, mc = "Mode: chase",  "#88ff88"
  elseif lockIsOn() and tgt ~= "" then mode, mc = "Mode: lock",   "#66ff66"
  end
  setHud(7, mode, mc)
end)
