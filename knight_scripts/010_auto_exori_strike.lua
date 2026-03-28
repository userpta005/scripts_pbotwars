--[[
  010_auto_exori_strike.lua — Exori Strike com alvo adjacente (≤1 SQM), mesmo andar.

  Monstro ou player; integra slot de suporte e throttle global.
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "exori strike"
local lastCast = 0
local GAP_MS = 2000
local MIN_MANA = 800

local function strikeReady()
  if knightChatOpen() then return false end
  local t = knightAttackingCreature()
  if not t then return false end
  local tp, mp = knightTargetPosPair(t)
  if not tp or not mp or tp.z ~= mp.z then return false end
  if getDistanceBetween(mp, tp) > 1 then return false end
  return knightSupportTimingAndSpellOk(SPELL, lastCast, GAP_MS, MIN_MANA)
end

knightExoriStrikeMacro = macro(180, "Auto Exori Strike", "Shift+7", function()
  if knightSupportShouldDefer("exori_strike") then return end
  if not strikeReady() then return end
  say(SPELL)
  lastCast = now
  knightTouchSupportCast()
end)

knightSupportPriorityRegister("exori_strike", function()
  if not knightSupportMacroEnabled(knightExoriStrikeMacro) then return false end
  return strikeReady()
end)
