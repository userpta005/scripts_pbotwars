--[[
  004_auto_utamo_tempo.lua — Utamo Tempo só com haste já activo, sem mana shield nem party buff.

  Respeita `canCast` e o sistema de prioridade partilhado (001).
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
  return knightSupportTimingAndSpellOk(SPELL, lastCast, GAP_MS, MIN_MANA)
end

knightUtamoTempoMacro = macro(200, "Utamo Tempo", "Shift+1", function()
  if knightSupportShouldDefer("utamo_tempo") then return end
  if not utamoReady() then return end
  say(SPELL)
  lastCast = now
  knightTouchSupportCast()
end)

knightSupportPriorityRegister("utamo_tempo", function()
  if not knightSupportMacroEnabled(knightUtamoTempoMacro) then return false end
  return utamoReady()
end)
