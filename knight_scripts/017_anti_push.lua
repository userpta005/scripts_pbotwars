-- [INICIO] 017_anti_push.lua
--
-- Objetivo: encher o tile onde estás com moedas (gold/plat alternados) ou usar crystal
--   quando não houver stack livre, para reduzir empurrão.

-- Alterna gold/plat no pe ou use de crystal para lotar o tile e dificultar push.
local dropGold = true

macro(420, "Anti Push", "Shift+G", function()
  -- Nao executa durante walk para evitar conflito de acoes.
  if player:isWalking() then return end
  -- Posicao atual.
  local mp = pos()
  -- Se tile ja estiver muito cheio, nao adiciona mais itens.
  local tile = g_map.getTile(mp)
  if tile and #(tile:getItems() or {}) >= 8 then return end

  -- Procura moedas em containers abertos.
  local gold, plat, crystal
  for _, c in pairs(getContainers()) do
    for _, item in ipairs(c:getItems()) do
      local id = item:getId()
      if     id == 3031 and not gold    then gold = item
      elseif id == 3035 and not plat    then plat = item
      elseif id == 3043 and not crystal then crystal = item end
    end
  end

  -- Modo A: prioriza drop de gold.
  if dropGold then
    if gold    then g_game.move(gold, mp, 1); dropGold = false; return end
    if plat    then g_game.use(plat); return end
    if crystal then g_game.use(crystal); return end
  else
    -- Modo B: prioriza drop de plat.
    if plat    then g_game.move(plat, mp, 1); dropGold = true; return end
    if crystal then g_game.use(crystal); return end
  end
end)

-- [FIM] 017_anti_push.lua
