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
        if patternName == name then
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
  if not self.parent.AV.settings.debugAutocraft then
    local key = self.parent:GetTraitKey(craftingType, researchIndex, traitIndex)
    local craftItems = self.parent:GetTraitStringFromKey(key)
    local patternIndex = self:GetPatternIndexFromResearchLine(craftingType, researchIndex)
    local traitType = findTraitType(craftingType, researchIndex, traitIndex) + 1
    return self.interactionTable:CraftSmithingItemByLevel(patternIndex, false, 1, LLC_FREE_STYLE_CHOICE, traitType, false, craftingType, 0, 0, true)
  else
    local key = self.parent:GetTraitKey(craftingType, researchIndex, traitIndex)
    local craftItems = self.parent:GetTraitStringFromKey(key)
    d("Would have crafted: "..craftItems)
  end
end

local function FindItemByLink(itemLink)
    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local slotLink = GetItemLink(BAG_BACKPACK, slotIndex, LINK_STYLE_BRACKETS)
        if slotLink == itemLink then
            return slotIndex
        end
    end
    return nil
end

function TC_Autocraft:DepositCreatedItems()
  if next(self.resultsTable) then
    for key, itemTable in pairs(self.resultsTable) do
      local itemLink = LibLazyCrafting.getItemLinkFromRequest(itemTable)
      d("itemLink")
      d(itemLink)
      local slotIndex = FindItemByLink(itemLink)
      d("slotIndex")
      d(slotIndex)
      if slotIndex then
        d("requesting move item")
        RequestMoveItem(BAG_BACKPACK, slotIndex, BAG_BANK, 0, 1)
        self.resultsTable[key] = nil
      end
    end
  end
end

function TC_Autocraft:ScanUnknownTraitsForCrafting(charId)
  local craftingType = GetCraftingInteractionType()
  local nirnCraftTypes = { CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_WOODWORKING }
  local charTable = {}
  charTable[charId] = 0
  local mask = self.parent.bitwiseChars[charId]
  local char = self.parent.AV.activelyResearchingCharacters[charId]
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
  for r = 1, researchLineLimit do
    if not self.lastCrafted[charId][r] then
      for t = 1, traitLimit do
        if not self.lastCrafted[charId][r] or not self.lastCrafted[charId][r][t] then
          if self.parent:DoesCharacterKnowTrait(craftingType, r, t) then
            key = self.parent:GetTraitKey(craftingType, r, t)
            trait = self.parent.AV.traitTable[key] or 0
            if self.parent.charBitMissing(trait, mask) and not research[key] and (not charTable[charId] or charTable[charId] < char["maxSimultResearch"][craftingType] ) then
              if not self.resultsTable[key] then
                self.resultsTable[key] = {}
              end
              self.resultsTable[key] = self:QueueItems(r, t)
              if not self.lastCrafted[charId][r] then
                self.lastCrafted[charId][r] = {}
              end
              self.lastCrafted[charId][r][t] = true
              charTable[charId] = charTable[charId] + 1
              break
            end
            if charTable[charId] >= char["maxSimultResearch"][craftingType] then
              return
            end
          end
        end
      end
    end
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

function TC_Autocraft:RegisterDepositItems(scene, newState)
  local bankingSceneName = "bank"
  if IsInGamepadPreferredMode() then
    bankingSceneName = "gamepad_banking"
  end
  local sceneName = scene:GetName()
  if sceneName == bankingSceneName and newState == SCENE_SHOWING then
    d("calling deposit created items")
    self:DepositCreatedItems()
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
  local buttonClass = "ZO_DefaultButton"
  local smithing_scene = SCENE_MANAGER:GetScene(smithingSceneName)
  local allBtn = GetControl("TC_ALL_CTL")
  if not allBtn then
    allBtn = CreateControlFromVirtual("TC_ALL_CTL", toplevel, "TC_ALL")
  end
  allBtn:SetText(self.parent.Lang.CRAFT_ALL)
  allBtn:SetFont(font)
  allBtn:SetAnchor(allBtnOrientation, toplevel, allBtnOrientation, 100, 0)
  allBtn:SetHandler("OnClicked", function()
    for id, char in pairs(self.parent.AV.activelyResearchingCharacters) do
      self:ScanUnknownTraitsForCrafting(id)
    end
  end)
  self.allFragment = ZO_SimpleSceneFragment:New(allBtn)
  smithing_scene:AddFragment(self.allFragment)
  for id, char in pairs(self.parent.AV.activelyResearchingCharacters) do
    local altBtn = GetControl("TC_ALT_CTL_"..char.name)
    if not altBtn then
      altBtn = CreateControlFromVirtual("TC_ALT_CTL_"..char.name, toplevel, "TC_ALT")
    end
    altBtn:SetAnchor(altBtnOrientation, allBtn, altBtnOrientation, offsetX, offsetY)
    offsetX = offsetX + offsetX
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
  self.resultsTable = {}
  self.lastCrafted = {}
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
  EVENT_MANAGER:RegisterForEvent(parent.Name, EVENT_CRAFTING_STATION_INTERACT, function()
    self.interactionTable:CraftAllItems()
  end)
  if parent.AV.settings.autoDepositOption then
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, newState) self:RegisterDepositItems(scene, newState) end)
  end
end

function TC_Autocraft:Destroy()
  if IsInGamepadPreferredMode() then
    self:RemoveGamepadUI()
  else
    self:RemoveKeyboardUI()
  end
  SCENE_MANAGER:UnregisterCallback("SceneStateChanged", function(scene, newState) self:RegisterDepositItems(scene, newState) end)
  EVENT_MANAGER:UnregisterForEvent(self.parent.Name, EVENT_CRAFTING_STATION_INTERACT)
  self.parent.autocraft = nil
end
