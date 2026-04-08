--[[
  010_combo_knight.lua — Mas exori hur melee (simplificado: sem passo lateral nem fila global).
  Depende de: 002_storage_init.lua
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "mas exori hur"
local lastCast = 0
local GAP_MS = 2200
local MIN_MANA = 1400

knightMasExoriHurMacro = macro(200, "Mas Exori Hur", "Shift+5", function()
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
