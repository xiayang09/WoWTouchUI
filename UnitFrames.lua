local ADDON = ...

local frames = {}
local unitFrameUnits = { player = true, target = true, targettarget = true }
local hiddenFrames = {}

local function HideBlizzardFrame(frame)
  if not frame or hiddenFrames[frame] then return end
  hiddenFrames[frame] = true
  -- A transparent protected button still responds to clicks. A secure
  -- visibility driver keeps it hidden through combat and bar updates.
  RegisterStateDriver(frame, "visibility", "hide")
  frame:Hide()
end

local function HideBlizzardUI()
  if InCombatLockdown() then return end
  HideBlizzardFrame(PlayerFrame)
  HideBlizzardFrame(TargetFrame)
  HideBlizzardFrame(TargetFrameToT)
  HideBlizzardFrame(TargetTargetFrame)
  HideBlizzardFrame(MainActionBar)
  for _, name in ipairs({
    "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "MultiBar5", "MultiBar6", "MultiBar7", "MultiBar8",
    "PetActionBar", "StanceBar", "PossessBar", "OverrideActionBar",
    "ExtraActionBarFrame", "ZoneAbilityFrame",
  }) do
    HideBlizzardFrame(_G[name])
  end
  for i = 1, 12 do
    HideBlizzardFrame(_G["ActionButton" .. i])
    HideBlizzardFrame(_G["PetActionButton" .. i])
    HideBlizzardFrame(_G["StanceButton" .. i])
    HideBlizzardFrame(_G["PossessButton" .. i])
    HideBlizzardFrame(_G["OverrideActionBarButton" .. i])
  end
  HideBlizzardFrame(ExtraActionButton1)
  HideBlizzardFrame(CastingBarFrame)
  HideBlizzardFrame(PetCastingBarFrame)
end

local function CreateCastBar()
  local bar = CreateFrame("StatusBar", ADDON.."CastBar", UIParent)
  bar:SetSize(360, 22)
  bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 76)
  bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
  bar:SetStatusBarColor(.42, .42, .46, .95)
  bar:SetMinMaxValues(0, 1)
  bar:Hide()
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(.02, .02, .025, .65)
  bar.name = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  bar.name:SetPoint("CENTER")
  bar.time = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  bar.time:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
  return bar
end

local castBar
local function UpdateCastBar()
  if not castBar then return end
  local name, _, _, startMS, endMS, _, _, notInterruptible = UnitCastingInfo("player")
  local channel = false
  if not name then name, _, _, startMS, endMS, _, notInterruptible = UnitChannelInfo("player"); channel = true end
  if not name or not startMS or not endMS then castBar:Hide(); return end
  local now = GetTime() * 1000
  local duration = math.max(0.01, (endMS - startMS) / 1000)
  local elapsed = math.max(0, math.min(duration, (now - startMS) / 1000))
  castBar:SetMinMaxValues(0, duration)
  castBar:SetValue(channel and (duration - elapsed) or elapsed)
  castBar.name:SetText(name)
  castBar.time:SetFormattedText("%.1f", channel and (duration - elapsed) or (duration - elapsed))
  castBar:SetStatusBarColor(notInterruptible and .55 or .42, notInterruptible and .55 or .42, notInterruptible and .58 or .46, .95)
  castBar:Show()
end

local function MakeBar(parent, height, color)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetHeight(height)
  bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
  bar:SetStatusBarColor(unpack(color))
  bar:SetMinMaxValues(0, 100)
  bar:SetValue(1)
  local background = bar:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetColorTexture(.07, .07, .08, .9)
  return bar
end

local function UpdateStatus(frame, unit)
  frame.restIcon:SetShown(unit == "player" and IsResting and IsResting())
  frame.pvpIcon:SetShown(UnitIsPVP and UnitIsPVP(unit))
  frame.combatIcon:SetShown(UnitAffectingCombat and UnitAffectingCombat(unit))
  frame.groupIcon:SetShown(unit == "player" and IsInGroup and IsInGroup())
  frame.leaderIcon:SetShown(unit == "player" and UnitIsGroupLeader and UnitIsGroupLeader("player"))
end

local function ClassBorderColor(unit)
  local _, class = UnitClass(unit)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  return c and c.r or .45, c and c.g or .45, c and c.b or .45
end

local function HealthColor(unit)
  local _, class = UnitClass(unit)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  local reaction = UnitReaction(unit, "player")
  if reaction and reaction <= 2 then return .85, .18, .18 end
  if reaction == 3 then return .95, .72, .12 end
  if reaction and reaction >= 4 then return .22, .72, .32 end
  return .34, .52, .36
end

local function SecondaryPowerType(unit)
  if unit ~= "player" then return nil end
  local class = select(2, UnitClass(unit))
  local types = { ROGUE = Enum.PowerType.ComboPoints, DRUID = Enum.PowerType.ComboPoints, PALADIN = Enum.PowerType.HolyPower, WARLOCK = Enum.PowerType.SoulShards, MAGE = Enum.PowerType.ArcaneCharges, MONK = Enum.PowerType.Chi, DEATHKNIGHT = Enum.PowerType.Runes, EVOKER = Enum.PowerType.Essence }
  return types[class]
end
local function CreateUnitFrame(unit)
  local frame = CreateFrame("Button", ADDON .. unit .. "Frame", UIParent, "SecureUnitButtonTemplate")
  frame:SetSize(unit == "targettarget" and 150 or 300, 58)
  frame:SetAttribute("unit", unit)
  frame:SetAttribute("type1", "target")
  frame:SetAttribute("type2", "togglemenu")
  if unit == "player" then frame:SetPoint("TOPLEFT", UIParent, "TOP", -308, -10)
  elseif unit == "target" then frame:SetPoint("TOPRIGHT", UIParent, "TOP", 308, -10)
  else frame:SetPoint("TOPLEFT", frames.target or UIParent, frames.target and "TOPRIGHT" or "TOP", frames.target and 8 or 264, frames.target and 0 or -10) end
  frame:SetFrameStrata("MEDIUM")
  frame:RegisterForClicks("AnyDown", "AnyUp")
  frame:RegisterUnitEvent("UNIT_HEALTH", unit)
  frame:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
  frame:RegisterUnitEvent("UNIT_POWER_UPDATE", unit)
  frame:RegisterUnitEvent("UNIT_MAXPOWER", unit)
  frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
  frame:RegisterUnitEvent("UNIT_MAXPOWER", unit)
  frame:RegisterUnitEvent("UNIT_NAME_UPDATE", unit)
  frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", unit)
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("PLAYER_UPDATE_RESTING")
  frame:RegisterEvent("PLAYER_FLAGS_CHANGED")
  frame:RegisterEvent("GROUP_ROSTER_UPDATE")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:RegisterEvent("UNIT_FACTION")
  if unit == "target" then
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    RegisterStateDriver(frame, "visibility", "[@target,exists] show; hide")
  elseif unit == "targettarget" then
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterUnitEvent("UNIT_TARGET", "target")
    RegisterStateDriver(frame, "visibility", "[@targettarget,exists] show; hide")
    frame:Hide()
  end

  local backdrop = frame:CreateTexture(nil, "BACKGROUND")
  backdrop:SetAllPoints()
  backdrop:SetColorTexture(.04, .045, .05, .85)
  local cr, cg, cb = ClassBorderColor(unit)
  local function BorderEdge(point, relativePoint, width, height)
    local edge = frame:CreateTexture(nil, "OVERLAY")
    edge:SetColorTexture(cr, cg, cb, .7)
    edge:SetPoint(point, frame, relativePoint)
    if width then edge:SetWidth(width) end
    if height then edge:SetHeight(height) end
    return edge
  end
  BorderEdge("TOPLEFT", "TOPLEFT", nil, 1):SetPoint("TOPRIGHT", frame, "TOPRIGHT")
  BorderEdge("BOTTOMLEFT", "BOTTOMLEFT", nil, 1):SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
  BorderEdge("TOPLEFT", "TOPLEFT", 1, nil):SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
  BorderEdge("TOPRIGHT", "TOPRIGHT", 1, nil):SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")

  local portrait = frame:CreateTexture(nil, "ARTWORK")
  portrait:SetSize(50, 50)
  if unit == "target" then
    portrait:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
  else
    portrait:SetPoint("LEFT", frame, "LEFT", 4, 0)
  end
  portrait:SetTexCoord(.08, .92, .08, .92)
  frame.portrait = portrait

  local name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  if unit == "target" then
    name:SetPoint("TOPRIGHT", portrait, "TOPLEFT", -8, -2)
    name:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -2)
    name:SetJustifyH("RIGHT")
  else
    name:SetPoint("TOPLEFT", portrait, "TOPRIGHT", 9, -2)
    name:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -2)
    name:SetJustifyH("LEFT")
  end
  frame.name = name
  local function StatusIcon(atlas, offset)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", offset, -4)
    icon:SetAtlas(atlas)
    icon:Hide()
    return icon
  end
  frame.restIcon = StatusIcon("UI-HUD-UnitFrame-Player-Status-Resting", 8)
  frame.pvpIcon = StatusIcon("UI-HUD-UnitFrame-Player-Status-PvP", 28)
  frame.combatIcon = StatusIcon("UI-HUD-UnitFrame-Player-Status-Combat", 48)
  frame.groupIcon = StatusIcon("UI-HUD-UnitFrame-Player-Status-Group", 68)
  frame.leaderIcon = StatusIcon("UI-HUD-UnitFrame-Player-Status-Leader", 88)

  local health = MakeBar(frame, 18, { .34, .52, .36 })
  if unit == "target" then
    health:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -21)
    health:SetPoint("RIGHT", portrait, "LEFT", -4, 0)
  else
    health:SetPoint("TOPLEFT", portrait, "TOPRIGHT", 4, -21)
    health:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
  end
  frame.health = health
  local healthText = health:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  healthText:SetPoint("CENTER", health)
  frame.healthText = healthText

  local power = MakeBar(frame, 8, { .28, .38, .56 })
  power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -4)
  if unit == "target" then
    power:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMLEFT", -4, 4)
  else
    power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
  end
  frame.power = power
  local secondary = MakeBar(frame, 6, { .8, .55, .15 })
  secondary:SetPoint("TOPLEFT", power, "BOTTOMLEFT", 0, -2)
  if unit == "target" then
    secondary:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMLEFT", -4, 2)
  else
    secondary:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 2)
  end
  secondary:Hide()
  frame.secondaryPower = secondary

  frame:SetScript("OnEvent", function(self)
    UpdateStatus(self, unit)
    -- Do not run addon-side unit updates during protected combat actions.
    -- Retail 12.1 can expose secret unit values while secure buttons are
    -- executing; skipping this pass prevents taint and UI flicker.
    if InCombatLockdown() then return end
    if not UnitExists(unit) then return end
    self.name:SetText(UnitName(unit) or "")
    SetPortraitTexture(self.portrait, unit)
    -- 12.1 returns secret values for unit health/power. Pass them directly to
    -- Blizzard widgets; never compare or format them in addon Lua.
    local hr, hg, hb = HealthColor(unit)
    self.health:SetStatusBarColor(hr, hg, hb)
    self.health:SetValue(UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
    self.healthText:SetText("")
    self.power:SetValue(UnitPowerPercent(unit, true, nil, CurveConstants.ScaleTo100))
    local powerType = UnitPowerType(unit)
    local color = PowerBarColor[powerType] or PowerBarColor.MANA
    self.power:SetStatusBarColor(color.r, color.g, color.b)
    local secondaryType = SecondaryPowerType(unit)
    if secondaryType and PowerBarColor[secondaryType] then
      local sc = PowerBarColor[secondaryType]
      self.secondaryPower:SetStatusBarColor(sc.r, sc.g, sc.b)
      self.secondaryPower:SetValue(UnitPowerPercent(unit, true, secondaryType, CurveConstants.ScaleTo100))
      self.secondaryPower:Show()
    else self.secondaryPower:Hide() end
  end)
  frame:RegisterEvent("PLAYER_UPDATE_RESTING")
  frame:RegisterEvent("PLAYER_FLAGS_CHANGED")
  frame:RegisterEvent("GROUP_ROSTER_UPDATE")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:RegisterEvent("UNIT_FACTION")
  frames[unit] = frame
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:RegisterEvent("PET_BAR_UPDATE")
loader:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
loader:RegisterEvent("UPDATE_POSSESS_BAR")
loader:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
loader:RegisterEvent("UPDATE_EXTRA_ACTIONBAR")
loader:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    CreateUnitFrame("player")
    CreateUnitFrame("target")
    CreateUnitFrame("targettarget")
    castBar = CreateCastBar()
    frames.player:GetScript("OnEvent")(frames.player)
    frames.target:GetScript("OnEvent")(frames.target)
    frames.targettarget:GetScript("OnEvent")(frames.targettarget)
  end
  HideBlizzardUI()
  UpdateCastBar()
end)

local castTicker = C_Timer.NewTicker(.05, UpdateCastBar)











