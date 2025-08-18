local TC = TraitCraft

local SMITHING = ZO_SmithingCreation

if IsInGamepadPreferredMode() then
  SMITHING = ZO_GamepadSmithingCreation
end

local function findTraitIndex(craftingSkillType, researchLineIndex, traitType)
	--Trying not to hard code the trait type indexes
	local _, _, numTraits, _ = GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)
	for traitIndex = 1, numTraits do
		local foundTraitType, _, _ = GetSmithingResearchLineTraitInfo(craftingSkillType, researchLineIndex, traitIndex)
		if foundTraitType == traitType then
			return traitIndex
		end
	end
	return ITEM_TRAIT_TYPE_NONE
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
          local traitIndex = findTraitIndex(craftingType, data.patternIndex, datalist.traitType)
          if icon and traitIndex and datalist.traitType ~= 0 then
            TC.AddAltNeedIcon(icon, craftingType, data.patternIndex, traitIndex, TOP, BOTTOM, 10, "craftId")
          end
        end)
      end)
    end
  end
end


EVENT_MANAGER:RegisterForEvent("TC_SmithingCreation", EVENT_CRAFTING_STATION_INTERACT, OnSmithingCreation)
