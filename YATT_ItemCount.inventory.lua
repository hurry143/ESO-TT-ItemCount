------------------------------------------------------------
-- LOCAL CONSTANTS
------------------------------------------------------------
local YATTIC = YATT_ItemCount;
local YATT = YATT_ItemCount.LIBYATT;
local CURRENT_PLAYER = zo_strformat('<<C:1>>', GetUnitName('player'));

------------------------------------------------------------
-- LOCAL VARIABLES
------------------------------------------------------------
local inventory = nil;

------------------------------------------------------------
-- PRIVATE METHODS
------------------------------------------------------------

------------------------------------------------------------
-- Updates the count for an item at an location.
--
-- @param   itemKey   the 'unique' key for the item.
-- @param   location  bank or the name of a character.
-- @param   count     the updated count of the item.
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
-- PUBLIC METHODS
------------------------------------------------------------

------------------------------------------------------------
-- Initializes the inventory data.
YATTIC.InitInventory = function()
  if not inventory then
    -- Set the local reference to the saved variable.
    inventory = YATTIC.GetSavedInventory();
  end
end

------------------------------------------------------------
-- Removes a character from the inventory data.
--
-- @param   charName  the name of the character to remove.
YATTIC.DeleteCharInventory = function(charName)
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
end

------------------------------------------------------------
-- Re-scans all items in both the bank and the current character's
-- backpack and updates the inventory data accordingly.
YATTIC.ReloadInventory = function()
  local items = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK, BAG_BANK, BAG_VIRTUAL);

  for slot, data in pairs(items) do
    local itemLink = GetItemLink(data.bagId, data.slotIndex);
    YATTIC.CacheItemLink(data.bagId, data.slotIndex, itemLink, data);
    YATTIC.UpdateInventory(itemLink);
  end

end

------------------------------------------------------------
-- Updates the inventory info for an item (for the current bag, bank, and craft bag).
--
-- @param   itemLink  the link for the item.
-- @param   amount    the amount that the item count has increased/decreased by.
YATTIC.UpdateInventory = function(itemLink, amount)
  if (not itemLink) then
    return;
  end

  -- For now, ignore the 'amount' and just get the counts directly.
  local bagpackCount, bankCount, craftbagCount = GetItemLinkStacks(itemLink);
  local itemKey = YATT:CreateItemIndex(itemLink);

  if (not itemKey) then
    return;
  end

  if (not inventory[itemKey]) then
    inventory[itemKey] = {};
  end

  updateBagCount(itemKey, CURRENT_PLAYER, bagpackCount);
  updateBagCount(itemKey, YATTIC.BANK_INDEX, bankCount);
  updateBagCount(itemKey, YATTIC.CRAFTBAG_INDEX, craftbagCount);

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
-- Returns the inventory count for a given item in the bank
-- and all of the characters' bags.
--
-- @param   itemLink  the link for the item.
--
-- @return  a table of location names and their respective counts.
YATTIC.GetInventory = function(itemLink)
  local itemKey = YATT:CreateItemIndex(itemLink);
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
