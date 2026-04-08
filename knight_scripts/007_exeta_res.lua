--[[
  007_exeta_res.lua — Exeta res melee.
  Depende de: 002_storage_init.lua
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "exeta res"
local lastCast = 0
local GAP_MS = 6000
local MIN_MANA = 350

local function exetaReady()
  if knightChatOpen() then return false end
  local t = knightAttackingCreature()
  if not t then return false end
  local tp, mp = knightTargetPosPair(t)
  if not tp or not mp or tp.z ~= mp.z then return false end
  if getDistanceBetween(mp, tp) > 1 then return false end
  return knightSpellReady(lastCast, GAP_MS, MIN_MANA)
end

knightExetaResMacro = macro(180, "Exeta Res", "Shift+6", function()
  if not exetaReady() then return end
  if not knightGlobalCastReady(600) then return end
  knightSpellSay(SPELL)
  lastCast = now
  knightTouchGlobalCast()
end)
