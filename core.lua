local addonName, addon = ...
addon.cleu = CreateFrame("Frame")
addon.cleu:SetScript("OnEvent",function(self,event,...)
  return addon.ParseCombat(addon,...)
end)
addon.events = CreateFrame("Frame")
addon.OnEvents = function(self,event,...)
  return addon[event] and addon[event](addon,event,...)
end
addon.events:SetScript("OnEvent", addon.OnEvents)
addon.events:RegisterEvent("ADDON_LOADED")
addon.events:RegisterEvent("PLAYER_LOGIN")
addon.events:RegisterEvent("PLAYER_LOGOUT")

local After, Ticker, IsEventValid = C_Timer.After, C_Timer.NewTicker, C_EventUtils.IsEventValid
local GetBestMapForUnit,GetMapInfo = C_Map.GetBestMapForUnit ,C_Map.GetMapInfo
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
local GetAuraDataByIndex = C_UnitAuras.GetAuraDataByIndex
local ADDON_LABEL = CreateTextureMarkup(775462, 32, 32, 16, 16, 0, 1, 0, 1).."|cff00FF98"..addonName.."|r"..CreateTextureMarkup(134414, 32, 32, 16, 16, 0, 1, 0, 1)
local TIP_LEFT = CreateTextureMarkup(775462, 32, 32, 16, 16, 0, 1, 0, 1)
local MONKID, ZEN_ID, ZENRET_ID, ZENRET_BUFF = 10, 126892, 126895, 126896
local ZEN_SPELL = C_Spell.GetSpellName(ZENRET_ID)
local colorMonk = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)["MONK"] or GREEN_FONT_COLOR

local defaults = {
  zone = UNKNOWN
}
local defaultsAccount = {
  spell = true,
  buff = true,
}

_, addon.playerClassId = UnitClassBase("player")
addon.playerGUID = UnitGUID("player")

local function wrapTuple(...)
  return {...}
end

local function table_count(t)
  local count = 0
  for k,v in pairs(t) do
    count = count + 1
  end
  return count
end

local timeFormatter = CreateFromMixins(SecondsFormatterMixin)
timeFormatter:Init(0,SecondsFormatter.Abbreviation.OneLetter,true,true)
timeFormatter:SetStripIntervalWhitespace(true)

local function formatDelta(delta)
  local timeStr = timeFormatter:Format(delta)
  local coloredCD
  if delta <= 210 then -- less than 3.5mins red
    coloredCD = RED_FONT_COLOR:WrapTextInColorCode(timeStr)
  elseif delta <= 480 then -- less than 8mins yellow
    coloredCD = YELLOW_FONT_COLOR:WrapTextInColorCode(timeStr)
  elseif delta <= 600 then -- Less than 10mins green
    coloredCD = GREEN_FONT_COLOR:WrapTextInColorCode(timeStr)
  else
    coloredCD = GRAY_FONT_COLOR:WrapTextInColorCode(_G.UNKNOWN)
  end
  return coloredCD
end

local function addToSpellTooltip(self,data)
  local optg, opt = ZenReturn_DB, ZenReturn_DBPC
  if not optg.spell then return end
  local self = self or GameTooltip
  local _, spell = self:GetSpell()
  if spell and (spell == ZENRET_ID) then
    if opt.zone and opt.zone ~= UNKNOWN then
      local r,g,b = colorMonk:GetRGB()
      self:AddDoubleLine(TIP_LEFT,opt.zone,nil,nil,nil,r,g,b,false)
      self:Show()
    end
  end
end

local function addToBuffTooltip(self,...)
  local unit,slot,auratype = ...
  if not unit == "player" then return end
  local optg, opt = ZenReturn_DB, ZenReturn_DBPC
  if not optg.buff then return end
  local auraInfo = GetAuraDataByIndex(unit,slot,auratype)
  if auraInfo and auraInfo.spellId == ZENRET_BUFF then
    if opt.zone and opt.zone ~= UNKNOWN then
      local r,g,b = colorMonk:GetRGB()
      self:AddDoubleLine(TIP_LEFT,opt.zone,nil,nil,nil,r,g,b,false)
      self:Show()
    end
  end
end

function addon.OnSettingChanged(setting,value)

end

function addon:createSettings()
  addon._category = Settings.RegisterVerticalLayoutCategory(addonName)
  local variableTable = ZenReturn_DB
  do
    local name = "Modify Buff Tooltip"
    local variable = "buff"
    local variableKey = "buff"
    local defaultValue = true
    local setting = Settings.RegisterAddOnSetting(addon._category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue)
    setting:SetValueChangedCallback(addon.OnSettingChanged)
    local tooltip = "Add temp bind location to the "..ZEN_SPELL.." Buff Tooltip"
    Settings.CreateCheckbox(addon._category, setting, tooltip)
  end

  do
    local name = "Modify Spell Tooltip"
    local variable = "spell"
    local variableKey = "spell"
    local defaultValue = true
    local setting = Settings.RegisterAddOnSetting(addon._category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue)
    setting:SetValueChangedCallback(addon.OnSettingChanged)
    local tooltip = "Add temp bind location to the "..ZEN_SPELL.." Spell Tooltip"
    Settings.CreateCheckbox(addon._category, setting, tooltip)
  end

  Settings.RegisterAddOnCategory(addon._category)
end

function addon:Print(msg,useLabel)
  local chatFrame = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
  if useLabel then
    msg = string.format("%s: %s",ADDON_LABEL,msg)
  end
  chatFrame:AddMessage(msg)
end

function addon:ADDON_LOADED(_,...)
  if ... == addonName then
    if self.playerClassId ~= MONKID then
      After(5,function()
        self:Print("You're not a Monk Harry!. "..addonName.." Disabled ;)",true)
      end)
      C_AddOns.DisableAddOn(addonName,self.playerGUID)
      return
    end
    After(15,function()
      self:Print("/"..string.lower(addonName).." (for help)",true)
    end)
    ZenReturn_DBPC = ZenReturn_DBPC or CopyTable(defaults)
    for k,v in pairs(defaults) do
      if ZenReturn_DBPC[k] == nil then
        ZenReturn_DBPC[k] = v
      end
    end
    ZenReturn_DB = ZenReturn_DB or CopyTable(defaultsAccount)
    for k,v in pairs(defaultsAccount) do
      if ZenReturn_DB[k] == nil then
        ZenReturn_DB[k] = v
      end
    end
    self:createSettings()
  end
end

function addon:PLAYER_LOGIN(_,...)
  addon.characterID = string.format("%s-%s",(UnitNameUnmodified("player")),GetNormalizedRealmName())
  if IsPlayerSpell(ZEN_ID) then
    self.cleu:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    if GameTooltip:HasScript("OnTooltipSetSpell") then
      GameTooltip:HookScript("OnTooltipSetSpell",addToSpellTooltip)
    end
    if GameTooltip.SetUnitAura then
      hooksecurefunc(GameTooltip,"SetUnitAura",addToBuffTooltip)
    end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
      TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell,addToSpellTooltip)
      TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura,addToBuffTooltip)
    end
  else
    if IsEventValid("LEARNED_SPELL_IN_TAB") then
      self.events:RegisterEvent("LEARNED_SPELL_IN_TAB")
    end
    if IsEventValid("LEARNED_SPELL_IN_SKILL_LINE") then
      self.events:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
    end
    return
  end
end

function addon:PLAYER_LOGOUT(_,...)

end

function addon:LEARNED_SPELL_IN_TAB(event,...)
  local spellID, spellIndex, spellGuildPerk = ...
  if spellID == ZEN_ID then
    self.events:UnregisterEvent(event)
    self:PLAYER_LOGIN("PLAYER_LOGIN")
  end
end
addon.LEARNED_SPELL_IN_SKILL_LINE = addon.LEARNED_SPELL_IN_TAB

function addon:ParseCombat(...)
  local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21, arg22, arg23, arg24  = CombatLogGetCurrentEventInfo()
  if addon.playerGUID ~= sourceGUID then return end
  if subevent ~= "SPELL_CAST_SUCCESS" then return end
  local spellID = arg12
  if spellID ~= ZEN_ID then return end
  local mapID = GetBestMapForUnit("player")
  local zoneInfo = GetMapInfo(mapID)
  local parentZone = zoneInfo and zoneInfo.parentMapID
  local parentZoneInfo = GetMapInfo(parentZone)
  local zone = format("%s: %s",parentZoneInfo and parentZoneInfo.name or UNKNOWN,zoneInfo and zoneInfo.name or UNKNOWN)
  ZenReturn_DBPC.zone = zone
end

local addonNameU, addonNameL = addonName:upper(), addonName:lower()
SlashCmdList[addonNameU] = function(msg, input)
  local option = {}
  msg = (msg or ""):trim()
  msg = msg:lower()
  for token in msg:gmatch("(%S+)") do
    tinsert(option,token)
  end
  if (not msg) or (msg == "") or (msg == "?") then
    addon:Print("Commands",true)
    addon:Print("/"..addonNameL.." options")
    addon:Print("    opens configuration")
    return
  end
  local cmd = option[1]
  if cmd == "options" or cmd == "opt" then
    Settings.OpenToCategory(addon._category:GetID())
  end
end
_G["SLASH_"..addonNameU.."1"] = "/"..addonNameL
--_G[addonName] = addon