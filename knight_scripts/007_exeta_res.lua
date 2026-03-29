--[[
  006_exeta_res.lua — Exeta Res em contacto (Chebyshev ≤ 1) com o alvo atacado.

  Exige percentagem de mana mínima (evita exeta “seco”). Cooldown local + fila 002.

  Depende de: 002_storage_init.lua (`knightAttackingPosition`, `manapercent`).
  PVE/PVP: válido contra qualquer criatura atacada que esteja adjacente.
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
  local mp = pos and pos() or nil
  if not tp or not mp or getDistanceBetween(mp, tp) > 1 then return false end
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
