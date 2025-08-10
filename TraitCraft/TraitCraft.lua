--Name Space
TraitCraft = {}
local TC = TraitCraft

--Basic Info
TC.Name = "TraitCraft"

TC.Default = {
    allCrafterIds = {},
    sharedCrafterVars = {},
    mainCrafter = {},
    blacksmithCharacter = {},
    clothierCharacter = {},
    woodworkingCharacter = {},
    jewelryCharacter = {},
    activelyResearchingCharacters = {},
    traitTable = {},
}

TC.currentlyLoggedInCharId = TC.currentlyLoggedInCharId or GetCurrentCharacterId()
TC.currentlyLoggedInChar = TC.currentlyLoggedInChar or {}
TC.bitwiseChars = TC.bitwiseChars or {}
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


function TC.GetCharacterBitwise()
  local characterList = {}
  for i = 1, GetNumCharacters() do
      local name, _, _, _, _, backupId, id = GetCharacterInfo(i)
      characterList[id or backupId] = 2^(i-1)
  end
  return characterList
end

--When Loaded
local function OnAddOnLoaded(eventCode, addonName)
  if addonName ~= TC.Name then return end
	EVENT_MANAGER:UnregisterForEvent(TC.Name, EVENT_ADD_ON_LOADED)

  TC.AV = ZO_SavedVars:NewAccountWide("TraitCraft_Vars", 1, nil, TC.Default)

  TC.bitwiseChars = TC.GetCharacterBitwise()
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

local function charBitMissing(trait, mask)
  -- Indicates that character bit needs to be set or is missing (as in the case of not researched)
  -- trait is the integer bitmask
  -- mask is the power-of-two flag for the character (e.g., 1, 2, 4, 8, ...)
  return (trait % (mask*2)) < mask
end

local function TC_Event_Player_Activated(event, isA)
	--Only fire once after login!
	EVENT_MANAGER:UnregisterForEvent("TC_PLAYER_ACTIVATED", EVENT_PLAYER_ACTIVATED)
	TC.currentlyLoggedInChar = {}
	TC.BuildMenu()
	if TC.AV.activelyResearchingCharacters[currentlyLoggedInCharId] then
    TraitCraft:ScanKnownTraits()
  end
end

function TraitCraft:GetTraitKey(craftingSkillType, researchLineIndex, traitIndex)
	if craftingSkillType == nil or researchLineIndex == nil or traitIndex == nil then return end
	return craftingSkillType * 10000 + researchLineIndex * 100 + traitIndex
end

local function AddAltNeedIcon(control, craftingType, researchLineIndex, traitIndex)
    local specificIcon = nil
    local sideFloat = 180
    local key = TraitCraft:GetTraitKey(craftingType, researchLineIndex, traitIndex)
    local trait = TC.AV.traitTable[key] or 2^GetNumCharacters()
    for id, mask in pairs(TC.bitwiseChars) do
      if TC.AV.activelyResearchingCharacters[id] then
        local iconPath = TC.AV.activelyResearchingCharacters[id].icon or TC.IconList[1]
        if charBitMissing(trait, mask) then
              if not control.altNeedIcon then
                  control.altNeedIcon = {}
              end
              if not control.altNeedIcon[id] then
                  local icon = WINDOW_MANAGER:CreateControl("iconId"..id.."C"..craftingType.."R"..researchLineIndex.."T"..traitIndex, control, CT_TEXTURE)
                  icon:SetDimensions(40, 40)
                  icon:SetAnchor(RIGHT, control, RIGHT, sideFloat, 0)
                  icon:SetTexture(iconPath)
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
    if TC.isValueInTable(TC.AV.allCrafterIds, currentlyLoggedInCharId) then
      ZO_PreHook(SMITHING, "ShowTraitsFor", function(self, data)
        researchLineId = data.researchLineIndex
        addSmithingHook()
      end)
    end
  end
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

function TraitCraft:WillCharacterKnowTrait(craftingSkillType, researchLineIndex, traitIndex)
	local _, _, knows = GetSmithingResearchLineTraitInfo(craftingSkillType, researchLineIndex, traitIndex)
	if knows then return true end
	local willKnow = GetSmithingResearchLineTraitTimes(craftingSkillType, researchLineIndex, traitIndex)
	if willKnow ~= nil then return true end
	return false
end

function TraitCraft:ScanKnownTraits()
  local char = TC.AV.activelyResearchingCharacters[currentlyLoggedInCharId]
  local traitLimit = 9
  local charBitId = TC.bitwiseChars[currentlyLoggedInCharId]
  local key = nil
  for _, craftingType in ipairs({ BLACKSMITH, CLOTHIER, WOODWORK, JEWELRY_CRAFTING }) do
    for researchLineIndex = 1, GetNumSmithingResearchLines(craftingType) do
      for traitIndex = 1, traitLimit do
        if self:WillCharacterKnowTrait(craftingType, researchLineIndex, traitIndex) then
          key = self:GetTraitKey(craftingType, researchLineIndex, traitIndex)
          if not TC.AV.traitTable[key] then
            TC.AV.traitTable[key] = 0
          end
          if charBitMissing(TC.AV.traitTable[key], charBitId) then
            TC.AV.traitTable[key] = TC.AV.traitTable[key] + charBitId
          end
        end
      end
    end
  end
end

EVENT_MANAGER:RegisterForEvent(TC.Name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
EVENT_MANAGER:RegisterForEvent("TC_PLAYER_ACTIVATED", EVENT_PLAYER_ACTIVATED, TC_Event_Player_Activated)
EVENT_MANAGER:RegisterForEvent(TC.name, EVENT_CRAFTING_STATION_INTERACT, OnCraftingInteract)
