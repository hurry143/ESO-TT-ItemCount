------------------------------------------------------------
-- NAMESPACE INITIALIZATION
------------------------------------------------------------
ToolTipster_ItemCount = {};
ToolTipster_ItemCount.name = 'ToolTipster_ItemCount';
ToolTipster_ItemCount.shortName = 'TTIC';
ToolTipster_ItemCount.version = '1.0.5';
ToolTipster_ItemCount.author = 'hurry143';

------------------------------------------------------------
-- LOCAL CONSTANTS
------------------------------------------------------------
local TTIC = ToolTipster_ItemCount;
local TTIC_OPTIONS_NAME = 'TTIC_Options';
local CURRENT_PLAYER = zo_strformat('<<C:1>>', GetUnitName('player'));
local BANK_INDEX = 'bank';
local LIB_TOOLTIPSTER = 'ToolTipster';
local LIB_ADDON_MENU = 'LibAddonMenu-2.0';
local SV_VER = 1;
local DISPLAY_NAME_OPTIONS = {};
DISPLAY_NAME_OPTIONS['full'] = GetString(TTIC_OPTION_DISPLAY_NAME_FULL);
DISPLAY_NAME_OPTIONS['first'] = GetString(TTIC_OPTION_DISPLAY_NAME_FIRST);
DISPLAY_NAME_OPTIONS['last'] = GetString(TTIC_OPTION_DISPLAY_NAME_LAST);
local DEFAULT_SETTINGS = {
  global = true,
  showBank = false,
  showPlayer = false,
  showAlts = true,
  showGuilds = true,
  displayName = 'full',
  showCharacters = {}
};
local DEFAULT_ACCT_SV = {
  inventory = {},
  guildBanks = {},
  knownCharacters = {},
  settings = DEFAULT_SETTINGS,
};
local DEFAULT_CHAR_SV = {
  settings = DEFAULT_SETTINGS,
};
local GUILD_BANK_RELOAD_DELAY = 1500;

------------------------------------------------------------
-- STYLES AND FORMATTING
------------------------------------------------------------
local BANK_ICON = '|t20:22:ESOUI/art/icons/mapkey/mapkey_bank.dds:inheritColor|t';
local BAG_ICON = '|t20:24:ESOUI/art/crafting/crafting_provisioner_inventorycolumn_icon.dds:inheritColor|t'
local PADDING_TOP = 10;
local TOOLTIP_FONT = 'ZoFontGame';
local COUNT_COLOR = 'FFFFFF';

------------------------------------------------------------
-- PRIVATE VARIABLES
------------------------------------------------------------
local TT = nil;
local LAM = nil;
local savedVars = {};
local optionsData = nil;
local knownChars = nil;
local inventory = nil;
local acctSettings = nil;
local charSettings = nil;
local currentGuildId = nil;
local guildBanks = nil;
local guildBankLoading = false;
local guildBankLoaded = false;

------------------------------------------------------------
-- PRIVATE METHODS FOR TRACKING ACCOUNT INVENTORY
------------------------------------------------------------

------------------------------------------------------------
-- Determines whether or not we should care about updates
-- for a given bag.
--
-- @param   bagId   the id of the bag
-- @return  true if bag should be monitored, false otherwise.
local function shouldMonitorBag(bagId)
  -- We only care about the backpack, the bank, and the guildbank.
  if (bagId > 3) then
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
  local itemKey = TT:CreateItemIndex(itemLink);
  
  if (not itemKey) then
    return;
  end

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

------------------------------------------------------------
-- Deletes the inventory data for a character.
-- 
-- @param charName  the name of the character to delete.
local function deleteCharacter(charName)
  for itemKey, _ in pairs(inventory) do
    for location, amount in pairs(inventory[itemKey]) do
      if (location == charName) then
        inventory[itemKey][location] = nil;
        local count = 0
        for _ in pairs(inventory[itemKey]) do
          count = count + 1;
        end
        if (count == 0) then
          inventory[itemKey] = nil;
        end
      end
    end
  end
  
  -- Remove character from list of known characters.
  TT:RemoveCharacterFromList(knownChars, charName);
  
  -- Remove character from settings.
  acctSettings.showCharacters[charName] = nil;
  charSettings.showCharacters[charName] = nil;
  
  -- Disable the character's checkbox in the settings menu.
  local checkbox = GetControl(TTIC.shortName..'_'..charName);
  checkbox.data.disabled = true;
  checkbox.data.default = false;
  checkbox:UpdateDisabled();
    
  -- Remove the character's entry from the dropdown in the settings menu.
  local dropdown = GetControl(TTIC.shortName..'_Char_DropDown');
  dropdown:UpdateChoices(knownChars);
  dropdown:UpdateValue(true, nil);
end

------------------------------------------------------------
-- Returns the itemLink for an item that was removed from a bag/slot.
-- The link should have been cached when the item was first detected
-- in the bag.
--
-- @param   bagId     the id of the bag.
-- @param   slotIndex the slot index within the bag.
-- @param   data      the slot data.
-- @return  the cached itemLink.
local function getCachedItemLink(bagId, slotIndex, data)
  -- Return the itemLink that we saved as a field in the slot data.
  return data.itemLink;
end

local function getInventory(itemLink)
  local itemKey = TT:CreateItemIndex(itemLink);
  local itemInventory = {};
  
  if (not itemKey or not inventory[itemKey]) then
    return itemInventory;
  end

  for location, count in pairs(inventory[itemKey]) do
    if (count and count > 0) then
      itemInventory[location] = count;
    end
  end

  return itemInventory; 
end

------------------------------------------------------------
-- PRIVATE METHODS FOR TRACKING GUILD INVENTORY
------------------------------------------------------------

local function getGuildInventory(itemLink)
  local itemKey = TT:CreateItemIndex(itemLink);
  local itemInventory = {};
  
  if (not itemKey) then
    return itemInventory;
  end
  
  for guildName, guildInventory in pairs(guildBanks) do 
    if guildInventory[itemKey] then
      itemInventory[guildName] = guildInventory[itemKey]; 
    end
  end

  return itemInventory;
end

------------------------------------------------------------
-- CALLBACKS FOR BAG/BANK UPDATE EVENTS
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

local function updateGuildInventory(itemLink, stackCount)
  if (not itemLink) then
    return;
  end
  
  if not guildBankLoaded then
    return
  end
  
  local guildName = GetGuildName(currentGuildId);
  local itemKey = TT:CreateItemIndex(itemLink);
  if itemKey then   
    if not guildBanks[guildName][itemKey] then
      guildBanks[guildName][itemKey] = 0;
    end
    
    guildBanks[guildName][itemKey] = guildBanks[guildName][itemKey] + stackCount;
    
    if (guildBanks[guildName][itemKey] <= 0) then
      guildBanks[guildName][itemKey] = nil;
    end
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
  if (bagId == BAG_GUILDBANK) then
    updateGuildInventory(itemLink, data.stackCount);
  else
    updateInventory(itemLink);
  end
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
  local itemLink = getCachedItemLink(bagId, slotIndex, data)
  if (bagId == BAG_GUILDBANK) then
    updateGuildInventory(itemLink, -1 * data.stackCount);
  else
    updateInventory(itemLink);
  end
end

------------------------------------------------------------
-- CALLBACKS FOR GUILD BANK UPDATE EVENTS
------------------------------------------------------------

local function reloadGuildInventory()
  if guildBankLoading then
    return 
  end;
  guildBankLoading = true;

  local guildName = GetGuildName(currentGuildId);
  local numSlots, numItems = 0, 0;
  guildBanks[guildName] = {};
  guildBanks[guildName]['timestamp'] = GetTimeStamp();
  local items = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_GUILDBANK);
  for slot, data in pairs(items) do
    numSlots = numSlots + 1;
    local itemLink = GetItemLink(data.bagId, data.slotIndex);
    if itemLink then
      cacheItemLink(data.bagId, data.slotIndex, itemLink, data);
      local itemKey = TT:CreateItemIndex(itemLink);
      if itemKey then
        if not guildBanks[guildName][itemKey] then
          guildBanks[guildName][itemKey] = 0;
          numItems = numItems + 1;
        end
        guildBanks[guildName][itemKey] = guildBanks[guildName][itemKey] + data.stackCount;
      end
    end
  end
  d(TTIC.name..': Scanned '..numItems..' items in '..numSlots..' slots for guild('..currentGuildId..') '..guildName);
  guildBankLoaded = true;
end

local function onGuildBankReady()
  zo_callLater(function() reloadGuildInventory() end, GUILD_BANK_RELOAD_DELAY);
end

local function onGuildBankSelected(event, guildId)
  guildBankLoading = false;
  guildBankLoaded = false;
  currentGuildId = guildId;
end

local function onGuildQuit(event, guildId, guildName)
  guildBanks[guildName] = nil;
end

------------------------------------------------------------
-- METHODS FOR DEALING WITH ADDON SETTINGS
------------------------------------------------------------

------------------------------------------------------------
-- If 'global' is turned on, then returns the current settings for
-- the entire account, otherwise returns the current settings for
-- the active character. The returned settings saved as part of this
-- addon's saved variables.
-- @return  the table containing the current settings.
local function activeSettings()
  return ((acctSettings.global and acctSettings) or
          charSettings)
end

------------------------------------------------------------
-- Builds out the controls for the settings menu.
local function buildOptionsMenu()

  if not LAM then
    return;
  end

  -- Create the data for populating the settings panel.
  optionsData = {};
  
  table.insert(optionsData, {
    type = 'description',
    text = GetString(TTIC_DESC),
  });
  
  table.insert(optionsData, {
    type = 'header',
    name = GetString(TTIC_MENU_GENERAL),
  });
  
  -- Create an option to save the settings account-wide.
  table.insert(optionsData, {
    type = 'checkbox',
    name = GetString(TTIC_OPTION_GLOBAL),
    tooltip = GetString(TTIC_OPTION_GLOBAL_TIP),
    default = DEFAULT_SETTINGS.global,
    getFunc = function() return acctSettings.global end,
    setFunc = function(value)
      TT:CopyAddonSettings(value, acctSettings, charSettings);
      acctSettings.global = value;
    end,
  });

  -- Create an option to show the amount of the item stored in the bank.
  table.insert(optionsData, {
    type = 'checkbox',
    name = GetString(TTIC_OPTION_BANK),
    tooltip = GetString(TTIC_OPTION_BANK_TIP),
    default = DEFAULT_SETTINGS.showBank,
    getFunc = function() return activeSettings().showBank end,
    setFunc = function(value) activeSettings().showBank = value end,
  });
  
  -- Create an option to show the amount of the item stored in the current bag.
  table.insert(optionsData, {
    type = 'checkbox',
    name = GetString(TTIC_OPTION_PLAYER),
    tooltip = GetString(TTIC_OPTION_PLAYER_TIP),
    default = DEFAULT_SETTINGS.showPlayer,
    getFunc = function() return activeSettings().showPlayer end,
    setFunc = function(value) activeSettings().showPlayer = value end,
  });
  
  -- Create an option to show the amount of the item stored in alts' bag.
  table.insert(optionsData, {
    type = 'checkbox',
    name = GetString(TTIC_OPTION_ALTS),
    tooltip = GetString(TTIC_OPTION_ALTS_TIP),
    default = DEFAULT_SETTINGS.showAlts,
    getFunc = function() return activeSettings().showAlts end,
    setFunc = function(value)
      activeSettings().showAlts = value;
      for _, altName in pairs(knownChars) do
        -- Toggle the character's checkbox in the settings menu.
        local checkbox = GetControl(TTIC.shortName..'_'..altName);
        if checkbox then
          checkbox.data.disabled = not value;
          checkbox.data.default = true;
          checkbox:UpdateDisabled();
        end
      end
    end,
  });
  
  -- Create an option to show the amount of the item stored in alts' bag.
  table.insert(optionsData, {
    type = 'checkbox',
    name = GetString(TTIC_OPTION_GUILDS),
    tooltip = GetString(TTIC_OPTION_GUILDS_TIP),
    default = DEFAULT_SETTINGS.showGuilds,
    getFunc = function() return activeSettings().showGuilds end,
    setFunc = function(value)
      activeSettings().showGuilds = value;
    end,
  });
  
  -- Create a section for selecting which characters to report amounts for.
  table.insert(optionsData, {
    type = 'header',
    name = GetString(TTIC_MENU_CHARACTERS),
  });
  
  table.insert(optionsData, {
    type = 'description',
    text = GetString(TTIC_MENU_CHARACTERS_DESC),
  });

  -- Create a checkbox for each character.
  for i=1, #knownChars do
    table.insert(optionsData, {
      type = 'checkbox',
      name = GetString(TTIC_OPTION_CHARACTER)..'|cF7F49E'..knownChars[i]..'|r',
      tooltip = GetString(TTIC_OPTION_CHARACTER_TIP),
      default = true,
      getFunc = function() return activeSettings().showCharacters[knownChars[i]] end,
      setFunc = function(value) activeSettings().showCharacters[knownChars[i]] = value end,
      disabled = false,
      reference = TTIC.shortName..'_'..knownChars[i],
    });
  end
  
  -- Create a section for appearance options.
  table.insert(optionsData, {
    type = 'header',
    name = GetString(TTIC_MENU_APPEARANCE),
  });
  
  table.insert(optionsData, {
    type = 'description',
    text = GetString(TTIC_MENU_APPEARANCE_DESC),
  });
  
  table.insert(optionsData, {
    type = 'dropdown',
    name = GetString(TTIC_OPTION_DISPLAY_NAME),
    tooltip = GetString(TTIC_OPTION_DISPLAY_NAME_TIP),
    choices = { GetString(TTIC_OPTION_DISPLAY_NAME_FULL), GetString(TTIC_OPTION_DISPLAY_NAME_FIRST), GetString(TTIC_OPTION_DISPLAY_NAME_LAST) },
    default = DEFAULT_SETTINGS.displayName,
    getFunc = function() return DISPLAY_NAME_OPTIONS[activeSettings().displayName] end,
    setFunc = function(value)
        local selected = 'full';
        for option, text in pairs(DISPLAY_NAME_OPTIONS) do
          if (text == value) then
            selected = option;
            break;
          end
        end
        activeSettings().displayName = selected;
      end,
  });
  
  -- Create an option for removing a character's data.
  local charToDelete = nil;
  
  -- Create a dropdown list and a button for deleting a character's data.
  table.insert(optionsData, {
    type = 'submenu',
    name = GetString(TTIC_MENU_DELETE),
    controls = {
      [1] = {
        type = 'description',
        text = GetString(TTIC_MENU_DELETE_DESC);
      },
      [2] = {
        type = 'dropdown',
        name = GetString(TTIC_OPTION_DELETE),
        tooltip = GetString(TTIC_OPTION_DELETE_TIP),
        choices = knownChars,
        getFunc = function() return charToDelete end,
        setFunc = function(value) charToDelete = value end,
        reference = TTIC.shortName..'_Char_DropDown', 
      },
      [3] = {
        type = 'button',
        name = GetString(TTIC_BUTTON_DELETE),
        tooltip = GetString(TTIC_BUTTON_DELETE_TIP),
        func = function() deleteCharacter(charToDelete) end,
      }
    };
  });
  
  LAM:RegisterOptionControls(TTIC_OPTIONS_NAME, optionsData);
end

------------------------------------------------------------
-- Uses LibAddonMenu to initialize the settings menu for this addon.
local function initOptionsMenu()

  LAM = LibStub(LIB_ADDON_MENU);
  if not LAM then
    return;
  end
  
  -- Create the basic data for creating the settings panel.
  local panelData = {
    type = 'panel',
    name = GetString(TTIC_NAME),
    displayName = GetString(TTIC_DISPLAY_NAME),
    author = TTIC.author,
    version = TTIC.version,
    registerForDefaults = true,
    registerForRefresh = true,
  };
  
  LAM:RegisterAddonPanel(TTIC_OPTIONS_NAME, panelData);
end

------------------------------------------------------------
-- PRIVATE METHODS FOR CREATING TOOLTIPS
------------------------------------------------------------

------------------------------------------------------------
-- Creates the tooltip text that shows the item count in a given bag.
--
-- @param location  bank or the name of a character.
-- @param count     the number to display.
local function createToolTipText(location, count, displayName)
  if (location == BANK_INDEX) then
    location = BANK_ICON;
  elseif (location == CURRENT_PLAYER) then
    location = BAG_ICON;
  elseif (displayName ~= 'full') then
    -- Display only the character's first name.
    for i in string.gmatch(location, "%S+") do
      location = ' '..i;
      if (displayName == 'first') then
        break;
      end
    end
  else
    location = ' '..location;
  end
  return zo_strformat('|c<<1>><<2>>|r<<3>>', COUNT_COLOR, count, location);
end

------------------------------------------------------------
-- Add info to an item's tooltip.
--
-- @param   control   the item tooltip control to modify.
-- @param   itemLink  the link for the item.
local function showToolTip(control, itemLink)
  if (not itemLink) then
    return;
  end

  local toolTip = {};
  local itemInventory = getInventory(itemLink);

  if (activeSettings().showAlts) then
    for _, charName in ipairs(knownChars) do
      if (charName ~= CURRENT_PLAYER and itemInventory[charName] and activeSettings().showCharacters[charName]) then
        table.insert(toolTip, createToolTipText(charName, itemInventory[charName], activeSettings().displayName));
      end
    end
  end
   
  if (activeSettings().showPlayer and itemInventory[CURRENT_PLAYER]) then
    table.insert(toolTip, 1, createToolTipText(CURRENT_PLAYER, itemInventory[CURRENT_PLAYER], 'full'));
  end
  
  if (activeSettings().showBank and itemInventory[BANK_INDEX]) then
    table.insert(toolTip, 1, createToolTipText(BANK_INDEX, itemInventory[BANK_INDEX], 'full'));
  end
  
  
  if (#toolTip > 0) then
    -- Concatenate all the entries into one line and add it to the tooltip.
    control:AddVerticalPadding(PADDING_TOP);
    control:AddLine(table.concat(toolTip, '  '), TOOLTIP_FONT, ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB());
  end
  
  if (activeSettings().showGuilds) then
    local guildInventory = getGuildInventory(itemLink);
    local lineNum = 1;
    for guildName, count in pairs(guildInventory) do
      if count > 0 then
        if lineNum == 1 then
          control:AddVerticalPadding(PADDING_TOP);
        else
          control:AddVerticalPadding(-10);
        end
        control:AddLine(createToolTipText(guildName, count, 'full'), TOOLTIP_FONT, 51/255, 245/255, 77/255);
        lineNum = lineNum + 1;
      end
    end
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
  EVENT_MANAGER:RegisterForEvent(TTIC.name, EVENT_GUILD_BANK_SELECTED, onGuildBankSelected);
  EVENT_MANAGER:RegisterForEvent(TTIC.name, EVENT_GUILD_BANK_ITEMS_READY, onGuildBankReady);
  EVENT_MANAGER:RegisterForEvent(TTIC.name, EVENT_GUILD_SELF_LEFT_GUILD, onGuildQuit);
  SHARED_INVENTORY:RegisterCallback('SlotAdded', onSlotAdded);
  SHARED_INVENTORY:RegisterCallback('SlotRemoved', onSlotRemoved);
  TT:RegisterCallback(TT.events.TT_EVENT_ITEM_TOOLTIP, showToolTip);
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
  
  savedVars = ZO_SavedVars:NewAccountWide('ItemCount_SavedVars', SV_VER, nil, DEFAULT_ACCT_SV);
  
  -- Create references to the various components of the saved variable.
  inventory = savedVars.inventory;
  guildBanks = savedVars.guildBanks;
  acctSettings = savedVars.settings;
  knownChars = savedVars.knownCharacters;
  
  -- Make sure that we add the current character to the list of known characters.
  if (TT:AddCharacterToList(knownChars, CURRENT_PLAYER)) then
      acctSettings.showCharacters[CURRENT_PLAYER] = true;
  end
  
  -- Check to see if we were kicked out of a guild while logged off.
  local guilds = {};
  for i=1, GetNumGuilds() do
    local guildId = GetGuildId(i);
    table.insert(guilds, GetGuildName(guildId));
  end
  
  for gName, _ in pairs(guildBanks) do
    local isMember = false;
    for _, guild in pairs(guilds) do
      if (gName == guild) then isMember = true; break; end
    end
    if not isMember then guildBanks[gName] = nil; end
  end
end

------------------------------------------------------------
-- Initializes data that's specific to a character.
local function initCharData()
  local charSavedVars = ZO_SavedVars:New('ItemCount_SavedVars', SV_VER, nil, DEFAULT_CHAR_SV);
  
  -- Create a reference to the character's settings.
  charSettings = charSavedVars.settings;
  
  for name, value in pairs(acctSettings.showCharacters) do
    -- If the current character is new, then make sure that the settings
    -- include it as an option.
    if (charSettings.showCharacters[name] == nil) then
      if (acctSettings.global) then
        -- If 'global' is true, then just use the global setting.
        charSettings.showCharacters[name] = value;
      else
        -- Otherwise, show the character's inventory by default.
        charSettings.showCharacters[name] = true;
      end
    end
  end
  
  -- Sync up with account settings.
  for name, value in pairs(charSettings.showCharacters) do
    -- Delete any characters that may have been deleted from the account
    -- settings since the last time the current character logged off.
    if (acctSettings.showCharacters[name] == nil) then
      charSettings.showCharacters[name] = nil;
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

  TT = LibStub(LIB_TOOLTIPSTER);
  initAccountData();
  initCharData();
  initOptionsMenu();
  buildOptionsMenu();
  
  EVENT_MANAGER:RegisterForEvent(TTIC.name, EVENT_PLAYER_ACTIVATED, onPlayerActivated);
  EVENT_MANAGER:UnregisterForUpdate(EVENT_ADD_ON_LOADED);
end

------------------------------------------------------------
-- REGISTER WITH THE GAME'S EVENTS
------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent(TTIC.name, EVENT_ADD_ON_LOADED, onAddOnLoaded);