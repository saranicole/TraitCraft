local TC = TraitCraft

local SMITHING = ZO_SmithingCreation

if IsInGamepadPreferredMode() then
  SMITHING = ZO_GamepadSmithingCreation
end

local function findTraitIndex(craftingSkillType, researchLineIndex, traitType)
	local _, _, numTraits, _ = GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)
	for traitIndex = 1, numTraits do
		local foundTraitType, description, _ = GetSmithingResearchLineTraitInfo(craftingSkillType, researchLineIndex, traitIndex)
		if foundTraitType == traitType then
			return traitIndex
		end
	end
	return ITEM_TRAIT_TYPE_NONE
end

local function findResearchLineIndex(craftingSkillType, patternName)
	local numResearchLines = GetNumSmithingResearchLines(craftingSkillType)
	for researchLineIndex = 1, numResearchLines do
		local foundResearchLine, _, _ = GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)
		if foundResearchLine == "Robe & Jerkin" and (patternName == "Robe" or patternName == "Jerkin"  or patternName == "Shirt") then
			return researchLineIndex
		end
		if foundResearchLine == patternName then
			return researchLineIndex
		end
	end
	return nil
end

local function FindLabel(rowControl)
  local child = nil
    for i = 1, rowControl:GetNumChildren() do
      local testchild = rowControl:GetChild(i)
        if testchild:GetType() == CT_LABEL then
            child = testchild
        end
    end
  return child
end

local function OnSmithingCreation(eventCode, craftingType)
  if next(TC.AV.allCrafterIds) then
    if TC.AV.allCrafters[craftingType] == TC.currentlyLoggedInCharId then
      ZO_PostHook(SMITHING, "RefreshTraitList", function(self, data)
        ZO_PostHook(self.traitList, "setupFunction", function(selflist, datalist)
          local icon = FindLabel(selflist:GetParent():GetParent():GetParent())
          local selectedTraitData = self.traitList.selectedData
          if selectedTraitData then
            if icon.iconSetupTraitDone == selectedTraitData.traitType then
              return
            end
            local selectedTrait = selectedTraitData.traitType
            local researchLineIndex = findResearchLineIndex(craftingType, self.patternList.selectedData.patternName)
            local traitIndex = findTraitIndex(craftingType, researchLineIndex, selectedTrait)
            if icon and researchLineIndex and traitIndex and selectedTrait ~= 0 then
              icon.iconSetupTraitDone = selectedTraitData.traitType
              TC.AddAltNeedIcon(icon, craftingType, researchLineIndex, traitIndex, TOP, BOTTOM, 10, "craftId")
            end
          end
        end)
      end)
    end
  end
end


EVENT_MANAGER:RegisterForEvent("TC_SmithingCreation", EVENT_CRAFTING_STATION_INTERACT, OnSmithingCreation)
