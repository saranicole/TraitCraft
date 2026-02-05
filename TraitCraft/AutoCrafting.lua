TC_Autocraft = ZO_Object:Subclass()

local LLC = LibLazyCrafting

local CRAFT_TOKEN_REVERSE = {
  ["BS"]         = CRAFTING_TYPE_BLACKSMITHING,
  ["CL"]         = CRAFTING_TYPE_CLOTHIER,
  ["WW"]         = CRAFTING_TYPE_WOODWORKING,
  ["JW"]         = CRAFTING_TYPE_JEWELRYCRAFTING,
}

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
    local patternName
    -- Scan through patterns to find one with an exact match
    for patternIndex = 1, GetNumSmithingPatterns() do
        patternName = GetSmithingPatternInfo(patternIndex)
        if name == patternName then
          return patternIndex
        end
    end
    -- Fall back to approximately the same name
    for pIndex = 1, GetNumSmithingPatterns() do
        patternName = GetSmithingPatternInfo(pIndex)
        local found = string.find(name, patternName, 1, true)
        if found ~= nil then
            return pIndex
        end
    end
    return nil
end

local function findTraitType(craftingSkillType, researchLineIndex, traitIndex)
  local foundTraitType, description, _ = GetSmithingResearchLineTraitInfo(craftingSkillType, researchLineIndex, traitIndex)
	return foundTraitType or ITEM_TRAIT_TYPE_NONE
end

function TC_Autocraft:QueueItems(charId, researchIndex, traitIndex)
  local craftingType = GetCraftingInteractionType()
  local patternIndex = self:GetPatternIndexFromResearchLine(craftingType, researchIndex)
  local traitType = findTraitType(craftingType, researchIndex, traitIndex)
  traitType = traitType + 1
  if patternIndex then
    local request = self.interactionTable:CraftSmithingItemByLevel(patternIndex, false, 1, LLC_FREE_STYLE_CHOICE, traitType, false, craftingType, 0, 0, false)
    if LLC.craftInteractionTables[craftingType]:isItemCraftable(craftingType, request) then
      self.interactionTable:craftItem(craftingType)
    end
  end
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

function TC_Autocraft:craftForType(scanResults, craftingType, charId)
  local craftCounter = 0
  for rIndex, entry in pairs(scanResults[craftingType]) do
    if type(entry) == "table" then
      for tIndex, obj in pairs(entry[rIndex]) do
        if self.parent:DoesCharacterKnowTrait(craftingType, rIndex, tIndex) then
          self:QueueItems(charId, rIndex, tIndex)
          craftCounter = craftCounter + 1
        end
      end
    else
      if self.parent:DoesCharacterKnowTrait(craftingType, rIndex, entry) then
        self:QueueItems(charId, rIndex, entry)
        craftCounter = craftCounter + 1
      end
    end
  end
  return craftCounter
end

function TC_Autocraft:CraftFromInput(scanResults, sender)

  local craftCounter = 0
  local craftingType = GetCraftingInteractionType()
  for iDex, entry in pairs(scanResults) do
    if craftingType == CRAFT_TOKEN_REVERSE[entry[1]] then
      local iterLen = #entry[2] - 1
      for i = 1, iterLen do
        local convertedObj = { [craftingType] = { [entry[2][i]] = entry[2][i + 1] } }
        craftCounter = self:craftForType(convertedObj, craftingType, sender)
      end
      scanResults[iDex] = nil
    end
  end
  if craftCounter > 0 then return true, scanResults end
  return false, scanResults
end

function TC_Autocraft:ScanUnknownTraitsForCrafting(charId)
  local craftingType = GetCraftingInteractionType()
  self.parent:ScanUnknownTraitsForCrafting(charId, craftingType, function(scanResults)
    local craftCounter = self:craftForType(scanResults, craftingType, charId)
    if craftCounter == 0 then
      SCENE_MANAGER:ShowBaseScene()
      local skillName = ZO_GetCraftingSkillName(craftingType)
      d(self.parent.Lang.CRAFT_FAILED..skillName)
    end
  end)
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

function TC_Autocraft:Initialize(parent)
  self.parent = parent
  if not LLC then
    return
  end
  if not LLC:GetRequestingAddon(parent.Name) then
    local styles = self.parent:GetCommonStyles()
    self.interactionTable = LLC:AddRequestingAddon(parent.Name, false, function (event, craftingType, requestTable)
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
