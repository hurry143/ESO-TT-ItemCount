------------------------------------------------------------
-- LOCAL CONSTANTS
------------------------------------------------------------
local YATTIC = YATT_ItemCount;
local YATT = YATT_ItemCount.LIBYATT;
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
local BANK_ICON = '|t<<1>>:<<2>>:ESOUI/art/icons/mapkey/mapkey_bank.dds:inheritColor|t';
local CRAFTBAG_ICON = '|t<<1>>:<<2>>:ESOUI/art/tooltips/icon_craft_bag.dds:inheritColor|t';
local BAG_ICON = '|t<<1>>:<<2>>:ESOUI/art/tooltips/icon_bag.dds:inheritColor|t'
local PADDING_TOP = -7;
local TOOLTIP_FONT = 'ZoFontGame';
local TOOLTIP_COLOR = ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB();
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
local headerAdded = false;

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
YATTIC.CacheItemLink = function(bagId, slotIndex, itemLink, data)
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
YATTIC.GetCachedItemLink = function(bagId, slotIndex, data)
  -- Return the itemLink that we saved as a field in the slot data.
  return data.itemLink;
end

------------------------------------------------------------
-- METHODS FOR CREATING TOOLTIPS
------------------------------------------------------------

local function selectColor(colorTable, timestamp)
  local color = colorTable['current'];
  if (not timestamp) or (not YATTIC.GetActiveSettings().displayDataAge) then
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

  if (YATTIC.GetActiveSettings().charNameFormat ~= 'full') then
    for i in string.gmatch(charName, "%S+") do
      labelText = i;
      if (YATTIC.GetActiveSettings().charNameFormat == 'first') then
        break;
      end
    end
  end

  return labelText;
end

local function getIcon(icon)
  local width = IsInGamepadPreferredMode() and 23 or 20;
  local height = IsInGamepadPreferredMode() and 25 or 22;

  return zo_strformat(icon, width, height);
end

local function addHeader(control)
  if (headerAdded) then
    return
  end

  if (not IsInGamepadPreferredMode()) then
    control:AddVerticalPadding(10);
  else
    local style = { fontSize = "$(GP_27)", fontFace = "$(GAMEPAD_MEDIUM_FONT)", uppercase = true };
    control:AddLine('', style, control:GetStyle("bodySection"));
  end
  headerAdded = true;
end

local function addVerticalPadding(control, padding)
  if (not IsInGamepadPreferredMode()) then
    control:AddVerticalPadding(padding);
  end
end

local function addLine(control, text)
  if (not IsInGamepadPreferredMode()) then
    control:AddLine(text, TOOLTIP_FONT, ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB());
  else
    local style = { fontSize = "$(GP_27)", fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_3 };
    control:AddLine(text, style);
  end
end

local function addInventoryToolTip(control, itemLink)
  local toolTip = {};
  local itemInventory = YATTIC.GetInventory(itemLink);
  local refinedInventory = {};
  if (YATTIC.GetActiveSettings().showRefined) then
    refinedInventory = YATTIC.GetInventory(GetItemLinkRefinedMaterialItemLink(itemLink));
  end

  if (YATTIC.GetActiveSettings().showPlayer and (itemInventory[CURRENT_PLAYER] or refinedInventory[CURRENT_PLAYER])) then
    table.insert(toolTip, 1, createCountLabel(itemInventory[CURRENT_PLAYER])..createRefinedCountLabel(refinedInventory[CURRENT_PLAYER])..getIcon(BAG_ICON));
  end

  if (YATTIC.GetActiveSettings().showBank and (itemInventory[YATTIC.BANK_INDEX] or refinedInventory[YATTIC.BANK_INDEX])) then
    table.insert(toolTip, 1, createCountLabel(itemInventory[YATTIC.BANK_INDEX])..createRefinedCountLabel(refinedInventory[YATTIC.BANK_INDEX])..getIcon(BANK_ICON));
  end

  if (YATTIC.GetActiveSettings().showCraftBag and (itemInventory[YATTIC.CRAFTBAG_INDEX] or refinedInventory[YATTIC.CRAFTBAG_INDEX])) then
    table.insert(toolTip, 1, createCountLabel(itemInventory[YATTIC.CRAFTBAG_INDEX])..createRefinedCountLabel(refinedInventory[YATTIC.CRAFTBAG_INDEX])..getIcon(CRAFTBAG_ICON));
  end

  if (#toolTip > 0) then
    -- Concatenate all the entries into one line and add it to the tooltip.
    addHeader(control);
    addVerticalPadding(control, PADDING_TOP);
    addLine(control, table.concat(toolTip, '  '));
  end
end

local function addAltsInventoryToolTip(control, itemLink)
  local toolTip = {};
  local itemInventory = YATTIC.GetInventory(itemLink);
  local refinedInventory = {};
  if (YATTIC.GetActiveSettings().showRefined) then
    refinedInventory = YATTIC.GetInventory(GetItemLinkRefinedMaterialItemLink(itemLink));
  end

  if (YATTIC.GetActiveSettings().showAlts) then
    for _, charName in pairs(YATTIC.GetKnownChars()) do
      local count = itemInventory[charName];
      local refinedCount = refinedInventory[charName];
      if (charName ~= CURRENT_PLAYER and YATTIC.GetActiveSettings().enabledAlts[charName] and (count or refinedCount)) then
        local countLabel = createCountLabel(count);
        local refinedCountLabel = createRefinedCountLabel(refinedCount);
        local locationLabel = createLocationLabel(generateCharLabelText(charName));
        table.insert(toolTip, countLabel..refinedCountLabel..' '..locationLabel);
      end
    end
  end

  if (#toolTip > 0) then
    addHeader(control);
    if (YATTIC.GetActiveSettings().showAltsNewLine) then
      for i = 1, #toolTip do
        addVerticalPadding(control, i == 1 and PADDING_TOP or - 15);
        addLine(control, toolTip[i]);
      end
    else
      -- Concatenate all the entries into one line and add it to the tooltip.
      addVerticalPadding(control, PADDING_TOP);
      addLine(control, table.concat(toolTip, '  '));
    end
  end
end

local function addGuildInventoryToolTip(control, itemLink)
  if (not YATTIC.GetActiveSettings().showGuilds) then
    return
  end

  local toolTip = {};
  local refinedInventory = {};
  if (YATTIC.GetActiveSettings().showRefined) then
    refinedInventory = YATTIC.GetGuildInventory(GetItemLinkRefinedMaterialItemLink(itemLink));
  end

  local guildInventory = YATTIC.GetGuildInventory(itemLink);
  for _, guildName in pairs(YATTIC.GetGuilds()) do
    local count = guildInventory[guildName];
    local refinedCount = refinedInventory[guildName];
    if (count or refinedCount) and YATTIC.GetActiveSettings().enabledGuilds[guildName] then
      local timestamp = YATTIC.GetGuildInventoryTimeStamp(guildName);
      local countLabel = createCountLabel(count, timestamp);
      local refinedCountLabel = createRefinedCountLabel(refinedCount, timestamp);
      local locationLabel = createGuildLabel(guildName, timestamp);
      table.insert(toolTip, countLabel..refinedCountLabel..' '..locationLabel);
    end
  end

  if (#toolTip > 0) then
    addHeader(control);
    if (YATTIC.GetActiveSettings().showGuildsNewLine) then
      for i = 1, #toolTip do
        addVerticalPadding(control, i == 1 and PADDING_TOP or - 15);
        addLine(control, toolTip[i]);
      end
    else
      -- Concatenate all the entries into one line and add it to the tooltip.
      addVerticalPadding(control, PADDING_TOP);
      addLine(control, table.concat(toolTip, '  '));
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

  headerAdded = false;
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
  YATTIC.ReloadInventory();
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
  YATTIC.CacheItemLink(bagId, slotIndex, itemLink, data);
  if (bagId == BAG_GUILDBANK) then
    YATTIC.UpdateGuildInventory(itemLink, data.stackCount);
  else
    YATTIC.UpdateInventory(itemLink, data.stackCount);
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
  local itemLink = YATTIC.GetCachedItemLink(bagId, slotIndex, data)
  if (bagId == BAG_GUILDBANK) then
    YATTIC.UpdateGuildInventory(itemLink, - 1 * data.stackCount);
  else
    YATTIC.UpdateInventory(itemLink, - 1 * data.stackCount);
  end
end

------------------------------------------------------------
-- This method is called whenever the player selects a different
-- guild bank at the bank teller.
-- @param   eventId   the event code.
-- @param   guildId   the id of the selected guild.
local function onGuildBankSelected(eventId, guildId)
  YATTIC.SelectGuildBank(guildId);
end

------------------------------------------------------------
-- This method is called when the data for the selected guild bank
-- is loaded and ready to be accessed.
local function onGuildBankReady()
  YATTIC.ReloadGuildInventory();
end

------------------------------------------------------------
-- This method is called when the player leaves a guild.
--
-- @param   eventId     the event code.
-- @param   guildId     the id of the guild.
-- @param   guildName   the full name of the guild.
local function onGuildQuit(eventId, guildId, guildName)
  YATTIC.DeleteGuildInventory(guildId, guildName);
end

------------------------------------------------------------
-- METHODS FOR INITIALIZING THE ADD-ON
------------------------------------------------------------

------------------------------------------------------------
-- Registers our callback methods with the appropriate events.
local function registerCallback()
  EVENT_MANAGER:RegisterForEvent(YATTIC.NAME, EVENT_INVENTORY_FULL_UPDATE, onInventoryFullUpdate);
  EVENT_MANAGER:RegisterForEvent(YATTIC.NAME, EVENT_CRAFT_COMPLETED, onInventoryFullUpdate);
  EVENT_MANAGER:RegisterForEvent(YATTIC.NAME, EVENT_GUILD_BANK_SELECTED, onGuildBankSelected);
  EVENT_MANAGER:RegisterForEvent(YATTIC.NAME, EVENT_GUILD_BANK_ITEMS_READY, onGuildBankReady);
  EVENT_MANAGER:RegisterForEvent(YATTIC.NAME, EVENT_GUILD_SELF_LEFT_GUILD, onGuildQuit);
  SHARED_INVENTORY:RegisterCallback('SlotAdded', onSlotAdded);
  SHARED_INVENTORY:RegisterCallback('SlotRemoved', onSlotRemoved);
  YATT:RegisterCallback(YATT.events.EVENT_ITEM_TOOLTIP, showToolTip);
end

------------------------------------------------------------
-- This method is called when a player has been activated.
--
-- @param   eventId   the event code.
local function onPlayerActivated(eventId)
  YATTIC.ReloadInventory();

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
  if (addonName ~= YATTIC.NAME) then
    return;
  end

  YATTIC.LoadAccountSettings();
  YATTIC.LoadCharSettings();
  YATTIC.InitInventory();
  YATTIC.InitGuildInventory();
  YATTIC.InitSettingsMenu();

  EVENT_MANAGER:RegisterForEvent(YATTIC.NAME, EVENT_PLAYER_ACTIVATED, onPlayerActivated);
  EVENT_MANAGER:UnregisterForUpdate(EVENT_ADD_ON_LOADED);
end

------------------------------------------------------------
-- REGISTER WITH THE GAME'S EVENTS
------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent(YATTIC.NAME, EVENT_ADD_ON_LOADED, onAddOnLoaded);
