TC_Requestor = ZO_Object:Subclass()

local TCR = TC_Requestor

TCR.protocol = {
  SUBJECT = "TRAITCRAFT:RESEARCH:V1",
  PROTO   = "traitcraft",
  VERSION = 1,
}

TCR.lastRequested = {}
local requestBody = {}

local MailSend = MAIL_SEND

if IsConsoleUI() or IsInGamepadPreferredMode() then
 MailSend = ZO_MailSend_Gamepad
end

local theMail = MAIL_SEND

if IsConsoleUI() or IsInGamepadPreferredMode() then
 theMail = MAIL_GAMEPAD
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

function TCR:BuildMail(rBody)
  -- requestBody example:
  -- {
  --   [CRAFTING_TYPE_BLACKSMITHING] = {
  --     itemType   = rIndex,
  --     traitIndex = tIndex,
  --   },
  -- }
  local items = {}
  local parts = {
    "proto=" .. TCR.protocol.PROTO,
    "ver="   .. TCR.protocol.VERSION,
  }

  for craftingType, data in pairs(rBody) do
    local token = CRAFT_TOKEN[craftingType]

    if token and data.itemType and data.traitIndex then
      items[#items + 1] = table.concat({
        token,
        tostring(data.itemType),
        tostring(data.traitIndex),
      }, "|")
    end
  end

  parts[#parts + 1] = "items=" .. table.concat(items, ";")
  return table.concat(parts, "\n")
end

function TCR:ScanUnknownTraitsForRequesting(parent)
  local charId = GetCurrentCharacterId()
  local craftTypes = { BLACKSMITH, CLOTHIER, WOODWORK, JEWELRY_CRAFTING }
  if not self.lastRequested[charId] then
    self.lastRequested[charId] = {}
  end
  local itemDescriptions = "|r\r\n  "
  for i = 1, #craftTypes do
    local craftingType = craftTypes[i]
    if not self.lastRequested[charId][craftingType] then
      self.lastRequested[charId][craftingType] = {}
    end
    parent:ScanUnknownTraitsForCrafting(charId, craftingType, function(scanResults)
      for rIndex, tIndex in pairs(scanResults[craftingType]) do
        if self.lastRequested[charId][craftingType][rIndex] == nil or not self.lastRequested[charId][craftingType][rIndex][tIndex] then
          requestBody[craftingType] = { itemType = rIndex, traitIndex = tIndex }
          itemDescriptions = itemDescriptions..parent:GetItemString(craftingType, rIndex, tIndex).."|r\r\n  "
        end
      end
    end, self.lastRequested)
  end
  return requestBody, itemDescriptions
end

function TCR:prepareRequest(parent)
  local request, items = self:ScanUnknownTraitsForRequesting(parent)
  local body = self:BuildMail(request)
  MailSend:ComposeMailTo(parent.AV.settings.crafterRequestee, TCR.protocol.SUBJECT)
  MailSend:InsertBodyText(body)
  requestBody = {}
  ZO_GamepadGenericHeader_SetActiveTabIndex(theMail.header, 1)
  zo_callLater(function()
    ZO_GamepadGenericHeader_SetActiveTabIndex(theMail.header, 2)
  end, 10)
  d(parent.Lang.SENT_MAIL.." "..parent.AV.settings.crafterRequestee.." "..parent.Lang.WITH_CRAFTING_REQUEST..items)
end

function TCR:AddPrepareButtonGamepad()
  self.autopopulateBtn = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
      {
        name = self.parent.Lang.AUTOFILL_REQUEST,
        keybind = "UI_SHORTCUT_QUATERNARY",
        order = 2500,
        callback = function()
          TCR:prepareRequest(self.parent)
        end
      },
    }
  KEYBIND_STRIP:AddKeybindButtonGroup(self.autopopulateBtn)
  self.showing = true
end

function TCR:AddPrepareButtonKeyboard()
  local mail_scene = SCENE_MANAGER:GetScene("mailbox")
  local allBtnParent = GetControl("TC_ALL_CTL")
  local prepareBtn = CreateControl(nil, allBtnParent, CT_BUTTON)
  prepareBtn:SetText(self.parent.Lang.AUTOFILL_REQUEST)
  prepareBtn:SetFont(font)
  prepareBtn:SetDimensions( 100 , 50 )
  prepareBtn:SetNormalTexture("EsoUI/Art/Buttons/ESO_buttonLarge_normal.dds")
  prepareBtn:SetPressedTexture("EsoUI/Art/Buttons/ESO_buttonlLarge_mouseDown.dds")
  prepareBtn:SetMouseOverTexture("EsoUI/Art/Buttons/ESO_buttonLarge_mouseOver.dds")
  prepareBtn:SetDisabledTexture("EsoUI/Art/Buttons/ESO_buttonLarge_disabled.dds")
  prepareBtn:SetAnchor(BOTTOM, nil, BOTTOM, 100, 0)
  prepareBtn:SetHandler("OnClicked", function()
    TCR:prepareRequest(self.parent)
  end)
  self.allFragment = ZO_SimpleSceneFragment:New(prepareBtn)
  mail_scene:AddFragment(self.allFragment)
  self.showing = true
end

function TCR:RemoveGamepadUI()
  KEYBIND_STRIP:RemoveKeybindButtonGroup(self.autopopulateBtn)
  self.showing = false
end

function TCR:RemoveKeyboardUI()
  local mail_scene = SCENE_MANAGER:GetScene("mailbox")
  if self.allFragment then
    mail_scene:RemoveFragment(self.allFragment)
  end
  if self.altFragment then
    mail_scene:RemoveFragment(self.altFragment)
  end
end

function TCR:Initialize(parent)
  self.parent = parent
  if parent.AV.settings.requestOption then
    SecurePostHook(MailSend, "SwitchToSendTab", function()
      if IsConsoleUI() or IsInGamepadPreferredMode() then
        self:AddPrepareButtonGamepad()
      else
        self:AddPrepareButtonKeyboard()
      end
    end)
    SecurePostHook(MailSend, "OnHidden", function()
      if IsConsoleUI() or IsInGamepadPreferredMode() then
        self:RemoveGamepadUI()
      else
        self:RemoveKeyboardUI()
      end
    end)
  end
end
