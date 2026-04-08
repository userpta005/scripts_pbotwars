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
