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
