--[[
  008_anti_paralyze.lua — Anti paralyse (simplificado).
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
  if not knightSpellReady(lastCast, GAP_MS, MIN_MANA) then return end
  -- Prioriza resposta ao paralyze com gate global mais curto.
  if not knightGlobalCastReady(200) then return end
  knightSpellSay(SPELL)
  lastCast = knightNow()
  knightTouchGlobalCast()
end)
