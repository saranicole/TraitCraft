local TC = TraitCraft

local LAM = LibHarvensAddonSettings

if not LibHarvensAddonSettings then
    d("LibHarvensAddonSettings is required!")
    return
end

local researcherLimit = 25
if IsInGamepadPreferredMode() then
  researcherLimit = 6
end

local MAIN_CRAFTER_NAME, MAIN_CRAFTER_ID, ACTIVELY_RESEARCHING_NAME, ACTIVELY_RESEARCHING_ID, RESEARCHER_TO_REMOVE_NAME, RESEARCHER_TO_REMOVE_ID
local BLACKSMITHING_CHARACTER_NAME, BLACKSMITHING_CHARACTER_ID, CLOTHING_CHARACTER_NAME, CLOTHING_CHARACTER_ID, WOODWORKING_CHARACTER_NAME, WOODWORKING_CHARACTER_ID, JEWELRY_CHARACTER_NAME, JEWELRY_CHARACTER_ID

--Icon
TC.IconList = {
  "/esoui/art/crafting/alchemy_tabicon_reagent_up.dds",
  "/esoui/art/crafting/alchemy_tabicon_solvent_up.dds",
  "/esoui/art/crafting/blueprints_tabicon_up.dds",
  "/esoui/art/crafting/designs_tabicon_up.dds",
  "/esoui/art/crafting/enchantment_tabicon_aspect_up.dds",
  "/esoui/art/crafting/enchantment_tabicon_deconstruction_up.dds",
  "/esoui/art/crafting/enchantment_tabicon_essence_up.dds",
  "/esoui/art/crafting/enchantment_tabicon_potency_up.dds",
  "/esoui/art/crafting/gamepad/gp_crafting_menuicon_designs.dds",
  "/esoui/art/crafting/gamepad/gp_crafting_menuicon_fillet.dds",
  "/esoui/art/crafting/gamepad/gp_crafting_menuicon_improve.dds",
  "/esoui/art/crafting/gamepad/gp_crafting_menuicon_refine.dds",
  "/esoui/art/crafting/gamepad/gp_jewelry_tabicon_icon.dds",
  "/esoui/art/crafting/gamepad/gp_reconstruct_tabicon.dds",
  "/esoui/art/crafting/jewelryset_tabicon_icon_up.dds",
  "/esoui/art/crafting/patterns_tabicon_up.dds",
  "/esoui/art/crafting/provisioner_indexicon_fish_up.dds",
  "/esoui/art/crafting/provisioner_indexicon_furnishings_up.dds",
  "/esoui/art/crafting/retrait_tabicon_up.dds",
  "/esoui/art/crafting/smithing_tabicon_armorset_up.dds",
  "/esoui/art/crafting/smithing_tabicon_weaponset_up.dds",
  "/esoui/art/writadvisor/advisor_tabicon_equip_up.dds",
  "/esoui/art/writadvisor/advisor_tabicon_quests_up.dds",
  "/esoui/art/companion/keyboard/category_u30_companions_up.dds",
  "/esoui/art/collections/collections_categoryicon_unlocked_up.dds",
  "/esoui/art/collections/collections_tabicon_housing_up.dds",
  "/esoui/art/companion/keyboard/companion_character_up.dds",
  "/esoui/art/companion/keyboard/companion_skills_up.dds",
  "/esoui/art/companion/keyboard/companion_overview_up.dds",
  "/esoui/art/guildfinder/keyboard/guildbrowser_guildlist_additionalfilters_up.dds",
  "/esoui/art/help/help_tabicon_cs_up.dds",
  "/esoui/art/help/help_tabicon_tutorial_up.dds",
  "/esoui/art/lfg/lfg_any_up_64.dds",
  "/esoui/art/lfg/lfg_tank_up_64.dds",
  "/esoui/art/lfg/lfg_dps_up_64.dds",
  "/esoui/art/lfg/lfg_healer_up_64.dds",
  "/esoui/art/lfg/lfg_indexicon_alliancewar_up.dds",
  "/esoui/art/lfg/lfg_indexicon_trial_up.dds",
  "/esoui/art/lfg/lfg_indexicon_zonestories_up.dds",
  "/esoui/art/mail/mail_tabicon_inbox_up.dds",
  "/esoui/art/market/keyboard/tabicon_crownstore_up.dds",
  "/esoui/art/market/keyboard/tabicon_daily_up.dds",
  "/esoui/art/tradinghouse/tradinghouse_materials_jewelrymaking_rawplating_up.dds",
  "/esoui/art/tradinghouse/tradinghouse_sell_tabicon_up.dds",
  "/esoui/art/vendor/vendor_tabicon_fence_up.dds",
}

function TC.GetCharacterList()
  local characterList = {}
  for i = 1, GetNumCharacters() do
      local name, _, _, _, _, backupId, id = GetCharacterInfo(i)
      table.insert(characterList, { name = ZO_CachedStrFormat(SI_UNIT_NAME, name), data = id or backupId })
  end
  return characterList
end

function TC.GetNameFromId(characterList, charId)
  for _, value in ipairs(characterList) do
    if value.data == charId then
      return value.name
    end
  end
end

function TC.GetCurrentCharInfo(characters)
  if TC.currentlyLoggedInChar.name and TC.currentlyLoggedInChar.id then
    return TC.currentlyLoggedInChar.name, TC.currentlyLoggedInChar.id
  end
  for _, value in ipairs(characters) do
    if value.data == TC.currentlyLoggedInCharId then
      TC.currentlyLoggedInChar = { name = value.name, id = value.data }
      return value.name, value.id
    end
  end
return nil, nil
end

function TC.CurrentActivelyResearching()
  local summary = " "
  for k, v in pairs(TC.AV.activelyResearchingCharacters) do
    local icon = v.icon or TC.IconList[1]
    summary = summary.."  |t40:40:"..icon.."|t  "..v.name.."|r\r\n  "
  end
  return summary
end

function TC.ResearchersToDropdown()
  local researchers = {}
  for k, v in pairs(TC.AV.activelyResearchingCharacters) do
    table.insert(researchers, { name = v.name, data = k } )
  end
  return researchers
end

function TC.ResearchersCount()
  local counter = 0
  for k, v in pairs(TC.AV.activelyResearchingCharacters) do
    counter = counter + 1
  end
  return counter
end

function TC.SetCrafterDefaults(characters)
  if not next(TC.AV.mainCrafter) and not MAIN_CRAFTER_NAME and not MAIN_CRAFTER_ID then
    MAIN_CRAFTER_NAME, MAIN_CRAFTER_ID  = TC.GetCurrentCharInfo(characters)
    TC.AV.mainCrafter = { name = MAIN_CRAFTER_NAME, data = MAIN_CRAFTER_ID }
    table.insert(TC.AV.allCrafterIds, MAIN_CRAFTER_ID)
  end
  if not TC.AV.allCrafters[CRAFTING_TYPE_BLACKSMITHING] and not BLACKSMITHING_CHARACTER_NAME and not BLACKSMITHING_CHARACTER_ID then
    BLACKSMITHING_CHARACTER_NAME, BLACKSMITHING_CHARACTER_ID  = TC.GetCurrentCharInfo(characters)
  end
  if not TC.AV.allCrafters[CRAFTING_TYPE_CLOTHIER] and not CLOTHING_CHARACTER_NAME and not CLOTHING_CHARACTER_ID then
    CLOTHING_CHARACTER_NAME, CLOTHING_CHARACTER_ID  = TC.GetCurrentCharInfo(characters)
  end
  if not TC.AV.allCrafters[CRAFTING_TYPE_WOODWORKING] and not WOODWORKING_CHARACTER_NAME and not WOODWORKING_CHARACTER_ID then
    WOODWORKING_CHARACTER_NAME, WOODWORKING_CHARACTER_ID  = TC.GetCurrentCharInfo(characters)
  end
  if not TC.AV.allCrafters[CRAFTING_TYPE_JEWELRYCRAFTING] and not JEWELRY_CHARACTER_NAME and not JEWELRY_CHARACTER_ID then
    JEWELRY_CHARACTER_NAME, JEWELRY_CHARACTER_ID  = TC.GetCurrentCharInfo(characters)
  end
end

function TC.BuildMenu()
  local characterList = TC.GetCharacterList()
  TC.SetCrafterDefaults(characterList)

  local IconName, Icon, LimitTraits

  local panel = LAM:AddAddon(TC.Name, {
    allowDefaults = false,  -- Show "Reset to Defaults" button
    allowRefresh = false    -- Enable automatic control updates
  })

  panel:AddSetting {
    type = LAM.ST_DROPDOWN,
    label = TC.Lang.MAIN_CRAFTER,
    items = characterList,
    getFunction = function() return MAIN_CRAFTER_NAME or TC.AV.mainCrafter.name end,
    setFunction = function(var, itemName, itemData)
      MAIN_CRAFTER_NAME = itemName
      MAIN_CRAFTER_ID = itemData.data
    end
  }

  panel:AddSetting {
    type = LAM.ST_DROPDOWN,
    label = TC.Lang.BLACKSMITHING_CHARACTER,
    items = characterList,
    getFunction = function() return BLACKSMITHING_CHARACTER_NAME or TC.GetNameFromId(characterList, (TC.AV.allCrafters[CRAFTING_TYPE_BLACKSMITHING] or TC.AV.mainCrafter.data)) end,
    setFunction = function(var, itemName, itemData)
      BLACKSMITHING_CHARACTER_NAME = itemName
      BLACKSMITHING_CHARACTER_ID = itemData.data
    end
  }

  panel:AddSetting {
    type = LAM.ST_DROPDOWN,
    label = TC.Lang.CLOTHING_CHARACTER,
    items = characterList,
    getFunction = function() return CLOTHING_CHARACTER_NAME or TC.GetNameFromId(characterList, (TC.AV.allCrafters[CRAFTING_TYPE_CLOTHIER] or TC.AV.mainCrafter.data)) end,
    setFunction = function(var, itemName, itemData)
      CLOTHING_CHARACTER_NAME = itemName
      CLOTHING_CHARACTER_ID = itemData.data

    end
  }

  panel:AddSetting {
    type = LAM.ST_DROPDOWN,
    label = TC.Lang.WOODWORKING_CHARACTER,
    items = characterList,
    getFunction = function() return WOODWORKING_CHARACTER_NAME or TC.GetNameFromId(characterList, (TC.AV.allCrafters[CRAFTING_TYPE_WOODWORKING] or TC.AV.mainCrafter.data))  end,
    setFunction = function(var, itemName, itemData)
      WOODWORKING_CHARACTER_NAME = itemName
      WOODWORKING_CHARACTER_ID = itemData.data

    end
  }

  panel:AddSetting {
    type = LAM.ST_DROPDOWN,
    label = TC.Lang.JEWELRY_CHARACTER,
    items = characterList,
    getFunction = function() return JEWELRY_CHARACTER_NAME  or TC.GetNameFromId(characterList, (TC.AV.allCrafters[CRAFTING_TYPE_JEWELRYCRAFTING] or TC.AV.mainCrafter.data))  end,
    setFunction = function(var, itemName, itemData)
      JEWELRY_CHARACTER_NAME = itemName
      JEWELRY_CHARACTER_ID = itemData.data
    end
  }

  panel:AddSetting {
    type = LAM.ST_CHECKBOX,
    label = TC.Lang.HIDE_CRAFTER_UNKNOWN_TRAITS,
    getFunction = function() return TC.AV.HideIconsWhenTraitsUnknown end,
    setFunction = function(var)
      TC.AV.HideIconsWhenTraitsUnknown = var
    end,
    default = false,
  }

  panel:AddSetting {
    type = LAM.ST_DROPDOWN,
    label = TC.Lang.SELECT_ACTIVELY_RESEARCHING,
    items = characterList,
    getFunction = function() return ACTIVELY_RESEARCHING_NAME end,
    setFunction = function(var, itemName, itemData)
      ACTIVELY_RESEARCHING_NAME = itemName
      ACTIVELY_RESEARCHING_ID = itemData.data
    end,
  }

 --Icon Select
  panel:AddSetting {
    type = LAM.ST_ICONPICKER,
    label = TC.Lang.CHARACTER_ICON,
    items = TC.IconList,
    getFunction = function() return Icon  end,
    setFunction = function(var, iconIndex, iconPath)
      IconName = iconPath
      Icon = iconIndex
    end,
  }

--Apply
  panel:AddSetting {
    type = LAM.ST_BUTTON,
    label = TC.Lang.ACTIVE_APPLY,
    buttonText = TC.Lang.ACTIVE_APPLY,
    clickHandler  = function()
      if MAIN_CRAFTER_NAME and MAIN_CRAFTER_ID then
        TC.AV.mainCrafter = { name = MAIN_CRAFTER_NAME, data = MAIN_CRAFTER_ID }
        if not TC.isValueInTable(TC.AV.allCrafterIds, MAIN_CRAFTER_ID) then
          table.insert(TC.AV.allCrafterIds, MAIN_CRAFTER_ID)
        end
      end
      if BLACKSMITHING_CHARACTER_NAME and BLACKSMITHING_CHARACTER_ID then
        if not TC.AV.allCrafters[CRAFTING_TYPE_BLACKSMITHING] or TC.AV.allCrafters[CRAFTING_TYPE_BLACKSMITHING] ~= BLACKSMITHING_CHARACTER_ID then
          table.insert(TC.AV.allCrafterIds, BLACKSMITHING_CHARACTER_ID)
          TC.AV.allCrafters[CRAFTING_TYPE_BLACKSMITHING] = BLACKSMITHING_CHARACTER_ID
        end
      end
      if CLOTHING_CHARACTER_NAME and CLOTHING_CHARACTER_ID then
        if not TC.AV.allCrafters[CRAFTING_TYPE_CLOTHIER] or TC.AV.allCrafters[CRAFTING_TYPE_CLOTHIER] ~= CLOTHING_CHARACTER_ID then
          table.insert(TC.AV.allCrafterIds, CLOTHING_CHARACTER_ID)
          TC.AV.allCrafters[CRAFTING_TYPE_CLOTHIER] = CLOTHING_CHARACTER_ID
        end
      end
      if WOODWORKING_CHARACTER_NAME and WOODWORKING_CHARACTER_ID then
        if not TC.AV.allCrafters[CRAFTING_TYPE_WOODWORKING] or TC.AV.allCrafters[CRAFTING_TYPE_WOODWORKING] ~= WOODWORKING_CHARACTER_ID then
          table.insert(TC.AV.allCrafterIds, WOODWORKING_CHARACTER_ID)
          TC.AV.allCrafters[CRAFTING_TYPE_WOODWORKING] = WOODWORKING_CHARACTER_ID
        end
      end
      if JEWELRY_CHARACTER_NAME and JEWELRY_CHARACTER_ID then
        if not TC.AV.allCrafters[CRAFTING_TYPE_JEWELRYCRAFTING] or TC.AV.allCrafters[CRAFTING_TYPE_JEWELRYCRAFTING] ~= JEWELRY_CHARACTER_ID then
          table.insert(TC.AV.allCrafterIds, JEWELRY_CHARACTER_ID)
          TC.AV.allCrafters[CRAFTING_TYPE_JEWELRYCRAFTING] = JEWELRY_CHARACTER_ID
        end
      end
      if ACTIVELY_RESEARCHING_ID then
        if TC.ResearchersCount() <= researcherLimit then
          if not TC.AV.activelyResearchingCharacters[ACTIVELY_RESEARCHING_ID] then
            TC.AV.activelyResearchingCharacters[ACTIVELY_RESEARCHING_ID] = {}
          end
          TC.AV.activelyResearchingCharacters[ACTIVELY_RESEARCHING_ID].name = ACTIVELY_RESEARCHING_NAME
          TC.AV.activelyResearchingCharacters[ACTIVELY_RESEARCHING_ID].icon = IconName
          Status = TC.Lang.STATUS_ADDED
        else
          Status = TC.Lang.STATUS_EXCEEDED_RESEARCHERS..tostring(researcherLimit)
        end
      end
      Status = Status or TC.Lang.STATUS_ADDED
      panel:UpdateControls()
    end
  }

  --Status
  panel:AddSetting {
    type = LAM.ST_LABEL,
    label = function()
      return Status or " "
    end
  }
--Clear Researching Characters
  panel:AddSetting {
    type = LAM.ST_BUTTON,
    label = TC.Lang.CLEAR_ACTIVELY_RESEARCHING,
    buttonText = TC.Lang.SHORT_CLEAR,
    clickHandler  = function()
      TC.AV.activelyResearchingCharacters = {}
      panel:UpdateControls()
    end
    }

  --Delete specific actively researching character
  panel:AddSetting {
    type = LAM.ST_DROPDOWN,
    label = TC.Lang.REMOVE_RESEARCHER,
    items = TC.ResearchersToDropdown(),
    getFunction = function() return RESEARCHER_TO_REMOVE_NAME end,
    setFunction = function(var, itemName, itemData)
      RESEARCHER_TO_REMOVE_NAME = itemName
      RESEARCHER_TO_REMOVE_ID = itemData.data
    end,
    }

  panel:AddSetting {
    type = LAM.ST_BUTTON,
    label = TC.Lang.SHORT_REMOVE,
    buttonText = TC.Lang.SHORT_REMOVE,
    clickHandler  = function()
      if RESEARCHER_TO_REMOVE_ID and TC.AV.activelyResearchingCharacters[RESEARCHER_TO_REMOVE_ID] then
          TC.AV.activelyResearchingCharacters[RESEARCHER_TO_REMOVE_ID] = nil
      end
      Status = TC.Lang.STATUS_REMOVED
      panel:UpdateControls()
    end
    }
    -- Reload UI
    panel:AddSetting {
    type = LAM.ST_BUTTON,
    label = TC.Lang.RELOAD_UI,
    buttonText = TC.Lang.SHORT_RELOAD_UI,
    clickHandler  = function()
      ReloadUI("ingame")
    end
    }
  --Configured
  panel:AddSetting {
    type = LAM.ST_SECTION,
    label = TC.Lang.ACTIVELY_RESEARCHING,
  }
  --Actively Researching Characters Summary
  panel:AddSetting {
    type = LAM.ST_LABEL,
    label = function()
      return TC.CurrentActivelyResearching()
    end
  }
  --Breakpoint
  panel:AddSetting {
    type = LAM.ST_SECTION,
    label = " ",
  }
end
