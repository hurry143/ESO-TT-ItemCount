------------------------------------------------------------
-- LOCAL CONSTANTS
------------------------------------------------------------
local TTIC = YATT_ItemCount;
local TT = YATT_ItemCount.LIBTT;
local GUILD_BANK_RELOAD_DELAY = 1500;

------------------------------------------------------------
-- LOCAL VARIABLES
------------------------------------------------------------
local guildInventory = nil;
local currentGuildId = nil;
local guildBankLoading = false;
local guildBankLoaded = false;

------------------------------------------------------------
-- PRIVATE METHODS
------------------------------------------------------------

------------------------------------------------------------
-- This method removes saved inventory data for any guilds
-- that the player no longer belongs to.
local function refreshGuildMembership()
  -- Check to see if we were kicked out of a guild while logged off.
  for guildName, _ in pairs(guildInventory) do
    local isMember = false;
    for _, activeGuildName in pairs(TTIC.GetGuilds()) do
      if (guildName == activeGuildName) then
        isMember = true;
        break;
      end
    end
    if not isMember then
      guildInventory[guildName] = nil;
    end
  end
end

------------------------------------------------------------
-- PUBLIC METHODS
------------------------------------------------------------

------------------------------------------------------------
-- Initializes the guild inventory data.
TTIC.InitGuildInventory = function()
  if not guildInventory then
    -- Set the local reference to the saved variable.
    guildInventory = TTIC:GetSavedGuildInventory();
  end
  refreshGuildMembership();
end

------------------------------------------------------------
-- This method must be called when the player selects a guild
-- bank at the bank teller.
--
-- @param   guildId   the id of the selected guild.
TTIC.SelectGuildBank = function(guildId)
  currentGuildId = guildId;
  guildBankLoading = false;
  guildBankLoaded = false;
end

------------------------------------------------------------
-- Removes a guild from the inventory data.
--
-- @param   guildId     the id of the guild to remove.
-- @param   guildName   the name of the guild to remove.
TTIC.DeleteGuildInventory = function(guildId, guildName)
  guildInventory[guildName] = nil;
end

------------------------------------------------------------
-- Re-scans all items in the selected build bank and updates
-- the inventory data accordingly.
TTIC.ReloadGuildInventory = function()
  -- Don't run this method again if the data is still being loaded.
  if guildBankLoading then
    return
  end;
  guildBankLoading = true;

  -- Add a delay to make sure that the client has all the data from the server.
  zo_callLater(function()
      local guildName = GetGuildName(currentGuildId);
      local numSlots, numItems = 0, 0;
      local items = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_GUILDBANK);

      guildInventory[guildName] = {};
      guildInventory[guildName]['timestamp'] = GetTimeStamp();

      for slot, data in pairs(items) do
        numSlots = numSlots + 1;
        local itemLink = GetItemLink(data.bagId, data.slotIndex);
        if itemLink then
          TTIC.CacheItemLink(data.bagId, data.slotIndex, itemLink, data);
          local itemKey = TT:CreateItemIndex(itemLink);
          if itemKey then
            if not guildInventory[guildName][itemKey] then
              guildInventory[guildName][itemKey] = 0;
              numItems = numItems + 1;
            end
            guildInventory[guildName][itemKey] = guildInventory[guildName][itemKey] + data.stackCount;
          end
        end
      end
      -- TODO Localize this logging text.
      d(TTIC.SHORTNAME..': Scanned |cFFFFFF'..numItems..'|r items in |cFFFFFF'..numSlots..'|r slots for guild('..currentGuildId..') |c33F54D'..guildName..'|r');
      guildBankLoaded = true;
    end,
    GUILD_BANK_RELOAD_DELAY);
end

------------------------------------------------------------
-- Updates the guild inventory info for an item.
--
-- @param   itemLink  the link for the item.
-- @param   amount    the amount that the item count has increased/decreased by.
TTIC.UpdateGuildInventory = function(itemLink, amount)
  if (not itemLink) then
    return;
  end

  if not guildBankLoaded then
    return
  end

  local guildName = GetGuildName(currentGuildId);
  local itemKey = TT:CreateItemIndex(itemLink);
  if itemKey then
    if not guildInventory[guildName][itemKey] then
      guildInventory[guildName][itemKey] = 0;
    end

    guildInventory[guildName][itemKey] = guildInventory[guildName][itemKey] + amount;

    if (guildInventory[guildName][itemKey] <= 0) then
      guildInventory[guildName][itemKey] = nil;
    end
  end
end

------------------------------------------------------------
-- Returns the inventory count for a given item in all guild banks.
--
-- @param   itemLink  the link for the item.
--
-- @return  a table of guild names and their respective counts.
TTIC.GetGuildInventory = function(itemLink)
  local itemKey = TT:CreateItemIndex(itemLink);
  local itemInventory = {};

  if (not itemKey) then
    return itemInventory;
  end

  for gName, gInv in pairs(guildInventory) do
    if gInv[itemKey] then
      itemInventory[gName] = gInv[itemKey];
    end
  end

  return itemInventory;
end

------------------------------------------------------------
-- Returns the timestamp for a given guild's inventory data.
--
-- @param   guildName   the name of the guild.
--
-- @return  the timestamp of the guild's data, or nil if the data cannot be found.
TTIC.GetGuildInventoryTimeStamp = function(guildName)
  local timestamp = nil;

  if guildInventory[guildName] then
    timestamp = guildInventory[guildName]['timestamp']
  end

  return timestamp;
end
