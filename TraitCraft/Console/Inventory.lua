TC_Inventory = ZO_Object:Subclass()

local researchableTraits = {
	[ITEM_TRAIT_TYPE_WEAPON_POWERED] = 23203, --Chysolite
	[ITEM_TRAIT_TYPE_WEAPON_CHARGED] = 23204, --Amethyst
	[ITEM_TRAIT_TYPE_WEAPON_PRECISE] = 4486, --Ruby
	[ITEM_TRAIT_TYPE_WEAPON_INFUSED] = 810, --Jade
	[ITEM_TRAIT_TYPE_WEAPON_DEFENDING] = 813, --Turquoise
	[ITEM_TRAIT_TYPE_WEAPON_TRAINING] = 23165, --Carnelian
	[ITEM_TRAIT_TYPE_WEAPON_SHARPENED] = 23149, --Fire Opal
	[ITEM_TRAIT_TYPE_WEAPON_DECISIVE] = 16291, --Citrine
	[ITEM_TRAIT_TYPE_WEAPON_NIRNHONED] = 56863, --Potent Nirncrux
	[ITEM_TRAIT_TYPE_ARMOR_STURDY] = 4456, --Quartz
	[ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE] = 23219, --Diamond
	[ITEM_TRAIT_TYPE_ARMOR_REINFORCED] = 30221, --Sardonyx
	[ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED] = 23221, --Almandine
	[ITEM_TRAIT_TYPE_ARMOR_TRAINING] = 4442, --Emerald
	[ITEM_TRAIT_TYPE_ARMOR_INFUSED] = 30219, --Bloodstone
	[ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS] = 23171, --Garnet
	[ITEM_TRAIT_TYPE_ARMOR_DIVINES] = 23173, --Sapphire
	[ITEM_TRAIT_TYPE_ARMOR_NIRNHONED] = 56862, --Fortified Nirncrux
	[ITEM_TRAIT_TYPE_JEWELRY_ARCANE] = 135155, --Cobalt
	[ITEM_TRAIT_TYPE_JEWELRY_HEALTHY] = 135156, --Antimony
	[ITEM_TRAIT_TYPE_JEWELRY_ROBUST] = 135157, --Zinc
	[ITEM_TRAIT_TYPE_JEWELRY_TRIUNE] = 139409, --Dawn-Prism
	[ITEM_TRAIT_TYPE_JEWELRY_INFUSED] = 139411, --Aurbic Amber
	[ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE] = 139410, --Titanium
	[ITEM_TRAIT_TYPE_JEWELRY_SWIFT] = 139412, --Gilding Wax
	[ITEM_TRAIT_TYPE_JEWELRY_HARMONY] = 139413, --Dibellium
	[ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY] = 139414 --Slaughterstone
}

function TC_Inventory:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function TC_Inventory:IsWeapon(itemType)
	return (itemType==ITEMTYPE_WEAPON)
end

function TC_Inventory:IsArmour(itemType, equipType)
	--Includes jewellery
	return (itemType==ITEMTYPE_ARMOR and equipType~=EQUIP_TYPE_INVALID and equipType~=EQUIP_TYPE_COSTUME)
end

local function IsBlacksmithWeapon(weaponType)
	return weaponType == WEAPONTYPE_AXE
		or weaponType == WEAPONTYPE_HAMMER
		or weaponType == WEAPONTYPE_SWORD
		or weaponType == WEAPONTYPE_TWO_HANDED_AXE
		or weaponType == WEAPONTYPE_TWO_HANDED_HAMMER
		or weaponType == WEAPONTYPE_TWO_HANDED_SWORD
		or weaponType == WEAPONTYPE_DAGGER
end
local function IsWoodworkingWeapon(weaponType)
	return weaponType == WEAPONTYPE_BOW
		or weaponType == WEAPONTYPE_FIRE_STAFF
		or weaponType == WEAPONTYPE_FROST_STAFF
		or weaponType == WEAPONTYPE_LIGHTNING_STAFF
		or weaponType == WEAPONTYPE_HEALING_STAFF
		or weaponType == WEAPONTYPE_SHIELD
end

function TC_Inventory:ItemToResearchLineIndex(itemType, armorType, weaponType, equipType)
	--Figure out which research index this item is. Hope to find a function to do this
	if itemType == ITEMTYPE_ARMOR then
		if equipType==EQUIP_TYPE_RING then
				return 1
		elseif equipType==EQUIP_TYPE_NECK then
				return 2
		elseif armorType == ARMORTYPE_HEAVY then
			if equipType == EQUIP_TYPE_CHEST then --Cuirass
				return 8
			elseif equipType == EQUIP_TYPE_FEET then --Sabatons
				return 9
			elseif equipType == EQUIP_TYPE_HAND then --Gauntlets
				return 10
			elseif equipType == EQUIP_TYPE_HEAD then --Helm
				return 11
			elseif equipType == EQUIP_TYPE_LEGS then --Greaves
				return 12
			elseif equipType == EQUIP_TYPE_SHOULDERS then --Pauldron
				return 13
			elseif equipType == EQUIP_TYPE_WAIST then --Girdle
				return 14
			end
		elseif armorType == ARMORTYPE_MEDIUM then
			if equipType == EQUIP_TYPE_CHEST then --Jack
				return 8
			elseif equipType == EQUIP_TYPE_FEET then --Boots
				return 9
			elseif equipType == EQUIP_TYPE_HAND then --Bracers
				return 10
			elseif equipType == EQUIP_TYPE_HEAD then --Helmet
				return 11
			elseif equipType == EQUIP_TYPE_LEGS then --Guards
				return 12
			elseif equipType == EQUIP_TYPE_SHOULDERS then --Arm Cops
				return 13
			elseif equipType == EQUIP_TYPE_WAIST then --Belt
				return 14
			end
		elseif armorType == ARMORTYPE_LIGHT then
			if equipType == EQUIP_TYPE_CHEST then --Robe+Shirt = Robe & Jerkin
				return 1
			elseif equipType == EQUIP_TYPE_FEET then --Shoes
				return 2
			elseif equipType == EQUIP_TYPE_HAND then --Gloves
				return 3
			elseif equipType == EQUIP_TYPE_HEAD then --Hat
				return 4
			elseif equipType == EQUIP_TYPE_LEGS then --Breeches
				return 5
			elseif equipType == EQUIP_TYPE_SHOULDERS then --Epaulets
				return 6
			elseif equipType == EQUIP_TYPE_WAIST then --Sash
				return 7
			end
		end
	elseif itemType == ITEMTYPE_WEAPON then
		if weaponType == WEAPONTYPE_AXE then
			return 1
		elseif weaponType == WEAPONTYPE_HAMMER then
			return 2
		elseif weaponType == WEAPONTYPE_SWORD then
			return 3
		elseif weaponType == WEAPONTYPE_TWO_HANDED_AXE then
			return 4
		elseif weaponType == WEAPONTYPE_TWO_HANDED_HAMMER then
			return 5
		elseif weaponType == WEAPONTYPE_TWO_HANDED_SWORD then
			return 6
		elseif weaponType == WEAPONTYPE_DAGGER then
			return 7
		elseif weaponType == WEAPONTYPE_BOW then
			return 1
		elseif weaponType == WEAPONTYPE_FIRE_STAFF then
			return 2
		elseif weaponType == WEAPONTYPE_FROST_STAFF then
			return 3
		elseif weaponType == WEAPONTYPE_LIGHTNING_STAFF then
			return 4
		elseif weaponType == WEAPONTYPE_HEALING_STAFF then
			return 5
		elseif weaponType == WEAPONTYPE_SHIELD then
			return 6
		end
	end
	return nil
end

function TC_Inventory:LinkToCraftingSkillType(itemLink)
	local itemType = GetItemLinkItemType(itemLink)
	if itemType==ITEMTYPE_ARMOR then
		local equipType = GetItemLinkEquipType(itemLink)
		if equipType==EQUIP_TYPE_RING or equipType==EQUIP_TYPE_NECK then
			return CRAFTING_TYPE_JEWELRYCRAFTING
		else
			local armorType = GetItemLinkArmorType(itemLink)
			if armorType==ARMORTYPE_HEAVY then
				return CRAFTING_TYPE_BLACKSMITHING
			elseif armorType==ARMORTYPE_MEDIUM or armorType==ARMORTYPE_LIGHT then
				return CRAFTING_TYPE_CLOTHIER
			end
		end
	elseif itemType==ITEMTYPE_WEAPON then
		local weaponType = GetItemLinkWeaponType(itemLink)
		if IsBlacksmithWeapon(weaponType) then
			return CRAFTING_TYPE_BLACKSMITHING
		elseif IsWoodworkingWeapon(weaponType) then
			return CRAFTING_TYPE_WOODWORKING
		end
	end
	return nil
end

function TC_Inventory:IsResearchableTrait(traitType)
	if not traitType then return false end
	return (researchableTraits[traitType] ~= nil)
end

function TC_Inventory:GetWhoKnows(craftingSkillType, researchLineIndex, traitIndex)
  local know = {}
	local dontKnow = {}
	local key = self.parent:GetTraitKey(craftingSkillType, researchLineIndex, traitIndex)
	local trait = self.parent.AV.traitTable[key] or 0
  for id, value in pairs(self.parent.AV.activelyResearchingCharacters) do
    local mask = self.parent.bitwiseChars[id]
    if self.parent.charBitMissing(trait, mask) then
      dontKnow[#dontKnow+1] = value.name
    else
      know[#know+1] = value.name
    end
  end
  return know, dontKnow
end

function TC_Inventory:formatWhoKnows(kk, dd)
  local formatted = " "
  if kk and #kk>0 then
    local knows = table.concat(kk, ", ")
    formatted = self.parent.Lang.RESEARCHED..": "..knows..".  \r\n"
  end
  if dd and #dd>0 then
    local dontknow = table.concat(dd, ", ")
    formatted = formatted..self.parent.Lang.UNRESEARCHED..": "..dontknow..".\r\n"
  end
  return formatted
end

function TC_Inventory:GetDetails(itemLink)
	local toHide = true
	local col = self.parent.AV.settings.inventory.colours.othersCan
	local r = col.r
	local g = col.g
	local b = col.b
	local kk = {}
	local dd = {}
-- 	if GetItemTraitInformation(dataEntry.bagId, dataEntry.slotIndex) == ITEM_TRAIT_INFORMATION_CAN_BE_RESEARCHED then
-- 		return toHide, r, g, b
-- 	end
	local itemType = GetItemLinkItemType(itemLink)
  local traitType = GetItemLinkTraitInfo(itemLink)
  if self:IsResearchableTrait(traitType) then
    local armorType = GetItemLinkArmorType(itemLink)
    local weaponType = GetItemLinkWeaponType(itemLink)
    local equipType = GetItemLinkEquipType(itemLink)
    local craftingSkillType = self:LinkToCraftingSkillType(itemLink)
    local researchLineIndex = self:ItemToResearchLineIndex(itemType, armorType, weaponType, equipType)
    local traitIndex = self.parent:FindTraitIndex(craftingSkillType, researchLineIndex, traitType)
    if craftingSkillType and researchLineIndex and traitIndex then
      if craftingSkillType>0 and researchLineIndex>0 and traitIndex>0 then
        kk, dd = self:GetWhoKnows(craftingSkillType, researchLineIndex, traitIndex)
        toHide = (#dd==0)
      end
    end
  end
	return toHide, kk, dd, r, g, b
end

function TC_Inventory:HookInventory(parent, bagId, slotIndex)
  local scenes = {
    ['gamepad_inventory_root'] = 0,
    ['gamepad_banking'] = 2,
    ['universalDeconstructionSceneGamepad'] = 2,
    ['gamepad_smithing_deconstruct'] = 2,
    ['gamepad_guild_bank'] = 2,
  }
  local currentScene = SCENE_MANAGER:GetCurrentSceneName()
  if not scenes[currentScene] or scenes[currentScene] ~= bagId then return end

  local currentTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
  if not currentTooltip then return end


  local currentBodySection = currentTooltip:GetStyle("bodySection")
  local currentBodyDescription = currentTooltip:GetStyle("bodyDescription")
  local currentDividerLine = currentTooltip:GetStyle("dividerLine")
  local currentSection = currentTooltip:AcquireSection(currentBodySection)

  local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
  local itemType = GetItemType(bagId, slotIndex)
  local equipType = GetItemLinkEquipType(itemLink)
  if itemLink and self:IsWeapon(itemType) or self:IsArmour(itemType, equipType) then
    local toHide, kk, dd, r, g, b = self:GetDetails(itemLink)
    currentSection:AddLine(self:formatWhoKnows(kk, dd), currentBodyDescription)
    currentTooltip:AddSection(currentSection)
  end
end

function TC_Inventory:setHookOnInventoryOpen()
  local origSelf = self
  SecurePostHook(ZO_Tooltip, "LayoutBagItem", function(self, bagId, slotIndex)
    origSelf:HookInventory(self, bagId, slotIndex)
  end)
end

function TC_Inventory:Initialize(parent)
  self.parent = parent
	self.inventories = {
		bag = {
			list = ZO_PlayerInventoryList,
			showKey = "bag",
			invKey = INVENTORY_BACKPACK,
		},
		bank = {
			list = ZO_PlayerBankBackpack,
			showKey = "bank",
			invKey = INVENTORY_BANK
		},
		guild = {
			list = ZO_GuildBankBackpack,
			showKey = "guild",
			invKey = INVENTORY_GUILD_BANK
		},
		deconstruction = {
			list = ZO_GamepadSmithingExtraction,
			showKey = "crafting",
			invKey = nil
		},
		improvement = {
			list = ZO_InventoryItemImprovement_Gamepad,
			showKey = "crafting",
			invKey = nil
		},
		assistant = {
			list = ZO_UniversalDeconstruction_Gamepad,
			showKey = "crafting",
			invKey = nil
		},
	}
	self:setHookOnInventoryOpen()
end
