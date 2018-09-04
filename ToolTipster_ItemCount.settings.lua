------------------------------------------------------------
-- LOCAL CONSTANTS
------------------------------------------------------------
local TTIC = ToolTipster_ItemCount;
local TT = ToolTipster_ItemCount.LIBTT;
local LAM = ToolTipster_ItemCount.LIBADDONMENU;
local TTIC_OPTIONS_NAME = 'TTIC_Options';
local CHAR_NAME_FORMATS = {
  ['full'] = GetString(TTIC_OPTION_DISPLAY_NAME_FULL);
  ['first'] = GetString(TTIC_OPTION_DISPLAY_NAME_FIRST);
  ['last'] = GetString(TTIC_OPTION_DISPLAY_NAME_LAST);
};
local SAVEDVARS_NAME = 'ItemCount_SavedVars';
local SAVEDVARS_VER = 1;

-- Default values for configurable settings.
local DEFAULT_SETTINGS = {
  global = true,
  showBank = false,
  showPlayer = false,
  showAlts = true,
  showGuilds = true,
  showRefined = true,
  charNameFormat = 'full',
  displayDataAge = true,
  enabledAlts = {},
};

-- Defaults for account-wide saved variables.
local DEFAULT_ACCT_SV = {
  inventory = {},
  guildInventory = {},
  knownCharacters = {},
  settings = DEFAULT_SETTINGS,
};

-- Defaults for character-specific saved variables.
local DEFAULT_CHAR_SV = {
  settings = DEFAULT_SETTINGS,
};

------------------------------------------------------------
-- LOCAL REFERENCES TO SAVED VARIABLES
------------------------------------------------------------
local acctSettings = nil;
local charSettings = nil;
local knownChars = nil;
local inventory = nil;
local guildInventory = nil;
local guilds = nil;

------------------------------------------------------------
-- PRIVATE METHODS
------------------------------------------------------------

------------------------------------------------------------
-- Deletes the inventory data for a character.
--
-- @param charName  the name of the character to delete.
local function deleteCharacter(charName)

  TTIC:DeleteCharInventory(charName);

  -- Remove character from list of known characters.
  TT:RemoveCharacterFromList(knownChars, charName);

  -- Remove character from settings.
  acctSettings.enabledAlts[charName] = nil;
  charSettings.enabledAlts[charName] = nil;

  -- Disable the character's checkbox in the settings menu.
  local checkbox = GetControl(TTIC.ABBR..'_'..charName);
  checkbox.data.disabled = true;
  checkbox.data.default = false;
  checkbox:UpdateDisabled();

  -- Remove the character's entry from the dropdown in the settings menu.
  local dropdown = GetControl(TTIC.ABBR..'_Char_DropDown');
  dropdown:UpdateChoices(knownChars);
  dropdown:UpdateValue(true, nil);
end

------------------------------------------------------------
-- Creates the data for populating the settings panel.
local function createOptionsData()
  local data = {};

  table.insert(data, {
    type = 'description',
    text = GetString(TTIC_DESC),
  });

  table.insert(data, {
    type = 'header',
    name = GetString(TTIC_MENU_GENERAL),
  });

  -- Create an option to save the settings account-wide.
  table.insert(data, {
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
  table.insert(data, {
    type = 'checkbox',
    name = GetString(TTIC_OPTION_BANK),
    tooltip = GetString(TTIC_OPTION_BANK_TIP),
    default = DEFAULT_SETTINGS.showBank,
    getFunc = function() return TTIC.GetActiveSettings().showBank end,
    setFunc = function(value) TTIC.GetActiveSettings().showBank = value end,
  });

  -- Create an option to show the amount of the item stored in the current bag.
  table.insert(data, {
    type = 'checkbox',
    name = GetString(TTIC_OPTION_PLAYER),
    tooltip = GetString(TTIC_OPTION_PLAYER_TIP),
    default = DEFAULT_SETTINGS.showPlayer,
    getFunc = function() return TTIC.GetActiveSettings().showPlayer end,
    setFunc = function(value) TTIC.GetActiveSettings().showPlayer = value end,
  });

  -- Create an option to show the amount of the item stored in alts' bag.
  table.insert(data, {
    type = 'checkbox',
    name = GetString(TTIC_OPTION_ALTS),
    tooltip = GetString(TTIC_OPTION_ALTS_TIP),
    default = DEFAULT_SETTINGS.showAlts,
    getFunc = function() return TTIC.GetActiveSettings().showAlts end,
    setFunc = function(value)
      TTIC.GetActiveSettings().showAlts = value;
      for _, altName in pairs(knownChars) do
        -- Toggle the character's checkbox in the settings menu.
        local checkbox = GetControl(TTIC.ABBR..'_'..altName);
        if checkbox then
          checkbox.data.disabled = not value;
          checkbox.data.default = true;
          checkbox:UpdateDisabled();
        end
      end

      local dropdown = GetControl(TTIC.ABBR..'_CharDropDown');
      if dropdown then
        dropdown.data.disabled = not value;
        dropdown.data.default = DEFAULT_SETTINGS.charNameFormat;
        dropdown:UpdateDisabled();
      end
    end,
  });

  -- Create an option to show the amount of the item stored in guild banks.
  table.insert(data, {
    type = 'checkbox',
    name = GetString(TTIC_OPTION_GUILDS),
    tooltip = GetString(TTIC_OPTION_GUILDS_TIP),
    default = DEFAULT_SETTINGS.showGuilds,
    getFunc = function() return TTIC.GetActiveSettings().showGuilds end,
    setFunc = function(value)
      TTIC.GetActiveSettings().showGuilds = value;
      local checkbox = GetControl(TTIC.ABBR..'_DisplayDataAge');
      if checkbox then
        checkbox.data.disabled = not value;
        checkbox.data.default = DEFAULT_SETTINGS.displayDataAge;
        checkbox:UpdateDisabled();
      end
    end,
  });

  -- Create an option to show the amount of the refined item.
  table.insert(data, {
    type = 'checkbox',
    name = GetString(TTIC_OPTION_REFINED),
    tooltip = GetString(TTIC_OPTION_REFINED_TIP),
    default = DEFAULT_SETTINGS.showRefined,
    getFunc = function() return TTIC.GetActiveSettings().showRefined end,
    setFunc = function(value)
      TTIC.GetActiveSettings().showRefined = value;
    end,
  });

  -- Create a section for selecting which characters to report amounts for.
  table.insert(data, {
    type = 'header',
    name = GetString(TTIC_MENU_CHARACTERS),
  });

  table.insert(data, {
    type = 'description',
    text = GetString(TTIC_MENU_CHARACTERS_DESC),
  });

  -- Create a checkbox for each character.
  for _, charName in pairs(knownChars) do
    table.insert(data, {
      type = 'checkbox',
      name = GetString(TTIC_OPTION_CHARACTER)..'|cF7F49E'..charName..'|r',
      tooltip = GetString(TTIC_OPTION_CHARACTER_TIP),
      default = true,
      getFunc = function() return TTIC.GetActiveSettings().enabledAlts[charName] end,
      setFunc = function(value) TTIC.GetActiveSettings().enabledAlts[charName] = value end,
      disabled = false,
      reference = TTIC.ABBR..'_'..charName,
    });
  end

  -- Create a section for appearance options.
  table.insert(data, {
    type = 'header',
    name = GetString(TTIC_MENU_APPEARANCE),
  });

  table.insert(data, {
    type = 'description',
    text = GetString(TTIC_MENU_APPEARANCE_DESC),
  });

  table.insert(data, {
    type = 'dropdown',
    name = GetString(TTIC_OPTION_DISPLAY_NAME),
    tooltip = GetString(TTIC_OPTION_DISPLAY_NAME_TIP),
    choices = { GetString(TTIC_OPTION_DISPLAY_NAME_FULL), GetString(TTIC_OPTION_DISPLAY_NAME_FIRST), GetString(TTIC_OPTION_DISPLAY_NAME_LAST) },
    default = DEFAULT_SETTINGS.charNameFormat,
    getFunc = function() return CHAR_NAME_FORMATS[TTIC.GetActiveSettings().charNameFormat] end,
    setFunc = function(value)
        local selected = 'full';
        for option, text in pairs(CHAR_NAME_FORMATS) do
          if (text == value) then
            selected = option;
            break;
          end
        end
        TTIC.GetActiveSettings().charNameFormat = selected;
      end,
    disabled = false,
    reference = TTIC.ABBR..'_CharDropDown',
  });

  -- Create an option to show the age of data.
  table.insert(data, {
    type = 'checkbox',
    name = GetString(TTIC_OPTION_DATAAGE),
    tooltip = GetString(TTIC_OPTION_DATAAGE_TIP),
    default = DEFAULT_SETTINGS.displayDataAge,
    getFunc = function() return TTIC.GetActiveSettings().displayDataAge end,
    setFunc = function(value)
      TTIC.GetActiveSettings().displayDataAge = value;
    end,
    disabled = false,
    reference = TTIC.ABBR..'_DisplayDataAge',
  });

  -- Create an option for removing a character's data.
  local charToDelete = nil;

  -- Create a dropdown list and a button for deleting a character's data.
  table.insert(data, {
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
        reference = TTIC.ABBR..'_Char_DropDown',
      },
      [3] = {
        type = 'button',
        name = GetString(TTIC_BUTTON_DELETE),
        tooltip = GetString(TTIC_BUTTON_DELETE_TIP),
        func = function() deleteCharacter(charToDelete) end,
      }
    };
  });

  return data;
end

------------------------------------------------------------
-- PUBLIC METHODS
------------------------------------------------------------

------------------------------------------------------------
-- If 'global' is turned on, then returns the current settings for
-- the entire account, otherwise returns the current settings for
-- the active character. The returned settings saved as part of this
-- addon's saved variables.
--
-- @return  the table containing the current settings.
TTIC.GetActiveSettings = function()
  return ((acctSettings.global and acctSettings) or
          charSettings)
end

------------------------------------------------------------
-- Initializes data that's shared across an entire account.
TTIC.LoadAccountSettings = function()

  local savedVars = ZO_SavedVars:NewAccountWide(SAVEDVARS_NAME, SAVEDVARS_VER, nil, DEFAULT_ACCT_SV);

  -- Create local references to the various components of the saved variable.
  acctSettings = savedVars.settings;
  knownChars = savedVars.knownCharacters;
  inventory = savedVars.inventory;
  guildInventory = savedVars.guildInventory;

  -- Make sure that we add the current character to the list of known characters.
  local currentChar = zo_strformat('<<C:1>>', GetUnitName('player'));
  if (TT:AddCharacterToList(knownChars, currentChar)) then
      acctSettings.enabledAlts[currentChar] = true;
  end

  -- Identify the guilds that the player belongs to.
  guilds = {};
  for i=1, GetNumGuilds() do
    local guildId = GetGuildId(i);
    table.insert(guilds, GetGuildName(guildId));
  end
end

------------------------------------------------------------
-- Initializes data that's specific to a character.
TTIC.LoadCharSettings = function()
  local savedVars = ZO_SavedVars:New(SAVEDVARS_NAME, SAVEDVARS_VER, nil, DEFAULT_CHAR_SV);

  -- Create a local reference to the character's settings.
  charSettings = savedVars.settings;

  for name, value in pairs(acctSettings.enabledAlts) do
    -- If the current character is new, then make sure that the settings
    -- include it as an option.
    if (charSettings.enabledAlts[name] == nil) then
      if (acctSettings.global) then
        -- If 'global' is true, then just use the global setting.
        charSettings.enabledAlts[name] = value;
      else
        -- Otherwise, show the character's inventory by default.
        charSettings.enabledAlts[name] = true;
      end
    end
  end

  -- Sync up with account settings.
  for name, value in pairs(charSettings.enabledAlts) do
    -- Delete any characters that may have been deleted from the account
    -- settings since the last time the current character logged off.
    if (acctSettings.enabledAlts[name] == nil) then
      charSettings.enabledAlts[name] = nil;
    end
  end
end

------------------------------------------------------------
-- Uses LibAddonMenu to initialize the settings menu for this addon.
TTIC.InitSettingsMenu = function()

  -- Create the basic data for creating the settings panel.
  local panelData = {
    type = 'panel',
    name = GetString(TTIC_NAME),
    displayName = GetString(TTIC_DISPLAY_NAME),
    author = TTIC.AUTHOR,
    version = TTIC.VERSION,
    registerForDefaults = true,
    registerForRefresh = true,
  };

  LAM:RegisterAddonPanel(TTIC_OPTIONS_NAME, panelData);
  LAM:RegisterOptionControls(TTIC_OPTIONS_NAME, createOptionsData());
end

------------------------------------------------------------
-- Returns the names of all known characters on the account.
--
-- @return  the saved variable holding the array of known character names.
TTIC.GetKnownChars = function()
  return knownChars;
end

------------------------------------------------------------
-- Returns the names of the guilds that the player belongs to.
--
-- @return  an array of guild names.
TTIC.GetGuilds = function()
  return guilds;
end

------------------------------------------------------------
-- Returns the inventory data for character bags and the bank.
--
-- @return  the saved variable holding the inventory table.
TTIC.GetSavedInventory = function()
  return inventory;
end

------------------------------------------------------------
-- Returns the inventory data for the guilds.
--
-- @return  the saved variable holding the guild inventory table.
TTIC.GetSavedGuildInventory = function()
  return guildInventory;
end
