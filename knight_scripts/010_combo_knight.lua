--[[
  010_combo_knight.lua — Mas exori hur melee.
  Depende de: 002_storage_init.lua
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "mas exori hur"
local lastCast = 0
local GAP_MS = 2000
local MIN_MANA = 1400

local function masHurReady()
  if knightChatOpen() then return false end
  local t = knightAttackingCreature()
  if not t then return false end
  local tp, mp = knightTargetPosPair(t)
  if not tp or not mp or tp.z ~= mp.z then return false end
  if getDistanceBetween(mp, tp) > 1 then return false end
  return knightSpellReady(lastCast, GAP_MS, MIN_MANA)
end

knightMasExoriHurMacro = macro(150, "Mas Exori Hur", "Shift+5", function()
  if not masHurReady() then return end
  if not knightGlobalCastReady(520) then return end
  local t = knightAttackingCreature()
  local tp = t and knightTargetPosPair(t) or nil
  if tp and knightTryStepSideForDiagonal and knightTryStepSideForDiagonal(tp, 190) then return end
  if tp and knightFaceTowardPosition then knightFaceTowardPosition(tp) end
  knightSpellSay(SPELL)
  lastCast = now
  knightTouchGlobalCast()
end)
