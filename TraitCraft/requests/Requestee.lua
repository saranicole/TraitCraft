TC_Requestee = ZO_Object:Subclass()

-- Note that this code is heavily inspired by Dolgubons MailHandler.lua in LazyWritCreator!  Thank you!

local TCR = TC_Requestee
local LLC = LibLazyCrafting

TCR.protocol = {
  SUBJECT = "TRAITCRAFT:RESEARCH:V1",
  PROTO   = "traitcraft",
  VERSION = 1,
}

TCR.lastRequested = {}

local requesteeMails = {}

local MailInbox = MAIL_INBOX

if IsConsoleUI() or IsInGamepadPreferredMode() then
 MailInbox = ZO_MailInbox_Gamepad
end

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

local CRAFT_TOKEN_REVERSE = {
  ["BS"]         = BLACKSMITH,
  ["CL"]         = CLOTHIER,
  ["WW"]         = WOODWORK,
  ["JW"]         = JEWELRY_CRAFTING,
}

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

function TCR.IsRequest(subject)
  if subject ~= TCR.protocol.SUBJECT then return false end
  return true
end

function TCR.NormalizeAccountName(account)
    if not account then return nil end
    account = tostring(account)
    if account:sub(1,1) ~= "@" then
        account = "@" .. account
    end
    return account
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

  local itemList = Split(data.items or "", ";")
  data.itemList = {}

  for ind, entry in ipairs(itemList) do
    local fields = Split(entry, "|")
    if #fields == 3 then
       data.itemList[#data.itemList + 1] = {
        craftingType   = CRAFT_TOKEN_REVERSE[fields[1]],
        researchIndex  = fields[2],
        traitIndex     = fields[3]
      }
    end
  end
  return data
end

local function findTraitType(craftingSkillType, researchLineIndex, traitIndex)
  local foundTraitType, description, _ = GetSmithingResearchLineTraitInfo(craftingSkillType, researchLineIndex, traitIndex)
	return foundTraitType or ITEM_TRAIT_TYPE_NONE
end

function TCR:QueueItems(item)
  local patternIndex = self.parent.autocraft:GetPatternIndexFromResearchLine(item.craftingType, item.researchIndex)
  local traitType = findTraitType(item.craftingType, item.researchIndex, item.traitIndex)
  traitType = traitType + 1
  local request = self.interactionTable:CraftSmithingItemByLevel(patternIndex, false, 1, LLC_FREE_STYLE_CHOICE, traitType, false, item.craftingType, 0, 0, false)
  if LLC.craftInteractionTables[craftingType]:isItemCraftable(item.craftingType, request) then
    self.interactionTable:craftItem(item.craftingType)
    self.lastRequested[item.craftingType][item.researchIndex][item.traitIndex] = true
  end
end

local function accessMail()
	if #requesteeMails == 0 then
		return
	else
		local mailId = requesteeMails[1]
		-- d(mailId)
		currentWorkingMail = mailId
		local requestResult = RequestReadMail(mailId)
		if requestResult and requestResult <= REQUEST_READ_MAIL_RESULT_SUCCESS_SERVER_REQUESTED then
		end
		zo_callLater(function()

				if currentWorkingMail == mailId and not IsReadMailInfoReady(mailId) then
					RequestReadMail(mailId)
				end
			end, math.max(GetLatency()+10, 100))
	end
end

function TCR.processMail(event, mailId)
  if not IsReadMailInfoReady(mailId) then
		-- d("Stop")
		zo_callLater(function() accessMail() end , 10 )
		return
	end
	local mailData = MailInbox:GetActiveMailData()

  if TCR.IsRequest(mailData.subject) then
    if LLC[self.parent.Name.."TCR"].craftingQueue == nil or next(LLC[self.parent.Name.."TCR"].craftingQueue) == nil then
      local parsed = TCR.Parse(mailData:GetReceivedText())
      if parsed then
        for k, item in pairs(parsed.itemList) do
          TCR.QueueItems(item)
        end
      end
    else
      d("TraitCraft: Active research job in progress.")
    end
  end
end

function TCR.receiveMail()
  local nextMail = GetNextMailId(nil)
	if not nextMail then
	 	EVENT_MANAGER:UnregisterForEvent(TCR.parent.Name.."mailbox", EVENT_MAIL_READABLE)
	 	return
	end

  while nextMail do
		local  _,_,subject, _,_,system,customer, _, numAtt, money = GetMailItemInfo (nextMail)
    if TCR.IsRequest(mailData.subject) then
      table.insert(requesteeMails,  nextMail)
    end
		nextMail = GetNextMailId(nextMail)
	end

  if #requesteeMails > 0 then
    zo_callLater(accessMail, 10)
  else
    EVENT_MANAGER:UnregisterForEvent(TCR.parent.Name.."mailbox", EVENT_MAIL_READABLE)
  end
end

function TCR.checkMail()
	EVENT_MANAGER:RegisterForEvent(TCR.parent.Name.."mailbox", EVENT_MAIL_READABLE, TCR.receiveMail)
end

function TCR:Initialize(parent)
  self.parent = parent
  if not LibLazyCrafting then
    return
  end
  local styles = parent:GetCommonStyles()
  self.interactionTable = LLC:AddRequestingAddon(parent.Name.."TCR", false, function (event, craftingType, requestTable)
      if not LLC_NO_FURTHER_CRAFT_POSSIBLE then
      d(event)
    end
    return
  end, parent.Author, styles)
  EVENT_MANAGER:RegisterForEvent(parent.Name.."mailbox", EVENT_MAIL_OPEN_MAILBOX , self.checkMail)
end
