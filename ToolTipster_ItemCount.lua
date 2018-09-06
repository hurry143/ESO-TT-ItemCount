------------------------------------------------------------
-- LOCAL CONSTANTS
------------------------------------------------------------
local TTIC = ToolTipster_ItemCount;
local TT = ToolTipster_ItemCount.LIBTT;
local CURRENT_PLAYER = zo_strformat('<<C:1>>', GetUnitName('player'));
local SECS_PER_WEEK = 604800;
local SECS_PER_DAY = 86400;
local SECS_PER_HOUR = 3600;

-- Determines whether or not a bag should be monitored for slots added/removed.
local MONITOR_BAGS = {
  [BAG_WORN] = true; -- 0
  [BAG_BACKPACK] = true; -- 1
  [BAG_BANK] = true; -- 2
  [BAG_GUILDBANK] = true; -- 3
  [BAG_BUYBACK] = true; -- 4
  [BAG_VIRTUAL] = true; -- 5
  [BAG_SUBSCRIBER_BANK] = false; -- 6
  [BAG_HOUSE_BANK_ONE] = false; -- 7
  [BAG_HOUSE_BANK_TWO] = false; -- 8
  [BAG_HOUSE_BANK_THREE] = false; -- 9
  [BAG_HOUSE_BANK_FOUR] = false; -- 10
  [BAG_HOUSE_BANK_FIVE] = false; -- 11
  [BAG_HOUSE_BANK_SIX] = false; -- 12
  [BAG_HOUSE_BANK_SEVEN] = false; -- 13
  [BAG_HOUSE_BANK_EIGHT] = false; -- 14
  [BAG_HOUSE_BANK_NINE] = false; -- 15
  [BAG_HOUSE_BANK_TEN] = false; -- 16
  [BAG_DELETE] = false; -- 17
}

------------------------------------------------------------
-- STYLES AND FORMATTING
------------------------------------------------------------
local BANK_ICON = '|t20:22:ESOUI/art/icons/mapkey/mapkey_bank.dds:inheritColor|t';
local CRAFTBAG_ICON = '|t20:22:ESOUI/art/tooltips/icon_craft_bag.dds:inheritColor|t';
local BAG_ICON = '|t20:24:ESOUI/art/crafting/crafting_provisioner_inventorycolumn_icon.dds:inheritColor|t'
local PADDING_TOP = -5;
local TOOLTIP_FONT = 'ZoFontGame';
local COUNT_COLOR = {
  ['current'] = 'FFFFFF';
  ['old'] = 'B2B2B2';
  ['older'] = '777777';
  ['stale'] = '464646';
}
local REFINED_COUNT_COLOR = {
  ['current'] = 'F0B618';
  ['old'] = 'B48812';
  ['older'] = '785B0C';
  ['stale'] = '483707';
}
local GUILD_LABEL_COLOR = {
  ['current'] = '33F54D';
  ['old'] = '26B83A';
  ['older'] = '1A7B27';
  ['stale'] = '0F4A17';
}

------------------------------------------------------------
-- UTILITY METHODS
------------------------------------------------------------

------------------------------------------------------------
-- Determines whether or not we should care about updates
-- for a given bag.
--
-- @param   bagId   the id of the bag
--
-- @return  true if bag should be monitored, false otherwise.
local function shouldMonitorBag(bagId)
  return MONITOR_BAGS[bagId];
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
TTIC.CacheItemLink = function(bagId, slotIndex, itemLink, data)
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
--
-- @return  the cached itemLink.
TTIC.GetCachedItemLink = function(bagId, slotIndex, data)
  -- Return the itemLink that we saved as a field in the slot data.
  return data.itemLink;
end

------------------------------------------------------------
-- METHODS FOR CREATING TOOLTIPS
------------------------------------------------------------

local function selectColor(colorTable, timestamp)
  local color = colorTable['current'];
  if (not timestamp) or (not TTIC.GetActiveSettings().displayDataAge) then
    return color;
  end

  local now = GetTimeStamp();
  local diff = now - timestamp;
  if diff < SECS_PER_HOUR * 12 then
    color = colorTable['current'];
  elseif diff < SECS_PER_DAY * 3 then
    color = colorTable['old'];
  elseif diff < SECS_PER_WEEK then
    color = colorTable['older'];
  else
    color = colorTable['stale'];
  end

  return color;
end

local function createCountLabel(count, timestamp)
  if not count then
    return '';
  end
  local color = selectColor(COUNT_COLOR, timestamp);
  return zo_strformat('|c<<1>><<2>>|r', color, count);
end

local function createRefinedCountLabel(refinedCount, timestamp)
  if not refinedCount then
    return '';
  end
  local color = selectColor(REFINED_COUNT_COLOR, timestamp);
  return zo_strformat(' |c<<1>>[<<2>>]|r', color, refinedCount);
end

local function createLocationLabel(location)
  return zo_strformat('<<1>>', location);
end

local function createGuildLabel(guildName, timestamp)
  local color = selectColor(GUILD_LABEL_COLOR, timestamp);
  return zo_strformat('|c<<1>><<2>>|r', color, guildName);
end

local function generateCharLabelText(charName)
  local labelText = charName;

  if (TTIC.GetActiveSettings().charNameFormat ~= 'full') then
    for i in string.gmatch(charName, "%S+") do
      labelText = i;
      if (TTIC.GetActiveSettings().charNameFormat == 'first') then
        break;
      end
    end
  end

  return labelText;
end

local function addInventoryToolTip(control, itemLink)
  local toolTip = {};
  local itemInventory = TTIC.GetInventory(itemLink);
  local refinedInventory = {};
  if (TTIC.GetActiveSettings().showRefined) then
    refinedInventory = TTIC.GetInventory(GetItemLinkRefinedMaterialItemLink(itemLink));
  end

  if (TTIC.GetActiveSettings().showPlayer and (itemInventory[CURRENT_PLAYER] or refinedInventory[CURRENT_PLAYER])) then
    table.insert(toolTip, 1, createCountLabel(itemInventory[CURRENT_PLAYER])..createRefinedCountLabel(refinedInventory[CURRENT_PLAYER])..BAG_ICON);
  end

  if (TTIC.GetActiveSettings().showCraftBag and (itemInventory[TTIC.CRAFTBAG_INDEX] or refinedInventory[TTIC.CRAFTBAG_INDEX])) then
    table.insert(toolTip, 1, createCountLabel(itemInventory[TTIC.CRAFTBAG_INDEX])..createRefinedCountLabel(refinedInventory[TTIC.CRAFTBAG_INDEX])..CRAFTBAG_ICON);
  end

  if (TTIC.GetActiveSettings().showBank and (itemInventory[TTIC.BANK_INDEX] or refinedInventory[TTIC.BANK_INDEX])) then
    table.insert(toolTip, 1, createCountLabel(itemInventory[TTIC.BANK_INDEX])..createRefinedCountLabel(refinedInventory[TTIC.BANK_INDEX])..BANK_ICON);
  end

  if (#toolTip > 0) then
    -- Concatenate all the entries into one line and add it to the tooltip.
    control:AddVerticalPadding(PADDING_TOP);
    control:AddLine(table.concat(toolTip, '  '), TOOLTIP_FONT, ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB());
  end
end

local function addAltsInventoryToolTip(control, itemLink)
  local toolTip = {};
  local itemInventory = TTIC.GetInventory(itemLink);
  local refinedInventory = {};
  if (TTIC.GetActiveSettings().showRefined) then
    refinedInventory = TTIC.GetInventory(GetItemLinkRefinedMaterialItemLink(itemLink));
  end

  if (TTIC.GetActiveSettings().showAlts) then
    for _, charName in pairs(TTIC.GetKnownChars()) do
      local count = itemInventory[charName];
      local refinedCount = refinedInventory[charName];
      if (charName ~= CURRENT_PLAYER and TTIC.GetActiveSettings().enabledAlts[charName] and (count or refinedCount)) then
        local countLabel = createCountLabel(count);
        local refinedCountLabel = createRefinedCountLabel(refinedCount);
        local locationLabel = createLocationLabel(generateCharLabelText(charName));
        table.insert(toolTip, countLabel..refinedCountLabel..' '..locationLabel);
      end
    end
  end

  if (#toolTip > 0) then
    if (TTIC.GetActiveSettings().showAltsNewLine) then
      for i = 1, #toolTip do
        control:AddVerticalPadding(i == 1 and PADDING_TOP or -15);
        control:AddLine(toolTip[i], TOOLTIP_FONT, ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB());
      end
    else
      -- Concatenate all the entries into one line and add it to the tooltip.
      control:AddVerticalPadding(PADDING_TOP);
      control:AddLine(table.concat(toolTip, '  '), TOOLTIP_FONT, ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB());
    end
  end
end

local function addGuildInventoryToolTip(control, itemLink)
  if (not TTIC.GetActiveSettings().showGuilds) then
    return
  end

  local toolTip = {};
  local refinedInventory = {};
  if (TTIC.GetActiveSettings().showRefined) then
    refinedInventory = TTIC.GetGuildInventory(GetItemLinkRefinedMaterialItemLink(itemLink));
  end

  local guildInventory = TTIC.GetGuildInventory(itemLink);
  for _, guildName in pairs(TTIC.GetGuilds()) do
    local count = guildInventory[guildName];
    local refinedCount = refinedInventory[guildName];
    if count or refinedCount then
      local timestamp = TTIC.GetGuildInventoryTimeStamp(guildName);
      local countLabel = createCountLabel(count, timestamp);
      local refinedCountLabel = createRefinedCountLabel(refinedCount, timestamp);
      local locationLabel = createGuildLabel(guildName, timestamp);
      table.insert(toolTip, countLabel..refinedCountLabel..' '..locationLabel);
    end
  end

  if (#toolTip > 0) then
    if (TTIC.GetActiveSettings().showGuildsNewLine) then
      for i = 1, #toolTip do
        control:AddVerticalPadding(i == 1 and PADDING_TOP or -15);
        control:AddLine(toolTip[i], TOOLTIP_FONT);
      end
    else
      -- Concatenate all the entries into one line and add it to the tooltip.
      control:AddVerticalPadding(PADDING_TOP);
      control:AddLine(table.concat(toolTip, '  '), TOOLTIP_FONT);
    end
  end
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

  control:AddVerticalPadding(10);
  addInventoryToolTip(control, itemLink);
  addAltsInventoryToolTip(control, itemLink)
  addGuildInventoryToolTip(control, itemLink);
end

------------------------------------------------------------
-- CALLBACKS FOR BAG/BANK UPDATE EVENTS
------------------------------------------------------------

------------------------------------------------------------
-- This method is called whenever a full update is required
-- for the player's active bag/bank inventory.
local function onInventoryFullUpdate()
  TTIC.ReloadInventory();
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
  TTIC.CacheItemLink(bagId, slotIndex, itemLink, data);
  if (bagId == BAG_GUILDBANK) then
    TTIC.UpdateGuildInventory(itemLink, data.stackCount);
  else
    TTIC.UpdateInventory(itemLink, data.stackCount);
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
  local itemLink = TTIC.GetCachedItemLink(bagId, slotIndex, data)
  if (bagId == BAG_GUILDBANK) then
    TTIC.UpdateGuildInventory(itemLink, -1 * data.stackCount);
  else
    TTIC.UpdateInventory(itemLink, -1 * data.stackCount);
  end
end

------------------------------------------------------------
-- This method is called whenever the player selects a different
-- guild bank at the bank teller.
-- @param   eventId   the event code.
-- @param   guildId   the id of the selected guild.
local function onGuildBankSelected(eventId, guildId)
  TTIC.SelectGuildBank(guildId);
end

------------------------------------------------------------
-- This method is called when the data for the selected guild bank
-- is loaded and ready to be accessed.
local function onGuildBankReady()
  TTIC.ReloadGuildInventory();
end

------------------------------------------------------------
-- This method is called when the player leaves a guild.
--
-- @param   eventId     the event code.
-- @param   guildId     the id of the guild.
-- @param   guildName   the full name of the guild.
local function onGuildQuit(eventId, guildId, guildName)
  TTIC.DeleteGuildInventory(guildId, guildName);
end

------------------------------------------------------------
-- METHODS FOR INITIALIZING THE ADD-ON
------------------------------------------------------------

------------------------------------------------------------
-- Registers our callback methods with the appropriate events.
local function registerCallback()
  EVENT_MANAGER:RegisterForEvent(TTIC.NAME, EVENT_INVENTORY_FULL_UPDATE, onInventoryFullUpdate);
  EVENT_MANAGER:RegisterForEvent(TTIC.NAME, EVENT_CRAFT_COMPLETED, onInventoryFullUpdate);
  EVENT_MANAGER:RegisterForEvent(TTIC.NAME, EVENT_GUILD_BANK_SELECTED, onGuildBankSelected);
  EVENT_MANAGER:RegisterForEvent(TTIC.NAME, EVENT_GUILD_BANK_ITEMS_READY, onGuildBankReady);
  EVENT_MANAGER:RegisterForEvent(TTIC.NAME, EVENT_GUILD_SELF_LEFT_GUILD, onGuildQuit);
  SHARED_INVENTORY:RegisterCallback('SlotAdded', onSlotAdded);
  SHARED_INVENTORY:RegisterCallback('SlotRemoved', onSlotRemoved);
  TT:RegisterCallback(TT.events.EVENT_ITEM_TOOLTIP, showToolTip);
end

------------------------------------------------------------
-- This method is called when a player has been activated.
--
-- @param   eventId   the event code.
local function onPlayerActivated(eventId)
  TTIC.ReloadInventory();

  -- Delay registering callbacks until data has been initialized.
  registerCallback();
end

------------------------------------------------------------
-- This method is called whenever any addon is loaded.
--
-- @param   eventId   the event code.
-- @param   addonName the name of the loaded addon.
local function onAddOnLoaded(eventId, addonName)
  -- Do nothing if it's some other addon that was loaded.
  if (addonName ~= TTIC.NAME) then
    return;
  end

  TTIC.LoadAccountSettings();
  TTIC.LoadCharSettings();
  TTIC.InitInventory();
  TTIC.InitGuildInventory();
  TTIC.InitSettingsMenu();

  EVENT_MANAGER:RegisterForEvent(TTIC.NAME, EVENT_PLAYER_ACTIVATED, onPlayerActivated);
  EVENT_MANAGER:UnregisterForUpdate(EVENT_ADD_ON_LOADED);
end

------------------------------------------------------------
-- REGISTER WITH THE GAME'S EVENTS
------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent(TTIC.NAME, EVENT_ADD_ON_LOADED, onAddOnLoaded);
