--[[
  011_auto_exori_strike.lua — Exori strike melee.
  Depende de: 002_storage_init.lua
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "exori strike"
local lastCast = 0
local GAP_MS = 1650
local MIN_MANA = 800

local function strikeReady()
  if knightChatOpen() then return false end
  local t = knightAttackingCreature()
  if not t then return false end
  local tp, mp = knightTargetPosPair(t)
  if not tp or not mp or tp.z ~= mp.z then return false end
  if getDistanceBetween(mp, tp) > 1 then return false end
  return knightSpellReady(lastCast, GAP_MS, MIN_MANA)
end

knightExoriStrikeMacro = macro(110, "Auto Exori Strike", "Shift+7", function()
  if not strikeReady() then return end
  if not knightGlobalCastReady(520) then return end
  local t = knightAttackingCreature()
  local tp = t and knightTargetPosPair(t) or nil
  if tp and knightFaceTowardPosition then knightFaceTowardPosition(tp) end
  knightSpellSay(SPELL)
  lastCast = now
  knightTouchGlobalCast()
end)
