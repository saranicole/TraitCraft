TC_Requestor = ZO_Object:Subclass()

local TCR = TC_Requestor

TCR.protocol = {
  SUBJECT = "TRAITCRAFT:RESEARCH:V1",
  PROTO   = "traitcraft",
  VERSION = 1,
}

TCR.lastRequested = {}

local BLACKSMITH 		= CRAFTING_TYPE_BLACKSMITHING
local CLOTHIER 			= CRAFTING_TYPE_CLOTHIER
local WOODWORK 			= CRAFTING_TYPE_WOODWORKING
local JEWELRY_CRAFTING 	= CRAFTING_TYPE_JEWELRYCRAFTING

local CRAFT_TOKEN = {
  [BLACKSMITH]       = "BS",
  [CLOTHIER]         = "CL",
  [WOODWORK]         = "WW",
  [JEWELRY_CRAFTING] = "JW",
}

TCR.requestBody = {}
local requestBody = TCR.requestBody

local function Split(str, delim)
  local result = {}
  for match in string.gmatch(str, "([^" .. delim .. "]+)") do
    result[#result + 1] = match
  end
  return result
end

function TCR:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function TCR.IsRequest(subject, body)
  if subject ~= TCR.protocol.SUBJECT then return false end
  if not body then return false end
  return body:find("proto=" .. TCR.protocol.PROTO, 1, true) ~= nil
end

function TCR.BuildMail(requestBody)
  -- requestBody example:
  -- {
  --   [CRAFTING_TYPE_BLACKSMITHING] = {
  --     itemType   = rIndex,
  --     traitIndex = tIndex,
  --   },
  -- }

  local items = {}
  local parts = {
    "proto=" .. TCR.PROTO,
    "ver="   .. TCR.VERSION,
    "from="  .. fromAccount,
    "char="  .. fromChar,
  }

  for craftingType, data in pairs(requestBody) do
    local token = CRAFT_TOKEN[craftingType]

    if token and data.itemType and data.traitIndex then
      items[#items + 1] = table.concat({
        token,
        tostring(data.itemType),
        tostring(data.traitIndex),
      }, "|")
    end
  end

  parts[#parts + 1] = "items=" .. table.concat(itemStrings, ";")
  return table.concat(parts, "\n")
end

function TCR:ScanUnknownTraitsForRequesting()
  local charId = self.parent.currentlyLoggedInCharId
  local craftTypes = { BLACKSMITH, CLOTHIER, WOODWORK, JEWELRY_CRAFTING }
  if not TCR.lastRequested[charId] then
    TCR.lastRequested[charId] = {}
  end
  for i = 1, #craftTypes do
    local craftingType = craftTypes[i]
    if not TCR.lastRequested[charId][craftingType] then
      TCR.lastRequested[charId][craftingType] = {}
    end
    self.parent:ScanUnknownTraitsForCrafting(charId, craftingType, function(scanResults)
      d(scanResults)
      for rIndex, entry in pairs(scanResults[craftingType]) do
        for tIndex, obj in pairs(entry[rIndex]) do
          if not TCR.lastRequested[charId][craftingType][rIndex][tIndex] then
            requestBody[craftingType] = { itemType = rIndex, traitIndex = tIndex }
          end
        end
      end
    end, TCR.lastRequested)
  end
  return requestBody
end

function TCR.NormalizeAccountName(account)
    if not account then return nil end
    account = tostring(account)
    if account:sub(1,1) ~= "@" then
        account = "@" .. account
    end
    return account
end

function TCR:SendRequest()
  local request = self:ScanUnknownTraitsForRequesting()
  local body = self.BuildMail(request)
  local recipient = TCR.NormalizeAccountName(self.parent.AV.settings.crafterRequestee)
  SendMail(recipient, TCR.protocol.SUBJECT, body)
end

function TCR:Initialize(parent)
  self.parent = parent
end
