TC_Requestor = ZO_Object:Subclass()

local TCR = TC_Requestor

TCR.protocol = {
  SUBJECT = "TRAITCRAFT:RESEARCH:V1",
  PROTO   = "traitcraft",
  VERSION = 1,
}

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
  for i = 1, #craftTypes do
    local craftingType = craftTypes[i]
    self.parent:ScanUnknownTraitsForCrafting(charId, craftingType, function(scanResults)
      for rIndex, entry in pairs(scanResults[craftingType]) do
        for tIndex, obj in pairs(entry[rIndex]) do
          requestBody[craftingType] = { itemType = rIndex, traitIndex = tIndex }
        end
      end
    end, nil)
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

function TCR.Parse(body)
  local data = {}

  for line in body:gmatch("[^\r\n]+") do
    local k, v = line:match("^(%w+)%=(.+)$")
    if k and v then
      data[k] = v
    end
  end

  -- Validate
  if data.proto ~= TCR.protocol.PROTO then return nil end
  if tonumber(data.ver) ~= TCR.protocol.VERSION then return nil end

  -- Parse items
  data.items = {}
  if data.items then end -- placeholder

  local itemList = Split(data.items or "", ";")
  for _, entry in ipairs(itemList) do
    local fields = Split(entry, "|")
    if #fields == 3 then
      data.items[#data.items + 1] = {
        craft   = fields[1],
        pattern = fields[2],
        trait   = fields[3],
      }
    end
  end

  return data
end

function TCR.receiveMail()
  -- send to autocrafting


--   local subject, body = GetMailItemInfo(i)
--
--   if TCR.IsRequest(subject, body) then
--     if CraftQueue:IsEmpty() then
--       RequestReadMail(i)
--       local parsed = TCR.Parse(body)
--       if parsed then
--         QueueItems(parsed.items)
--       end
--     else
--       d("TraitCraft: Active research job in progress.")
--     end
--   end
end

function TCR:Initialize(parent)
  self.parent = parent
  self:setupRequestor()
end


