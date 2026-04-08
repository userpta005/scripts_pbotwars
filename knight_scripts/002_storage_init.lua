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
