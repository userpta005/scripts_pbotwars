-- [INICIO] 07_combo_knight.lua

-- Primeiras duas pancadas do ciclo (strike).
local STRIKE_SPELL = "exori strike"
-- Finisher alinhado ao alvo no passo 3.
local MAS_HUR = "mas exori hur"
-- Espera minima antes de recomecar o ciclo completo.
local COMBO_CD = 1750

-- Passo atual (1-3) e id do player para detectar troca de alvo.
local comboStep, comboLastTargetId = 1, 0
-- Timestamp do fim do ultimo ciclo e do ultimo strike.
local lastComboEnd, lastStrikeAt = 0, 0

onAttackingCreatureChange(function(creature)
  if not creature or not creature:isPlayer() then return end
  local id = creature:getId()
  -- Reseta FSM do combo quando o lock muda de player.
  if id ~= comboLastTargetId then
    comboStep = 1
    comboLastTargetId = id
  end
end)

macro(85, "Combo Knight", "Shift+5", function()
  -- Combo so contra player visivel como alvo de ataque.
  local t = g_game.getAttackingCreature()
  if not t or not t:isPlayer() then return end
  local tp, mp = t:getPosition(), pos()
  -- Mesmo andar obrigatorio para direcionar mas hur.
  if not tp or not mp or tp.z ~= mp.z then return end

  if comboStep <= 2 then
    -- Passo 1: respeita CD global entre ciclos.
    if comboStep == 1 and lastComboEnd > 0 and (now - lastComboEnd) < COMBO_CD then return end
    -- Passo 2: micro-gap entre dois strikes seguidos.
    if comboStep == 2 and (now - lastStrikeAt) < 100 then return end
    say(STRIKE_SPELL)
    lastStrikeAt = now
    comboStep = comboStep + 1
  elseif comboStep == 3 then
    -- Orienta o sprite antes do area finisher.
    local dx, dy = tp.x - mp.x, tp.y - mp.y
    if dx ~= 0 or dy ~= 0 then
      turn(math.abs(dx) >= math.abs(dy) and (dx > 0 and 1 or 3) or (dy > 0 and 2 or 0))
    end
    say(MAS_HUR)
    comboStep = 1
    lastComboEnd = now
  end
end)

-- [FIM] 07_combo_knight.lua
