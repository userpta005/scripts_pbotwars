--[[
  021_auto_ring_crowd.lua
  Equipa anel automaticamente quando houver muitos monstros proximos e desequipa quando normaliza.

  Config:
    RING_ID            -> clientId do anel (default 6299)
    MONSTER_THRESHOLD  -> minimo de monstros para equipar (default 4)
    CHECK_RADIUS       -> raio em sqm para contagem (default 6)
    SAME_FLOOR_ONLY    -> contar so no mesmo andar (default true)
]]

storage = (type(storage) == "table" and storage) or {}
if knightEnsureStorage then
  knightEnsureStorage({
    ringCrowdEnabled = true,
    ringCrowdRingId = 6299,
    ringCrowdEquippedId = 1128,
    ringCrowdManaged = false,
  })
end

-- Configuracao via codigo (sem campo UI):
-- RING_BAG_ID: id do ring no container
-- RING_EQUIPPED_ID: id do ring quando equipado (se transformar)
local RING_BAG_ID = 6299
local RING_EQUIPPED_ID = 1128

local MONSTER_THRESHOLD = 4
local CHECK_RADIUS = 6
local SAME_FLOOR_ONLY = true

local CHECK_MS = 220
local ACTION_GAP_MS = 450

local lastActionAt = 0

local function getConfiguredRingId()
  return RING_BAG_ID
end

local function getConfiguredEquippedId()
  return RING_EQUIPPED_ID
end

local function isTargetRingEquipped(equippedId, ringId, equippedAltId)
  if type(equippedId) ~= "number" or equippedId <= 0 then return false end
  if equippedId == ringId then return true end
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
  for _, c in pairs(containers) do
    if c and c.getItems then
      for _, it in ipairs(c:getItems() or {}) do
        if itemId(it) == id then
          return it
        end
      end
    end
  end
  return nil
end

local function moveItemToRingSlot(item)
  if not item then return false end
  local slot = ringSlotIndex()
  local moved = false

  if moveToSlot then
    local ok = pcall(function() moveToSlot(item, slot) end)
    if ok then return true end
  end

  if g_game and g_game.move then
    local count = 1
    pcall(function() count = item:getCount() end)
    local ok = pcall(function()
      g_game.move(item, { x = 65535, y = slot, z = 0 }, math.max(1, count))
    end)
    moved = ok and true or false
  end
  return moved
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
        -- Alguns clientes usam index 0-based, outros 1-based.
        local candidates = { #items, #items + 1 }
        for _, idx in ipairs(candidates) do
          local posOk, slotPos = pcall(function() return c:getSlotPosition(idx) end)
          if posOk and slotPos then return slotPos end
        end
      end
    end
  end
  return nil
end

local function unequipRing(item)
  if not item or not g_game or not g_game.move then return false end
  local dest = findContainerFreeSlot()
  if not dest then return false end
  local count = 1
  pcall(function() count = item:getCount() end)
  local ok = pcall(function() g_game.move(item, dest, math.max(1, count)) end)
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
  local ringId = getConfiguredRingId()
  local equippedAltId = getConfiguredEquippedId()
  local ring = getEquippedRing()
  local equippedId = itemId(ring)
  local atk = knightAttackingCreature and knightAttackingCreature() or nil
  local attackingMonster = atk and atk.isMonster and atk:isMonster() or false
  local shouldEquip = attackingMonster and monsters >= MONSTER_THRESHOLD
  local wearingTargetRing = isTargetRingEquipped(equippedId, ringId, equippedAltId)

  -- Recupera o estado após reload: se já estiver usando o ring alvo, marca como gerenciado.
  if wearingTargetRing and storage.ringCrowdManaged ~= true then
    storage.ringCrowdManaged = true
  end

  if shouldEquip then
    if wearingTargetRing then return end
    local bagRing = findRingInContainers(ringId)
    if bagRing and moveItemToRingSlot(bagRing) then
      lastActionAt = now
      storage.ringCrowdManaged = true
    end
    return
  end

  local shouldUnequip = (not attackingMonster) or monsters < MONSTER_THRESHOLD
  if not ring then
    storage.ringCrowdManaged = false
    return
  end

  -- Se fomos nós que equipamos, remove mesmo que o ID do item mude ao equipar.
  local canRemoveManaged = storage.ringCrowdManaged == true
  if shouldUnequip and (canRemoveManaged or wearingTargetRing) and unequipRing(ring) then
    lastActionAt = now
    storage.ringCrowdManaged = false
  end
end)


