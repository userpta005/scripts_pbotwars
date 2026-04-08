--[[
  knight_all_in_one.lua

  Monolito auto-gerado a partir de knight_scripts/*.lua.
  Inclui scripts 001..021.
  NAO EDITAR MANUALMENTE - regenerar a partir dos modulares.
  Ordem: 001..021.
]]

if type(setDefaultTab) == "function" then
  setDefaultTab("Main")
end


-- ========== 001_pvp_manual_mode.lua ==========

--[[
  001_pvp_manual_mode.lua — Um clique: desliga TargetBot/CaveBot/AttackBot (vBot) e liga
  Auto Exori Strike, Auto Target e Auto Chase (knight_scripts).

  Carregar primeiro no perfil: só regista o botão; ao clicar resolve as macros globalmente.

  Depende de (macros ao clicar): 011_auto_exori_strike.lua, 012_auto_target.lua (`knightExoriStrikeMacro`,
  `knightAutoTargetMacro`, `knightAutoChaseMacro`). Se vBot não estiver carregado, os `setOff`
  são ignorados em segurança.
]]

local function safeCall(fn)
  if type(fn) ~= "function" then return end
  pcall(fn)
end

local function modoPvpManual()
  if type(TargetBot) == "table" and type(TargetBot.setOff) == "function" then
    safeCall(function() TargetBot.setOff() end)
  end
  if type(CaveBot) == "table" and type(CaveBot.setOff) == "function" then
    safeCall(function() CaveBot.setOff() end)
  end
  if type(AttackBot) == "table" and type(AttackBot.setOff) == "function" then
    safeCall(function() AttackBot.setOff() end)
  end

  if knightExoriStrikeMacro and knightExoriStrikeMacro.setOn then
    safeCall(function() knightExoriStrikeMacro:setOn() end)
  end
  if knightAutoTargetMacro and knightAutoTargetMacro.setOn then
    safeCall(function() knightAutoTargetMacro:setOn() end)
  end
  if knightAutoChaseMacro and knightAutoChaseMacro.setOn then
    safeCall(function() knightAutoChaseMacro:setOn() end)
  end
end

local btnPvpManual = addButton("btn_pvp_manual", "Modo PVP manual (bots off)", function()
  modoPvpManual()
  if knightFlashBtn then knightFlashBtn(btnPvpManual) end
end)

-- ========== 002_storage_init.lua ==========

--[[
  002_storage_init.lua — Base do knight_scripts (PbotWars / OTCv8 game_bot).

  Tempos: apenas `now` do game_bot (sem relogios misturados).
  Entre spells: so `knightGlobalCastReady` / `knightTouchGlobalCast` (ms configuravel).
  Vertical engine factory partilhada por 012 (chase) e 013 (follow).
  Walk memory helper evita re-path spam no mesmo destino.
]]

storage = (type(storage) == "table" and storage) or {}

KNIGHT_EXORI_GAUGE_SPELL = KNIGHT_EXORI_GAUGE_SPELL or "exori gauge"
KNIGHT_EXORI_GAUGE_MIN_MANA = KNIGHT_EXORI_GAUGE_MIN_MANA or 400

function knightSupportMacroEnabled(macroRef)
  if not macroRef then return false end
  local ok, on = pcall(function() return macroRef:isOn() end)
  if ok and on then return true end
  ok, on = pcall(function() return macroRef:isEnabled() end)
  if ok and on then return true end
  return false
end

knightMacroIsOn = knightSupportMacroEnabled

function knightEnsureStorage(defaults)
  if type(defaults) ~= "table" then return end
  if type(storage) ~= "table" then storage = {} end
  for k, v in pairs(defaults) do
    if storage[k] == nil then storage[k] = v end
  end
end

function knightTrim(s)
  if type(s) ~= "string" then return "" end
  return s:match("^%s*(.-)%s*$") or ""
end

function knightNameMatchLock(lockName, creatureName)
  local a = knightTrim(lockName or "")
  local b = knightTrim(creatureName or "")
  if a == "" or b == "" then return false end
  if a == b then return true end
  return string.lower(a) == string.lower(b)
end

function knightIsWalking()
  if not player or not player.isWalking then return false end
  local ok, w = pcall(function() return player:isWalking() end)
  return ok and w == true
end

function knightFlashBtn(b)
  if not b then return end
  pcall(function() b:setImageColor("green") end)
  if schedule then
    schedule(500, function() pcall(function() b:setImageColor("white") end) end)
  end
end

function knightMapUseTopThing(x, y, z)
  if not g_map or not g_map.getTile or not g_game or not g_game.use then return end
  pcall(function()
    local tile = g_map.getTile({ x = x, y = y, z = z })
    local top = tile and tile:getTopUseThing()
    if top then g_game.use(top) end
  end)
end

function knightGameAttackReady()
  local g = g_game
  return not not (g and g.isAttacking and g.getAttackingCreature and g.attack)
end

function knightGameAttack(creature)
  if not creature or not knightGameAttackReady() then return end
  pcall(function() g_game.attack(creature) end)
end

function knightChatOpen()
  local c = modules and modules.game_console
  if not c then return false end
  local ok, open = pcall(function() return c:isChatEnabled() end)
  return ok and open == true
end

function knightSpellSay(text)
  if type(text) ~= "string" or text == "" then return end
  if say then
    local ok = pcall(function() say(text) end)
    if ok then return end
  end
  if g_game and g_game.talk then
    pcall(function() g_game.talk(text) end)
  end
end

--- Cooldown local da spell + mana (usa so `now` do bot).
function knightSpellReady(lastAt, gapMs, minMana)
  if type(now) ~= "number" then return false end
  lastAt = lastAt or 0
  if (now - lastAt) < gapMs then return false end
  if minMana and mana then
    local okM, m = pcall(function() return mana() end)
    if not okM or type(m) ~= "number" or m < minMana then return false end
  end
  return true
end

--- Minimo de ms entre qualquer say() de spell deste pacote (anti-colisao).
function knightGlobalCastReady(minGapMs)
  if type(now) ~= "number" then return false end
  local last = storage._lastGlobalCastAt or 0
  if type(last) ~= "number" or last <= 0 then return true end
  if now < last then return true end
  return (now - last) >= (minGapMs or 600)
end

function knightTouchGlobalCast()
  if type(now) == "number" then
    storage._lastGlobalCastAt = now
  end
end

function knightAttackingCreature()
  if not g_game or not g_game.isAttacking or not g_game.isAttacking() then return nil end
  return g_game.getAttackingCreature and g_game.getAttackingCreature() or nil
end

function knightAttackingPosition()
  local t = knightAttackingCreature()
  if not t then return nil end
  local ok, p = pcall(function() return t:getPosition() end)
  if ok and p then return p end
  return nil
end

function knightTargetPosPair(creature)
  local mp = pos and pos() or nil
  if not creature or not mp then return nil, nil end
  local ok, tp = pcall(function() return creature:getPosition() end)
  if not ok or not tp then return nil, nil end
  return tp, mp
end

function knightFindLockedPlayer(lockName, sameFloorOnly)
  local tname = knightTrim(lockName or "")
  if tname == "" then return nil end

  local function aliveAndFloor(c)
    if not c or not c.isPlayer or not c:isPlayer() then return nil end
    local pOk, tp = pcall(function() return c:getPosition() end)
    if not pOk or not tp then return nil end
    if sameFloorOnly then
      local lzOk, lz = pcall(function() return posz() end)
      if not lzOk or lz ~= tp.z then return nil end
    end
    local hOk, h = pcall(function() return c:getHealthPercent() end)
    if hOk and type(h) == "number" and h <= 0 then return nil end
    return c
  end

  for _, useMulti in ipairs({ false, true }) do
    if getPlayerByName then
      local ok, c = pcall(function() return getPlayerByName(tname, useMulti) end)
      if ok and c then
        c = aliveAndFloor(c)
        if c then return c end
      end
    end
  end

  if getSpectators then
    local ok, specs = pcall(function() return getSpectators() end)
    if ok and type(specs) == "table" then
      for _, c in pairs(specs) do
        if c and c.isPlayer and c:isPlayer() then
          local locOk, isLocal = pcall(function() return c:isLocalPlayer() end)
          if not (locOk and isLocal) then
            local nOk, n = pcall(function() return c:getName() end)
            if nOk and knightNameMatchLock(tname, n) then
              local v = aliveAndFloor(c)
              if v then return v end
            end
          end
        end
      end
    end
  end
  return nil
end

function knightSeePlayerByNameAnywhere(lockName)
  local n = knightTrim(lockName or "")
  if n == "" then return nil end
  if knightFindLockedPlayer then
    local c = knightFindLockedPlayer(n, false)
    if c then return c end
  end
  if getCreatureByName then
    local ok, x = pcall(function() return getCreatureByName(n) end)
    if ok and x then return x end
  end
  return nil
end

function knightSafeCreatureId(creature)
  if not creature then return 0 end
  local ok, id = pcall(function() return creature:getId() end)
  return (ok and type(id) == "number") and id or 0
end

--- Vertical engine factory: partilhado entre chase (012) e follow (013).
--- prefix determina chaves em storage ("_chase" ou "_follow").
function knightCreateVerticalEngine(prefix)
  local WINDOW_MS = 4800
  local SCAN_RADIUS = 2
  local EXANI_GAP_MS = 900
  local VANISH_WALK_MS = 90
  local VANISH_SURROUND_MS = 750
  local FLOOR_STEPS = 4
  local FLOOR_STEP_MS = 115
  local FOOT_RETRY_MS = { 60, 160 }
  local MISMATCH_ARM_MS = 550

  local adjIndex = 0
  local offPlaneSince = nil
  local lastExaniAt = 0

  local kVU = prefix .. "VerticalUntil"
  local kFx = prefix .. "LadderFx"
  local kFy = prefix .. "LadderFy"
  local kFz = prefix .. "LadderFz"

  local E = {}

  function E.armed()
    local u = storage[kVU]
    return type(u) == "number" and u > now
  end

  function E.arm()
    storage[kVU] = now + WINDOW_MS
  end

  function E.clear()
    storage[kVU] = 0
    offPlaneSince = nil
    storage[kFx] = nil
    storage[kFy] = nil
    storage[kFz] = nil
    adjIndex = 0
  end

  function E.setLadderFoot(oldPos)
    if not oldPos then return end
    storage[kFx] = oldPos.x
    storage[kFy] = oldPos.y
    storage[kFz] = oldPos.z
    adjIndex = 0
  end

  function E.ladderFootXY(lz)
    local fx, fy, fz = storage[kFx], storage[kFy], storage[kFz]
    if type(fx) ~= "number" or type(fy) ~= "number" or type(fz) ~= "number" then return nil, nil end
    if fz ~= lz then return nil, nil end
    return fx, fy
  end

  function E.useSurrounding()
    for i = -1, 1 do
      for j = -1, 1 do
        knightMapUseTopThing(posx() + i, posy() + j, posz())
      end
    end
  end

  function E.tryExaniTera()
    if now - lastExaniAt < EXANI_GAP_MS then return end
    lastExaniAt = now
    if say then pcall(function() say("exani tera") end) end
  end

  function E.tryLadderUsesAtFoot(wx, wy, lz)
    local mp = pos and pos() or nil
    if not mp or mp.z ~= lz then return end
    local cands = {}
    for dx = -SCAN_RADIUS, SCAN_RADIUS do
      for dy = -SCAN_RADIUS, SCAN_RADIUS do
        local x, y = wx + dx, wy + dy
        local t = { x = x, y = y, z = lz }
        if getDistanceBetween(mp, t) <= 1 then
          local df = getDistanceBetween({ x = wx, y = wy, z = lz }, t)
          cands[#cands + 1] = { x = x, y = y, df = df }
        end
      end
    end
    table.sort(cands, function(a, b) return a.df < b.df end)
    if #cands == 0 then return end
    adjIndex = (adjIndex % #cands) + 1
    local c = cands[adjIndex]
    knightMapUseTopThing(c.x, c.y, lz)
  end

  function E.onTargetMoved(creature, newPos, oldPos, targetName)
    if not creature or not oldPos then return end
    local nOk, cname = pcall(function() return creature:getName() end)
    if not nOk or type(cname) ~= "string" then return end
    if targetName == "" or not knightNameMatchLock(targetName, cname) then return end

    if not newPos then
      E.arm()
      E.setLadderFoot(oldPos)
      schedule(VANISH_WALK_MS, function()
        if autoWalk then pcall(function() autoWalk(oldPos) end) end
      end)
      schedule(VANISH_SURROUND_MS, function()
        if E.armed() then E.useSurrounding() end
      end)
    elseif oldPos.z ~= newPos.z then
      E.arm()
      E.setLadderFoot(oldPos)
      local wentUp = newPos.z < oldPos.z
      if autoWalk then pcall(function() autoWalk(oldPos) end) end
      if wentUp then
        knightMapUseTopThing(oldPos.x, oldPos.y, oldPos.z)
        for _, d in ipairs(FOOT_RETRY_MS) do
          schedule(d, function() knightMapUseTopThing(oldPos.x, oldPos.y, oldPos.z) end)
        end
        schedule(FOOT_RETRY_MS[#FOOT_RETRY_MS] + 80, function()
          E.tryLadderUsesAtFoot(oldPos.x, oldPos.y, oldPos.z)
        end)
        knightMapUseTopThing(newPos.x, newPos.y - 1, newPos.z)
      else
        schedule(40, function() knightMapUseTopThing(oldPos.x, oldPos.y, oldPos.z) end)
        schedule(130, function() knightMapUseTopThing(oldPos.x, oldPos.y, oldPos.z) end)
        schedule(220, function() E.tryLadderUsesAtFoot(oldPos.x, oldPos.y, oldPos.z) end)
      end
      for i = 1, FLOOR_STEPS do
        schedule(i * FLOOR_STEP_MS, function()
          if not E.armed() then return end
          if autoWalk and getDistanceBetween(pos(), oldPos) > 1 then
            pcall(function() autoWalk(oldPos) end)
          end
          if getDistanceBetween(pos(), oldPos) == 0 and posz() > newPos.z
              and not knightSeePlayerByNameAnywhere(targetName) then
            E.tryExaniTera()
          end
        end)
      end
    end
  end

  function E.onLocalPlayerAscend(creature, newPos, oldPos, targetName)
    if not newPos or not oldPos or not creature then return end
    local nOk, cname = pcall(function() return creature:getName() end)
    local pOk, pname = pcall(function() return player:getName() end)
    if not nOk or not pOk or type(cname) ~= "string" or type(pname) ~= "string" or cname ~= pname then return end
    if newPos.z <= oldPos.z then return end
    if targetName == "" or not E.armed() then return end
    if knightSeePlayerByNameAnywhere(targetName) then return end
    E.tryExaniTera()
    E.useSurrounding()
  end

  function E.checkOffPlane(lpOk, lp, lz, ffx)
    if lpOk and lp and lp.z ~= lz then
      if not offPlaneSince then offPlaneSince = now end
      if not E.armed() and (now - offPlaneSince) >= MISMATCH_ARM_MS then
        E.arm()
      end
    elseif ffx and (not lpOk or not lp) then
      if not offPlaneSince then offPlaneSince = now end
      if not E.armed() and (now - offPlaneSince) >= MISMATCH_ARM_MS then
        E.arm()
      end
    end
  end

  return E
end

--- Walk memory helper: evita re-path spam no mesmo destino.
function knightCreateWalkMemory(walkGapMs, rewalkMs)
  local lastX, lastY, lastZ = nil, nil, nil
  local lastAt = 0
  local M = {}
  function M.clear()
    lastX, lastY, lastZ = nil, nil, nil
  end
  function M.shouldWalk(tx, ty, tz)
    if now - lastAt < walkGapMs then return false end
    if lastX ~= tx or lastY ~= ty or lastZ ~= tz then return true end
    return (now - lastAt) >= rewalkMs
  end
  function M.remember(tx, ty, tz)
    lastX, lastY, lastZ = tx, ty, tz
    lastAt = now
  end
  return M
end

knightEnsureStorage({
  lastAttackedMe = "",
  lastAttacked = "",
  _target = "",
  _targetId = 0,
  _targetEnabled = false,
  _chaseEnabled = false,
  followLeader = "",
  _followEnabled = false,
  _followVerticalUntil = 0,
  _followLadderFx = nil,
  _followLadderFy = nil,
  _followLadderFz = nil,
  _chaseVerticalUntil = 0,
  _chaseLadderFx = nil,
  _chaseLadderFy = nil,
  _chaseLadderFz = nil,
  pushVictimName = "",
  _pushActive = false,
  _pushDest = nil,
  lastExivaName = "",
  lastExivaMessage = "",
  lastExivaDist = "",
  exivaManualName = "",
  lastExivaTime = 0,
  _lastGlobalCastAt = 0,
})

-- ========== 003_damage_capture.lua ==========

--[[
  003_damage_capture.lua — Registo de nomes para HUD / Recover / Exiva.

  - storage.lastAttackedMe: último autor de dano recebido (parser EN/PT sobre o texto do cliente).
  - storage.lastAttacked: nome da criatura quando o alvo de ataque do cliente muda.

  Depende de: 002_storage_init.lua (`knightTrim`, `knightEnsureStorage`).
  PVE/PVP: mesmo fluxo; filtro por MessageModes.DamageReceived (= 22, gamelib const).
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

-- ========== 004_auto_exori_gauge.lua ==========

--[[
  004_auto_exori_gauge.lua — Exori Gauge.
  Depende de: 002_storage_init.lua
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = KNIGHT_EXORI_GAUGE_SPELL or "exori gauge"
local lastCast = 0
local GAP_MS = 2300
local MIN_MANA = KNIGHT_EXORI_GAUGE_MIN_MANA or 400

local function gaugeReady()
  if knightChatOpen() then return false end
  if hasPartyBuff and hasPartyBuff() then return false end
  return knightSpellReady(lastCast, GAP_MS, MIN_MANA)
end

knightExoriGaugeMacro = macro(200, "Exori Gauge", "Shift+0", function()
  if not gaugeReady() then return end
  if not knightGlobalCastReady(600) then return end
  knightSpellSay(SPELL)
  lastCast = now
  knightTouchGlobalCast()
end)

-- ========== 005_auto_utamo_tempo.lua ==========

--[[
  005_auto_utamo_tempo.lua — Utamo tempo.
  Depende de: 002_storage_init.lua
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "utamo tempo"
local lastCast = 0
local GAP_MS = 2300
local MIN_MANA = 200

local function utamoReady()
  if knightChatOpen() then return false end
  if hasHaste and not hasHaste() then return false end
  if (hasManaShield and hasManaShield()) or (hasPartyBuff and hasPartyBuff()) then return false end
  return knightSpellReady(lastCast, GAP_MS, MIN_MANA)
end

knightUtamoTempoMacro = macro(200, "Utamo Tempo", "Shift+1", function()
  if not utamoReady() then return end
  if not knightGlobalCastReady(600) then return end
  knightSpellSay(SPELL)
  lastCast = now
  knightTouchGlobalCast()
end)

-- ========== 006_auto_haste.lua ==========

--[[
  006_auto_haste.lua — Utani tempo hur.
  Depende de: 002_storage_init.lua
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "utani tempo hur"
local lastCast = 0
local GAP_MS = 3200
local MIN_MANA = 100

local function hasteReady()
  if knightChatOpen() then return false end
  if hasHaste and hasHaste() then return false end
  return knightSpellReady(lastCast, GAP_MS, MIN_MANA)
end

knightHasteMacro = macro(400, "Auto Haste", "Shift+2", function()
  if not hasteReady() then return end
  if not knightGlobalCastReady(600) then return end
  knightSpellSay(SPELL)
  lastCast = now
  knightTouchGlobalCast()
end)

-- ========== 007_exeta_res.lua ==========

--[[
  007_exeta_res.lua — Exeta res melee.
  Depende de: 002_storage_init.lua
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "exeta res"
local lastCast = 0
local GAP_MS = 6000
local MIN_MANA = 350

local function exetaReady()
  if knightChatOpen() then return false end
  local t = knightAttackingCreature()
  if not t then return false end
  local tp, mp = knightTargetPosPair(t)
  if not tp or not mp or tp.z ~= mp.z then return false end
  if getDistanceBetween(mp, tp) > 1 then return false end
  return knightSpellReady(lastCast, GAP_MS, MIN_MANA)
end

knightExetaResMacro = macro(180, "Exeta Res", "Shift+6", function()
  if not exetaReady() then return end
  if not knightGlobalCastReady(600) then return end
  knightSpellSay(SPELL)
  lastCast = now
  knightTouchGlobalCast()
end)

-- ========== 008_anti_paralyze.lua ==========

--[[
  008_anti_paralyze.lua — Anti paralyse (gate global mais curto).
  Depende de: 002_storage_init.lua
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "utani tempo hur"
local lastCast = 0
local GAP_MS = 1700
local MIN_MANA = 60

knightAntiParalyzeMacro = macro(100, "Anti Paralyze", "Shift+3", function()
  if not isParalyzed or not isParalyzed() then return end
  if not mana or mana() < MIN_MANA then return end
  if type(now) ~= "number" then return end
  if (now - lastCast) < GAP_MS then return end
  if not knightGlobalCastReady(200) then return end
  knightSpellSay(SPELL)
  lastCast = now
  knightTouchGlobalCast()
end)

-- ========== 009_anti_kick.lua ==========

--[[
  009_anti_kick.lua - Rotacao periodica do facing (N->E->S->W).

  Em alguns OTs reduz efeito de "kick"/empurrao posicional.
  Pausa se o chat de texto estiver ativo.

  Depende de: 002_storage_init.lua (`knightChatOpen`) quando disponivel.
]]

local ROTATE_MS = 680
local dirIndex = 0 -- 0=N, 1=E, 2=S, 3=W

macro(ROTATE_MS, "Anti Kick", "Shift+4", function()
  if knightChatOpen and knightChatOpen() then return end
  if not turn then return end
  pcall(function() turn(dirIndex) end)
  dirIndex = (dirIndex + 1) % 4
end)

-- ========== 010_combo_knight.lua ==========

--[[
  010_combo_knight.lua — Mas exori hur melee.
  Depende de: 002_storage_init.lua
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "mas exori hur"
local lastCast = 0
local GAP_MS = 2200
local MIN_MANA = 1400

local function masHurReady()
  if knightChatOpen() then return false end
  local t = knightAttackingCreature()
  if not t then return false end
  local tp, mp = knightTargetPosPair(t)
  if not tp or not mp or tp.z ~= mp.z then return false end
  if getDistanceBetween(mp, tp) > 1 then return false end
  return knightSpellReady(lastCast, GAP_MS, MIN_MANA)
end

knightMasExoriHurMacro = macro(200, "Mas Exori Hur", "Shift+5", function()
  if not masHurReady() then return end
  if not knightGlobalCastReady(600) then return end
  knightSpellSay(SPELL)
  lastCast = now
  knightTouchGlobalCast()
end)

-- ========== 011_auto_exori_strike.lua ==========

--[[
  011_auto_exori_strike.lua — Exori strike melee.
  Depende de: 002_storage_init.lua
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "exori strike"
local lastCast = 0
local GAP_MS = 2000
local MIN_MANA = 800

local function strikeReady()
  if knightChatOpen() then return false end
  local t = knightAttackingCreature()
  if not t then return false end
  local tp, mp = knightTargetPosPair(t)
  if not tp or not mp or tp.z ~= mp.z then return false end
  if getDistanceBetween(mp, tp) > 1 then return false end
  return knightSpellReady(lastCast, GAP_MS, MIN_MANA)
end

knightExoriStrikeMacro = macro(180, "Auto Exori Strike", "Shift+7", function()
  if not strikeReady() then return end
  if not knightGlobalCastReady(600) then return end
  knightSpellSay(SPELL)
  lastCast = now
  knightTouchGlobalCast()
end)

-- ========== 012_auto_target.lua ==========

--[[
  012_auto_target.lua — Lock de alvo PVP + Auto Chase.

  - Auto Target (Shift+Q): mantém `g_game.attack` no jogador lockado no mesmo piso.
  - Auto Chase (2): força chase mode 1 e perseguição vertical via motor partilhado
    (`knightCreateVerticalEngine` de 002).

  Exclusão mútua automática com 013 Follow PVP.
  Depende de: 002_storage_init.lua, 003 recomendado (lastAttacked).
]]

storage = (type(storage) == "table" and storage) or {}
if knightEnsureStorage then
  knightEnsureStorage({
    _target = "",
    _targetId = 0,
    lastAttacked = "",
    _targetEnabled = false,
    _chaseEnabled = false,
    _chaseVerticalUntil = 0,
    _chaseLadderFx = nil,
    _chaseLadderFy = nil,
    _chaseLadderFz = nil,
  })
end

local CHASE_POLL_MS = 85
local SAME_FLOOR_COMFORT_DIST = 2
local REATTACK_GAP_MS = 120
local CHASE_ATTACK_GAP_MS = 50
local LADDER_USE_GAP_MS = 280
local LADDER_ACTION_DIST = 4

local trim = knightTrim or function(s)
  if type(s) ~= "string" then return "" end
  return s:match("^%s*(.-)%s*$") or ""
end
local chatOpen = function()
  return knightChatOpen and knightChatOpen() or false
end
local macroIsOn = knightMacroIsOn or function(m)
  if not m then return false end
  local ok, on = pcall(function() return m:isOn() end)
  if ok and on then return true end
  ok, on = pcall(function() return m:isEnabled() end)
  return ok and on or false
end
local nameMatch = knightNameMatchLock or function(a, b)
  return trim(a) ~= "" and trim(a) == trim(b)
end

local chaseEngine = knightCreateVerticalEngine("_chase")
local chaseWalkMem = knightCreateWalkMemory(145, 320)

local throttleAt = {}
local function throttle(key, ms)
  if (now - (throttleAt[key] or 0)) < ms then return false end
  throttleAt[key] = now
  return true
end

local lastChaseLadderUseAt = 0
local chaseWasOn = false

local autoTargetMacro
local autoChaseMacro

local function safeSetOff(m)
  if not m or not m.setOff then return end
  pcall(function() m:setOff() end)
end

local function disableFollowIfNeeded()
  if macroIsOn(knightFollowMacro) then
    safeSetOff(knightFollowMacro)
    storage.followLeader = ""
  end
end

onAttackingCreatureChange(function(creature, oldCreature)
  if not creature or not creature.isPlayer or not creature:isPlayer() then return end
  local nOk, name = pcall(function() return creature:getName() end)
  if not nOk or type(name) ~= "string" or name == "" then return end
  name = trim(name)
  if macroIsOn(autoTargetMacro) or macroIsOn(autoChaseMacro) then
    storage._target = name
    storage.followLeader = ""
  end
end)

onCreaturePositionChange(function(creature, newPos, oldPos)
  if not autoChaseMacro or autoChaseMacro:isOff() then return end
  local tname = knightTrim(storage._target or "")
  chaseEngine.onTargetMoved(creature, newPos, oldPos, tname)
  chaseEngine.onLocalPlayerAscend(creature, newPos, oldPos, tname)
end)

autoTargetMacro = macro(100, "Auto Target", "Shift+Q", function()
  disableFollowIfNeeded()
  if chatOpen() then return end
  if not knightGameAttackReady() then return end

  local tname = trim(storage._target or "")
  local target = knightFindLockedPlayer(tname, true)
  if not target then
    if tname ~= "" then storage._targetId = 0 end
    return
  end

  storage._targetId = knightSafeCreatureId(target)

  local cur = nil
  pcall(function() cur = g_game.getAttackingCreature() end)
  local curName = ""
  if cur and cur.isPlayer and cur:isPlayer() then
    local cnOk, cn = pcall(function() return cur:getName() end)
    if cnOk and type(cn) == "string" then curName = trim(cn) end
  end
  local attacking = false
  pcall(function() attacking = g_game.isAttacking() end)
  if not nameMatch(tname, curName) or not attacking then
    if throttle("reattack", REATTACK_GAP_MS) then knightGameAttack(target) end
  end
end)

autoChaseMacro = macro(CHASE_POLL_MS, "Auto Chase", "2", function()
  if not autoChaseMacro or autoChaseMacro:isOff() then return end
  disableFollowIfNeeded()
  if chatOpen() then return end

  local tname = trim(storage._target or "")
  if tname == "" then
    chaseEngine.clear()
    chaseWalkMem.clear()
    return
  end

  if g_game and g_game.getChaseMode and g_game.setChaseMode then
    local okMode, m = pcall(function() return g_game.getChaseMode() end)
    if okMode and m ~= 1 then pcall(function() g_game.setChaseMode(1) end) end
  end

  local target = knightFindLockedPlayer(tname, false)
  if not target and getPlayerByName then
    for _, multi in ipairs({ true, false }) do
      local ok, p = pcall(function() return getPlayerByName(tname, multi) end)
      if ok and p then target = p break end
    end
  end

  if target then
    storage._targetId = knightSafeCreatureId(target)
  else
    storage._targetId = 0
  end

  if target and knightGameAttackReady() and throttle("chase_attack", CHASE_ATTACK_GAP_MS) then
    knightGameAttack(target)
  end

  if not autoWalk then return end

  local lzOk, lz = pcall(function() return posz() end)
  if not lzOk then return end
  local mp = pos and pos() or nil
  if not mp then return end

  local lp, lpOk = nil, false
  if target then
    local a, b = pcall(function() return target:getPosition() end)
    lpOk = a and b ~= nil
    lp = b
  end

  local ffx, ffy = chaseEngine.ladderFootXY(lz)

  if lpOk and lp.z == lz then
    chaseEngine.clear()
    local sameDist = getDistanceBetween(mp, lp)
    if sameDist <= SAME_FLOOR_COMFORT_DIST then return end
    if not chaseWalkMem.shouldWalk(lp.x, lp.y, lp.z) then return end
    pcall(function()
      autoWalk(lp, 20, { ignoreNonPathable = true, precision = 2 })
    end)
    chaseWalkMem.remember(lp.x, lp.y, lp.z)
    return
  end

  chaseEngine.checkOffPlane(lpOk, lp, lz, ffx)

  local function doChaseOtherPlaneWalkUse(wx, wy)
    if not chaseEngine.armed() then return end
    local dest = { x = wx, y = wy, z = lz }
    local dist = getDistanceBetween(mp, dest)
    if dist <= LADDER_ACTION_DIST then
      if now - lastChaseLadderUseAt >= LADDER_USE_GAP_MS then
        chaseEngine.tryLadderUsesAtFoot(wx, wy, lz)
        lastChaseLadderUseAt = now
      end
      return
    end
    if not chaseWalkMem.shouldWalk(wx, wy, lz) then return end
    pcall(function()
      autoWalk(dest, 20, { ignoreNonPathable = true, precision = 2 })
    end)
    chaseWalkMem.remember(wx, wy, lz)
  end

  if ffx and chaseEngine.armed() then
    doChaseOtherPlaneWalkUse(ffx, ffy)
    return
  end

  if lpOk and lp and lp.z ~= lz and chaseEngine.armed() then
    doChaseOtherPlaneWalkUse(lp.x, lp.y)
  end
end)

local btnClear
local function doClear()
  storage._target = ""
  storage._targetId = 0
  chaseEngine.clear()
  chaseWalkMem.clear()
  if g_game and g_game.cancelAttackAndFollow then
    pcall(function() g_game.cancelAttackAndFollow() end)
  end
  knightFlashBtn(btnClear)
end
btnClear = addButton("btn_clear", "Clear Target [4]", doClear)
hotkey("4", doClear)

local btnRecover
local function doRecover()
  if chatOpen() then return end
  local name = trim(storage.lastAttacked or "")
  if name == "" then return end
  storage._target = name
  local c = knightFindLockedPlayer(name, true)
  storage._targetId = knightSafeCreatureId(c)
  if c then knightGameAttack(c) end
  knightFlashBtn(btnRecover)
end
btnRecover = addButton("btn_recover", "Recover Target [Shift+E]", doRecover)
hotkey("Shift+E", doRecover)

macro(150, function()
  local on = autoChaseMacro and autoChaseMacro:isOn()
  if on and not chaseWasOn then
    chaseEngine.clear()
    chaseWalkMem.clear()
  elseif not on and chaseWasOn then
    chaseEngine.clear()
    chaseWalkMem.clear()
  end
  chaseWasOn = on and true or false
  storage._targetEnabled = macroIsOn(autoTargetMacro)
  storage._chaseEnabled = on
end)

knightAutoTargetMacro = autoTargetMacro
knightAutoChaseMacro = autoChaseMacro

-- ========== 013_follow.lua ==========

--[[
  013_follow.lua — Follow PVP (só caminha; não mantém attack no líder).

  Com a macro ligada, o próximo player atacado passa a ser `followLeader`. Perseguição por
  `autoWalk`; mudança de Z via motor partilhado (`knightCreateVerticalEngine` de 002).
  Uses em sqm adjacentes via `knightMapUseTopThing` (002).

  Exclusão mútua automática com 012 Auto Chase.
  Depende de: 002_storage_init.lua
]]
storage = (type(storage) == "table" and storage) or {}
if knightEnsureStorage then
  knightEnsureStorage({
    followLeader = "",
    lastAttacked = "",
    _followEnabled = false,
    _followVerticalUntil = 0,
    _followLadderFx = nil,
    _followLadderFy = nil,
    _followLadderFz = nil,
  })
end

local FOLLOW_POLL_MS = 85
local SAME_FLOOR_COMFORT_DIST = 2
local INTERRUPTOR_MS = 500
local LADDER_USE_GAP_MS = 280
local LADDER_ACTION_DIST = 4

local trim = knightTrim or function(s)
  if type(s) ~= "string" then return "" end
  return s:match("^%s*(.-)%s*$") or ""
end
local chatOpen = function()
  return knightChatOpen and knightChatOpen() or false
end
local macroIsOn = knightMacroIsOn or function(m)
  if not m then return false end
  local ok, on = pcall(function() return m:isOn() end)
  if ok and on then return true end
  ok, on = pcall(function() return m:isEnabled() end)
  return ok and on or false
end
local nameMatch = knightNameMatchLock or function(a, b)
  return trim(a) ~= "" and trim(a) == trim(b)
end

local followEngine = knightCreateVerticalEngine("_follow")
local followWalkMem = knightCreateWalkMemory(145, 320)

local lastLadderUseAt = 0
local followWasOn = false

local function safeCancelAttack()
  if g_game and g_game.cancelAttack then
    pcall(function() g_game.cancelAttack() end)
  end
end

local function cancelAttackIfTargetingLeader(lname)
  if not lname or lname == "" then return end
  if not g_game or not g_game.isAttacking or not g_game.getAttackingCreature then return end
  local attacking, cur
  local ok = pcall(function()
    attacking = g_game.isAttacking()
    cur = attacking and g_game.getAttackingCreature() or nil
  end)
  if not ok or not cur then return end
  local nOk, n = pcall(function() return cur:getName() end)
  if nOk and type(n) == "string" and nameMatch(lname, n) then
    safeCancelAttack()
  end
end

local followMacro = macro(INTERRUPTOR_MS, "Follow PVP", "3", function() end)
knightFollowMacro = followMacro

local function safeSetOff(m)
  if not m or not m.setOff then return end
  pcall(function() m:setOff() end)
end

local function disableTargetAndChaseIfNeeded()
  if macroIsOn(knightAutoTargetMacro) then safeSetOff(knightAutoTargetMacro) end
  if macroIsOn(knightAutoChaseMacro) then safeSetOff(knightAutoChaseMacro) end
end

onAttackingCreatureChange(function(creature)
  if not followMacro or not followMacro:isOn() then return end
  disableTargetAndChaseIfNeeded()
  if chatOpen() then return end
  if not creature or not creature.isPlayer or not creature:isPlayer() then return end
  local nOk, name = pcall(function() return creature:getName() end)
  if not nOk or type(name) ~= "string" then return end
  name = trim(name)
  if name == "" then return end
  storage.followLeader = name
  storage._target = ""
  safeCancelAttack()
end)

macro(FOLLOW_POLL_MS, function()
  if not followMacro or not followMacro:isOn() then return end
  disableTargetAndChaseIfNeeded()
  if chatOpen() then return end
  local lname = trim(storage.followLeader or "")
  if lname == "" then return end
  cancelAttackIfTargetingLeader(lname)
  if not autoWalk then return end

  local lzOk, lz = pcall(function() return posz() end)
  if not lzOk then return end
  local mp = pos and pos() or nil
  if not mp then return end

  local leader = knightFindLockedPlayer and knightFindLockedPlayer(lname, false) or nil
  if not leader and getPlayerByName then
    for _, multi in ipairs({ true, false }) do
      local ok, p = pcall(function() return getPlayerByName(lname, multi) end)
      if ok and p then leader = p break end
    end
  end

  local lp, lpOk = nil, false
  if leader then
    local a, b = pcall(function() return leader:getPosition() end)
    lpOk = a and b ~= nil
    lp = b
  end

  local ffx, ffy = followEngine.ladderFootXY(lz)

  if lpOk and lp.z == lz then
    followEngine.clear()
    local sameDist = getDistanceBetween(mp, lp)
    if sameDist <= SAME_FLOOR_COMFORT_DIST then return end
    if not followWalkMem.shouldWalk(lp.x, lp.y, lp.z) then return end
    pcall(function()
      autoWalk(lp, 20, { ignoreNonPathable = true, precision = 2 })
    end)
    followWalkMem.remember(lp.x, lp.y, lp.z)
    return
  end

  followEngine.checkOffPlane(lpOk, lp, lz, ffx)

  local function doOtherPlaneWalkUse(wx, wy)
    if not followEngine.armed() then return end
    local target = { x = wx, y = wy, z = lz }
    local dist = getDistanceBetween(mp, target)
    if dist <= LADDER_ACTION_DIST then
      if now - lastLadderUseAt >= LADDER_USE_GAP_MS then
        followEngine.tryLadderUsesAtFoot(wx, wy, lz)
        lastLadderUseAt = now
      end
      return
    end
    if not followWalkMem.shouldWalk(wx, wy, lz) then return end
    pcall(function()
      autoWalk(target, 20, { ignoreNonPathable = true, precision = 2 })
    end)
    followWalkMem.remember(wx, wy, lz)
  end

  if ffx and followEngine.armed() then
    doOtherPlaneWalkUse(ffx, ffy)
    return
  end

  if lpOk and lp and lp.z ~= lz and followEngine.armed() then
    doOtherPlaneWalkUse(lp.x, lp.y)
  end
end)

onCreaturePositionChange(function(creature, newPos, oldPos)
  if not followMacro or followMacro:isOff() then return end
  local lname = trim(storage.followLeader or "")
  if lname == "" then return end
  followEngine.onTargetMoved(creature, newPos, oldPos, lname)
  followEngine.onLocalPlayerAscend(creature, newPos, oldPos, lname)
end)

local btnClearFollow

local function clearFollow()
  storage.followLeader = ""
  followEngine.clear()
  followWalkMem.clear()
  if g_game and g_game.cancelAttackAndFollow then
    pcall(function() g_game.cancelAttackAndFollow() end)
  end
  knightFlashBtn(btnClearFollow)
end

btnClearFollow = addButton("btn_clear_follow", "Clear Follow [1]", clearFollow)
hotkey("1", clearFollow)

macro(150, function()
  local on = followMacro:isOn()
  if on and not followWasOn then
    storage.followLeader = ""
    followEngine.clear()
    followWalkMem.clear()
  end
  followWasOn = on
  storage._followEnabled = on
end)

-- ========== 014_bugmap.lua ==========

--[[
  014_bugmap.lua — “Bug map”: use em linha na direcção das teclas WASD/QEZC.

  Lê teclas via `modules.corelib.g_keyboard` (isKeyPressed). Usa `knightMapUseTopThing` no pé e
  ao longo do vector até ao comprimento do offset (máx 5 passos por eixo).

  Depende de: 002_storage_init.lua (`knightChatOpen`, `knightMapUseTopThing`).
  PVE/PVP: cuidado em PVP (uses visíveis); mesmo comportamento técnico.
]]

local BUG_DIRS = {
  w = { 0, -5 }, e = { 3, -3 }, d = { 5, 0 }, c = { 3, 3 },
  s = { 0, 5 }, z = { -3, 3 }, a = { -5, 0 }, q = { -3, -3 },
}

macro(50, "BugMap", "Shift+T", function()
  if knightChatOpen and knightChatOpen() then return end
  local k = modules.corelib and modules.corelib.g_keyboard
  if not k or not k.isKeyPressed then return end

  local dx, dy
  for key, dir in pairs(BUG_DIRS) do
    if k.isKeyPressed(key) then
      dx, dy = dir[1], dir[2]
      break
    end
  end
  if not dx then return end

  local mp = pos and pos() or nil
  if not mp then return end

  knightMapUseTopThing(mp.x, mp.y, mp.z)
  local steps = math.max(math.abs(dx), math.abs(dy))
  local sx = dx == 0 and 0 or (dx > 0 and 1 or -1)
  local sy = dy == 0 and 0 or (dy > 0 and 1 or -1)
  for i = 1, steps do
    knightMapUseTopThing(mp.x + sx * i, mp.y + sy * i, mp.z)
  end
end)

-- ========== 015_id_cursor_map.lua ==========

--[[
  015_id_cursor_map.lua - Shift+Y imprime ID da criatura/item sob cursor no minimapa.
  Fallback: lista clientIds de todo stack do tile.

  Depende de: gameMapPanel e, opcionalmente, `knightChatOpen` (002).
]]

local function idCursorMapRun()
  if knightChatOpen and knightChatOpen() then return end

  local gm = modules.game_interface and modules.game_interface.gameMapPanel
  if not gm or not gm.mousePos then return end

  local okTile, tile = pcall(function() return gm:getTile(gm.mousePos) end)
  if not okTile or not tile then return end

  local okPos, tpos = pcall(function() return tile:getPosition() end)
  if not okPos or not tpos then return end

  local pstr = string.format("%d,%d,%d", tpos.x, tpos.y, tpos.z)
  local msg = ""

  pcall(function()
    local offset = gm.getPositionOffset and gm:getPositionOffset(gm.mousePos) or nil
    local c = offset and tile.getTopCreatureEx and tile:getTopCreatureEx(offset) or nil
    if c then
      local cname = c.getName and c:getName() or "?"
      local cid = c.getId and c:getId() or "?"
      msg = string.format("[ID] %s id=%s | %s", tostring(cname), tostring(cid), pstr)
      return
    end
    local lt = nil
    if offset and tile.getTopLookThingEx then
      lt = tile:getTopLookThingEx(offset)
    end
    if (not lt) and tile.getTopLookThing then
      lt = tile:getTopLookThing()
    end
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
end

if singlehotkey then
  singlehotkey("Shift+Y", "ID cursor mapa", idCursorMapRun)
else
  hotkey("Shift+Y", idCursorMapRun)
end

-- ========== 016_pull_items.lua ==========

--[[
  016_pull_items.lua — Puxar itens dos 8 sqm vizinhos para o pé (2 direções por tick).

  Considera pickupable ou não “NotMoveable” (API do item). Usa `g_game.move`; só quando parado.

  Depende de: 002_storage_init.lua (`knightChatOpen`, `knightIsWalking`).
  PVE: útil para loot no chão; PVP: pode ser lento — desliga se não quiseres o ruído.
]]

local PD = {
  { -1, -1 }, { 0, -1 }, { 1, -1 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 },
}
local pullTick = 0

local function itemCanPull(item)
  if not item then return false end
  local ok, pick = pcall(function() return item:isPickupable() end)
  if ok and pick then return true end
  ok, pick = pcall(function()
    return item.isNotMoveable and not item:isNotMoveable()
  end)
  return ok and pick == true
end

macro(260, "Puxar Itens", "Shift+F", function()
  if knightChatOpen and knightChatOpen() then return end
  if knightIsWalking and knightIsWalking() then return end
  if not g_map or not g_map.getTile or not g_game or not g_game.move then return end

  local mp = pos and pos() or nil
  if not mp then return end

  pullTick = pullTick + 1
  for off = 0, 1 do
    local idx = ((pullTick - 1 + off) % #PD) + 1
    local d = PD[idx]
    local ok, tile = pcall(function()
      return g_map.getTile({ x = mp.x + d[1], y = mp.y + d[2], z = mp.z })
    end)
    if ok and tile then
      local items = tile.getItems and tile:getItems() or {}
      for _, item in ipairs(items) do
        if itemCanPull(item) then
          local cnt = 1
          pcall(function() cnt = item:getCount() end)
          pcall(function() g_game.move(item, mp, cnt) end)
          return
        end
      end
    end
  end
end)

-- ========== 017_anti_push.lua ==========

--[[
  017_anti_push.lua — Encher o tile do pé com moedas (alterna gold/platinum) ou usar crystal coin.

  Objectivo: reduz empurrões em alguns servidores. Limite de stacks visíveis no tile para evitar
  spam. Só corre quando parado; inventário via `getContainers()` do bot.

  Depende de: 002_storage_init.lua (`knightChatOpen`, `knightIsWalking`).
  PVP: ATENÇÃO — deixa lixo no chão e gasta recursos; avalia risco.
]]

local ITEM_GOLD, ITEM_PLAT, ITEM_CRYSTAL = 3031, 3035, 3043
local TILE_MAX_STACKS = 8

local dropGold = true

macro(420, "Anti Push", "Shift+G", function()
  if knightChatOpen and knightChatOpen() then return end
  if knightIsWalking and knightIsWalking() then return end
  if not g_map or not g_map.getTile or not g_game or not g_game.move or not g_game.use then return end

  local mp = pos and pos() or nil
  if not mp then return end

  local ok, tile = pcall(function() return g_map.getTile(mp) end)
  if not ok or not tile then return end
  local items = tile.getItems and tile:getItems() or {}
  if #items >= TILE_MAX_STACKS then return end

  local gold, plat, crystal
  if getContainers then
    local cOk, containers = pcall(getContainers)
    if cOk and type(containers) == "table" then
      for _, c in pairs(containers) do
        if c and c.getItems then
          for _, item in ipairs(c:getItems() or {}) do
            local idOk, id = pcall(function() return item:getId() end)
            if idOk and type(id) == "number" then
              if id == ITEM_GOLD and not gold then gold = item
              elseif id == ITEM_PLAT and not plat then plat = item
              elseif id == ITEM_CRYSTAL and not crystal then crystal = item
              end
            end
          end
        end
      end
    end
  end

  local function moveOne(it, nextDropGold)
    pcall(function() g_game.move(it, mp, 1) end)
    dropGold = nextDropGold
  end

  if dropGold then
    if gold then moveOne(gold, false) return end
    if plat then pcall(function() g_game.use(plat) end) return end
    if crystal then pcall(function() g_game.use(crystal) end) return end
  else
    if plat then moveOne(plat, true) return end
    if crystal then pcall(function() g_game.use(crystal) end) return end
  end
end)

-- ========== 018_push_control.lua ==========

--[[
  018_push_control.lua — Push assistido: destino sob cursor, vítima por target,
  aproxima e empurra até o tile destino.

  Depende de: 002_storage_init.lua (`knightTrim`, `knightFlashBtn`, `knightIsWalking`,
  `knightEnsureStorage`).
]]

storage = storage or {}
if knightEnsureStorage then
  knightEnsureStorage({
    pushVictimName = "",
    lastAttacked = "",
    _pushActive = false,
    _pushDest = nil,
  })
end

local trim = knightTrim or function(s)
  if type(s) ~= "string" then return "" end
  return s:match("^%s*(.-)%s*$") or ""
end
local flashBtn = knightFlashBtn or function() end
local isWalking = knightIsWalking or function()
  if not player or not player.isWalking then return false end
  local ok, w = pcall(function() return player:isWalking() end)
  return ok and w == true
end

local PUSH_INTERVAL = 480
local pushDest, pushActive, lastPushAt = nil, false, 0
local lastPushWalkAt = 0
local btnPushDest, btnPushMark, btnPushGo, btnPushStop

local function setPushDest()
  pcall(function()
    local tile = getTileUnderCursor()
    if tile then
      pushDest = tile:getPosition()
      storage._pushDest = pushDest
      flashBtn(btnPushDest)
    end
  end)
end

local function markPushVictim()
  local ok, t = pcall(function() return g_game.getAttackingCreature() end)
  if ok and t then
    local pOk, isP = pcall(function() return t:isPlayer() end)
    if pOk and isP then
      local nOk, n = pcall(function() return t:getName() end)
      if nOk and type(n) == "string" and n ~= "" then
        storage.pushVictimName = trim(n)
        flashBtn(btnPushMark)
        return
      end
    end
  end
  local fallback = trim(storage.lastAttacked or "")
  if fallback ~= "" then
    storage.pushVictimName = fallback
    flashBtn(btnPushMark)
  end
end

local function stopPush()
  pushActive = false
  storage._pushActive = false
  flashBtn(btnPushStop)
end

local function startPush()
  if trim(storage.pushVictimName) == "" then markPushVictim() end
  if trim(storage.pushVictimName) == "" or not pushDest then return end
  pushActive = true
  storage._pushActive = true
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

macro(220, function()
  if not pushActive or not pushDest then return end
  local vname = trim(storage.pushVictimName)
  if vname == "" then
    pushActive = false
    storage._pushActive = false
    return
  end

  local ok, creature = pcall(function() return getPlayerByName(vname, true) end)
  if not ok or not creature then return end
  local cpOk, cp = pcall(function() return creature:getPosition() end)
  if not cpOk or not cp then return end

  if cp.x == pushDest.x and cp.y == pushDest.y and cp.z == pushDest.z then
    pushActive = false
    storage._pushActive = false
    return
  end

  local mp = pos and pos() or nil
  if not mp then return end
  if mp.z ~= cp.z or getDistanceBetween(mp, cp) > 1 then
    if not isWalking() and (now - lastPushWalkAt) >= 170 then
      pcall(function() autoWalk(cp, 20, { ignoreNonPathable = true, precision = 1 }) end)
      lastPushWalkAt = now
    end
    return
  end

  if isWalking() then return end
  if mp.x == cp.x and mp.y == cp.y then return end
  if now - lastPushAt < PUSH_INTERVAL then return end

  local dx, dy = pushDest.x - cp.x, pushDest.y - cp.y
  local sx = dx == 0 and 0 or (dx > 0 and 1 or -1)
  local sy = dy == 0 and 0 or (dy > 0 and 1 or -1)
  local np = { x = cp.x + sx, y = cp.y + sy, z = cp.z }
  if np.x == mp.x and np.y == mp.y then return end

  local tOk, destTile = pcall(function() return g_map.getTile(np) end)
  if not tOk or not destTile then return end
  local wOk, walkable = pcall(function() return destTile:isWalkable() end)
  if not wOk or not walkable then return end
  local crOk, cr = pcall(function() return destTile:getCreatures() end)
  if crOk and cr then
    for _, c in ipairs(cr) do if c ~= creature then return end end
  end

  lastPushAt = now
  pcall(function() g_game.move(creature, np) end)
end)

-- ========== 019_exiva.lua ==========

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

-- ========== 020_status_hud.lua ==========

--[[
  020_status_hud.lua — Painel de estado (storage alimentado por 003, 012, 013, push scripts, etc.).

  Linhas: último que te atacou, último alvo atacado, lock/chase, follow, push, modo derivado
  por prioridade (push > follow > chase > lock > idle).

  No pack ordenado: último script (depois de `019_exiva.lua`).
  Depende de: 002_storage_init.lua (`knightEnsureStorage`, `knightTrim`).
]]

storage = (type(storage) == "table" and storage) or {}
if knightEnsureStorage then
  knightEnsureStorage({
    lastAttackedMe = "",
    lastAttacked = "",
    _target = "",
    followLeader = "",
    pushVictimName = "",
    _targetEnabled = false,
    _chaseEnabled = false,
    _followEnabled = false,
    _pushActive = false,
    _pushDest = nil,
  })
end

local trim = knightTrim
local DIM = "#888888"
local hud = {
  addLabel("k_h1", "Atacou-me: -"),
  addLabel("k_h2", "Ataquei: -"),
  addLabel("k_h3", "Alvo: -"),
  addLabel("k_h4", "Follow: -"),
  addLabel("k_h5", "Push: -"),
  addLabel("k_h6", "Mode: idle"),
}

local function setHud(i, text, color)
  pcall(function()
    hud[i]:setText(text)
    hud[i]:setColor(color or DIM)
  end)
end

macro(280, function()
  local am = storage.lastAttackedMe or ""
  local la = storage.lastAttacked or ""
  local tgt = storage._target or ""
  local fl = storage.followLeader or ""
  local pv = trim(storage.pushVictimName or "")
  local targetOn = storage._targetEnabled == true
  local chaseOn = storage._chaseEnabled == true
  local fOn = storage._followEnabled == true and fl ~= ""
  local pushOn = storage._pushActive == true
  local pd = storage._pushDest

  local function v(s) return s ~= "" and s or "-" end

  setHud(1, "Atacou-me: " .. v(am), am ~= "" and "#ff6666" or DIM)
  setHud(2, "Ataquei: " .. v(la), la ~= "" and "#66ff66" or DIM)
  setHud(3, "Alvo: " .. (targetOn and v(tgt) or "-"), targetOn and "#66ff66" or DIM)
  setHud(4, "Follow: " .. (fOn and fl or "-"), fOn and "#66ccff" or DIM)

  if pv ~= "" and pd and type(pd.x) == "number" and type(pd.y) == "number" then
    setHud(5, "Push: [" .. pv .. "] > " .. pd.x .. "," .. pd.y .. (pushOn and " [ON]" or ""),
        pushOn and "#88ff88" or "#ffaa00")
  else
    setHud(5, "Push: " .. (pv ~= "" and ("[" .. pv .. "]") or "-"), pv ~= "" and "#ffaa00" or DIM)
  end

  local mode, mc = "Mode: idle", DIM
  if pushOn then mode, mc = "Mode: push", "#ffaa00"
  elseif fOn then mode, mc = "Mode: follow", "#66ccff"
  elseif chaseOn and targetOn and tgt ~= "" then mode, mc = "Mode: chase", "#88ff88"
  elseif targetOn and tgt ~= "" then mode, mc = "Mode: lock", "#66ff66"
  end
  setHud(6, mode, mc)
end)

-- ========== 021_auto_ring_crowd.lua ==========

--[[
  021_auto_ring_crowd.lua
  Equipa ring quando ha monstros suficientes no raio; desequipa quando abaixo do limite.

  Config (codigo):
    RING_BAG_ID, RING_EQUIPPED_ID
    MONSTER_THRESHOLD  -> >= equipa; < desequipa (default 4)
    CHECK_RADIUS       -> sqm (default 10; ajuste no codigo)
    SAME_FLOOR_ONLY

  Anti-loop (varias rings na BP):
    - Move so 1 unidade para o dedo / para o container.
    - Nao equipa da BP se o dedo ja tiver OUTRO item (evita swap infinito).
    - Timers separados: precisa manter >= limiar por STABLE_EQUIP_MS para equipar;
      precisa manter < limiar por STABLE_UNEQUIP_MS para desequipar (oscilar 3/4 nao reseta o timer errado).
    - Apos equip/unequip com sucesso, bloqueia a acao oposta por POST_*_LOCK_MS.
]]

storage = (type(storage) == "table" and storage) or {}
if knightEnsureStorage then
  knightEnsureStorage({
    ringCrowdEnabled = true,
    ringCrowdManaged = false,
    ringCrowdManagedId = 0,
  })
end

local RING_BAG_ID = 6299
local RING_EQUIPPED_ID = 1128

local MONSTER_THRESHOLD = 4
local CHECK_RADIUS = 10
local SAME_FLOOR_ONLY = true

local CHECK_MS = 220
local ACTION_GAP_MS = 650
local STABLE_EQUIP_MS = 700
local STABLE_UNEQUIP_MS = 900
local POST_EQUIP_LOCK_MS = 2200
local POST_UNEQUIP_LOCK_MS = 2200

local lastActionAt = 0
local lastEquipOkAt = 0
local lastUnequipOkAt = 0
local equipSince = nil
local unequipSince = nil

local function getRingBagId()
  return RING_BAG_ID
end

local function getRingEquippedId()
  return RING_EQUIPPED_ID
end

local function isTargetRingEquipped(equippedId, bagId, equippedAltId)
  if type(equippedId) ~= "number" or equippedId <= 0 then return false end
  if equippedId == bagId then return true end
  if equippedAltId > 0 and equippedId == equippedAltId then return true end
  return false
end

local function ringSlotIndex()
  if type(InventorySlot) == "table" then
    if type(InventorySlot.Ring) == "number" then return InventorySlot.Ring end
    if type(InventorySlot.Finger) == "number" then return InventorySlot.Finger end
  end
  if type(InventorySlotRing) == "number" then return InventorySlotRing end
  if type(InventorySlotFinger) == "number" then return InventorySlotFinger end
  if type(SlotRing) == "number" then return SlotRing end
  if type(SlotFinger) == "number" then return SlotFinger end
  return 9
end

local function getEquippedRing()
  if getFinger then
    local ok, item = pcall(getFinger)
    if ok and item then return item end
  end
  local slot = ringSlotIndex()
  if getInventoryItem then
    local ok, item = pcall(function() return getInventoryItem(slot) end)
    if ok and item then return item end
  end
  if player and player.getInventoryItem then
    local ok, item = pcall(function() return player:getInventoryItem(slot) end)
    if ok and item then return item end
  end
  return nil
end

local function itemId(item)
  if not item or not item.getId then return 0 end
  local ok, id = pcall(function() return item:getId() end)
  if ok and type(id) == "number" then return id end
  return 0
end

local function findRingInContainers(id)
  if not getContainers then return nil end
  local ok, containers = pcall(getContainers)
  if not ok or type(containers) ~= "table" then return nil end
  local best, bestCount = nil, 999999
  for _, c in pairs(containers) do
    if c and c.getItems then
      for _, it in ipairs(c:getItems() or {}) do
        if itemId(it) == id then
          local cnt = 1
          pcall(function() cnt = it:getCount() end)
          if cnt < bestCount then
            best, bestCount = it, cnt
          end
        end
      end
    end
  end
  return best
end

local function moveOneRingToSlot(item)
  if not item then return false end
  local slot = ringSlotIndex()
  if moveToSlot then
    local ok = pcall(function() moveToSlot(item, slot) end)
    if ok then return true end
  end
  if g_game and g_game.move then
    local ok = pcall(function()
      g_game.move(item, { x = 65535, y = slot, z = 0 }, 1)
    end)
    return ok and true or false
  end
  return false
end

local function findContainerFreeSlot()
  if not getContainers then return nil end
  local ok, containers = pcall(getContainers)
  if not ok or type(containers) ~= "table" then return nil end
  for _, c in pairs(containers) do
    if c and c.getItems and c.getCapacity and c.getSlotPosition then
      local items = c:getItems() or {}
      local capOk, cap = pcall(function() return c:getCapacity() end)
      if capOk and type(cap) == "number" and #items < cap then
        for _, idx in ipairs({ #items, #items + 1 }) do
          local posOk, slotPos = pcall(function() return c:getSlotPosition(idx) end)
          if posOk and slotPos then return slotPos end
        end
      end
    end
  end
  return nil
end

local function unequipOneRing(item)
  if not item or not g_game or not g_game.move then return false end
  local dest = findContainerFreeSlot()
  if not dest then return false end
  local ok = pcall(function() g_game.move(item, dest, 1) end)
  return ok and true or false
end

local function countNearbyMonsters(radius, sameFloorOnly)
  if not getSpectators then return 0 end
  local ok, specs = pcall(function() return getSpectators() end)
  if not ok or type(specs) ~= "table" then return 0 end
  local myPos = pos and pos() or nil
  if not myPos then return 0 end

  local total = 0
  for _, c in pairs(specs) do
    if c and c.isMonster and c:isMonster() then
      local pOk, cp = pcall(function() return c:getPosition() end)
      if pOk and cp then
        if (not sameFloorOnly or cp.z == myPos.z) and getDistanceBetween(myPos, cp) <= radius then
          local hOk, hp = pcall(function() return c:getHealthPercent() end)
          if not hOk or (type(hp) == "number" and hp > 0) then
            total = total + 1
          end
        end
      end
    end
  end
  return total
end

macro(CHECK_MS, "Auto Ring Crowd", "Shift+8", function()
  if knightChatOpen and knightChatOpen() then return end
  if storage.ringCrowdEnabled == false then return end
  if now - lastActionAt < ACTION_GAP_MS then return end

  local monsters = countNearbyMonsters(CHECK_RADIUS, SAME_FLOOR_ONLY)

  if monsters >= MONSTER_THRESHOLD then
    unequipSince = nil
    if equipSince == nil then equipSince = now end
  else
    equipSince = nil
    if unequipSince == nil then unequipSince = now end
  end

  local allowEquip = equipSince ~= nil and (now - equipSince) >= STABLE_EQUIP_MS
  local allowUnequip = unequipSince ~= nil and (now - unequipSince) >= STABLE_UNEQUIP_MS

  local bagId = getRingBagId()
  local equippedAltId = getRingEquippedId()
  local ring = getEquippedRing()
  local equippedId = itemId(ring)
  local wearingTargetRing = isTargetRingEquipped(equippedId, bagId, equippedAltId)
  local managedId = tonumber(storage.ringCrowdManagedId) or 0

  if wearingTargetRing and storage.ringCrowdManaged ~= true then
    storage.ringCrowdManaged = true
    storage.ringCrowdManagedId = equippedId
    managedId = equippedId
  end

  if monsters >= MONSTER_THRESHOLD and allowEquip then
    if now - lastUnequipOkAt < POST_UNEQUIP_LOCK_MS then return end
    if wearingTargetRing then return end
    if ring and not wearingTargetRing then return end
    local bagRing = findRingInContainers(bagId)
    if bagRing and moveOneRingToSlot(bagRing) then
      lastActionAt = now
      lastEquipOkAt = now
      storage.ringCrowdManaged = true
      storage.ringCrowdManagedId = equippedAltId > 0 and equippedAltId or bagId
    end
    return
  end

  if monsters < MONSTER_THRESHOLD and allowUnequip then
    if now - lastEquipOkAt < POST_EQUIP_LOCK_MS then return end
    if not ring then
      storage.ringCrowdManaged = false
      storage.ringCrowdManagedId = 0
      return
    end
    local canUnequipManaged = storage.ringCrowdManaged == true
        and managedId > 0
        and equippedId == managedId
    if not (wearingTargetRing or canUnequipManaged) then return end
    if unequipOneRing(ring) then
      lastActionAt = now
      lastUnequipOkAt = now
      storage.ringCrowdManaged = false
      storage.ringCrowdManagedId = 0
    end
  end
end)
