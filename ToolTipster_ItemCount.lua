------------------------------------------------------------
-- LOCAL CONSTANTS
------------------------------------------------------------
local TTIC = ToolTipster_ItemCount;
local TT = ToolTipster_ItemCount.LIBTT;
local CURRENT_PLAYER = zo_strformat('<<C:1>>', GetUnitName('player'));

------------------------------------------------------------
-- STYLES AND FORMATTING
------------------------------------------------------------
local BANK_ICON = '|t20:22:ESOUI/art/icons/mapkey/mapkey_bank.dds:inheritColor|t';
local BAG_ICON = '|t20:24:ESOUI/art/crafting/crafting_provisioner_inventorycolumn_icon.dds:inheritColor|t'
local PADDING_TOP = 10;
local TOOLTIP_FONT = 'ZoFontGame';
local COUNT_COLOR = 'FFFFFF';
local REFINED_COUNT_COLOR = 'F0B618';

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
  -- We only care about the backpack, the bank, and the guildbank.
  if (bagId > 3) then
    return false;
  end
  
  return true;
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

local function createCountLabel(count)
  if not count then
    return '';
  end
  return zo_strformat('|c<<1>><<2>>|r', COUNT_COLOR, count);
end

local function createRefinedCountLabel(refinedCount)
  if not refinedCount then
    return '';
  end
  return zo_strformat(' |c<<1>>[<<2>>]|r', REFINED_COUNT_COLOR, refinedCount);
end

local function createLocationLabel(location)
  return zo_strformat('<<1>>', location);
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
  
  if (TTIC.GetActiveSettings().showPlayer and (itemInventory[CURRENT_PLAYER] or refinedInventory[CURRENT_PLAYER])) then
    table.insert(toolTip, 1, createCountLabel(itemInventory[CURRENT_PLAYER])..createRefinedCountLabel(refinedInventory[CURRENT_PLAYER])..BAG_ICON);
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
  local lineNum = 1;
  for _, guildName in pairs(TTIC.GetGuilds()) do
    local count = guildInventory[guildName];
    local refinedCount = refinedInventory[guildName];
    if count or refinedCount then
      if lineNum == 1 then
        control:AddVerticalPadding(PADDING_TOP);
      else
        control:AddVerticalPadding(-10);
      end
      local countLabel = createCountLabel(count);
      local refinedCountLabel = createRefinedCountLabel(refinedCount);
      local locationLabel = createLocationLabel(guildName);
      control:AddLine(countLabel..refinedCountLabel..' '..locationLabel, TOOLTIP_FONT, 51/255, 245/255, 77/255);
      lineNum = lineNum + 1;
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

  addInventoryToolTip(control, itemLink);
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
  TT:RegisterCallback(TT.events.TT_EVENT_ITEM_TOOLTIP, showToolTip);
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