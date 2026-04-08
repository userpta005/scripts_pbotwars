--[[
  006_auto_haste.lua — Utani tempo hur (simplificado).
  Depende de: 002_storage_init.lua
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "utani tempo hur"
local lastCast = 0
local GAP_MS = 3200
local MIN_MANA = 100

knightHasteMacro = macro(400, "Auto Haste", "Shift+2", function()
  if hasHaste and hasHaste() then return end
  if not knightSpellReady(lastCast, GAP_MS, MIN_MANA) then return end
  if not knightGlobalCastReady(600) then return end
  knightSpellSay(SPELL)
  lastCast = knightNow()
  knightTouchGlobalCast()
end)
