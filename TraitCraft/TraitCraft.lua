--Name Space
TraitCraft = {}
local TC = TraitCraft

--Basic Info
TC.Name = "TraitCraft"

TC.Default = {
    allCrafterIds = {},
    mainCrafter = {},
    blacksmithCharacter = {},
    clothierCharacter = {},
    woodworkingCharacter = {},
    jewelryCharacter = {},
    activelyResearchingCharacters = {},
    limitTraitsSaved = true,
}

TC.currentlyLoggedInCharId = TC.currentlyLoggedInCharId or GetCurrentCharacterId()
TC.currentlyLoggedInChar = TC.currentlyLoggedInChar or {}
local currentlyLoggedInCharId = TC.currentlyLoggedInCharId
local currentlyLoggedInChar = {}
local researchLineId = nil

local BLACKSMITH 		= CRAFTING_TYPE_BLACKSMITHING
local CLOTHIER 			= CRAFTING_TYPE_CLOTHIER
local WOODWORK 			= CRAFTING_TYPE_WOODWORKING
local JEWELRY_CRAFTING 	= CRAFTING_TYPE_JEWELRYCRAFTING

local SMITHING = ZO_SmithingResearch

if IsInGamepadPreferredMode() then
  SMITHING = ZO_GamepadSmithingResearch
end

--When Loaded
local function OnAddOnLoaded(eventCode, addonName)
  if addonName ~= TC.Name then return end
	EVENT_MANAGER:UnregisterForEvent(TC.Name, EVENT_ADD_ON_LOADED)

  TC.AV = ZO_SavedVars:NewAccountWide("TraitCraft_Vars", 1, nil, TC.Default)
end

function TC.isValueInTable(table, element)
  for _, v in ipairs(table) do
    if element == v then
      return true
    end
  end
return false
end

function TC.getValueInTable(table, element)
  for _, v in pairs(table) do
    if element == v then
      return element
    end
  end
  return nil
end

local function getValueFromTable(t)
    return select(2, next(t))
end

local function TC_Event_Player_Activated(event, isA)
	--Only fire once after login!
	EVENT_MANAGER:UnregisterForEvent("TC_PLAYER_ACTIVATED", EVENT_PLAYER_ACTIVATED)
	TC.currentlyLoggedInChar = {}
	TC.BuildMenu()
	if TC.AV.activelyResearchingCharacters[currentlyLoggedInCharId] then
    TC.AV.activelyResearchingCharacters[currentlyLoggedInCharId].unknownTraits = {}
    TraitCraft:ScanUnknownTraits()
  end
  if next(TC.AV.allCrafterIds) then
    if TC.isValueInTable(TC.AV.allCrafterIds, currentlyLoggedInCharId) and getValueFromTable(TC.AV.activelyResearchingCharacters).unknownTraits then
      TraitCraft:ScanIntersectingKnownTraitsOnCrafter()
    end
  end
end

local function AddAltNeedIcon(control, craftingType, researchLineIndex, traitIndex)
    local specificIcon = nil
    local sideFloat = 170
    for id, value in pairs(TC.AV.activelyResearchingCharacters) do
      local altNeeds = currentlyLoggedInChar[id][craftingType]
      if altNeeds and altNeeds[researchLineIndex] and altNeeds[researchLineIndex][traitIndex] then
          if not control.altNeedIcon then
              control.altNeedIcon = {}
          end
          if not control.altNeedIcon[id] then
              local icon = WINDOW_MANAGER:CreateControl("iconId"..id.."C"..craftingType.."R"..researchLineIndex.."T"..traitIndex, control, CT_TEXTURE)
              icon:SetDimensions(40, 40)
              icon:SetAnchor(RIGHT, control, RIGHT, sideFloat, 0)
              icon:SetTexture(value.icon)
              control.altNeedIcon[id] = icon
          end
          if control.altNeedIcon[id] then
            control.altNeedIcon[id]:SetHidden(false)
            sideFloat = sideFloat + 40
          end
      elseif control.altNeedIcon and control.altNeedIcon[id] then
        control.altNeedIcon[id]:SetHidden(true)
      end
    end
end

local function addSmithingHook()
  ZO_PreHook(SMITHING, "SetupTraitDisplay", function(self, control, researchLine, known, duration, traitIndex)
      local icon = nil
      icon = control:GetNamedChild("Icon")
      AddAltNeedIcon(icon, researchLine.craftingType, researchLineId, traitIndex)
  end)
end

local function OnCraftingInteract(eventCode, craftingType)
  if next(TC.AV.allCrafterIds) then
    if TC.isValueInTable(TC.AV.allCrafterIds, currentlyLoggedInCharId) and getValueFromTable(TC.AV.activelyResearchingCharacters).unknownTraits then
      ZO_PreHook(SMITHING, "ShowTraitsFor", function(self, data)
        researchLineId = data.researchLineIndex
        addSmithingHook()
      end)
    end
  end
end

function TraitCraft:GetTraitKey(craftingSkillType, researchLineIndex, traitIndex)
	if craftingSkillType == nil or researchLineIndex == nil or traitIndex == nil then return end
	return craftingSkillType * 10000 + researchLineIndex * 100 + traitIndex
end

function TraitCraft:GetTraitFromKey(key)
  traitIndex = key % 10000 % 100
  researchLineIndex = (key % 10000 - traitIndex) / 100
  craftingSkillType = (key - traitIndex - (researchLineIndex * 100)) / 10000
--   local craftingName = GetCraftingSkillName(craftingSkillType)
--   local researchLineName = GetSmithingResearchLineInfo(craftingSkillType,researchLineIndex)
--   local traitType, _, known = GetSmithingResearchLineTraitInfo(craftingSkillType,researchLineIndex, traitIndex)
--   local traitName = GetString("SI_ITEMTRAITTYPE", traitType)
	return craftingSkillType, researchLineIndex, traitIndex
end

function TraitCraft:DoesCharacterKnowTrait(craftingSkillType, researchLineIndex, traitIndex)
	local _, _, knows = GetSmithingResearchLineTraitInfo(craftingSkillType, researchLineIndex, traitIndex)
	if knows then return true end
	return false
end

function TraitCraft:WillCharacterKnowTrait(craftingSkillType, researchLineIndex, traitIndex)
	local _, _, knows = GetSmithingResearchLineTraitInfo(craftingSkillType, researchLineIndex, traitIndex)
	if knows then return true end
	local willKnow = GetSmithingResearchLineTraitTimes(craftingSkillType, researchLineIndex, traitIndex)
	if willKnow ~= nil then return true end
	return false
end

function TraitCraft:ScanIntersectingKnownTraitsOnCrafter()
	for id, value in pairs(TC.AV.activelyResearchingCharacters) do
    if value.unknownTraits then
      for index, traitKey in pairs(value.unknownTraits) do
        local craftingSkillType, researchLineIndex, traitIndex = TraitCraft:GetTraitFromKey(traitKey)
        if TC.AV.blacksmithCharacter.data == currentlyLoggedInCharId and craftingSkillType == BLACKSMITH then
          if TraitCraft:DoesCharacterKnowTrait(craftingSkillType, researchLineIndex, traitIndex) then
            if not currentlyLoggedInChar[id] then
              currentlyLoggedInChar[id] = {}
            end

            if not currentlyLoggedInChar[id][BLACKSMITH] then
              currentlyLoggedInChar[id][BLACKSMITH] = {}
            end
            if not currentlyLoggedInChar[id][BLACKSMITH][researchLineIndex] then
              currentlyLoggedInChar[id][BLACKSMITH][researchLineIndex] = { [traitIndex] = true }
            end
          end
        end
        if TC.AV.clothierCharacter.data == currentlyLoggedInCharId and craftingSkillType == CLOTHIER then
          if TraitCraft:DoesCharacterKnowTrait(craftingSkillType, researchLineIndex, traitIndex) then
            if not currentlyLoggedInChar[id] then
              currentlyLoggedInChar[id] = {}
            end

            if not currentlyLoggedInChar[id][CLOTHIER] then
              currentlyLoggedInChar[id][CLOTHIER] = {}
            end
            if not currentlyLoggedInChar[id][CLOTHIER][researchLineIndex] then
              currentlyLoggedInChar[id][CLOTHIER][researchLineIndex] = { [traitIndex] = true }
            end
          end
        end
        if TC.AV.woodworkingCharacter.data == currentlyLoggedInCharId and craftingSkillType == WOODWORK then
          if TraitCraft:DoesCharacterKnowTrait(craftingSkillType, researchLineIndex, traitIndex) then
            if not currentlyLoggedInChar[id] then
              currentlyLoggedInChar[id] = {}
            end
            if not currentlyLoggedInChar[id][WOODWORK] then
              currentlyLoggedInChar[id][WOODWORK] = {}
            end
            if not currentlyLoggedInChar[id][WOODWORK][researchLineIndex] then
              currentlyLoggedInChar[id][WOODWORK][researchLineIndex] = { [traitIndex] = true }
            end
          end
        end
        if TC.AV.jewelryCharacter.data == currentlyLoggedInCharId and craftingSkillType == JEWELRY_CRAFTING then
          if TraitCraft:DoesCharacterKnowTrait(craftingSkillType, researchLineIndex, traitIndex) then
            if not currentlyLoggedInChar[id] then
              currentlyLoggedInChar[id] = {}
            end
            if not currentlyLoggedInChar[id][JEWELRY_CRAFTING] then
              currentlyLoggedInChar[id][JEWELRY_CRAFTING] = {}
            end
            if not currentlyLoggedInChar[id][JEWELRY_CRAFTING][researchLineIndex] then
              currentlyLoggedInChar[id][JEWELRY_CRAFTING][researchLineIndex] = { [traitIndex] = true }
            end
          end
        end
      end
    else
      d("Researching character has no unknown traits.")
    end
  end
end

function TraitCraft:ScanUnknownTraits()
  local char = TC.AV.activelyResearchingCharacters[currentlyLoggedInCharId]
  local traitLimit = 9
  if TC.AV.limitTraitsSaved then
    traitLimit = 1
  end
	for researchLineIndex = 1, GetNumSmithingResearchLines(BLACKSMITH) do
		for traitIndex = 1, traitLimit do
      if not self:WillCharacterKnowTrait(BLACKSMITH, researchLineIndex, traitIndex) then
        table.insert(char.unknownTraits, self:GetTraitKey(BLACKSMITH, researchLineIndex, traitIndex))
      end
		end
	end
	for researchLineIndex = 1, GetNumSmithingResearchLines(CLOTHIER) do
    for traitIndex = 1, traitLimit do
      if not self:WillCharacterKnowTrait(CLOTHIER, researchLineIndex, traitIndex) then
        table.insert(char.unknownTraits, self:GetTraitKey(CLOTHIER, researchLineIndex, traitIndex))
      end
    end
	end
	for researchLineIndex = 1, GetNumSmithingResearchLines(WOODWORK) do
    for traitIndex = 1, traitLimit do
      if not self:WillCharacterKnowTrait(WOODWORK, researchLineIndex, traitIndex) then
        table.insert(char.unknownTraits, self:GetTraitKey(WOODWORK, researchLineIndex, traitIndex))
      end
    end
	end
	for researchLineIndex = 1, GetNumSmithingResearchLines(JEWELRY_CRAFTING) do
    for traitIndex = 1, traitLimit do
      if not self:WillCharacterKnowTrait(JEWELRY_CRAFTING, researchLineIndex, traitIndex) then
        table.insert(char.unknownTraits, self:GetTraitKey(JEWELRY_CRAFTING, researchLineIndex, traitIndex))
      end
    end
	end
end

EVENT_MANAGER:RegisterForEvent(TC.Name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
EVENT_MANAGER:RegisterForEvent("TC_PLAYER_ACTIVATED", EVENT_PLAYER_ACTIVATED, TC_Event_Player_Activated)
EVENT_MANAGER:RegisterForEvent(TC.name, EVENT_CRAFTING_STATION_INTERACT, OnCraftingInteract)
