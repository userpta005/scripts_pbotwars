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
