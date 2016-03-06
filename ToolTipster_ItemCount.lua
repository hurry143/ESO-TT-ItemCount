------------------------------------------------------------
-- NAMESPACE INITIALIZATION
------------------------------------------------------------
ToolTipster_ItemCount = {};
ToolTipster_ItemCount.name = 'ToolTipster_ItemCount';
ToolTipster_ItemCount.version = '0.1.0';
ToolTipster_ItemCount.author = 'hurry143';

-- Register this module with ToolTipster
ToolTipster.submodules[ToolTipster_ItemCount.name] = ToolTipster_ItemCount;

------------------------------------------------------------
-- LOCAL CONSTANTS
------------------------------------------------------------
local TTIC = ToolTipster_ItemCount;
local SV_VER = 1;
local CURRENT_PLAYER = zo_strformat('<<C:1>>', GetUnitName('player'));
local BANK_INDEX = 'bank';
local LIB_ADDON_MENU = 'LibAddonMenu-2.0';
local DEFAULT_SETTINGS = {
  global = false,
  showBank = false,
  showPlayer = false,
  showCharacters = {}
};
local DEFAULT_ACCT_SAVED_VARS = {
  inventory = {},
  knownCharacters = {},
  settings = DEFAULT_SETTINGS,
};
local DEFAULT_CHAR_SAVED_VARS = {
  settings = DEFAULT_SETTINGS,
};

------------------------------------------------------------
-- PRIVATE VARIABLES
------------------------------------------------------------
local savedVars = {};
local knownChars = nil;
local inventory = nil;
local acctSettings = nil;
local charSettings = nil;

------------------------------------------------------------
-- PRIVATE METHODS FOR MAINTAINING THE INVENTORY
------------------------------------------------------------

------------------------------------------------------------
-- Determines whether or not we should care about updates
-- for a given bag.
--
-- @param   bagId   the id of the bag
-- @return  true if bag should be monitored, false otherwise.
local function shouldMonitorBag(bagId)
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
local function updateBagCount(itemKey, location, count) 
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
local function updateInventory(itemLink)
  if (not itemLink) then
    return;
  end
  
  local bagpackCount, bankCount = GetItemLinkStacks(itemLink);
  local itemKey = ToolTipster.CreateItemIndex(itemLink);

  if (not inventory[itemKey]) then
    inventory[itemKey] = {};
  end
      
  updateBagCount(itemKey, CURRENT_PLAYER, bagpackCount);
  updateBagCount(itemKey, BANK_INDEX, bankCount);
  
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

local function deleteCharacter(charName)
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
local function reloadInventory()
  local items = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK, BAG_BANK);
  
  for slot, data in pairs(items) do
    local itemLink = GetItemLink(data.bagId, data.slotIndex);
    cacheItemLink(data.bagId, data.slotIndex, itemLink, data);
    updateInventory(itemLink);
  end

end

------------------------------------------------------------
-- This method is called whenever an item is added to a bag slot.
--
-- @param   bagId     the id of the bag.
-- @param   slotIndex the slot index within the bag. 
-- @param   data      the data of the added slot.
local function onSlotAdded(bagId, slotIndex, data)
  if (not shouldMonitorBag(bagId)) then
    return;
  end
  
  local itemLink = GetItemLink(bagId, slotIndex);
  cacheItemLink(bagId, slotIndex, itemLink, data);
  updateInventory(itemLink);
end

------------------------------------------------------------
-- This method is called whenever an item is removed from a bag slot.
--
-- @param   bagId     the id of the bag.
-- @param   slotIndex the slot index within the bag. 
-- @param   data      the data of the removed slot.
local function onSlotRemoved(bagId, slotIndex, data)
  if (not shouldMonitorBag(bagId)) then
    return;
  end
  
  -- Use the itemLink that was cached when the item was counted earlier.
  updateInventory(getCachedItemLink(bagId, slotIndex, data));
end

------------------------------------------------------------
-- METHODS FOR DEALING WITH ADDON SETTINGS
------------------------------------------------------------

local function activeSettings()
  return ((acctSettings.global and acctSettings) or
          charSettings)
end

local function initLibAddonMenu()
  local panelData = {
    type = 'panel',
    name = GetString(TTIC_NAME),
    displayName = GetString(TTIC_NAME),
    author = TTIC.author,
    version = TTIC.version,
    registerForDefaults = true,
  };
  local optionsData = {};
  
  table.insert(optionsData, {
    type = 'checkbox',
    name = 'Global settings',
    tooltip = 'Global settings',
    getFunc = function() return acctSettings.global end,
    setFunc = function(value)
      local sourceSettings = acctSettings;
      local targetSettings = charSettings;
      if (not value) then
        sourceSettings = charSettings;
        targetSettings = acctSettings;
      end
      for key, value in pairs(sourceSettings) do
        if (type(value) == 'table') then
          for t_key, t_value in pairs(value) do
            targetSettings[key][t_key] = t_value;
          end
        else
          targetSettings[key] = value;
        end
      end
      acctSettings.global = value;
    end,
  });
  
  table.insert(optionsData, {
    type = 'header',
    name = "Select what to show in an item's tooltip",
  });
  
  table.insert(optionsData, {
    type = 'checkbox',
    name = 'Show bank',
    tooltip = 'Show bank count',
    getFunc = function() return activeSettings().showBank end,
    setFunc = function(value) activeSettings().showBank = value end,
  });
  
  table.insert(optionsData, {
    type = 'checkbox',
    name = 'Show player',
    tooltip = 'Show bank player',
    getFunc = function() return activeSettings().showPlayer end,
    setFunc = function(value) activeSettings().showPlayer = value end,
  });
  
  local characters = {};
  for charName, _ in pairs(knownChars) do
    table.insert(characters, charName);
  end
  table.sort(characters);
  
  for i=1, #characters do
    table.insert(optionsData, {
      type = 'checkbox',
      name = 'Show items from '..characters[i],
      tooltip = 'Show count from this character',
      getFunc = function() return activeSettings().showCharacters[characters[i]] end,
      setFunc = function(value) activeSettings().showCharacters[characters[i]] = value end,
    });
  end
  
  local charToDelete = nil;
  local charList = {};
  table.insert(charList, 1, ' ');
  for charName, _ in pairs(knownChars) do
    table.insert(charList, charName);
  end
  table.sort(charList);
  
  table.insert(optionsData, {
    type = 'submenu',
    name = 'Delete a character',
    controls = {
      [1] = {
        type = 'dropdown',
        name = 'Delete a character',
        tooltip = 'Delete a character',
        choices = charList,
        getFunc = function() return charToDelete end,
        setFunc = function(value) charToDelete = value end,
      },
      [2] = {
        type = 'button',
        name = 'Delete character',
        tooltip = 'Click to delete this character',
        func = function() deleteCharacter(charToDelete) end,
      }
    };
  });
  
  local LAM = LibStub(LIB_ADDON_MENU);
  if LAM then
    LAM:RegisterAddonPanel('TTIC_Options', panelData);

    LAM:RegisterOptionControls('TTIC_Options', optionsData);
  end
end

------------------------------------------------------------
-- METHODS FOR INITIALIZING THE ADD-ON
------------------------------------------------------------

------------------------------------------------------------
-- Registers our callback methods with the appropriate events.
local function registerCallback()
  EVENT_MANAGER:RegisterForEvent(TTIC.name, EVENT_INVENTORY_FULL_UPDATE, reloadInventory);
  EVENT_MANAGER:RegisterForEvent(TTIC.name, EVENT_CRAFT_COMPLETED, reloadInventory);
  SHARED_INVENTORY:RegisterCallback('SlotAdded', onSlotAdded);
  SHARED_INVENTORY:RegisterCallback('SlotRemoved', onSlotRemoved);
end

------------------------------------------------------------
-- This method is called when a player has been activated.
-- 
-- @param   eventId   the event code.
local function onPlayerActivated(eventId)
  reloadInventory();
   
  -- Delay registering callbacks until data has been initialized.
  registerCallback();
end

------------------------------------------------------------
-- Initializes data that's shared across an entire account.
local function initAccountData()
  
  savedVars = ZO_SavedVars:NewAccountWide('ItemCount_SavedVars', SV_VER, nil, DEFAULT_ACCT_SAVED_VARS);
  inventory = savedVars.inventory;
  acctSettings = savedVars.settings;
  knownChars = savedVars.knownCharacters;
  
  if (knownChars[CURRENT_PLAYER] == nil) then
      knownChars[CURRENT_PLAYER] = CURRENT_PLAYER;
  end
  
  if (acctSettings.showCharacters[CURRENT_PLAYER] == nil) then
    acctSettings.showCharacters[CURRENT_PLAYER] = true;
  end
end

------------------------------------------------------------
-- Initializes data that's specific to a character.
local function initCharData()
  local charSavedVars = ZO_SavedVars:New('ItemCount_SavedVars', SV_VER, nil, DEFAULT_CHAR_SAVED_VARS);
  charSettings = charSavedVars.settings;
  
  for name, value in pairs(acctSettings.showCharacters) do
    if (charSettings.showCharacters[name] == nil) then
      if (acctSettings.global) then
        charSettings.showCharacters[name] = value;
      else
        charSettings.showCharacters[name] = true;
      end
    end
  end
end

------------------------------------------------------------
-- This method is called whenever any addon is loaded.
-- 
-- @param   eventId   the event code.
-- @param   addonName the name of the loaded addon.
local function onAddOnLoaded(eventId, addonName)
  -- Do nothing if it's some other addon that was loaded.
  if (addonName ~= TTIC.name) then
    return;
  end

  initAccountData();
  initCharData();
  initLibAddonMenu();
  
  EVENT_MANAGER:RegisterForEvent(TTIC.name, EVENT_PLAYER_ACTIVATED, onPlayerActivated);
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
  local itemKey = ToolTipster.CreateItemIndex(itemLink);
  
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
      elseif (activeSettings().showCharacters[location]) then
        table.insert(toolTip, toolTipText);
      end
    
    end
  end
  
  -- Sort the entries by character name.
  table.sort(toolTip);
  
  if (activeSettings().showPlayer and backpack) then
    -- Always show the entry for the current toon before all others.
    table.insert(toolTip, 1, backpack);
  end
  
  if (activeSettings().showBank and bank) then
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

EVENT_MANAGER:RegisterForEvent(TTIC.name, EVENT_ADD_ON_LOADED, onAddOnLoaded);

