--Name Space
TraitCraft = {}
local TC = TraitCraft

--Basic Info
TC.Name = "TraitCraft"

TC.Default = {
    allCrafterIds = {},
    allCrafters = {},
    mainCrafter = {},
    activelyResearchingCharacters = {},
    traitTable = {},
    savedCharacterList = {},
}

TC.currentlyLoggedInCharId = TC.currentlyLoggedInCharId or GetCurrentCharacterId()
TC.currentlyLoggedInChar = TC.currentlyLoggedInChar or {}
TC.bitwiseChars = TC.bitwiseChars or {}
TC.traitIndexKey = nil
local currentlyLoggedInCharId = TC.currentlyLoggedInCharId
local currentlyLoggedInChar = {}
local researchLineId = nil

local BLACKSMITH 		= CRAFTING_TYPE_BLACKSMITHING
local CLOTHIER 			= CRAFTING_TYPE_CLOTHIER
local WOODWORK 			= CRAFTING_TYPE_WOODWORKING
local JEWELRY_CRAFTING 	= CRAFTING_TYPE_JEWELRYCRAFTING

TC.craftingTypeIndex = 1
TC.researchLineIndex = 1
TC.traitIndex = 1

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

function TC.CompareCharChanges(savedList, currentList)
  local deltaList = { reordered = {}, deleted = {} }
  for charId, mask in pairs(currentList) do
    if savedList[charId] and savedList[charId] ~= mask then
      -- Order swap involving character that was researching - save the old mask for subtraction
      deltaList.reordered[charId] = savedList[charId]
    end
  end
  for charId, mask in pairs(savedList) do
    if not currentList[charId] then
      -- Character deleted involving character that was researching - save the old mask for subtraction
      deltaList.deleted[charId] = savedList[charId]
      if next(TC.AV.activelyResearchingCharacters) and TC.AV.activelyResearchingCharacters[charId] then
        TC.AV.activelyResearchingCharacters[charId] = nil
      end
    end
  end
  return deltaList
end

function TC.charBitMissing(trait, mask)
  -- Indicates that character bit needs to be set or is missing (as in the case of not researched)
  -- trait is the integer bitmask
  -- mask is the power-of-two flag for the character (e.g., 1, 2, 4, 8, ...)
  return (trait % (mask*2)) < mask
end

function TC.ResolveTraitDiffs()
  local start = GetFrameTimeMilliseconds()
  local key = nil
  local allMasks = nil
  while true do
    key, allMasks = next(TC.AV.traitTable, TC.traitIndexKey)
    if not key then
      EVENT_MANAGER:UnregisterForUpdate("TC_TraitMaskMigration")
      TC.AV.savedCharacterList = TC.bitwiseChars
      return
    end
    for charId, mask in pairs(TC.deltaList.deleted) do
      if not TC.charBitMissing(allMasks, mask) then
        -- fix deleted
        TC.AV.traitTable[key] = TC.AV.traitTable[key] - mask
      end
    end
    for charId, mask in pairs(TC.deltaList.reordered) do
      if not TC.charBitMissing(allMasks, mask) then
        -- fix reordered
        TC.AV.traitTable[key] = TC.AV.traitTable[key] - mask + TC.bitwiseChars[charId]
      end
    end
    TC.traitIndexKey = key
    if GetFrameTimeMilliseconds() - start > 5 then
        return
    end
  end
end

--When Loaded
local function OnAddOnLoaded(eventCode, addonName)
  if addonName ~= TC.Name then return end
	EVENT_MANAGER:UnregisterForEvent(TC.Name, EVENT_ADD_ON_LOADED)

  TC.AV = ZO_SavedVars:NewAccountWide("TraitCraft_Vars", 1, nil, TC.Default)

  TC.bitwiseChars = TC.GetCharacterBitwise()

  if not next(TC.AV.savedCharacterList) then
    TC.AV.savedCharacterList = TC.bitwiseChars
  else
    TC.deltaList = TC.CompareCharChanges(TC.AV.savedCharacterList, TC.bitwiseChars)
    if next(TC.deltaList.reordered) or next(TC.deltaList.deleted) then
      EVENT_MANAGER:RegisterForUpdate("TC_TraitMaskMigration", 0, TC.ResolveTraitDiffs)
    end
  end
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

function TraitCraft:GetTraitKey(craftingSkillType, researchLineIndex, traitIndex)
	if craftingSkillType == nil or researchLineIndex == nil or traitIndex == nil then return end
	return craftingSkillType * 10000 + researchLineIndex * 100 + traitIndex
end

function TraitCraft:WillCharacterKnowTrait(craftingSkillType, researchLineIndex, traitIndex)
	local _, _, knows = GetSmithingResearchLineTraitInfo(craftingSkillType, researchLineIndex, traitIndex)
	if knows then return true end
	local willKnow = GetSmithingResearchLineTraitTimes(craftingSkillType, researchLineIndex, traitIndex)
	if willKnow ~= nil then return true end
	return false
end

function TraitCraft:SetTraitKnown(craftingType, researchLineIndex, traitIndex)
  local charBitId = TC.bitwiseChars[currentlyLoggedInCharId]
  local key = TraitCraft:GetTraitKey(craftingType, researchLineIndex, traitIndex)
  if key and not TC.AV.traitTable[key] then
    TC.AV.traitTable[key] = 0
  end
  if key and TC.charBitMissing(TC.AV.traitTable[key], charBitId) then
    TC.AV.traitTable[key] = TC.AV.traitTable[key] + charBitId
  end
end

function TraitCraft:SetTraitUnknown(craftingType, researchLineIndex, traitIndex)
  local charBitId = TC.bitwiseChars[currentlyLoggedInCharId]
  local key = TraitCraft:GetTraitKey(craftingType, researchLineIndex, traitIndex)
  if key and TC.AV.traitTable[key] and TC.AV.traitTable[key] > 0 then
    if key and not TC.charBitMissing(TC.AV.traitTable[key], charBitId) then
      TC.AV.traitTable[key] = TC.AV.traitTable[key] - charBitId
    end
  end
end

local function checkTrait(charBitId, craftingType, researchLineIndex, traitIndex)
  if TraitCraft:WillCharacterKnowTrait(craftingType, researchLineIndex, traitIndex) then
    TraitCraft:SetTraitKnown(nil, craftingType, researchLineIndex, traitIndex)
  end
end

local function SetResearchHooks()
  EVENT_MANAGER:UnregisterForEvent("TC_ResearchComplete", EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED)
  EVENT_MANAGER:UnregisterForEvent("TC_ResearchCanceled", EVENT_SMITHING_TRAIT_RESEARCH_CANCELED)
  EVENT_MANAGER:RegisterForEvent("TC_ResearchComplete", EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED, TC.SetTraitKnown)
  EVENT_MANAGER:RegisterForEvent("TC_ResearchCanceled", EVENT_SMITHING_TRAIT_RESEARCH_CANCELED, TC.SetTraitUnknown)
end

function TraitCraft:ScanKnownTraits()
  local start = GetFrameTimeMilliseconds()
  local charBitId = TC.bitwiseChars[currentlyLoggedInCharId]
  local craftTypes = { BLACKSMITH, CLOTHIER, WOODWORK, JEWELRY_CRAFTING }
  local traitLimit = 9
  while true do
    checkTrait(charBitId, craftTypes[TC.craftingTypeIndex], TC.researchLineIndex, TC.traitIndex)
    TC.traitIndex = TC.traitIndex + 1
    if TC.traitIndex > traitLimit then
      TC.traitIndex = 1
      TC.researchLineIndex = TC.researchLineIndex + 1
      if TC.researchLineIndex > GetNumSmithingResearchLines(craftTypes[TC.craftingTypeIndex]) then
          TC.researchLineIndex = 1
          TC.craftingTypeIndex = TC.craftingTypeIndex + 1
      end
    end
    if TC.craftingTypeIndex > #craftTypes then
      EVENT_MANAGER:UnregisterForUpdate("TC_ScanKnownTraits")
      SetResearchHooks()
      return
    end
    if GetFrameTimeMilliseconds() - start > 5 then
        return -- resume next frame with current indices
    end
  end
end

local function TC_Event_Player_Activated(event, isA)
	--Only fire once after login!
	EVENT_MANAGER:UnregisterForEvent("TC_PLAYER_ACTIVATED", EVENT_PLAYER_ACTIVATED)
	TC.currentlyLoggedInChar = {}
	TC.BuildMenu()
	if TC.AV.activelyResearchingCharacters[currentlyLoggedInCharId] then
    EVENT_MANAGER:RegisterForUpdate("TC_ScanKnownTraits", 0, TC.ScanKnownTraits)
  end
end

function TC.AddAltNeedIcon(control, craftingType, researchLineIndex, traitIndex, firstOrientation, secondOrientation, sideFloat, prefix)
    local icon
    if not prefix then
      prefix = "iconId"
    end
    if not sideFloat then
      sideFloat = 180
    end
    local origSideFloat = sideFloat
    local charCounter = 0
    local key = TraitCraft:GetTraitKey(craftingType, researchLineIndex, traitIndex)
    local trait = TC.AV.traitTable[key] or 2^GetNumCharacters()
    for id, mask in pairs(TC.bitwiseChars) do
      if TC.AV.activelyResearchingCharacters[id] then
        local iconPath = TC.AV.activelyResearchingCharacters[id].icon or TC.IconList[1]
        if TC.charBitMissing(trait, mask) then
          sideFloat = origSideFloat + charCounter * 40
          if "@Saranicole1980" == GetDisplayName() then
            d("sideFloat")
            d(sideFloat)
          end
          if not control.altNeedIcon then
              control.altNeedIcon = {}
          end
          if not control.altNeedIcon[id] then
            if not GetControl(prefix..id.."C"..craftingType.."R"..researchLineIndex.."T"..traitIndex) then
              icon = WINDOW_MANAGER:CreateControl(prefix..id.."C"..craftingType.."R"..researchLineIndex.."T"..traitIndex, control, CT_TEXTURE)
              icon:SetDimensions(40, 40)
              icon:SetAnchor(firstOrientation, control, secondOrientation, sideFloat, 0)
              icon:SetTexture(iconPath)
              control.altNeedIcon[id] = icon
            end
          end
          if control.altNeedIcon[id] then
            control.altNeedIcon[id]:SetHidden(false)
          end
          charCounter = charCounter + 1
        elseif control.altNeedIcon and control.altNeedIcon[id] then
          control.altNeedIcon[id]:ClearAnchors()
          control.altNeedIcon[id]:SetHidden(true)
        end
      end
    end
  return icon
end

local function addSmithingHook()
  ZO_PreHook(SMITHING, "SetupTraitDisplay", function(self, control, researchLine, known, duration, traitIndex)
      local icon = nil
      icon = control:GetNamedChild("Icon")
      TC.AddAltNeedIcon(icon, researchLine.craftingType, researchLineId, traitIndex, RIGHT, RIGHT)
  end)
end

local function OnCraftingInteract(eventCode, craftingType)
  if next(TC.AV.allCrafterIds) then
    if TC.AV.allCrafters[craftingType] == currentlyLoggedInCharId then
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

EVENT_MANAGER:RegisterForEvent(TC.Name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
EVENT_MANAGER:RegisterForEvent("TC_PLAYER_ACTIVATED", EVENT_PLAYER_ACTIVATED, TC_Event_Player_Activated)
EVENT_MANAGER:RegisterForEvent(TC.name, EVENT_CRAFTING_STATION_INTERACT, OnCraftingInteract)
