------------------------------------------------------------
-- NAMESPACE INITIALIZATION
------------------------------------------------------------
ToolTipster_ItemCount = {};
ToolTipster_ItemCount.name = 'ToolTipster_ItemCount';

-- Register this module with ToolTipster
ToolTipster.submodules[ToolTipster_ItemCount.name] = ToolTipster_ItemCount;

------------------------------------------------------------
-- LOCAL CONSTANTS
------------------------------------------------------------
local TTIC = ToolTipster_ItemCount;
local SV_INVENTORY_VER = 1;
local CURRENT_PLAYER = zo_strformat('<<C:1>>', GetUnitName('player'));
local BANK_INDEX = 'bank';

------------------------------------------------------------
-- PRIVATE VARIABLES
------------------------------------------------------------
local inventory = nil;
local itemLinkCache = {};

------------------------------------------------------------
-- PRIVATE METHODS FOR MAINTAINING THE INVENTORY
------------------------------------------------------------

------------------------------------------------------------
-- Determines whether or not we should care about updates
-- for a given bag.
--
-- @param   bagId   the id of the bag
-- @return  true if bag should be monitored, false otherwise.
local function ShouldMonitorBag(bagId)
  -- We only care about the backpack and the bank.
  if (bagId > 2) then
    return false;
  end
  
  return true;
end

------------------------------------------------------------
-- Updates the count for an item at an location.
--
-- @param   itemKey   the 'unique' key for the item.
-- @param   location  bank or the name of a character.
local function UpdateBagCount(itemKey, location, count) 
  if (count > 0) then
    -- Update the location's count for the item. 
    inventory[itemKey][location] = count;
  else
    -- If the location no longer has any stacks of the item, then
    -- remove the location's entry from the item's table.
    inventory[itemKey][location] = nil;
  end
end

------------------------------------------------------------
-- Updates the inventory info for an item.
--
-- @param   itemLink  the link for the item.
local function UpdateInventory(itemLink)
  if (not itemLink) then
    return;
  end
  
  local bagpackCount, bankCount = GetItemLinkStacks(itemLink);
  local itemKey = ToolTipster.createItemIndex(itemLink);

  if (not inventory[itemKey]) then
    inventory[itemKey] = {};
  end
      
  UpdateBagCount(itemKey, CURRENT_PLAYER, bagpackCount);
  UpdateBagCount(itemKey, BANK_INDEX, bankCount);
  
  -- Count the number of entries that remain for the item after the updates.
  local count = 0
  for _ in pairs(inventory[itemKey]) do
    count = count + 1;
  end

  if (count == 0) then
    -- If there aren't any stacks of the item anywhere, then remove
    -- the item's entry completely.
    inventory[itemKey] = nil;
  end
end

------------------------------------------------------------
-- Saves the itemLink for an item in a bag/slot. This cached value
-- can be used if that item is removed from the same slot later,
-- since the SlotRemoved does not provide any data about the removed
-- item.
--
-- @param   bagId     the id of the bag.
-- @param   slotIndex the slot index within the bag.
-- @param   itemLink  the itemLink to save.
-- @param   data      the slot data.
local function cacheItemLink(bagId, slotIndex, itemLink, data)
  -- For now, save the itemLink as a field directly in the slot data.
  -- We always have the option of saving it in a local table.
  data.itemLink = itemLink;
end

------------------------------------------------------------
-- Returns the itemLink for an item that was removed from a bag/slot.
-- The link should have been cached when the item was first detected
-- in the bag.
--
-- @param   bagId     the id of the bag.
-- @param   slotIndex the slot index within the bag.
-- @param   data      the slot data.
-- @return  itemLink  the cached itemLink.
local function getCachedItemLink(bagId, slotIndex, data)
  -- Return the itemLink that we saved as a field in the slot data.
  return data.itemLink;
end

------------------------------------------------------------
-- PRIVATE METHODS FOR CREATING TOOLTIPS
------------------------------------------------------------

------------------------------------------------------------
-- Creates the tooltip text that shows the item count in a given bag.
--
-- @param location  bank or the name of a character.
-- @param count     the number to display.
local function createToolTipText(location, count)
  if (location == BANK_INDEX) then
    location = GetString(TTIC_LABEL_BANK);
  end
  return location..': '..count;
end

------------------------------------------------------------
-- CALLBACKS FOR BAG UPDATE EVENTS
------------------------------------------------------------

------------------------------------------------------------
-- Re-scans all items in both the bank and the current player's
-- backpack and updates the inventory data accordingly.
local function ReloadInventory()
  local items = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK, BAG_BANK);
  
  for slot, data in pairs(items) do
    local itemLink = GetItemLink(data.bagId, data.slotIndex);
    cacheItemLink(data.bagId, data.slotIndex, itemLink, data);
    UpdateInventory(itemLink);
  end

end

------------------------------------------------------------
-- This method is called whenever an item is added to a bag slot.
--
-- @param   bagId     the id of the bag.
-- @param   slotIndex the slot index within the bag. 
-- @param   data      the data of the added slot.
local function OnSlotAdded(bagId, slotIndex, data)
  if (not ShouldMonitorBag(bagId)) then
    return;
  end
  
  local itemLink = GetItemLink(bagId, slotIndex);
  cacheItemLink(bagId, slotIndex, itemLink, data);
  UpdateInventory(itemLink);
end

------------------------------------------------------------
-- This method is called whenever an item is removed from a bag slot.
--
-- @param   bagId     the id of the bag.
-- @param   slotIndex the slot index within the bag. 
-- @param   data      the data of the removed slot.
local function OnSlotRemoved(bagId, slotIndex, data)
  if (not ShouldMonitorBag(bagId)) then
    return;
  end
  
  -- Use the itemLink that was cached when the item was counted earlier.
  UpdateInventory(getCachedItemLink(bagId, slotIndex, data));
end

------------------------------------------------------------
-- METHODS FOR INITIALIZING THE ADD-ON
------------------------------------------------------------

------------------------------------------------------------
-- Registers our callback methods with the appropriate events.
local function RegisterCallback()
  EVENT_MANAGER:RegisterForEvent(TTIC.name, EVENT_INVENTORY_FULL_UPDATE, ReloadInventory);
  EVENT_MANAGER:RegisterForEvent(TTIC.name, EVENT_CRAFT_COMPLETED, ReloadInventory);
  SHARED_INVENTORY:RegisterCallback('SlotAdded', OnSlotAdded);
  SHARED_INVENTORY:RegisterCallback('SlotRemoved', OnSlotRemoved);
end

------------------------------------------------------------
-- This method is called when a player has been activated.
-- 
-- @param   eventId   the event code.
local function OnPlayerActivated(eventId)
  ReloadInventory();
  
  -- Delay registering callbacks until data has been initialized.
  RegisterCallback();
end

------------------------------------------------------------
-- Initializes data that's shared across an entire account.
local function InitAccountData()
  local default = {};
  
  inventory = ZO_SavedVars:NewAccountWide('ItemCount_Inventory', SV_INVENTORY_VER, nil, default);
end

------------------------------------------------------------
-- This method is called whenever any addon is loaded.
-- 
-- @param   eventId   the event code.
-- @param   addonName the name of the loaded addon.
local function OnAddOnLoaded(eventId, addonName)
  -- Do nothing if it's some other addon that was loaded.
  if (addonName ~= TTIC.name) then
    return;
  end

  InitAccountData();

  EVENT_MANAGER:RegisterForEvent(TTIC.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated);
  EVENT_MANAGER:UnregisterForUpdate(EVENT_ADD_ON_LOADED);
end

------------------------------------------------------------
-- PUBLIC METHODS
------------------------------------------------------------

------------------------------------------------------------
-- Add info to an item's tooltip.
--
-- @param   control   the item tooltip control to modify.
-- @param   itemLink  the link for the item.
function ToolTipster_ItemCount.ShowToolTip(control, itemLink)
  if (not itemLink) then
    return;
  end

  local toolTip = {};
  local bank = nil;
  local backpack = nil;
  local itemKey = ToolTipster.createItemIndex(itemLink);
  
  if (not itemKey or not inventory[itemKey]) then
    return;
  end

  for location, count in pairs(inventory[itemKey]) do
    if (count and count > 0) then
      local toolTipText = createToolTipText(location, count);
      
      if (location == BANK_INDEX) then
        bank = toolTipText;
      elseif (location == CURRENT_PLAYER) then
        backpack = toolTipText;
      else
        table.insert(toolTip, toolTipText);
      end
    
    end
  end
  
  -- Sort the entries by character name.
  table.sort(toolTip);
  
  if backpack then
    -- Always show the entry for the current toon before all others.
    table.insert(toolTip, 1, backpack);
  end
  
  if bank then
    -- Always show the entry for the bank first.
    table.insert(toolTip, 1, bank);
  end
  
  if (#toolTip > 0) then
    -- Concatenate all the entries into one line and add it to the tooltip.
    control:AddLine(table.concat(toolTip, ', '));
  end
end

------------------------------------------------------------
-- REGISTER WITH THE GAME'S EVENTS
------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent(TTIC.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded);

