TC_Requestor = ZO_Object:Subclass()

local TCR = TC_Requestor

TCR.lastRequested = {}

local CRAFT_TOKEN = {
  [CRAFTING_TYPE_BLACKSMITHING]       = "BS",
  [CRAFTING_TYPE_CLOTHIER]            = "CL",
  [CRAFTING_TYPE_WOODWORKING]         = "WW",
  [CRAFTING_TYPE_JEWELRYCRAFTING]     = "JW"
}

function TCR:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function TCR:ScanUnknownTraitsForRequesting(parent)
  local charId = GetCurrentCharacterId()
  local craftTypes = { BLACKSMITH, CLOTHIER, WOODWORK, JEWELRY_CRAFTING }
  if not self.lastRequested[charId] then
    self.lastRequested[charId] = {}
  end
  local itemDescriptions = "|r\r\n  "
  local sendObject = {}
  for i = 1, #craftTypes do
    local craftingType = craftTypes[i]
    if not self.lastRequested[charId][craftingType] then
      self.lastRequested[charId][craftingType] = {}
    end
    parent:ScanUnknownTraitsForCrafting(charId, craftingType, function(scanResults)
      local record = {}
      for rIndex, tIndex in pairs(scanResults[craftingType]) do
        if self.lastRequested[charId][craftingType][rIndex] == nil or not self.lastRequested[charId][craftingType][rIndex][tIndex] then
          record = { rIndex, tIndex }
        end
      end
      sendObject[#sendObject + 1] = { CRAFT_TOKEN[craftingType], record }
    end, self.lastRequested)
  end
  return sendObject
end

function TCR:Initialize(parent)
  if not LibDynamicMail then return true end
  self.parent = parent
end
