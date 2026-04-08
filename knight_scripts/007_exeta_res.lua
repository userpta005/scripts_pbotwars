--[[
  007_exeta_res.lua — Exeta res melee (simplificado).
  Depende de: 002_storage_init.lua
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "exeta res"
local lastCast = 0
local GAP_MS = 6000
local MIN_MANA = 350

knightExetaResMacro = macro(180, "Exeta Res", "Shift+6", function()
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
