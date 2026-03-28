--[[
  006_exeta_res.lua — Exeta Res em melee (Chebyshev ≤ 1) ao alvo actual.

  Poupa mana se `manapercent()` estiver no limiar; monstro ou player (PVE/PVP).
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "exeta res"
local lastCast = 0
local GAP_MS = 5500
local MIN_MANA = 100
local MIN_MANA_PCT = 30

local function exetaReady()
  if knightChatOpen() then return false end
  local tp = knightAttackingPosition()
  if not tp or getDistanceBetween(pos(), tp) > 1 then return false end
  if manapercent and manapercent() <= MIN_MANA_PCT then return false end
  return knightSupportTimingAndSpellOk(SPELL, lastCast, GAP_MS, MIN_MANA)
end

knightExetaResMacro = macro(180, "Exeta Res", "Shift+6", function()
  if knightSupportShouldDefer("exeta_res") then return end
  if not exetaReady() then return end
  say(SPELL)
  lastCast = now
  knightTouchSupportCast()
end)

knightSupportPriorityRegister("exeta_res", function()
  if not knightSupportMacroEnabled(knightExetaResMacro) then return false end
  return exetaReady()
end)
