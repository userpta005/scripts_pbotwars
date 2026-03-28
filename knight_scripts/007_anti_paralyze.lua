--[[
  007_anti_paralyze.lua — Utani Tempo Hur para remover paralisia (prioridade máxima na fila 001).

  Propósito PVP/PVE: reagir de imediato — não bloqueia por chat nem pelo gap global *antes* do
  cast (só cooldown local + mana + `canCast`). Após `say`, `knightTouchSupportCast()` evita
  colidir com outros suportes no mesmo tick.

  Depende de: 001_storage_init.lua
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "utani tempo hur"
local lastCast = 0
local GAP_MS = 1700
local MIN_MANA = 60

local function antiParalyzeReady()
  if not isParalyzed or not isParalyzed() then return false end
  if not mana or mana() < MIN_MANA then return false end
  if (now - lastCast) < GAP_MS then return false end
  if canCast and not canCast(SPELL) then return false end
  return true
end

knightAntiParalyzeMacro = macro(100, "Anti Paralyze", "Shift+3", function()
  if knightSupportShouldDefer("anti_paralyze") then return end
  if not antiParalyzeReady() then return end
  say(SPELL)
  lastCast = now
  knightTouchSupportCast()
end)

knightSupportPriorityRegister("anti_paralyze", function()
  if not knightSupportMacroEnabled(knightAntiParalyzeMacro) then return false end
  return antiParalyzeReady()
end)
