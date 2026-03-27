-- [INICIO] 08_auto_target.lua

-- Lock de alvo, clear, recover e chase compartilham o mesmo estado em storage.
storage = storage or {}
if knightEnsureStorage then
  knightEnsureStorage({
    _target = "",
    _targetId = 0,
    lastAttacked = "",
    _targetEnabled = false,
    _chaseEnabled = false,
  })
end

-- Ultimo "tick" autorizado por chave (debounce de acoes repetidas).
local _ts = {}
local function throttle(key, ms)
  if (now - (_ts[key] or 0)) < ms then return false end
  _ts[key] = now
  return true
end

local flashBtn = knightFlashBtn

onAttackingCreatureChange(function(creature)
  if not creature or not creature:isPlayer() then return end
  storage.lastAttacked = creature:getName()
end)

local autoTargetMacro = macro(100, "Auto Target", "Shift+Q", function()
  local tname = storage._target
  -- Sem nome travado o macro so observa.
  if not tname or tname == "" then return end
  local target = getPlayerByName(tname, true)
  -- Player fora do campo de visao nao da para reatacar.
  if not target then return end
  local tp = target:getPosition()
  -- Alvo em outro andar nao recebe attack automatico.
  if not tp or tp.z ~= posz() then return end

  local cur = g_game.getAttackingCreature()
  local curName = (cur and cur:isPlayer() and cur:getName() or "")
  -- Reafixa ataque se o cliente perdeu o lock ou parou de atacar.
  if curName ~= tname or not g_game.isAttacking() then
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
  -- Recover precisa de historico de ultimo player atacado.
  if not name or name == "" then return end
  storage._target = name
  local c = getPlayerByName(name, true)
  storage._targetId = c and c:getId() or 0
  if c then g_game.attack(c) end
  flashBtn(btnRecover)
end
btnRecover = addButton("btn_recover", "Recover Target [Shift+E]", doRecover)
hotkey("Shift+E", doRecover)

local autoChaseMacro = macro(100, "Auto Chase", "2", function()
  -- Chase mode 1 = seguir agressivamente o alvo.
  if g_game.getChaseMode and g_game.getChaseMode() ~= 1 then
    g_game.setChaseMode(1)
  end
  local target = getPlayerByName(storage._target, true)
  if not target then return end
  local tp = target:getPosition()
  if not tp or tp.z ~= posz() then return end

  if throttle("chase_attack", 150) then g_game.attack(target) end
  if getDistanceBetween(pos(), tp) > 1 then
    if throttle("chase_walk", 180) then
      autoWalk(tp, 20, { ignoreNonPathable = true, precision = 1 })
    end
  end
end)

macro(150, function()
  -- Publica flags para HUD e outros scripts isolados.
  storage._targetEnabled = autoTargetMacro:isOn()
  storage._chaseEnabled = autoChaseMacro:isOn()
end)

-- [FIM] 08_auto_target.lua
