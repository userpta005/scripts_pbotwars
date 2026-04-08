--[[
  015_id_cursor_map.lua - Shift+Y imprime ID da criatura/item sob cursor no minimapa.
  Fallback: lista clientIds de todo stack do tile.

  Depende de: gameMapPanel e, opcionalmente, `knightChatOpen` (002).
]]

local function idCursorMapRun()
  if knightChatOpen and knightChatOpen() then return end

  local gm = modules.game_interface and modules.game_interface.gameMapPanel
  if not gm or not gm.mousePos then return end

  local okTile, tile = pcall(function() return gm:getTile(gm.mousePos) end)
  if not okTile or not tile then return end

  local okPos, tpos = pcall(function() return tile:getPosition() end)
  if not okPos or not tpos then return end

  local pstr = string.format("%d,%d,%d", tpos.x, tpos.y, tpos.z)
  local msg = ""

  pcall(function()
    local offset = gm.getPositionOffset and gm:getPositionOffset(gm.mousePos) or nil
    local c = offset and tile.getTopCreatureEx and tile:getTopCreatureEx(offset) or nil
    if c then
      local cname = c.getName and c:getName() or "?"
      local cid = c.getId and c:getId() or "?"
      msg = string.format("[ID] %s id=%s | %s", tostring(cname), tostring(cid), pstr)
      return
    end
    local lt = nil
    if offset and tile.getTopLookThingEx then
      lt = tile:getTopLookThingEx(offset)
    end
    if (not lt) and tile.getTopLookThing then
      lt = tile:getTopLookThing()
    end
    if lt and lt.getId then
      msg = string.format("[ID] clientId=%s | %s", tostring(lt:getId()), pstr)
    end
  end)

  if msg == "" then
    local ids = {}
    pcall(function()
      for _, item in pairs(tile:getItems() or {}) do
        if item.getId then ids[#ids + 1] = tostring(item:getId()) end
      end
    end)
    msg = string.format("[ID] %s | stack [%s]", pstr, #ids > 0 and table.concat(ids, ", ") or "-")
  end

  print(msg)
  if info then info(msg) end
end

if singlehotkey then
  singlehotkey("Shift+Y", "ID cursor mapa", idCursorMapRun)
else
  hotkey("Shift+Y", idCursorMapRun)
end
