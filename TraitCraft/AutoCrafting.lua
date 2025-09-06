TC_Autocraft = ZO_Object:Subclass()

function TC_Autocraft:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function TC_Autocraft:GetPatternIndexFromResearchLine(craftingType, researchLineIndex)
    -- Get the research line's name (e.g., "Axe", "Chest", "Bow")
    local name, _, _, numTraits = GetSmithingResearchLineInfo(craftingType, researchLineIndex)
    if not name then
        return nil
    end
    -- Scan through patterns to find one with the same name
    for patternIndex = 1, GetNumSmithingPatterns() do
        local patternName = GetSmithingPatternInfo(patternIndex)
        local found = string.find(name, patternName, 1, true)
        if found ~= nil then
            return patternIndex
        end
    end
    return nil
end

local function findTraitType(craftingSkillType, researchLineIndex, traitIndex)
  local foundTraitType, description, _ = GetSmithingResearchLineTraitInfo(craftingSkillType, researchLineIndex, traitIndex)
	return foundTraitType or ITEM_TRAIT_TYPE_NONE
end

function TC_Autocraft:QueueItems(researchIndex, traitIndex)
  local craftingType = GetCraftingInteractionType()
  local patternIndex = self:GetPatternIndexFromResearchLine(craftingType, researchIndex)
  local traitType = findTraitType(craftingType, researchIndex, traitIndex)
  traitType = traitType + 1
  return self.interactionTable:CraftSmithingItemByLevel(patternIndex, false, 1, LLC_FREE_STYLE_CHOICE, traitType, false, craftingType, 0, 0, false)
end

local function sortKeysByValue(tbl)
  local keys = {}
  for k in pairs(tbl) do
      table.insert(keys, k)
  end
  table.sort(keys, function(a, b)
      if tbl[a] == tbl[b] then
          return a < b  -- tiebreaker: smaller key first
      else
          return tbl[a] > tbl[b]
      end
  end)
  return keys
end

local function getKeys(tbl)
  local keys = {}
  if not tbl then
    return {}
  end
  for k, _ in pairs(tbl) do
      table.insert(keys, k)
  end
  return keys
end

function TC_Autocraft:rollupNonCraftable(nonCraftableTotals, craftingType)
  local skillName = ZO_GetCraftingSkillName(craftingType)
  return self.parent.Lang.CRAFT_FAILED..skillName..":\r\n"..self.parent.Lang.MISSING_MATS..nonCraftableTotals.materials.."\r\n"..self.parent.Lang.MISSING_KNOWLEDGE..nonCraftableTotals.knowledge
end

function TC_Autocraft:incrementNonCraftable(nonCraftableTotals, nonCraftable)
  if nonCraftable.missingMats and next(nonCraftable.missingMats.materials) then
    nonCraftableTotals.materials = nonCraftableTotals.materials + 1
  end
  if nonCraftable.missingKnowledge and next(nonCraftable.missingKnowledge.knowledge) then
    nonCraftableTotals.knowledge = nonCraftableTotals.knowledge + 1
  end
  return nonCraftableTotals
end

function TC_Autocraft:ScanUnknownTraitsForCrafting(charId)
  local craftingType = GetCraftingInteractionType()
  local nirnCraftTypes = { CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_WOODWORKING }
  local tempResearchTable = {
    rCounter = {},
    rObjects = {}
  }
  local mask = self.parent.bitwiseChars[charId]
  local char = self.parent.AV.activelyResearchingCharacters[charId]
  if not char then
    d(self.parent.Lang.LOG_INTO_CHAR)
    return
  end
  if not char["maxSimultResearch"] then
    d(self.parent.Lang.LOG_INTO_CHAR)
    return
  end
  local research = char.research or {}
  local researchLineLimit = GetNumSmithingResearchLines(craftingType)
  local traitLimit = 9
  if not self.parent.AV.settings.autoCraftNirnhoned and self.parent.isValueInTable(nirnCraftTypes, craftingType) then
    traitLimit = 8
  end
  local key
  local trait
  if not self.lastCrafted[charId] then
    self.lastCrafted[charId] = {}
  end
  if not self.lastCrafted[charId][craftingType] then
    self.lastCrafted[charId][craftingType] = {}
  end
  if not self.rIndices[charId] then
    self.rIndices[charId] = {}
  end
  if not self.rObjects[charId] then
    self.rObjects[charId] = {}
  end
  if not self.rIndices[charId][craftingType] then
    for r = 1, researchLineLimit do
      if not self.lastCrafted[charId][craftingType][r] then
        for t = 1, traitLimit do
          key = self.parent:GetTraitKey(craftingType, r, t)
          trait = self.parent.AV.traitTable[key] or 0
          if self.parent.charBitMissing(trait, mask) and not research[key] then
            if not tempResearchTable.rCounter[r] then
              tempResearchTable.rCounter[r] = 0
            end
            tempResearchTable.rCounter[r] =  tempResearchTable.rCounter[r] + 1
            if not tempResearchTable.rObjects[r] then
              tempResearchTable.rObjects[r] = {}
            end
            table.insert(tempResearchTable.rObjects[r], t)
          end
        end
      end
    end
    self.rIndices[charId][craftingType] = sortKeysByValue(tempResearchTable.rCounter)
    self.rObjects[charId] = tempResearchTable.rObjects
  end

  --Sort by minimum research duration
  local traitCounter = 0
  local nonCraftableTotals = {
    materials = 0,
    knowledge = 0,
  }
  for i = 1, #self.rIndices[charId][craftingType] do
    local rIndex = self.rIndices[charId][craftingType][i]
    if not self.lastCrafted[charId][craftingType][rIndex] then
      self.lastCrafted[charId][craftingType][rIndex] = {}
    end
    for j = 1, #self.rObjects[charId][rIndex] do
      local tIndex = self.rObjects[charId][rIndex][j]
      if not self.lastCrafted[charId][craftingType][rIndex][tIndex] then
        local thisKey = self.parent:GetTraitKey(craftingType, rIndex, tIndex)
        --Debug
        local request = self:QueueItems(rIndex, tIndex)
        if not LibLazyCrafting.craftInteractionTables[craftingType]:isItemCraftable(craftingType, request) then
          local nonCraftableObj = LibLazyCrafting.craftInteractionTables[craftingType]["getNonCraftableReasons"](request)
          nonCraftableTotals = self:incrementNonCraftable(nonCraftableTotals, nonCraftableObj)
        else
          self.interactionTable:craftItem(craftingType)
          self.lastCrafted[charId][craftingType][rIndex][tIndex] = true
          traitCounter = traitCounter + 1
          break
        end
      end
    end
    if traitCounter >= char["maxSimultResearch"][craftingType] then
      return
    end
  end
  --No successful crafts
  if traitCounter == 0 then
    d(self:rollupNonCraftable(nonCraftableTotals, craftingType))
  end
end

local function getGamepadCraftKeyIcon()
	local key
	for i =1, 4 do
		key = GetActionBindingInfo(3, 1, 3, i)
		if IsKeyCodeGamepadKey(key) then
			break
		end
	end
	return GetGamepadIconPathForKeyCode(key) or  GetMouseIconPathForKeyCode(key) or GetKeyboardIconPathForKeyCode(key) or ""
end

function TC_Autocraft:CreateGamepadUI()
  TC_SCREEN:SetHidden(false)
  local label = GetControl("TC_SCREENBackdropOutput")
  label:SetText(self.parent.Lang.CRAFT_ALL)
  self.autoCraftBtn = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    {
        name = self.parent.Lang.CRAFT_SPECIFIC,
        keybind = "UI_SHORTCUT_TERTIARY",
        order = 2400,
        callback = function()
          if not self.selectedAutoCraft or self.selectedAutoCraft == self.parent.Lang.CRAFT_ALL then
            self.selectedAutoCraft = select(2, next(self.parent.AV.activelyResearchingCharacters)).name
          else
            charId = self.parent.GetCharIdByName(self.selectedAutoCraft)
            local char = select(2, next(self.parent.AV.activelyResearchingCharacters, charId))
            if char then
              self.selectedAutoCraft = char.name
            else
              self.selectedAutoCraft = self.parent.Lang.CRAFT_ALL
            end
          end
          local label = GetControl("TC_SCREENBackdropOutput")
          label:SetText(self.selectedAutoCraft)
        end,
      },
    {
        name = self.parent.Lang.CRAFT_ALL,
        keybind = "UI_SHORTCUT_QUATERNARY",
        order = 2500,
        callback = function()
          if not self.selectedAutoCraft then
            for id, char in pairs(self.parent.AV.activelyResearchingCharacters) do
              self:ScanUnknownTraitsForCrafting(id)
            end
          else
            local charId = self.parent.GetCharIdByName(self.selectedAutoCraft)
            self:ScanUnknownTraitsForCrafting(charId)
          end
        end,
      },
    }
  KEYBIND_STRIP:AddKeybindButtonGroup(self.autoCraftBtn)
  self.showing = true
end

function TC_Autocraft:RemoveGamepadUI()
  KEYBIND_STRIP:RemoveKeybindButtonGroup(self.autoCraftBtn)
  TC_SCREEN:SetHidden(true)
  self.showing = false
end

function TC_Autocraft:RemoveKeyboardUI()
  local smithingSceneName = "smithing"
  local toplevel = ZO_SmithingTopLevel
  local smithing_scene = SCENE_MANAGER:GetScene(smithingSceneName)
  if self.allFragment then
    smithing_scene:RemoveFragment(self.allFragment)
  end
  if self.altFragment then
    smithing_scene:RemoveFragment(self.altFragment)
  end
end

function TC_Autocraft:CreateKeyboardUI()
  local smithingSceneName = "smithing"
  local toplevel = ZO_SmithingTopLevel
  local allBtnOrientation = TOP
  local altBtnOrientation = BOTTOM
  local offsetX = 0
  local offsetY = 40
  local font = "ZoFontGameLarge"
  local smithing_scene = SCENE_MANAGER:GetScene(smithingSceneName)
  local allBtnParent = GetControl("TC_ALL_CTL")
  if not allBtnParent then
    allBtnParent = CreateControlFromVirtual("TC_ALL_CTL", toplevel, "TC_ALL_PARENT")
  end
  local altBtnParent = GetControl("TC_ALT_CTL")
  if not altBtnParent then
    altBtnParent = CreateControlFromVirtual("TC_ALT_CTL", toplevel, "TC_ALT_PARENT")
  end
  allBtn = CreateControl(nil, allBtnParent, CT_BUTTON)
  allBtn:SetText(self.parent.Lang.CRAFT_ALL)
  allBtn:SetFont(font)
  allBtn:SetDimensions( allBtnParent:GetWidth() , allBtnParent:GetHeight() )
  allBtn:SetNormalTexture("EsoUI/Art/Buttons/ESO_buttonLarge_normal.dds")
  allBtn:SetPressedTexture("EsoUI/Art/Buttons/ESO_buttonlLarge_mouseDown.dds")
  allBtn:SetMouseOverTexture("EsoUI/Art/Buttons/ESO_buttonLarge_mouseOver.dds")
  allBtn:SetDisabledTexture("EsoUI/Art/Buttons/ESO_buttonLarge_disabled.dds")
  allBtn:SetAnchor(allBtnOrientation, toplevel, allBtnOrientation, 100, 0)
  allBtn:SetHandler("OnClicked", function()
    for id, char in pairs(self.parent.AV.activelyResearchingCharacters) do
      self:ScanUnknownTraitsForCrafting(id)
    end
  end)
  self.allFragment = ZO_SimpleSceneFragment:New(allBtn)
  smithing_scene:AddFragment(self.allFragment)
  for id, char in pairs(self.parent.AV.activelyResearchingCharacters) do
    altBtn = CreateControl(nil, altBtnParent, CT_BUTTON)
    altBtn:SetAnchor(altBtnOrientation, allBtn, altBtnOrientation, offsetX, offsetY)
    altBtn:SetState( NORMAL )
    altBtn:SetDimensions( altBtnParent:GetWidth() , altBtnParent:GetHeight() )
    altBtn:SetNormalTexture("EsoUI/Art/Buttons/ESO_buttonLarge_normal.dds")
    altBtn:SetPressedTexture("EsoUI/Art/Buttons/ESO_buttonlLarge_mouseDown.dds")
    altBtn:SetMouseOverTexture("EsoUI/Art/Buttons/ESO_buttonLarge_mouseOver.dds")
    altBtn:SetDisabledTexture("EsoUI/Art/Buttons/ESO_buttonLarge_disabled.dds")
    offsetY = offsetY + offsetY
    altBtn:SetText(char.name)
    altBtn:SetFont(font)
    altBtn:SetHandler("OnClicked", function()
      self:ScanUnknownTraitsForCrafting(id)
    end)
    self.altFragment = ZO_SimpleSceneFragment:New(altBtn)
    smithing_scene:AddFragment(self.altFragment)
  end
end

function TC_Autocraft:GetCommonStyles()
	-- Courtesy of Weolo and wolfstar's TraitBuddy
	local styles = {}
	local STYLE_KHAJIIT = 9
	for itemStyleIndex = 1, STYLE_KHAJIIT do
		local itemStyleId = GetValidItemStyleId(itemStyleIndex)
		if itemStyleId > 0 then
			-- d(sf("Adding style %s itemStyleId %s", GetItemStyleName(itemStyleId), itemStyleId))
			styles[itemStyleId] = true
		end
	end
	return styles
end

function TC_Autocraft:Initialize(parent)
  self.parent = parent
  if not LibLazyCrafting then
    return
  end
  self.lastCrafted = {}
  self.rIndices = {}
  self.rObjects = {}
  if not LibLazyCrafting:GetRequestingAddon(parent.Name) then
    local styles = self:GetCommonStyles()
    self.interactionTable = LibLazyCrafting:AddRequestingAddon(parent.Name, false, function (event, craftingType, requestTable)
      if not LLC_NO_FURTHER_CRAFT_POSSIBLE then
        d(event)
      end
      return
    end, parent.Author, styles)
  end
  if not IsInGamepadPreferredMode() then
    EVENT_MANAGER:RegisterForEvent(parent.Name, EVENT_CRAFTING_STATION_INTERACT, function()
      self:CreateKeyboardUI()
    end)
  else
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, newState)
      local sceneName = scene:GetName()
      if sceneName == "gamepad_smithing_root" and newState == SCENE_SHOWING then
        self:CreateGamepadUI()
      elseif self.showing then
        self:RemoveGamepadUI()
      end
    end)
  end
end

function TC_Autocraft:Destroy()
  if IsInGamepadPreferredMode() then
    self:RemoveGamepadUI()
  else
    self:RemoveKeyboardUI()
  end
  self.parent.autocraft = nil
end
