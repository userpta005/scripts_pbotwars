--[[
  003_auto_exori_gauge.lua — Mantém Exori Gauge quando possível.

  - Não lança com party buff equivalente (`hasPartyBuff`).
  - Partilha slot com outros suportes via `knightSupportShouldDefer` + `knightTouchSupportCast`.
  - Em PVP/PVE: não dispara com chat aberto.

  Constantes globais opcionais: KNIGHT_EXORI_GAUGE_SPELL, KNIGHT_EXORI_GAUGE_MIN_MANA (001).
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = KNIGHT_EXORI_GAUGE_SPELL or "exori gauge"
local lastCast = 0
local GAP_MS = 2300
local MIN_MANA = KNIGHT_EXORI_GAUGE_MIN_MANA or 400

local function gaugeReady()
  if knightChatOpen() then return false end
  if hasPartyBuff and hasPartyBuff() then return false end
  return knightSupportTimingAndSpellOk(SPELL, lastCast, GAP_MS, MIN_MANA)
end

knightExoriGaugeMacro = macro(200, "Exori Gauge", "Shift+0", function()
  if knightSupportShouldDefer("exori_gauge") then return end
  if not gaugeReady() then return end
  say(SPELL)
  lastCast = now
  knightTouchSupportCast()
end)

knightSupportPriorityRegister("exori_gauge", function()
  if not knightSupportMacroEnabled(knightExoriGaugeMacro) then return false end
  return gaugeReady()
end)
