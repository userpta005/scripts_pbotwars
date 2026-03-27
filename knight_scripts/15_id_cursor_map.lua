-- [INICIO] 15_id_cursor_map.lua

-- Hotkey: ID de creature/item sob cursor ou stack completo do tile.
singlehotkey("Shift+Y", "ID cursor mapa", function()
  -- Nao dispara enquanto o foco esta no chat.
  if modules.game_console and modules.game_console:isChatEnabled() then return end
  -- Painel do mapa precisa existir e expor mousePos.
  local gm = modules.game_interface and modules.game_interface.gameMapPanel
  if not gm or not gm.mousePos then return end
  local tile = gm:getTile(gm.mousePos)
  if not tile then return end
  local tpos = tile:getPosition()
  -- Coordenadas fixas para o rodape da mensagem.
  local pstr = string.format("%d,%d,%d", tpos.x, tpos.y, tpos.z)
  local msg = ""
  pcall(function()
    -- Offset dentro do tile conforme pixel sob o cursor.
    local offset = gm:getPositionOffset(gm.mousePos)
    -- Prioriza criatura no stack sob o cursor.
    local c = tile:getTopCreatureEx(offset)
    if c then
      msg = string.format("[ID] %s id=%s | %s", c:getName() or "?", tostring(c:getId()), pstr)
      return
    end
    -- Senao item "look" no mesmo offset ou topo generico do tile.
    local lt = tile:getTopLookThingEx(offset) or tile:getTopLookThing()
    if lt and lt.getId then
      msg = string.format("[ID] clientId=%s | %s", tostring(lt:getId()), pstr)
    end
  end)
  -- Fallback: dump de todos os clientIds empilhados no tile.
  if msg == "" then
    local ids = {}
    pcall(function()
      for _, item in pairs(tile:getItems() or {}) do
        if item.getId then ids[#ids + 1] = tostring(item:getId()) end
      end
    end)
    msg = string.format("[ID] %s | stack [%s]", pstr, #ids > 0 and table.concat(ids, ", ") or "-")
  end
  -- Eco no log do bot; popup opcional se o client expoe info().
  print(msg)
  if info then info(msg) end
end)

-- [FIM] 15_id_cursor_map.lua
