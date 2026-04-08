--[[
  004_auto_exori_gauge.lua — Exori Gauge.
  Depende de: 002_storage_init.lua
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = KNIGHT_EXORI_GAUGE_SPELL or "exori gauge"
local lastCast = 0
local GAP_MS = 2300
local MIN_MANA = KNIGHT_EXORI_GAUGE_MIN_MANA or 400

local function gaugeReady()
  if knightChatOpen() then return false end
  if hasPartyBuff and hasPartyBuff() then return false end
  return knightSpellReady(lastCast, GAP_MS, MIN_MANA)
end

knightExoriGaugeMacro = macro(200, "Exori Gauge", "Shift+0", function()
  if not gaugeReady() then return end
  if not knightGlobalCastReady(600) then return end
  knightSpellSay(SPELL)
  lastCast = now
  knightTouchGlobalCast()
end)
