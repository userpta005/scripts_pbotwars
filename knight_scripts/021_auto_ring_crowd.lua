--[[
  021_auto_ring_crowd.lua
  Equipa ring quando ha monstros suficientes no raio; desequipa quando abaixo do limite.

  Config (codigo):
    RING_BAG_ID, RING_EQUIPPED_ID
    MONSTER_THRESHOLD  -> >= equipa; < desequipa (default 4)
    CHECK_RADIUS       -> sqm (default 10; ajuste no codigo)
    SAME_FLOOR_ONLY

  Anti-loop (varias rings na BP):
    - Move so 1 unidade para o dedo / para o container.
    - Nao equipa da BP se o dedo ja tiver OUTRO item (evita swap infinito).
    - Timers separados: precisa manter >= limiar por STABLE_EQUIP_MS para equipar;
      precisa manter < limiar por STABLE_UNEQUIP_MS para desequipar (oscilar 3/4 nao reseta o timer errado).
    - Apos equip/unequip com sucesso, bloqueia a acao oposta por POST_*_LOCK_MS.

  Pensado para PvE; em PvP desliga a macro ou storage.ringCrowdEnabled = false.
]]

storage = (type(storage) == "table" and storage) or {}
if knightEnsureStorage then
  knightEnsureStorage({
    ringCrowdEnabled = true,
    ringCrowdManaged = false,
  })
end

local RING_BAG_ID = 6299
local RING_EQUIPPED_ID = 1128

local MONSTER_THRESHOLD = 4
local CHECK_RADIUS = 10
local SAME_FLOOR_ONLY = true

local CHECK_MS = 220
local ACTION_GAP_MS = 650
local STABLE_EQUIP_MS = 700
local STABLE_UNEQUIP_MS = 900
local POST_EQUIP_LOCK_MS = 2200
local POST_UNEQUIP_LOCK_MS = 2200

local lastActionAt = 0
local lastEquipOkAt = 0
local lastUnequipOkAt = 0
local equipSince = nil
local unequipSince = nil

local function getRingBagId()
  return RING_BAG_ID
end

local function getRingEquippedId()
  return RING_EQUIPPED_ID
end

local function isTargetRingEquipped(equippedId, bagId, equippedAltId)
  if type(equippedId) ~= "number" or equippedId <= 0 then return false end
  if equippedId == bagId then return true end
  if equippedAltId > 0 and equippedId == equippedAltId then return true end
  return false
end

local function ringSlotIndex()
  if type(InventorySlot) == "table" then
    if type(InventorySlot.Ring) == "number" then return InventorySlot.Ring end
    if type(InventorySlot.Finger) == "number" then return InventorySlot.Finger end
  end
  if type(InventorySlotRing) == "number" then return InventorySlotRing end
  if type(InventorySlotFinger) == "number" then return InventorySlotFinger end
  if type(SlotRing) == "number" then return SlotRing end
  if type(SlotFinger) == "number" then return SlotFinger end
  return 9
end

local function getEquippedRing()
  if getFinger then
    local ok, item = pcall(getFinger)
    if ok and item then return item end
  end
  local slot = ringSlotIndex()
  if getInventoryItem then
    local ok, item = pcall(function() return getInventoryItem(slot) end)
    if ok and item then return item end
  end
  if player and player.getInventoryItem then
    local ok, item = pcall(function() return player:getInventoryItem(slot) end)
    if ok and item then return item end
  end
  return nil
end

local function itemId(item)
  if not item or not item.getId then return 0 end
  local ok, id = pcall(function() return item:getId() end)
  if ok and type(id) == "number" then return id end
  return 0
end

local function findRingInContainers(id)
  if not getContainers then return nil end
  local ok, containers = pcall(getContainers)
  if not ok or type(containers) ~= "table" then return nil end
  local best, bestCount = nil, 999999
  for _, c in pairs(containers) do
    if c and c.getItems then
      for _, it in ipairs(c:getItems() or {}) do
        if itemId(it) == id then
          local cnt = 1
          pcall(function() cnt = it:getCount() end)
          if cnt < bestCount then
            best, bestCount = it, cnt
          end
        end
      end
    end
  end
  return best
end

local function moveOneRingToSlot(item)
  if not item then return false end
  local slot = ringSlotIndex()
  if moveToSlot then
    local ok = pcall(function() moveToSlot(item, slot) end)
    if ok then return true end
  end
  if g_game and g_game.move then
    local ok = pcall(function()
      g_game.move(item, { x = 65535, y = slot, z = 0 }, 1)
    end)
    return ok and true or false
  end
  return false
end

local function findContainerFreeSlot()
  if not getContainers then return nil end
  local ok, containers = pcall(getContainers)
  if not ok or type(containers) ~= "table" then return nil end
  for _, c in pairs(containers) do
    if c and c.getItems and c.getCapacity and c.getSlotPosition then
      local items = c:getItems() or {}
      local capOk, cap = pcall(function() return c:getCapacity() end)
      if capOk and type(cap) == "number" and #items < cap then
        for _, idx in ipairs({ #items, #items + 1 }) do
          local posOk, slotPos = pcall(function() return c:getSlotPosition(idx) end)
          if posOk and slotPos then return slotPos end
        end
      end
    end
  end
  return nil
end

local function unequipOneRing(item)
  if not item or not g_game or not g_game.move then return false end
  local dest = findContainerFreeSlot()
  if not dest then return false end
  local ok = pcall(function() g_game.move(item, dest, 1) end)
  return ok and true or false
end

local function countNearbyMonsters(radius, sameFloorOnly)
  if not getSpectators then return 0 end
  local ok, specs = pcall(function() return getSpectators() end)
  if not ok or type(specs) ~= "table" then return 0 end
  local myPos = pos and pos() or nil
  if not myPos then return 0 end

  local total = 0
  for _, c in pairs(specs) do
    if c and c.isMonster and c:isMonster() then
      local pOk, cp = pcall(function() return c:getPosition() end)
      if pOk and cp then
        if (not sameFloorOnly or cp.z == myPos.z) and getDistanceBetween(myPos, cp) <= radius then
          local hOk, hp = pcall(function() return c:getHealthPercent() end)
          if not hOk or (type(hp) == "number" and hp > 0) then
            total = total + 1
          end
        end
      end
    end
  end
  return total
end

macro(CHECK_MS, "Auto Ring Crowd", "Shift+8", function()
  if knightChatOpen and knightChatOpen() then return end
  if storage.ringCrowdEnabled == false then return end
  if now - lastActionAt < ACTION_GAP_MS then return end

  local monsters = countNearbyMonsters(CHECK_RADIUS, SAME_FLOOR_ONLY)

  if monsters >= MONSTER_THRESHOLD then
    unequipSince = nil
    if equipSince == nil then equipSince = now end
  else
    equipSince = nil
    if unequipSince == nil then unequipSince = now end
  end

  local allowEquip = equipSince ~= nil and (now - equipSince) >= STABLE_EQUIP_MS
  local allowUnequip = unequipSince ~= nil and (now - unequipSince) >= STABLE_UNEQUIP_MS

  local bagId = getRingBagId()
  local equippedAltId = getRingEquippedId()
  local ring = getEquippedRing()
  local equippedId = itemId(ring)
  local wearingTargetRing = isTargetRingEquipped(equippedId, bagId, equippedAltId)

  if wearingTargetRing and storage.ringCrowdManaged ~= true then
    storage.ringCrowdManaged = true
  end

  if monsters >= MONSTER_THRESHOLD and allowEquip then
    if now - lastUnequipOkAt < POST_UNEQUIP_LOCK_MS then return end
    if wearingTargetRing then return end
    if ring and not wearingTargetRing then return end
    local bagRing = findRingInContainers(bagId)
    if bagRing and moveOneRingToSlot(bagRing) then
      lastActionAt = now
      lastEquipOkAt = now
      storage.ringCrowdManaged = true
    end
    return
  end

  if monsters < MONSTER_THRESHOLD and allowUnequip then
    if now - lastEquipOkAt < POST_EQUIP_LOCK_MS then return end
    if not ring then
      storage.ringCrowdManaged = false
      return
    end
    if not (wearingTargetRing or storage.ringCrowdManaged == true) then return end
    if unequipOneRing(ring) then
      lastActionAt = now
      lastUnequipOkAt = now
      storage.ringCrowdManaged = false
    end
  end
end)
