--[[
  002_storage_init.lua — Base do pacote knight_scripts (helpers + `storage`).

  No pack ordenado, vem logo a seguir a `001_pvp_manual_mode.lua` (só regista UI; este ficheiro
  define funções usadas pelo resto). Sem o 001, podes carregar este como primeiro script.

  Referência OTClient v8 (`otclientv8/modules/game_bot`): contexto expõe `say` (= g_game.talk),
  `turn`, `pos`, `mana`, `canCast`, `macro`, `onTextMessage`, `getContainers`, condições em
  `player_conditions.lua` (`hasHaste`, `isParalyzed`, `hasManaShield`, `hasPartyBuff`, …).

  Convenção: prefixo `00N_*.lua` por ordem crescente. Helpers centralizam `pcall` contra APIs
  C++ instáveis (mortes, logout, lag).

  PVE/PVP: nomes de lock/correspondência trim + case-insensitive; distâncias em Chebyshev,
  consistentes com `getDistanceBetween` do bot.
]]

storage = (type(storage) == "table" and storage) or {}

--- Espaço mínimo (ms) entre spells que chamam `knightTouchSupportCast()` (gauge, utamo, haste,
--- exeta, anti-paralyze, mas hur, strike). Evita colisão no mesmo “slot” de grupo/recarga.
KNIGHT_SUPPORT_CAST_GAP = KNIGHT_SUPPORT_CAST_GAP or 1500

--- Spell e mana mínima para o macro 004_auto_exori_gauge.
KNIGHT_EXORI_GAUGE_SPELL = KNIGHT_EXORI_GAUGE_SPELL or "exori gauge"
KNIGHT_EXORI_GAUGE_MIN_MANA = KNIGHT_EXORI_GAUGE_MIN_MANA or 400

--- Prioridade do slot partilhado: índices menores têm precedência no `knightSupportShouldDefer`.
KNIGHT_SUPPORT_PRIORITY_ORDER = KNIGHT_SUPPORT_PRIORITY_ORDER or {
  "anti_paralyze",
  "exori_gauge",
  "utamo_tempo",
  "haste",
  "exeta_res",
  "mas_exori_hur",
  "exori_strike",
}

--- @type table<string, fun(): boolean> mapas `id` → função “quer cast agora” (registo por script).
knightSupportPriorityClaims = knightSupportPriorityClaims or {}

--- @return number gap efetivo em ms
function knightSupportGap()
  return KNIGHT_SUPPORT_CAST_GAP or 1500
end

--- Macro do bot ligada? (`macro`:on()/off() do OTClient).
--- @param macroRef userdata|nil
--- @return boolean
function knightSupportMacroEnabled(macroRef)
  if not macroRef then return false end
  local ok, on = pcall(function() return macroRef:isOn() end)
  return ok and on == true
end

--- Alias semântico para macros que não são “suporte” (ex.: Auto Target).
knightMacroIsOn = knightSupportMacroEnabled

--- Regista pedido de prioridade para o sistema de defer (chamar uma vez por script).
--- @param id string identificador em KNIGHT_SUPPORT_PRIORITY_ORDER
--- @param claimFn fun(): boolean
function knightSupportPriorityRegister(id, claimFn)
  if type(id) ~= "string" or type(claimFn) ~= "function" then return end
  knightSupportPriorityClaims[id] = claimFn
end

--- @param myId string
--- @return boolean true se algum id de prioridade superior “reclama” o próximo cast
function knightSupportShouldDefer(myId)
  if type(KNIGHT_SUPPORT_PRIORITY_ORDER) ~= "table" or type(myId) ~= "string" then return false end
  local myPos
  for i, rid in ipairs(KNIGHT_SUPPORT_PRIORITY_ORDER) do
    if rid == myId then myPos = i break end
  end
  if not myPos then return false end
  for i = 1, myPos - 1 do
    local fn = knightSupportPriorityClaims[KNIGHT_SUPPORT_PRIORITY_ORDER[i]]
    if type(fn) == "function" then
      local ok, wants = pcall(fn)
      if ok and wants then return true end
    end
  end
  return false
end

--- Garante chaves por omissão em `storage` (não sobrescreve valores existentes).
--- @param defaults table|nil
function knightEnsureStorage(defaults)
  if type(defaults) ~= "table" then return end
  if type(storage) ~= "table" then storage = {} end
  for k, v in pairs(defaults) do
    if storage[k] == nil then storage[k] = v end
  end
end

--- @param s any
--- @return string
function knightTrim(s)
  if type(s) ~= "string" then return "" end
  return s:match("^%s*(.-)%s*$") or ""
end

--- Compara nome do lock PVP com nome de criatura (trim + case-insensitive se diferir).
--- @param lockName string|nil
--- @param creatureName string|nil
--- @return boolean
function knightNameMatchLock(lockName, creatureName)
  local a = knightTrim(lockName or "")
  local b = knightTrim(creatureName or "")
  if a == "" or b == "" then return false end
  if a == b then return true end
  return string.lower(a) == string.lower(b)
end

--- Jogador em movimento (`player:isWalking`), com `pcall`.
--- @return boolean
function knightIsWalking()
  if not player or not player.isWalking then return false end
  local ok, w = pcall(function() return player:isWalking() end)
  return ok and w == true
end

--- Flash visual breve em botão (opcional `schedule` do bot).
--- @param b userdata|nil
function knightFlashBtn(b)
  if not b then return end
  pcall(function() b:setImageColor("green") end)
  if schedule then
    schedule(500, function() pcall(function() b:setImageColor("white") end) end)
  end
end

--- `g_map.getTile` + `getTopUseThing` + `g_game.use` (escadas, alavancas, etc.).
--- @param x number
--- @param y number
--- @param z number
function knightMapUseTopThing(x, y, z)
  if not g_map or not g_map.getTile or not g_game or not g_game.use then return end
  pcall(function()
    local tile = g_map.getTile({ x = x, y = y, z = z })
    local top = tile and tile:getTopUseThing()
    if top then g_game.use(top) end
  end)
end

--- @return boolean
function knightGameAttackReady()
  local g = g_game
  return not not (g and g.isAttacking and g.getAttackingCreature and g.attack)
end

--- `g_game.attack(creature)` sem rebentar se o cliente estiver incompleto.
--- @param creature userdata|nil
function knightGameAttack(creature)
  if not creature or not knightGameAttackReady() then return end
  pcall(function() g_game.attack(creature) end)
end

--- Chat de texto activo (não spam de spell ao escrever).
--- @return boolean
function knightChatOpen()
  return modules.game_console and modules.game_console.isChatEnabled and
      modules.game_console:isChatEnabled()
end

--- ms desde o último `knightTouchSupportCast`.
function knightMsSinceSupportCast()
  if type(storage) ~= "table" then return 1e12 end
  return now - (storage.lastSupportCastAt or 0)
end

--- Marca instante do último cast que ocupa o slot partilhado de suporte.
function knightTouchSupportCast()
  if type(storage) == "table" then storage.lastSupportCastAt = now end
end

--- Cooldown local (por spell) + global de suporte + mana + `canCast`. Não inclui defer nem chat.
--- @param spell string
--- @param lastAt number|nil timestamp `now` do último cast desta spell
--- @param localGapMs number
--- @param minMana number|nil
--- @return boolean
function knightSupportTimingAndSpellOk(spell, lastAt, localGapMs, minMana)
  lastAt = lastAt or 0
  if (now - lastAt) < localGapMs then return false end
  if knightMsSinceSupportCast() < knightSupportGap() then return false end
  if minMana and mana and mana() < minMana then return false end
  if canCast and not canCast(spell) then return false end
  return true
end

--- Posição da criatura atacada pelo cliente e posição local.
--- @return userdata|nil
function knightAttackingCreature()
  if not g_game or not g_game.isAttacking or not g_game.isAttacking() then return nil end
  return g_game.getAttackingCreature and g_game.getAttackingCreature() or nil
end

--- Posição do alvo de ataque; nil se não houver alvo válido.
--- @return table|nil
function knightAttackingPosition()
  local t = knightAttackingCreature()
  if not t then return nil end
  local ok, p = pcall(function() return t:getPosition() end)
  if ok and p then return p end
  return nil
end

--- Par `(tp, mp)` para geometria face ao alvo (009/010). `tp` = alvo, `mp` = jogador.
--- @param creature userdata|nil
--- @return table|nil tp, table|nil mp
function knightTargetPosPair(creature)
  local mp = pos and pos() or nil
  if not creature or not mp then return nil, nil end
  local ok, tp = pcall(function() return creature:getPosition() end)
  if not ok or not tp then return nil, nil end
  return tp, mp
end

--- Resolve jogador pelo nome armado em `storage._target` (PVP). Usa `getPlayerByName` e,
--- em fallback, `getSpectators()` (OTClient game_bot `map.lua`).
--- @param lockName string|nil
--- @param sameFloorOnly boolean se true, só aceita criatura no mesmo `posz()` que o local player
--- @return userdata|nil
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

--- Jogador visível em qualquer andar pelo nome (exani / degraus / follow & chase).
--- @param lockName string|nil
--- @return userdata|nil
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

--- ID estável da criatura (0 se inválido).
--- @param creature userdata|nil
--- @return number
function knightSafeCreatureId(creature)
  if not creature then return 0 end
  local ok, id = pcall(function() return creature:getId() end)
  return (ok and type(id) == "number") and id or 0
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
  lastSupportCastAt = 0,
})
