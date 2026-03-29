--[[
  005_auto_haste.lua — Utani Tempo Hur quando falta condição Haste.

  Usa `hasHaste` (PlayerStates.Haste via game_bot). Partilha prioridade global com 002.

  Depende de: 002_storage_init.lua
  PVE/PVP: essencial em movimento; respeita chat fechado para não falar no input.
]]

storage = (type(storage) == "table" and storage) or {}

local SPELL = "utani tempo hur"
local lastCast = 0
local GAP_MS = 3200
local MIN_MANA = 100

local function hasteReady()
  if knightChatOpen() then return false end
  if hasHaste and hasHaste() then return false end
  return knightSupportTimingAndSpellOk(SPELL, lastCast, GAP_MS, MIN_MANA)
end

knightHasteMacro = macro(400, "Auto Haste", "Shift+2", function()
  if knightSupportShouldDefer("haste") then return end
  if not hasteReady() then return end
  say(SPELL)
  lastCast = now
  knightTouchSupportCast()
end)

knightSupportPriorityRegister("haste", function()
  if not knightSupportMacroEnabled(knightHasteMacro) then return false end
  return hasteReady()
end)
