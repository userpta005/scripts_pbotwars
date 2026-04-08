--[[
  011_auto_exori_strike.lua — Exori strike melee (simplificado).
  Depende de: 002_storage_init.lua
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "exori strike"
local lastCast = 0
local GAP_MS = 2000
local MIN_MANA = 800

knightExoriStrikeMacro = macro(180, "Auto Exori Strike", "Shift+7", function()
  local t = knightAttackingCreature()
  if not t then return end
  local tp, mp = knightTargetPosPair(t)
  if not tp or not mp or tp.z ~= mp.z then return end
  if getDistanceBetween(mp, tp) > 1 then return end
  if not knightSpellReady(lastCast, GAP_MS, MIN_MANA) then return end
  if not knightGlobalCastReady(600) then return end
  knightSpellSay(SPELL)
  lastCast = knightNow()
  knightTouchGlobalCast()
end)
