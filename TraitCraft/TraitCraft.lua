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
    settings = {
      showKnown = false,
      showResearching = true,
      showUnknown = true,
      knownColor = {
        r = 0.0,
        g = 0.447,
        b = 0.698
      },
      unknownColor = {
        r = 0.4,
        g = 0.4,
        b = 0.4
      },
      researchingColor = {
        r = 0.902,
        g = 0.624,
        b = 0.0
      }
    }
}

TC.currentlyLoggedInCharId = TC.currentlyLoggedInCharId or GetCurrentCharacterId()
TC.currentlyLoggedInChar = TC.currentlyLoggedInChar or {}
TC.bitwiseChars = TC.bitwiseChars or {}
TC.traitIndexKey = nil
TC.hookLock = false


local currentlyLoggedInCharId = TC.currentlyLoggedInCharId
local currentlyLoggedInChar = {}
local researchLineIndex = nil

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

function TraitCraft:FindTraitIndex(craftingSkillType, researchLineIndex, traitType)
	local _, _, numTraits, _ = GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)
	for traitIndex = 1, numTraits do
		local foundTraitType, description, _ = GetSmithingResearchLineTraitInfo(craftingSkillType, researchLineIndex, traitIndex)
		if foundTraitType == traitType then
			return traitIndex
		end
	end
	return ITEM_TRAIT_TYPE_NONE
end

function TraitCraft:GetTraitKey(craftingSkillType, researchLineIndex, traitIndex)
	if craftingSkillType == nil or researchLineIndex == nil or traitIndex == nil then return end
	return craftingSkillType * 10000 + researchLineIndex * 100 + traitIndex
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

function TraitCraft:IsResearchingTrait(craftingSkillType, researchLineIndex, traitIndex)
	local _, _, knows = GetSmithingResearchLineTraitInfo(craftingSkillType, researchLineIndex, traitIndex)
	if knows then return false end
	local willKnow = GetSmithingResearchLineTraitTimes(craftingSkillType, researchLineIndex, traitIndex)
	if willKnow ~= nil then return true end
	return false
end

function TraitCraft:GetResearchTimeForTrait(craftingSkillType, researchLineIndex, traitIndex)
	local duration, timeRemaining = GetSmithingResearchLineTraitTimes(craftingSkillType, researchLineIndex, traitIndex)
  local whenDoneTimeStamp = GetTimeStamp() + timeRemaining
  return whenDoneTimeStamp
end

function TraitCraft:SetTraitResearching(craftingType, researchLineIndex, traitIndex, whenDone)
  local char = TC.AV.activelyResearchingCharacters[currentlyLoggedInCharId]
  if char then
    local key = TraitCraft:GetTraitKey(craftingType, researchLineIndex, traitIndex)
    if not char.research then
      char.research = {}
    end
    char.research[key] = whenDone
  end
end

function TraitCraft:SetTraitKnownOnCharIdWithKey(id, key)
  local charBitId = TC.bitwiseChars[id]
  if key and not TC.AV.traitTable[key] then
    TC.AV.traitTable[key] = 0
  end
  if key and TC.charBitMissing(TC.AV.traitTable[key], charBitId) then
    TC.AV.traitTable[key] = TC.AV.traitTable[key] + charBitId
  end
end

function TraitCraft:SetTraitKnown(craftingType, researchLineIndex, traitIndex)
  local charBitId = TC.bitwiseChars[currentlyLoggedInCharId]
  local key = TraitCraft:GetTraitKey(craftingType, researchLineIndex, traitIndex)
  if key and not TC.AV.traitTable[key] then
    TC.AV.traitTable[key] = 0
  end
  if key then
    if TC.charBitMissing(TC.AV.traitTable[key], charBitId) then
      TC.AV.traitTable[key] = TC.AV.traitTable[key] + charBitId
    end
    local char = TC.AV.activelyResearchingCharacters[currentlyLoggedInCharId]
    if char and char.research and next(char.research) then
      if char.research[key] then
        char.research[key] = nil
      end
    end
  end
end

function TraitCraft:SetTraitUnknown(craftingType, researchLineIndex, traitIndex)
  local charBitId = TC.bitwiseChars[currentlyLoggedInCharId]
  local key = TraitCraft:GetTraitKey(craftingType, researchLineIndex, traitIndex)
  if key then
    if TC.AV.traitTable[key] and TC.AV.traitTable[key] > 0 then
      if key and not TC.charBitMissing(TC.AV.traitTable[key], charBitId) then
        TC.AV.traitTable[key] = TC.AV.traitTable[key] - charBitId
      end
    end
    local char = TC.AV.activelyResearchingCharacters[currentlyLoggedInCharId]
    if char and char.research and next(char.research) then
      if char.research[key] then
        char.research[key] = nil
      end
    end
  end
end

local function checkTrait(craftingType, researchLineIndex, traitIndex)
  if TraitCraft:IsResearchingTrait(craftingType, researchLineIndex, traitIndex) then
    local whenDone = TraitCraft:GetResearchTimeForTrait(craftingType, researchLineIndex, traitIndex)
    TraitCraft:SetTraitResearching(craftingType, researchLineIndex, traitIndex, whenDone)
  elseif TraitCraft:DoesCharacterKnowTrait(craftingType, researchLineIndex, traitIndex) then
    TraitCraft:SetTraitKnown(craftingType, researchLineIndex, traitIndex)
  else
    TraitCraft:SetTraitUnknown(craftingType, researchLineIndex, traitIndex)
  end
end

local function SetResearchHooks()
  EVENT_MANAGER:UnregisterForEvent("TC_ResearchComplete", EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED)
  EVENT_MANAGER:UnregisterForEvent("TC_ResearchCanceled", EVENT_SMITHING_TRAIT_RESEARCH_CANCELED)
  EVENT_MANAGER:UnregisterForEvent("TC_ResearchStarted", EVENT_SMITHING_TRAIT_RESEARCH_STARTED)
  EVENT_MANAGER:RegisterForEvent("TC_ResearchComplete", EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED, TC.SetTraitKnown)
  EVENT_MANAGER:RegisterForEvent("TC_ResearchStarted", EVENT_SMITHING_TRAIT_RESEARCH_STARTED, TC.SetTraitKnown)
  EVENT_MANAGER:RegisterForEvent("TC_ResearchCanceled", EVENT_SMITHING_TRAIT_RESEARCH_CANCELED, TC.SetTraitUnknown)
end

function TraitCraft:ScanKnownTraits()
  local start = GetFrameTimeMilliseconds()
  local craftTypes = { BLACKSMITH, CLOTHIER, WOODWORK, JEWELRY_CRAFTING }
  local traitLimit = 9
  while true do
    checkTrait(craftTypes[TC.craftingTypeIndex], TC.researchLineIndex, TC.traitIndex)
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

function TraitCraft:ScanForResearchExpired()
  if not IsUnitInCombat("player") and not IsUnitDead("player") then
    local now = GetTimeStamp()
    for id, char in pairs(TC.AV.activelyResearchingCharacters) do
      if char.research and next(char.research) then
        for key, done in pairs(char.research) do
          local timeRemaining = GetDiffBetweenTimeStamps(done, now)
          if timeRemaining <= 0 then
            TraitCraft:SetTraitKnownOnCharIdWithKey(id, key)
            char.research[key] = nil
            local traitKey = TraitCraft:GetTraitStringFromKey(key)
            d(TraitCraft.Lang.RESEARCH_EXPIRED..char.name.." - "..traitKey)
          end
        end
      end
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
  if IsConsoleUI() then
    TC.inventory = TC_Inventory:New(TC)
  end
  local FIVE_MINUTES_MS = 5 * 60 * 1000  -- 5 min in ms
  EVENT_MANAGER:UnregisterForUpdate("TC_ScanForResearchExpired")
  EVENT_MANAGER:RegisterForUpdate("TC_ScanForResearchExpired", FIVE_MINUTES_MS, TC.ScanForResearchExpired)
end

function TC.addResearchIcon(control, craftingType, researchLineIndex, traitIndex, firstOrientation, secondOrientation, sideFloat, controlName)
  local icon
  if control.altNeedIcon and next(control.altNeedIcon) then
    for id, icon in pairs(control.altNeedIcon) do
      icon:ClearAnchors()
      icon:SetHidden(true)
    end
  end
  if not control.researchIcon then
    control.researchIcon = { path = "/esoui/art/lfg/lfg_tabicon_grouptools_up.dds" }
  end
  if not control.researchIcon.icon then
    icon = WINDOW_MANAGER:CreateControl(controlName, control, CT_TEXTURE)
    icon:SetDimensions(40, 40)
    icon:SetAnchor(firstOrientation, control, secondOrientation, sideFloat, 0)
    icon:SetTexture(control.researchIcon.path)
    control.researchIcon.icon = icon
  else
    control.researchIcon.icon:SetHidden(false)
  end
  return icon
end

local function setupNoop()
  return
end

function TC.CreateIcon(control, id, iconPath, r, g, b, sideFloat, firstOrientation, secondOrientation, controlName)
  local icon
  if not control.altNeedIcon then
      control.altNeedIcon = {}
  end
  if not control.altNeedIcon[id] then
    if not GetControl(controlName) then
      icon = WINDOW_MANAGER:CreateControl(controlName, control, CT_TEXTURE)
      icon:SetDimensions(40, 40)
      icon:SetAnchor(firstOrientation, control, secondOrientation, sideFloat, 0)
      icon:SetTexture(iconPath)
      icon:SetColor(r, g, b, 1)
      control.altNeedIcon[id] = icon
    end
  end
  if control.altNeedIcon[id] then
    control.altNeedIcon[id]:SetHidden(false)
  end
  return icon
end

function TC.addCharIcon(control, id, value, sideFloat, key, firstOrientation, secondOrientation, controlName)
  local icon
  if control.researchIcon and control.researchIcon.icon then
    control.researchIcon.icon:ClearAnchors()
    control.researchIcon.icon:SetHidden(true)
  end
  if control.altNeedIcon and control.altNeedIcon[id] then
    control.altNeedIcon[id]:ClearAnchors()
    control.altNeedIcon[id]:SetHidden(true)
  end
  local trait = TC.AV.traitTable[key] or 0
  local mask = TC.bitwiseChars[id]
  local iconPath = value.icon or TC.IconList[1]
  --Unknown
  if TC.charBitMissing(trait, mask) then
    local char = TC.AV.activelyResearchingCharacters[id]
    --Researching
    if GetDisplayName() == "@Saranicole1980" then
      d("key")
      d(key)
      d("Setting")
      d(TC.AV.settings.showResearching)
      d("char")
      d(char)
      d("research")
      d(char.research)
    end
    if TC.AV.settings.showResearching and char and char.research and char.research[key] then
      TC.CreateIcon(control, id, iconPath, TC.AV.settings.researchingColor.r, TC.AV.settings.researchingColor.g, TC.AV.settings.researchingColor.b, sideFloat, firstOrientation, secondOrientation, controlName)
    elseif TC.AV.settings.showUnknown then
      TC.CreateIcon(control, id, iconPath, TC.AV.settings.unknownColor.r, TC.AV.settings.unknownColor.g, TC.AV.settings.unknownColor.b, sideFloat, firstOrientation, secondOrientation, controlName)
    end
  --Known
  elseif TC.AV.settings.showKnown then
    TC.CreateIcon(control, id, iconPath, TC.AV.settings.knownColor.r, TC.AV.settings.knownColor.g, TC.AV.settings.knownColor.b, sideFloat, firstOrientation, secondOrientation, controlName)
  end
end

function TC.AddAltNeedIcon(control, craftingType, researchLineIndex, traitIndex, firstOrientation, secondOrientation, sideFloat, prefix)
  local controlName
  local knows = TraitCraft:DoesCharacterKnowTrait(craftingType, researchLineIndex, traitIndex)
  if not knows then
    controlName = prefix.."Unresearched"..currentlyLoggedInCharId.."C"..craftingType.."R"..researchLineIndex.."T"..traitIndex
    TC.addResearchIcon(control, craftingType, researchLineIndex, traitIndex, firstOrientation, secondOrientation, sideFloat, controlName)
  else
    local key = TraitCraft:GetTraitKey(craftingType, researchLineIndex, traitIndex)
    for id, value in pairs(TC.AV.activelyResearchingCharacters) do
      controlName = prefix..id.."C"..craftingType.."R"..researchLineIndex.."T"..traitIndex
      TC.addCharIcon(control, id, value, sideFloat, key, firstOrientation, secondOrientation, controlName)
      sideFloat = sideFloat + 40
    end
  end
end

local function setupTraitDisplayCallback(self, control, researchLine, known, duration, traitIndex)
  local icon = nil
  icon = control:GetNamedChild("Icon")
  if traitIndex then
    TC.AddAltNeedIcon(icon, researchLine.craftingType, researchLineIndex, traitIndex, RIGHT, RIGHT, 180, "iconId")
  end
  TC.hookLock = setupNoop
end

local function addSmithingHook()
  ZO_PreHook(SMITHING, "SetupTraitDisplay", TC.hookLock)
end

local function OnCraftingInteract(eventCode, craftingType)
  if next(TC.AV.allCrafterIds) then
    if TC.AV.allCrafters[craftingType] == currentlyLoggedInCharId then
      TC.hookLock = setupTraitDisplayCallback
      ZO_PreHook(SMITHING, "ShowTraitsFor", function(self, data)
        researchLineIndex = data.researchLineIndex
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

function TraitCraft:GetTraitStringFromKey(key)
  traitIndex = key % 10000 % 100
  researchLineIndex = (key % 10000 - traitIndex) / 100
  craftingSkillType = (key - traitIndex - (researchLineIndex * 100)) / 10000
  local craftingName = GetCraftingSkillName(craftingSkillType)
  local researchLineName = GetSmithingResearchLineInfo(craftingSkillType,researchLineIndex)
  local traitType, _, known = GetSmithingResearchLineTraitInfo(craftingSkillType,researchLineIndex, traitIndex)
  local traitName = GetString("SI_ITEMTRAITTYPE", traitType)
	return researchLineName..": "..traitName
end

EVENT_MANAGER:RegisterForEvent(TC.Name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
EVENT_MANAGER:RegisterForEvent("TC_PLAYER_ACTIVATED", EVENT_PLAYER_ACTIVATED, TC_Event_Player_Activated)
EVENT_MANAGER:RegisterForEvent(TC.name, EVENT_CRAFTING_STATION_INTERACT, OnCraftingInteract)
