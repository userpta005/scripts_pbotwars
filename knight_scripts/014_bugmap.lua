-- [INICIO] 014_bugmap.lua
--
-- Objetivo: com teclas WASD/QEZC (estilo movimento), `use` no tile atual e ao longo
--   de uma linha de tiles (“bug map”) sem disparar com chat aberto.

-- Bug map: usa tiles em linha na direcao das teclas (sem depender do chat aberto).
local function useTopThing(x, y, z)
  local tile = g_map.getTile({x = x, y = y, z = z})
  -- Item ou objeto usavel no topo do tile.
  local top = tile and tile:getTopUseThing()
  if top then g_game.use(top) end
end

-- Offset dx/dy por tecla no teclado do client (grade 8 direcoes).
local BUG_DIRS = {
  w={0,-5}, e={3,-3}, d={5,0}, c={3,3},
  s={0,5}, z={-3,3}, a={-5,0}, q={-3,-3},
}

macro(50, "BugMap", "Shift+T", function()
  -- Evita usar teclas do bug map enquanto o chat captura input.
  if modules.game_console and modules.game_console:isChatEnabled() then return end
  local k = modules.corelib and modules.corelib.g_keyboard
  if not k then return end

  -- Vetor (dx,dy) conforme tecla ainda pressionada naquele tick.
  local dx, dy
  for key, dir in pairs(BUG_DIRS) do
    if k.isKeyPressed(key) then dx, dy = dir[1], dir[2]; break end
  end
  if not dx then return end

  -- Tile inicial e raio em passos ao longo da linha escolhida.
  local mp = pos()
  useTopThing(mp.x, mp.y, mp.z)
  local steps = math.max(math.abs(dx), math.abs(dy))
  -- Passo unitario -1/0/+1 em cada eixo para caminhar a reta.
  local sx = dx == 0 and 0 or (dx > 0 and 1 or -1)
  local sy = dy == 0 and 0 or (dy > 0 and 1 or -1)
  for i = 1, steps do
    useTopThing(mp.x + sx * i, mp.y + sy * i, mp.z)
  end
end)

-- [FIM] 014_bugmap.lua
