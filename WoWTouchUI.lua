local ADDON, ns = ...
ns = ns or {}

local NUM_BUTTONS = 10
local BIG_SIZE = 150
local DEFAULT_SIZE = 100
local SMALL_SIZE = 72
local UTILITY_BUTTON_SIZE = 80
local UTILITY_BUTTON_GAP = 12
local DEFAULTS = {
  buttons = {
    { id = "Assisted", point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -85, y = 105, size = BIG_SIZE },
    { id = "Skill2", point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -306, y = 44, size = DEFAULT_SIZE },
    { id = "Skill3", point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -276, y = 163, size = DEFAULT_SIZE },
    { id = "Skill4", point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -215, y = 275, size = DEFAULT_SIZE },
    { id = "Skill5", point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -90, y = 305, size = DEFAULT_SIZE },
    { id = "Skill6", point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -190, y = 21, size = SMALL_SIZE },
    { id = "Skill7", point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -16, y = 220, size = SMALL_SIZE },
    { id = "Movement", point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -449, y = 44, size = DEFAULT_SIZE },
    { id = "Recuperate", point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -579, y = 44, size = DEFAULT_SIZE },
    { id = "Hearthstone", point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -700, y = 44, size = DEFAULT_SIZE },
  }
}

local MOUNT_SPELL = 150544
local RECUPERATE_SPELLS = { 1231411, 1231418 }

local db, editMode = nil, false
local enabled = not (type(WoWTouchUI_AccountDB) == "table" and WoWTouchUI_AccountDB.enabled == false)
local addonFrameStates = {}
local assistedTicker
local initialized = false
local buttons, picker, hint = {}, nil, nil
local editShade, settingsFrame
local exitEditButton, resetPositionsButton
local hiddenBagHolder
local hiddenChatButtons
local originalChatLayout
local menuButton
local bagButton
local mapButton
local reloadButton
local chatButton
local chatToggleAnimation
local touchQuestTracker
local touchQuestRows = {}

local function QuestIsWatched(questID, info)
  if info and info.isWatched then return true end
  if C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(questID) then return true end
  if C_QuestLog.IsQuestWatched then
    return C_QuestLog.IsQuestWatched(questID) == true
  end
  return false
end

local function GetWatchedQuestIDs()
  local ids = {}
  if C_QuestLog.GetNumQuestWatches and C_QuestLog.GetQuestIDForQuestWatchIndex then
    for i = 1, C_QuestLog.GetNumQuestWatches() do
      local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
      if id then ids[id] = true end
    end
  end
  return ids
end

local function BuildTouchQuestTracker()
  if touchQuestTracker then return end
  touchQuestTracker = CreateFrame("Frame", ADDON.."QuestTracker", UIParent, "BackdropTemplate")
  touchQuestTracker:SetSize(500, 260)
  touchQuestTracker:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 0, -12)
  touchQuestTracker:SetFrameStrata("MEDIUM")
  -- Keep the tracker as a text-only overlay. Remove any backdrop supplied by
  -- BackdropTemplate and make all backdrop colors fully transparent.
  if touchQuestTracker.SetBackdrop then touchQuestTracker:SetBackdrop(nil) end
  if touchQuestTracker.SetBackdropColor then touchQuestTracker:SetBackdropColor(0, 0, 0, 0) end
  if touchQuestTracker.SetBackdropBorderColor then touchQuestTracker:SetBackdropBorderColor(0, 0, 0, 0) end
  touchQuestTracker.title = touchQuestTracker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  touchQuestTracker.title:SetPoint("TOPLEFT", 10, -8)
  touchQuestTracker.title:SetText("任务")
  touchQuestTracker.rows = {}
end

local function ReanchorTouchQuestTracker()
  if not touchQuestTracker or not Minimap then return end
  if touchQuestTracker.SetBackdrop then touchQuestTracker:SetBackdrop(nil) end
  if touchQuestTracker.SetBackdropColor then touchQuestTracker:SetBackdropColor(0, 0, 0, 0) end
  if touchQuestTracker.SetBackdropBorderColor then touchQuestTracker:SetBackdropBorderColor(0, 0, 0, 0) end
  touchQuestTracker:SetParent(UIParent)
  touchQuestTracker:ClearAllPoints()
  touchQuestTracker:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 0, -12)
end

local function HideBlizzardMicroMenu()
  local frame = _G.MicroMenu or _G.MicroMenuFrame or _G.MainMenuBarMicroButtons
  if not frame then return end
  frame:SetAlpha(0)
  frame:Hide()
  if not frame.WoWTouchUIHidden then
    frame.WoWTouchUIHidden = true
    frame:HookScript("OnShow", function(self) self:SetAlpha(0); self:Hide() end)
  end
end

local function HideBlizzardQuestTracker()
  local tracker = _G.ObjectiveTrackerFrame or _G.QuestWatchFrame or _G.QuestTrackerFrame
  if not tracker then return end
  tracker:SetAlpha(0)
  tracker:Hide()
  if tracker.SetShown then tracker:SetShown(false) end
  if not tracker.WoWTouchUIHidden then
    tracker.WoWTouchUIHidden = true
    tracker:HookScript("OnShow", function(self)
      self:SetAlpha(0)
      self:Hide()
    end)
  end
end

local function UpdateTouchQuestTracker()
  BuildTouchQuestTracker()
  HideBlizzardQuestTracker()
  for _, row in ipairs(touchQuestRows) do row:Hide() end
  local rowIndex, y = 0, -30
  local count = C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0
  local activeQuests, watchedQuests = {}, {}
  local watchedIDs = GetWatchedQuestIDs()
  for index = 1, count do
    local info = C_QuestLog.GetInfo(index)
    if info and info.questID and not info.isHeader then
      activeQuests[#activeQuests + 1] = info
      if watchedIDs[info.questID] or QuestIsWatched(info.questID, info) then watchedQuests[#watchedQuests + 1] = info end
    end
  end
  local quests = watchedQuests
  for _, info in ipairs(quests) do
    if rowIndex < 12 then
      rowIndex = rowIndex + 1
      local row = touchQuestRows[rowIndex] or touchQuestTracker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      touchQuestRows[rowIndex] = row
      row:SetPoint("TOPLEFT", 10, y)
      row:SetWidth(360)
      row:SetHeight(28)
      row:SetJustifyH("LEFT")
      row:SetText(info.title or "")
      row:Show()
      -- Leave a full title row before drawing its objectives.
      y = y - 31
      local objectives = C_QuestLog.GetQuestObjectives(info.questID) or {}
      for _, objective in ipairs(objectives) do
        rowIndex = rowIndex + 1
        local objectiveRow = touchQuestRows[rowIndex] or touchQuestTracker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        touchQuestRows[rowIndex] = objectiveRow
        objectiveRow:SetPoint("TOPLEFT", 20, y)
        objectiveRow:SetWidth(410)
        objectiveRow:SetHeight(19)
        objectiveRow:SetJustifyH("LEFT")
        local progress = objective.numRequired and objective.numFulfilled and
          (" (" .. objective.numFulfilled .. "/" .. objective.numRequired .. ")") or ""
        objectiveRow:SetText("• " .. (objective.text or "") .. progress)
        objectiveRow:SetTextColor(objective.finished and .3 or 1, objective.finished and 1 or 1, objective.finished and .3 or 1)
        objectiveRow:Show()
        y = y - 19
      end
    end
  end
  touchQuestTracker:SetHeight(math.max(44, -y + 8))
  touchQuestTracker:SetShown(rowIndex > 0)
  HideBlizzardQuestTracker()
end
local microPanel
local microOpenAnimation
local microMenuHooked
local SetupMicroMenu
local OpenAddonSettings
local SetEditMode
local SetupChat
local editScaleSlider, editNamesButton

local function SetAddonFramesShown(shown)
  local prefix = ADDON
  local frame = EnumerateFrames()
  while frame do
    local name = frame.GetName and frame:GetName()
    if name and name:sub(1, #prefix) == prefix then
      if shown then
        if addonFrameStates[frame] then frame:Show() end
      else
        addonFrameStates[frame] = frame:IsShown()
        frame:Hide()
      end
    end
    frame = EnumerateFrames(frame)
  end
end

local function SetEnabled(value, quiet)
  value = value == true
  enabled = value
  WoWTouchUI_AccountDB = WoWTouchUI_AccountDB or {}
  WoWTouchUI_AccountDB.enabled = value
  if value then
    SetAddonFramesShown(true)
    if ns.SetUnitFramesEnabled then ns.SetUnitFramesEnabled(true) end
    -- Do not rebuild or reload the UI from a slash command. Existing frames
    -- are restored in place; the normal event flow reapplies layout later.
    if not InCombatLockdown() then
      SetupMinimap(); SetupBags(); SetupMicroMenu()
    end
    for _, button in ipairs(buttons) do UpdateButton(button) end
  else
    SetEditMode(false)
    if settingsFrame then settingsFrame:Hide() end
    if picker then picker:Hide() end
    if ns.SetUnitFramesEnabled then ns.SetUnitFramesEnabled(false) end
    SetAddonFramesShown(false)
  end
  if not quiet then print("WoWTouchUI: " .. (value and "手机界面已开启。" or "手机界面已关闭，已恢复PC界面。")) end
end

ns.IsEnabled = function() return enabled end
ns.SetEnabled = SetEnabled

local function IsSavedEnabled()
  return not (type(WoWTouchUI_AccountDB) == "table" and WoWTouchUI_AccountDB.enabled == false)
end

-- Register this before PLAYER_LOGIN so the command remains available when
-- the addon is disabled and intentionally creates no UI objects.
SLASH_WOWTOUCHUI1 = "/wtui"
SlashCmdList.WOWTOUCHUI = function(msg)
  msg = (msg or ""):lower()
  if msg == "on" or msg == "开启" then
    WoWTouchUI_AccountDB = WoWTouchUI_AccountDB or {}
    WoWTouchUI_AccountDB.enabled = true
    ReloadUI()
  elseif msg == "off" or msg == "关闭" then
    WoWTouchUI_AccountDB = WoWTouchUI_AccountDB or {}
    WoWTouchUI_AccountDB.enabled = false
    ReloadUI()
  elseif not initialized then
    print("WoWTouchUI: 当前已关闭，请输入 /wtui on 开启。")
  end
end

local function StyleMenuButton(button)
  if button.WoWTouchUIStyled then return end
  button.WoWTouchUIStyled = true
  button:HookScript("OnEnter", function()
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
  end)
  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetColorTexture(.08, .08, .1, 1)
  local backgroundMask = button:CreateMaskTexture(nil, "BACKGROUND")
  backgroundMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  backgroundMask:SetAllPoints(background)
  background:AddMaskTexture(backgroundMask)
  if button.Background then button.Background:SetAlpha(0) end
  if button.PushedBackground then button.PushedBackground:SetAlpha(0) end
  local ring = button:CreateTexture(nil, "OVERLAY")
  ring:SetTexture("Interface\\AddOns\\WoWTouchUI\\NormalRing")
  ring:SetAllPoints(button)
  ring:SetVertexColor(.25, .25, .25, .9)
  button.WoWTouchUIBorder = ring
end

local function AttachMicroMenu()
  if not microPanel then return end
  microPanel:ClearAllPoints()
  microPanel:SetPoint("TOPRIGHT", menuButton, "TOPLEFT", -12, 0)
end

local function SetupBuffs()
  if InCombatLockdown() or not BuffFrame then return end
  BuffFrame:ClearAllPoints()
  BuffFrame:SetPoint("TOPLEFT", Minimap or UIParent, "TOPRIGHT", 18, 0)
  local container = BuffFrame.AuraContainer
  if container then
    container.isHorizontal = true
    container.addIconsToRight = true
    container.addIconsToTop = false
    if BuffFrame.UpdateGridLayout then BuffFrame:UpdateGridLayout() end
  end
end

local function SetFrameShown(frame, shown)
  if not frame then return end
  frame:SetShown(shown)
end

local function CenterBlizzardPanels()
  local panels = { WorldMapFrame, QuestLogFrame, AchievementFrame }
  for _, panel in ipairs(panels) do
    if panel and panel.ClearAllPoints then
      panel:ClearAllPoints()
      panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
  end
end

local function HookBlizzardPanels()
  for _, panel in ipairs({ WorldMapFrame, QuestLogFrame, AchievementFrame }) do
    if panel and not panel.WoWTouchUICentered then
      panel.WoWTouchUICentered = true
      panel:HookScript("OnShow", CenterBlizzardPanels)
    end
  end
  CenterBlizzardPanels()
end

local achievementHooked
local function HookAchievementPanel()
  local panel = AchievementFrame
  if not panel then return end
  if not achievementHooked then
    achievementHooked = true
    panel:HookScript("OnShow", function(self)
      self:ClearAllPoints()
      self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end)
  end
  if panel:IsShown() then
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

local function SetupMinimap()
  if not Minimap or not MinimapCluster then return end
  MinimapCluster:ClearAllPoints()
  MinimapCluster:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 12, -12)
  MinimapCluster:SetSize(228, 228)
  if MinimapCluster.SetClipsChildren then MinimapCluster:SetClipsChildren(false) end
  Minimap:ClearAllPoints()
  Minimap:SetPoint("TOPLEFT", MinimapCluster, "TOPLEFT", 0, 0)
  Minimap:SetSize(228, 228)
  if Minimap.SetClipsChildren then Minimap:SetClipsChildren(false) end
  Minimap:SetMaskTexture("Interface\\AddOns\\WoWTouchUI\\SquareMask")
  for _, name in ipairs({ "MinimapBorder", "MinimapBorderTop", "MinimapBackdrop" }) do
    local texture = _G[name]
    if texture and texture.SetTexture then texture:SetAlpha(0) end
  end
  for _, name in ipairs({ "MinimapBackdrop", "MinimapCompassTexture" }) do
    local texture = _G[name]
    if texture and texture.SetAlpha then texture:SetAlpha(0) end
  end
  if ExpansionLandingPageMinimapButton then
    ExpansionLandingPageMinimapButton:SetParent(MinimapCluster)
    ExpansionLandingPageMinimapButton:ClearAllPoints()
    ExpansionLandingPageMinimapButton:SetPoint("BOTTOMRIGHT", MinimapCluster, "BOTTOMRIGHT", -8, 8)
    ExpansionLandingPageMinimapButton:SetFrameStrata("MEDIUM")
    ExpansionLandingPageMinimapButton:SetAlpha(1)
    ExpansionLandingPageMinimapButton:Show()
    if not InCombatLockdown() and not ExpansionLandingPageMinimapButton.WoWTouchUIHoverDisabled then
      ExpansionLandingPageMinimapButton:SetScript("OnEnter", nil)
      ExpansionLandingPageMinimapButton.WoWTouchUIHoverDisabled = true
    end
  end
  local function PlaceMinimapElement(frame, point, relative, relPoint, x, y)
    if not frame or not frame.ClearAllPoints then return end
    if frame.SetParent then frame:SetParent(MinimapCluster) end
    frame:ClearAllPoints()
    frame:SetPoint(point, relative or MinimapCluster, relPoint or point, x or 0, y or 0)
    frame:Show()
  end
  PlaceMinimapElement(_G.MinimapCalendarFrame or _G.GameTimeFrame, "TOPRIGHT", MinimapCluster, "TOPRIGHT", -8, -8)
  PlaceMinimapElement(_G.MinimapTracking, "TOPLEFT", MinimapCluster, "TOPLEFT", 8, -8)
  PlaceMinimapElement(_G.MinimapZoomIn, "BOTTOMRIGHT", MinimapCluster, "BOTTOMRIGHT", -8, 38)
  PlaceMinimapElement(_G.MinimapZoomOut, "BOTTOMRIGHT", MinimapCluster, "BOTTOMRIGHT", -8, 8)
  local zoneText = _G.MinimapZoneTextButton or _G.MinimapZoneText
  if zoneText and zoneText.SetParent then zoneText:SetParent(Minimap) end
  if zoneText and zoneText.ClearAllPoints then
    zoneText:ClearAllPoints(); zoneText:SetPoint("TOP", Minimap, "TOP", 0, -6)
    if zoneText.SetWidth then zoneText:SetWidth(170) end
    if zoneText.SetJustifyH then zoneText:SetJustifyH("CENTER") end
    if zoneText.SetFrameStrata then zoneText:SetFrameStrata("HIGH") end
    if zoneText.SetFrameLevel then zoneText:SetFrameLevel(120) end
    if zoneText.SetAlpha then zoneText:SetAlpha(1) end
    zoneText:Show()
  end
  if MinimapZoneText and MinimapZoneText ~= zoneText then
    MinimapZoneText:SetParent(Minimap); MinimapZoneText:ClearAllPoints()
    MinimapZoneText:SetPoint("TOP", Minimap, "TOP", 0, -6)
    if MinimapZoneText.SetFrameStrata then MinimapZoneText:SetFrameStrata("HIGH") end
    if MinimapZoneText.SetFrameLevel then MinimapZoneText:SetFrameLevel(121) end
    MinimapZoneText:SetAlpha(1); MinimapZoneText:SetWidth(170)
    if MinimapZoneText.SetJustifyH then MinimapZoneText:SetJustifyH("CENTER") end
    MinimapZoneText:Show()
  end
  ReanchorTouchQuestTracker()
  HideBlizzardMicroMenu()
end
local function DisablePersonalResource()
  local frame = PersonalResourceDisplayFrame or _G.PersonalResourceDisplayFrame
  if not frame then return end
  frame:SetAlpha(0)
  frame:Hide()
  if not frame.WoWTouchUIHidden then
    frame.WoWTouchUIHidden = true
    frame:HookScript("OnShow", function(self) self:SetAlpha(0); self:Hide() end)
  end
end


local minimapHooksInstalled
local function KeepInterfaceLayout()
  if not enabled then return end
  SetupMinimap()
  HookBlizzardPanels()
  C_Timer.After(0, HookAchievementPanel)
  C_Timer.After(1, HookAchievementPanel)
  BuildTouchQuestTracker()
  ReanchorTouchQuestTracker()
  HideBlizzardMicroMenu()
  UpdateTouchQuestTracker()
  SetupChat()
  SetupBuffs()
  -- Blizzard's edit mode applies its layout on several subsequent frames.
  C_Timer.After(0, function() SetupMinimap(); SetupChat(); SetupBuffs() end)
  C_Timer.After(.25, function() SetupMinimap(); SetupChat(); SetupBuffs() end)
  C_Timer.After(.75, function() SetupMinimap(); SetupChat(); SetupBuffs() end)
  C_Timer.After(1.5, function() SetupMinimap(); SetupChat(); SetupBuffs() end)
end

local function HookBlizzardEditMode()
  if minimapHooksInstalled then return end
  local manager = EditModeManagerFrame
  if not manager then return end
  minimapHooksInstalled = true
  if manager.EnterEditMode then hooksecurefunc(manager, "EnterEditMode", KeepInterfaceLayout) end
  if manager.ExitEditMode then hooksecurefunc(manager, "ExitEditMode", KeepInterfaceLayout) end
  manager:HookScript("OnHide", KeepInterfaceLayout)
  manager:HookScript("OnShow", KeepInterfaceLayout)
end

local function StartLayoutGuard()
  if not C_Timer or not C_Timer.NewTicker then return end
  if not WoWTouchUI_LayoutGuard then
    WoWTouchUI_LayoutGuard = C_Timer.NewTicker(.5, function()
      if not enabled then return end
      local manager = EditModeManagerFrame
      if manager and manager:IsShown() then return end
      SetupMinimap()
      HookBlizzardPanels()
      C_Timer.After(0, HookAchievementPanel)
      SetupChat()
      SetupBuffs()
    end)
  end
end

local function SetupBags()
  if not hiddenBagHolder then
    hiddenBagHolder = CreateFrame("Frame", ADDON.."HiddenBags", UIParent)
    hiddenBagHolder:Hide()
  end
  for _, name in ipairs({
    "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
    "CharacterReagentBag0Slot", "BagBarExpandToggle", "MainMenuBarBackpackButton",
  }) do
    local bagButton = _G[name]
    if bagButton then
      bagButton:SetParent(hiddenBagHolder)
      bagButton:Hide()
    end
  end
end

SetupChat = function()
  if InCombatLockdown() or not ChatFrame1 then return end
  ChatFrame1:SetClampedToScreen(false)
  ChatFrame1:SetUserPlaced(true)
  if not originalChatLayout then
    originalChatLayout = { width = ChatFrame1:GetWidth(), height = ChatFrame1:GetHeight(), points = {} }
    for i = 1, ChatFrame1:GetNumPoints() do
      originalChatLayout.points[i] = { ChatFrame1:GetPoint(i) }
    end
    if GeneralDockManager then
      originalChatLayout.dockPoints = {}
      for i = 1, GeneralDockManager:GetNumPoints() do
        originalChatLayout.dockPoints[i] = { GeneralDockManager:GetPoint(i) }
      end
    end
  end
  ChatFrame1:ClearAllPoints()
  ChatFrame1:SetPoint("TOPRIGHT", menuButton or UIParent, "TOPLEFT", -18, -92)
  ChatFrame1:SetSize(420, 150)
  if GeneralDockManager then
    GeneralDockManager:ClearAllPoints()
    GeneralDockManager:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 2)
    GeneralDockManager:SetClampedToScreen(false)
    GeneralDockManager:Hide()
  end
  if not hiddenChatButtons then
    hiddenChatButtons = CreateFrame("Frame", ADDON.."HiddenChatButtons", UIParent)
    hiddenChatButtons:Hide()
  end
  for _, name in ipairs({ "QuickJoinToastButton", "ChatFrameChannelButton", "ChatFrameMenuButton" }) do
    local button = _G[name]
    if button then button:SetParent(hiddenChatButtons); button:Hide() end
  end
  if ChatFrame1Tab then ChatFrame1Tab:Hide() end
  if chatButton and not chatButton.initialized then
    ChatFrame1:Hide()
    if GeneralDockManager then GeneralDockManager:Hide() end
    chatButton.initialized = true
  else
    ChatFrame1:SetAlpha(1)
    ChatFrame1:Show()
  end
end

local function RestoreChatLayout()
  if not originalChatLayout or not ChatFrame1 then return end
  ChatFrame1:ClearAllPoints()
  ChatFrame1:SetSize(originalChatLayout.width, originalChatLayout.height)
  for _, point in ipairs(originalChatLayout.points) do
    ChatFrame1:SetPoint(point[1], point[2], point[3], point[4], point[5])
  end
  if GeneralDockManager and originalChatLayout.dockPoints then
    GeneralDockManager:ClearAllPoints()
    for _, point in ipairs(originalChatLayout.dockPoints) do
      GeneralDockManager:SetPoint(point[1], point[2], point[3], point[4], point[5])
    end
  end
end

local function MakeRoundIcon(button, iconPath)
  local mask = button:CreateMaskTexture(nil, "ARTWORK")
  mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  mask:SetPoint("CENTER", button, "CENTER")
  mask:SetSize(button:GetWidth() * .88, button:GetHeight() * .88)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("CENTER", button, "CENTER")
  icon:SetSize(button:GetWidth() * .88, button:GetHeight() * .88)
  icon:SetTexture(iconPath)
  icon:SetTexCoord(.08, .92, .08, .92)
  icon:AddMaskTexture(mask)
  local highlight = button:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints(button)
  highlight:SetColorTexture(1, 1, 1, .25)
  highlight:AddMaskTexture(mask)
  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(button)
  background:SetColorTexture(.08, .08, .1, 1)
  background:AddMaskTexture(mask)
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\AddOns\\WoWTouchUI\\NormalRing")
  border:SetAllPoints(button)
  border:SetVertexColor(.25, .25, .25, .9)
  button.WoWTouchUIBorder = border
end

local function AddUtilityLabel(button, text)
  local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("TOP", button, "BOTTOM", 0, -2)
  label:SetWidth(100)
  label:SetScale(1)
  label:SetJustifyH("CENTER")
  label:SetWordWrap(false)
  label:SetTextColor(1, 1, 1)
  label:SetText(text)
  button.WoWTouchUILabel = label
end

SetupMicroMenu = function()
  if not menuButton then
    menuButton = CreateFrame("Button", ADDON.."SystemMenuButton", UIParent)
    menuButton:SetFrameStrata("HIGH")
    menuButton:SetFrameLevel(100)
    menuButton:SetSize(UTILITY_BUTTON_SIZE, UTILITY_BUTTON_SIZE)
    menuButton:RegisterForClicks("AnyUp")
    MakeRoundIcon(menuButton, "Interface\\Icons\\Trade_Engineering")
    AddUtilityLabel(menuButton, "功能菜单")
    menuButton:SetScript("OnClick", function()
      if not microPanel then SetupMicroMenu() end
      if microPanel then
        if microPanel:IsShown() then
          microOpenAnimation:Stop()
          microPanel:Hide()
        else
          AttachMicroMenu()
          microPanel:Show()
          microOpenAnimation:Play()
        end
      end
    end)
  end
  menuButton:ClearAllPoints()
  menuButton:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -18, -18)
  menuButton:Show()
  if not bagButton then
    bagButton = CreateFrame("Button", ADDON.."BagButton", UIParent)
    bagButton:SetFrameStrata("HIGH")
    bagButton:SetFrameLevel(100)
    bagButton:SetSize(UTILITY_BUTTON_SIZE, UTILITY_BUTTON_SIZE)
    bagButton:RegisterForClicks("AnyUp")
    MakeRoundIcon(bagButton, "Interface\\Icons\\INV_Misc_Bag_08")
    AddUtilityLabel(bagButton, "背包")
    bagButton:SetScript("OnClick", function()
      if ToggleAllBags then ToggleAllBags() end
    end)
  end
  bagButton:ClearAllPoints()
  bagButton:SetPoint("TOP", menuButton, "BOTTOM", 0, -UTILITY_BUTTON_GAP)
  if not mapButton then
    mapButton = CreateFrame("Button", ADDON.."MapButton", UIParent)
    mapButton:SetFrameStrata("HIGH")
    mapButton:SetFrameLevel(100)
    mapButton:SetSize(UTILITY_BUTTON_SIZE, UTILITY_BUTTON_SIZE)
    mapButton:RegisterForClicks("AnyUp")
    MakeRoundIcon(mapButton, "Interface\\Icons\\INV_Misc_Map_01")
    AddUtilityLabel(mapButton, "地图")
    mapButton:SetScript("OnClick", function()
      if ToggleWorldMap then ToggleWorldMap() elseif WorldMapFrame then
        if WorldMapFrame:IsShown() then HideUIPanel(WorldMapFrame) else ShowUIPanel(WorldMapFrame) end
      end
    end)
  end
  mapButton:ClearAllPoints()
  mapButton:SetPoint("TOP", bagButton, "BOTTOM", 0, -UTILITY_BUTTON_GAP)
  if not chatButton then
    chatButton = CreateFrame("Button", ADDON.."ChatButton", UIParent)
    chatButton:SetFrameStrata("HIGH"); chatButton:SetFrameLevel(100)
    chatButton:SetSize(UTILITY_BUTTON_SIZE, UTILITY_BUTTON_SIZE)
    chatButton:RegisterForClicks("AnyUp")
    MakeRoundIcon(chatButton, "Interface\\Icons\\INV_Misc_Note_01")
    AddUtilityLabel(chatButton, "聊天")
    chatToggleAnimation = chatButton:CreateAnimationGroup()
    local fade = chatToggleAnimation:CreateAnimation("Alpha")
    fade:SetFromAlpha(0); fade:SetToAlpha(1); fade:SetDuration(.18)
    chatButton:SetScript("OnClick", function()
      if not ChatFrame1 then return end
      if ChatFrame1:IsShown() then ChatFrame1:Hide(); if GeneralDockManager then GeneralDockManager:Hide() end
      else
        SetupChat(); ChatFrame1:SetAlpha(0); ChatFrame1:Show()
        if GeneralDockManager then GeneralDockManager:Hide() end
        chatToggleAnimation:Stop(); chatToggleAnimation:Play()
        chatToggleAnimation:SetScript("OnFinished", function() ChatFrame1:SetAlpha(1) end)
      end
    end)
    chatButton:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText("聊天"); GameTooltip:Show() end)
    chatButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  chatButton:ClearAllPoints()
  chatButton:SetPoint("TOP", mapButton, "BOTTOM", 0, -UTILITY_BUTTON_GAP)
  if not reloadButton then
    reloadButton = CreateFrame("Button", ADDON.."ReloadButton", UIParent)
    reloadButton:SetFrameStrata("HIGH")
    reloadButton:SetFrameLevel(100)
    reloadButton:SetSize(UTILITY_BUTTON_SIZE, UTILITY_BUTTON_SIZE)
    reloadButton:RegisterForClicks("AnyUp")
    MakeRoundIcon(reloadButton, "Interface\\Icons\\INV_Misc_Gear_01")
    AddUtilityLabel(reloadButton, "重载")
    reloadButton:SetScript("OnClick", ReloadUI)
  end
  reloadButton:ClearAllPoints()
  reloadButton:SetPoint("TOP", chatButton, "BOTTOM", 0, -UTILITY_BUTTON_GAP)
  if not microPanel then
      microPanel = CreateFrame("Frame", ADDON.."MicroMenuPanel", UIParent)
      microPanel:SetFrameStrata("HIGH")
      microPanel:SetFrameLevel(100)
      microPanel:SetPoint("TOPRIGHT", menuButton, "TOPLEFT", -12, 0)
      microPanel:SetSize(1, 1)
      microPanel:Hide()
      microOpenAnimation = microPanel:CreateAnimationGroup()
      local fade = microOpenAnimation:CreateAnimation("Alpha")
      fade:SetFromAlpha(0)
      fade:SetToAlpha(1)
      fade:SetDuration(.18)
      local slide = microOpenAnimation:CreateAnimation("Translation")
      slide:SetOffset(-22, 0)
      slide:SetDuration(.18)
      local function AddSystemButton(id, icon, label, onClick, index)
        local button = CreateFrame("Button", ADDON..id, microPanel)
        button:SetSize(80, 80)
        button:SetPoint("LEFT", microPanel, "LEFT", (index - 1) * 96, 0)
        button:RegisterForClicks("AnyUp")
        StyleMenuButton(button)
        local texture = button:CreateTexture(nil, "ARTWORK")
        texture:SetPoint("CENTER")
        texture:SetSize(68, 68)
        texture:SetTexture(icon)
        texture:SetTexCoord(.08, .92, .08, .92)
        local mask = button:CreateMaskTexture(nil, "ARTWORK")
        mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        mask:SetPoint("CENTER", texture, "CENTER")
        mask:SetSize(68, 68)
        texture:AddMaskTexture(mask)
        AddUtilityLabel(button, label)
        button:SetScript("OnClick", function() microPanel:Hide(); onClick() end)
        return button
      end
      local systemButtons = {
        { "AddonSettingsButton", "插件设置", OpenAddonSettings, "settings" },
        { "EditModeButton", "编辑按钮", function() SetEditMode(not editMode) end, "edit" },
        { "CharacterButton", "角色", function() ToggleCharacter("PaperDollFrame") end, "character" },
        { "SpellbookButton", "法术书", function() ToggleSpellBook("spell") end, "spellbook" },
        { "TalentButton", "天赋", function() if PlayerSpellsFrame then ToggleFrame(PlayerSpellsFrame) end end, "talent" },
        { "AchievementButton", "成就", function() if AchievementFrame_Toggle then AchievementFrame_Toggle() end end, "achievement" },
        { "QuestButton", "任务", function() if QuestLogFrame then ToggleFrame(QuestLogFrame) elseif ToggleQuestLog then ToggleQuestLog() end end, "quest" },
        { "GuildButton", "公会", function() if GuildFrame_Toggle then GuildFrame_Toggle() end end, "guild" },
        { "CollectionsButton", "收藏", function() if ToggleCollectionsJournal then ToggleCollectionsJournal() end end, "collections" },
        { "AdventureButton", "冒险指南", function() if EncounterJournal_Toggle then EncounterJournal_Toggle() end end, "adventure" },
        { "StoreButton", "商城", function() if StoreMicroButton and StoreMicroButton:GetScript("OnClick") then StoreMicroButton:GetScript("OnClick")(StoreMicroButton) end end, "store" },
        { "HelpButton", "帮助", function() if ToggleHelpFrame then ToggleHelpFrame() end end, "help" },
      }
      for index, entry in ipairs(systemButtons) do
        AddSystemButton(entry[1], "Interface\\AddOns\\WoWTouchUI\\Assets\\" .. entry[4] .. ".tga", entry[2], entry[3], index)
      end
      microPanel:SetSize(#systemButtons * 96 - 16, 104)
      AttachMicroMenu()
    if not microPanel.initialized then
      microPanel.initialized = true
      microPanel:Hide()
    end
  end
end

local function UpdateCooldown(button)
  local cooldown = button.cooldown
  if button.itemID then
    if C_Item and C_Item.GetItemCooldown then
      local start, duration, enabled = C_Item.GetItemCooldown(button.itemID)
      if canaccessvalue(start) and canaccessvalue(duration) and canaccessvalue(enabled)
          and start and duration and enabled ~= 0 then
        cooldown:SetCooldown(start, duration)
      else
        cooldown:Clear()
      end
    end
    return
  end
  if not button.spellID then
    cooldown:Clear()
    return
  end
  local spellID = C_Spell.GetOverrideSpell(button.spellID) or button.spellID
  local charges = C_Spell.GetSpellCharges(spellID)
  local showCharge = charges
      and canaccessvalue(charges.maxCharges)
      and charges.maxCharges > 1
  if showCharge then
    local chargeDuration = C_Spell.GetSpellChargeDuration(spellID)
    if chargeDuration then
      cooldown:SetCooldownFromDurationObject(chargeDuration)
    else
      cooldown:Clear()
    end
  else
    local spellDuration = C_Spell.GetSpellCooldownDuration(spellID)
    if spellDuration then
      cooldown:SetCooldownFromDurationObject(spellDuration)
    else
      cooldown:Clear()
    end
  end
end

local function UpdateAllCooldowns()
  for _, button in ipairs(buttons) do UpdateCooldown(button) end
end

local RefreshAssistedButtons

local function CopyDefaults()
  local saved = WoWTouchUI_AccountDB
  local character = type(WoWTouchUI_CharacterDB) == "table" and WoWTouchUI_CharacterDB or {}
  local characterButtons = type(character.buttons) == "table" and character.buttons or {}
  local savedButtons = type(saved) == "table" and saved.buttons
  local savedScale = type(saved) == "table" and saved.buttonScale
  db = {
    buttons = {},
    buttonScale = type(savedScale) == "number" and math.max(1, math.min(1.5, savedScale)) or 1,
    showSpellNames = not (type(saved) == "table" and saved.showSpellNames == false),
  }
  for i = 1, NUM_BUTTONS do
    local d = DEFAULTS.buttons[i]
    local source = type(savedButtons) == "table" and savedButtons[d.id]
    local b = {}
    for _, k in ipairs({ "id", "point", "relPoint", "x", "y", "size" }) do b[k] = d[k] end
    if type(source) == "table" then
      -- Account data owns only layout. Older versions also stored actions;
      -- those are ignored here and replaced by character data below.
      for _, k in ipairs({ "point", "relPoint", "x", "y", "size" }) do
        if source[k] ~= nil then b[k] = source[k] end
      end
    end
    local action = characterButtons[d.id]
    if type(action) == "table" then
      for _, k in ipairs({ "spellID", "itemID", "actionKind", "assisted", "customAction" }) do
        if action[k] ~= nil then b[k] = action[k] end
      end
    end
    db.buttons[i] = b
  end
end

local function SaveSettings()
  local saved = { layoutVersion = 4, buttonScale = db.buttonScale, showSpellNames = db.showSpellNames, buttons = {} }
  for i = 1, NUM_BUTTONS do
    local button = db.buttons[i]
    saved.buttons[button.id] = {}
    for _, key in ipairs({ "point", "relPoint", "x", "y", "size" }) do
      saved.buttons[button.id][key] = button[key]
    end
  end
  WoWTouchUI_AccountDB = saved
end

local function MigrateButtonSettings(saved, version)
  if type(saved) ~= "table" or saved.layoutVersion == version then return end
  local oldButtons = type(saved.buttons) == "table" and saved.buttons or {}
  local migrated = {}
  for i = 1, NUM_BUTTONS do
    local oldIndex = i == 9 and 12 or i == 10 and 11 or (i <= 5 and i or i + 2)
    migrated[DEFAULTS.buttons[i].id] = oldButtons[oldIndex]
  end
  saved.buttons = migrated
  saved.layoutVersion = version
end

local function SaveCharacterAction(button)
  WoWTouchUI_CharacterDB = WoWTouchUI_CharacterDB or { layoutVersion = 2, buttons = {} }
  WoWTouchUI_CharacterDB.layoutVersion = 2
  WoWTouchUI_CharacterDB.buttons = WoWTouchUI_CharacterDB.buttons or {}
  local saved = WoWTouchUI_CharacterDB.buttons[button.builtinID] or {}
  saved.spellID = button.spellID
  saved.itemID = button.itemID
  saved.actionKind = button.actionKind
  saved.assisted = button.actionKind == "assisted" or nil
  saved.customAction = true
  WoWTouchUI_CharacterDB.buttons[button.builtinID] = saved
end

local function SpellName(id)
  if not id then return nil end
  local info = C_Spell and C_Spell.GetSpellInfo(id)
  return info and info.name or (GetSpellInfo and GetSpellInfo(id))
end

local function GetAssistedSpell()
  return C_AssistedCombat and C_AssistedCombat.GetActionSpell and C_AssistedCombat.GetActionSpell()
end

local function KnownSpell(candidates)
  for _, spellID in ipairs(candidates or {}) do
    if (IsPlayerSpell and IsPlayerSpell(spellID)) or
       (IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellID)) then
      return spellID
    end
  end
  -- Universal spells can be in the spellbook before the known-spell cache settles.
  if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
    local playerBank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    for slot = 1, 500 do
      local info = C_SpellBook.GetSpellBookItemInfo(slot, playerBank)
      if info and info.spellID then
        for _, candidate in ipairs(candidates or {}) do
          if info.spellID == candidate then return candidate end
        end
      end
    end
  end
end

local function DefaultAction(index)
  if index == 1 then return { kind = "assisted", spellID = GetAssistedSpell() } end
  if index == 8 then
    local _, class = UnitClass("player")
    if class == "DRUID" then
      -- Travel Form is the natural movement action for druids. Keep the
      -- button empty if the form is not known yet (for example during login).
      local travelForm = KnownSpell({ 783 }) or 783
      return { kind = "spell", spellID = travelForm }
    end
    return { kind = "mount", spellID = MOUNT_SPELL }
  end
  if index == 9 then return { kind = "spell", spellID = KnownSpell(RECUPERATE_SPELLS) } end
  if index == 10 then return { kind = "item", itemID = 6948 } end
  -- Other slots start empty. The player can assign any spell in edit mode.
  return { kind = "spell", spellID = nil }
end

local function ButtonAction(button)
  local b = button.db
  -- Older saved layouts stored the original mount default as a spell/action.
  -- Treat that built-in value as a default for druids so their movement slot
  -- changes to Travel Form when they log onto a druid.
  if button.builtinID == "Movement" then
    local _, class = UnitClass("player")
    if class == "DRUID" and (b.actionKind == "mount" or b.spellID == MOUNT_SPELL or b.spellID == 783) then
      return DefaultAction(button.index)
    end
  end
  if b.customAction then
    return { kind = b.assisted and "assisted" or b.actionKind or "spell", spellID = b.spellID, itemID = b.itemID }
  end
  return DefaultAction(button.index)
end

local function UpdateAssistedIcons()
  if not enabled then return end
  local hasAssistedButton = false
  for _, button in ipairs(buttons) do
    if button.actionKind == "assisted" then
      hasAssistedButton = true
      break
    end
  end
  if not hasAssistedButton or not C_AssistedCombat or not C_AssistedCombat.GetNextCastSpell then return end

  -- The suggested spell may briefly be nil while the official rotation updates.
  -- Keep the last icon in that case, just as the action button remains usable.
  local nextSpell = C_AssistedCombat.GetNextCastSpell(false)
  if not nextSpell then return end
  local icon = C_Spell.GetSpellTexture(nextSpell)
  if not icon then return end
  for _, button in ipairs(buttons) do
    if button.actionKind == "assisted" then button.icon:SetTexture(icon) end
  end
end

local function SetButtonAction(button, action, userSelected)
  if InCombatLockdown() then
    print("WoWTouchUI: 战斗中不能修改技能，请脱离战斗后再试。")
    return
  end
  local kind = action.kind
  button.actionKind = kind
  local spellID = kind == "assisted" and GetAssistedSpell() or action.spellID
  local itemID = action.itemID
  button.spellID, button.itemID = spellID, itemID
  -- Use a secure macro for the random favorite mount. This is the same
  -- protected action exposed by Blizzard's mount button and works across
  -- clients where the summonmount attribute is not available to addons.
  local secureType = kind == "item" and "item" or kind == "mount" and "macro" or "spell"
  button:SetAttribute("type", secureType)
  button:SetAttribute("type1", secureType)
  button:SetAttribute("type2", secureType)
  local spellAction = ((kind == "spell" or kind == "assisted" or kind == "mount") and spellID) or nil
  button:SetAttribute("spell", spellAction)
  button:SetAttribute("spell1", spellAction)
  button:SetAttribute("spell2", spellAction)
  -- Some 12.1 clients do not resolve this protected action by numeric ID;
  -- also provide the localized spell name as the secure action value.
  if kind == "mount" and spellAction then
    local mountName = SpellName(spellAction)
    if mountName then
      button:SetAttribute("spell", mountName)
      button:SetAttribute("spell1", mountName)
      button:SetAttribute("spell2", mountName)
    end
  end
  -- Secure item actions require an item link/name. A bare numeric value is
  -- interpreted as a bag slot and causes C_Item.IsEquippableItem errors.
  local itemAction = itemID and ("item:" .. tostring(itemID)) or nil
  button:SetAttribute("item", itemAction)
  button:SetAttribute("item1", itemAction)
  button:SetAttribute("item2", itemAction)
  button:SetAttribute("summonmount", nil)
  button:SetAttribute("summonmount1", nil)
  button:SetAttribute("summonmount2", nil)
  button:SetAttribute("macrotext", nil)
  button:SetAttribute("macrotext1", nil)
  button:SetAttribute("macrotext2", nil)
  if kind == "mount" then
    local mountMacro = "/cast [nomounted] 150544"
    button:SetAttribute("macrotext", mountMacro)
    button:SetAttribute("macrotext1", mountMacro)
    button:SetAttribute("macrotext2", mountMacro)
    button:SetAttribute("spell", nil)
    button:SetAttribute("spell1", nil)
    button:SetAttribute("spell2", nil)
  end
  local icon = itemID and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
      or spellID and C_Spell.GetSpellTexture(spellID)
  local hasIcon = icon ~= nil
  if button.emptyBackground then button.emptyBackground:SetShown(not hasIcon) end
  button.icon:SetTexture(icon)
  button.icon:SetShown(hasIcon)
  -- Keep the circular button, but show the complete spell artwork with a
  -- small breathing margin instead of zooming/cropping it to the edge.
  button.icon:SetTexCoord(0, 1, 0, 1)
  if button.border then
    local configured = spellID or itemID or kind == "mount"
    button.border:SetVertexColor(configured and .2 or .55, configured and 1 or .55, configured and .2 or .55, 1)
    if button.editHighlight then button.editHighlight:SetShown(editMode and configured) end
  end
  button.label:SetText(kind == "assisted" and (ASSISTED_COMBAT_LABEL or "一键辅助") or kind == "mount" and "随机坐骑" or kind == "item" and "炉石" or SpellName(spellID) or "")
  button.label:SetShown(db.showSpellNames)
  if userSelected then
    button.db.spellID = spellID
    button.db.itemID = itemID
    button.db.actionKind = kind
    button.db.assisted = kind == "assisted" or nil
    button.db.customAction = true
  end
  UpdateCooldown(button)
  if kind == "assisted" then UpdateAssistedIcons() end
  if userSelected then SaveCharacterAction(button) end
end

local function RefreshDefaultActions()
  if InCombatLockdown() then return end
  for _, button in ipairs(buttons) do
    SetButtonAction(button, ButtonAction(button))
  end
end

RefreshAssistedButtons = RefreshDefaultActions

local function UpdateButton(button)
  local b = button.db
  button:ClearAllPoints()
  button:SetPoint(b.point, UIParent, b.relPoint, b.x, b.y)
  button:SetSize(b.size * db.buttonScale, b.size * db.buttonScale)
  button.icon:SetSize(button:GetWidth() * .9, button:GetHeight() * .9)
  if button.label then button.label:SetWidth(math.max(240, button:GetWidth() * 2.4)) end
  if button.border then
    button.border:SetSize(button:GetWidth(), button:GetHeight())
    button.editHighlight:SetSize(button:GetWidth() - 8, button:GetHeight() - 8)
    button.targetHighlight:SetSize(button:GetWidth() - 4, button:GetHeight() - 4)
  end
end

local function ResetButtonPositions()
  if InCombatLockdown() then return end
  for _, button in ipairs(buttons) do
    local defaults = DEFAULTS.buttons[button.index]
    local saved = button.db
    saved.point = defaults.point
    saved.relPoint = defaults.relPoint
    saved.x = defaults.x
    saved.y = defaults.y
    saved.size = defaults.size
    UpdateButton(button)
  end
  SaveSettings()
  print("WoWTouchUI: 技能按钮已还原默认位置和大小。")
end

local function CreateButton(i)
  local b = db.buttons[i]
  local button = CreateFrame("Button", ADDON.."Builtin"..b.id.."Button", UIParent, "SecureActionButtonTemplate")
  button.db, button.index = b, i
  button.builtinID = b.id
  button:RegisterForClicks("AnyDown", "AnyUp")
  button:EnableMouse(true)
  button:SetAttribute("type", "spell")
  button:SetAttribute("type1", "spell")
  button:SetAttribute("type2", "spell")
  button:SetFrameStrata("MEDIUM")
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.emptyBackground = button:CreateTexture(nil, "BACKGROUND")
  button.emptyBackground:SetPoint("TOPLEFT", 4, -4)
  button.emptyBackground:SetPoint("BOTTOMRIGHT", -4, 4)
  button.emptyBackground:SetColorTexture(0, 0, 0, .58)
  local emptyMask = button:CreateMaskTexture(nil, "BACKGROUND")
  emptyMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  emptyMask:SetAllPoints(button.emptyBackground)
  button.emptyBackground:AddMaskTexture(emptyMask)
  button.emptyBackground:Hide()
  button.icon:SetPoint("CENTER", button, "CENTER")
  button.icon:SetTexture(nil)
  button.icon:Hide()
  button.icon:SetTexCoord(0, 1, 0, 1)
  local mask = button:CreateMaskTexture(nil, "ARTWORK")
  mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  mask:SetAllPoints(button.icon); button.icon:AddMaskTexture(mask)
  -- Normal border and edit highlight use separate assets so either style can
  -- be replaced independently.
  button.border = button:CreateTexture(nil, "OVERLAY")
  button.border:SetTexture("Interface\\AddOns\\WoWTouchUI\\NormalRing")
  button.border:SetPoint("CENTER", button, "CENTER")
  button.border:SetDrawLayer("OVERLAY", 6)
  button.border:SetVertexColor(.25, .25, .25, .9)
  button.border:Show()
  button.editHighlight = button:CreateTexture(nil, "OVERLAY")
  button.editHighlight:SetPoint("TOPLEFT", 4, -4)
  button.editHighlight:SetPoint("BOTTOMRIGHT", -4, 4)
  button.editHighlight:SetColorTexture(.15, 1, .2, .22)
  local editHighlightMask = button:CreateMaskTexture(nil, "OVERLAY")
  editHighlightMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  editHighlightMask:SetAllPoints(button.editHighlight)
  button.editHighlight:AddMaskTexture(editHighlightMask)
  button.editHighlight:Hide()
  button.targetHighlight = button:CreateTexture(nil, "OVERLAY")
  button.targetHighlight:SetPoint("TOPLEFT", 2, -2)
  button.targetHighlight:SetPoint("BOTTOMRIGHT", -2, 2)
  button.targetHighlight:SetColorTexture(1, .78, .08, .32)
  local targetMask = button:CreateMaskTexture(nil, "OVERLAY")
  targetMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  targetMask:SetAllPoints(button.targetHighlight)
  button.targetHighlight:AddMaskTexture(targetMask)
  button.targetHighlight:Hide()
  button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  button.cooldown:SetAllPoints(button)
  button.cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
  button.cooldown:EnableMouse(false)
  button.cooldown:SetHideCountdownNumbers(false)
  button.cooldown:SetDrawSwipe(true)
  button.cooldown:SetDrawEdge(false)
  button.cooldown:SetDrawBling(false)
  button.cooldown:SetSwipeTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  button.cooldown:SetSwipeColor(0, 0, 0, 0.75)
  button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.label:SetPoint("BOTTOM", button, "BOTTOM", 0, 5)
  button.label:SetWidth(240)
  button.label:SetJustifyH("CENTER")
  button.label:SetWordWrap(false)
  button.label:SetTextColor(1, 1, 1)
  local indexLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  indexLabel:SetPoint("LEFT", button, "RIGHT", 8, 0)
  indexLabel:SetText(i)
  -- Fallback for clients that ignore the protected mount action value. The
  -- mount journal API is protected in combat, so only call it while safe.
  button:SetScript("PostClick", function(self)
    if self.actionKind == "mount" and not InCombatLockdown()
        and C_MountJournal and C_MountJournal.SummonByID then
      C_MountJournal.SummonByID(0)
    end
  end)
  button:SetMovable(true)
  local edit = CreateFrame("Button", ADDON.."Builtin"..b.id.."EditButton", UIParent)
  edit:SetAllPoints(button)
  edit:SetFrameStrata("DIALOG")
  edit:SetFrameLevel(70)
  edit:EnableMouse(true)
  edit:EnableMouseWheel(true)
  edit:RegisterForDrag("LeftButton")
  edit:SetScript("OnClick", function() picker:ShowFor(button) end)
  edit:SetScript("OnDragStart", function() button:StartMoving() end)
  edit:SetScript("OnDragStop", function()
    button:StopMovingOrSizing()
    local right, bottom = button:GetRight(), button:GetBottom()
    local x, y = right - UIParent:GetWidth(), bottom
    local settings = button.db
    if math.abs(settings.x - x) > 1 or math.abs(settings.y - y) > 1
        or settings.point ~= "BOTTOMRIGHT" or settings.relPoint ~= "BOTTOMRIGHT" then
      settings.x, settings.y, settings.point, settings.relPoint = x, y, "BOTTOMRIGHT", "BOTTOMRIGHT"
      UpdateButton(button)
      SaveSettings()
    end
  end)
  edit:SetScript("OnMouseWheel", function(_, delta)
    local settings = button.db
    local size = math.max(42, math.min(140, (settings.size or DEFAULT_SIZE) + delta * 4))
    if size ~= settings.size then
      settings.size = size
      UpdateButton(button)
      if WoWTouchUI_AccountDB then SaveSettings() end
    end
  end)
  edit:Hide()
  button.edit = edit
  SetButtonAction(button, ButtonAction(button))
  UpdateButton(button)
  buttons[#buttons + 1] = button
end

local function BuildAddonSettings()
  settingsFrame = CreateFrame("Frame", ADDON.."Settings", UIParent, "BackdropTemplate")
  settingsFrame:SetSize(480, 330)
  settingsFrame:SetPoint("CENTER")
  settingsFrame:SetFrameStrata("FULLSCREEN_DIALOG")
  settingsFrame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 20, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
  settingsFrame:Hide()

  local title = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 25, -23)
  title:SetText("WoWTouchUI 插件设置")

  local close = CreateFrame("Button", nil, settingsFrame, "UIPanelCloseButton")
  close:SetSize(48, 48)
  close:SetPoint("TOPRIGHT", -7, -7)

  local label = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("TOPLEFT", 35, -85)
  label:SetText("技能按钮大小")

  local valueLabel = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  valueLabel:SetPoint("TOPRIGHT", -35, -81)
  settingsFrame.valueLabel = valueLabel

  local slider = CreateFrame("Slider", ADDON.."ButtonScaleSlider", settingsFrame, "OptionsSliderTemplate")
  slider:SetPoint("TOP", settingsFrame, "TOP", 0, -143)
  slider:SetSize(300, 40)
  slider:SetMinMaxValues(1, 1.5)
  slider:SetValueStep(.05)
  slider:SetObeyStepOnDrag(true)
  local thumb = slider:GetThumbTexture()
  if thumb then thumb:SetSize(44, 44) end
  _G[slider:GetName() .. "Low"]:SetText("1.0×")
  _G[slider:GetName() .. "High"]:SetText("1.5×")
  _G[slider:GetName() .. "Text"]:SetText("")
  slider:SetScript("OnValueChanged", function(_, value)
    value = math.floor(value * 20 + .5) / 20
    valueLabel:SetFormattedText("%.2f×", value)
    if settingsFrame.syncing or value == db.buttonScale then return end
    if InCombatLockdown() then
      settingsFrame.syncing = true
      slider:SetValue(db.buttonScale)
      settingsFrame.syncing = false
      valueLabel:SetFormattedText("%.2f×", db.buttonScale)
      return
    end
    db.buttonScale = value
    for _, button in ipairs(buttons) do UpdateButton(button) end
    SaveSettings()
  end)
  settingsFrame.slider = slider

  local minus = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
  minus:SetSize(58, 54)
  minus:SetPoint("RIGHT", slider, "LEFT", -8, 0)
  minus:SetText("−")
  minus:SetScript("OnClick", function() slider:SetValue(math.max(1, db.buttonScale - .05)) end)

  local plus = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
  plus:SetSize(58, 54)
  plus:SetPoint("LEFT", slider, "RIGHT", 8, 0)
  plus:SetText("+")
  plus:SetScript("OnClick", function() slider:SetValue(math.min(1.5, db.buttonScale + .05)) end)

  local namesButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
  namesButton:SetSize(380, 58)
  namesButton:SetPoint("TOP", settingsFrame, "TOP", 0, -225)
  namesButton:SetScript("OnClick", function(self)
    db.showSpellNames = not db.showSpellNames
    self:SetText(db.showSpellNames and "显示技能名字：开" or "显示技能名字：关")
    for _, button in ipairs(buttons) do button.label:SetShown(db.showSpellNames) end
    SaveSettings()
  end)
  settingsFrame.namesButton = namesButton
end

OpenAddonSettings = function()
  if not settingsFrame then BuildAddonSettings() end
  settingsFrame.syncing = true
  settingsFrame.slider:SetValue(db.buttonScale)
  settingsFrame.valueLabel:SetFormattedText("%.2f×", db.buttonScale)
  settingsFrame.namesButton:SetText(db.showSpellNames and "显示技能名字：开" or "显示技能名字：关")
  settingsFrame.syncing = false
  settingsFrame:Show()
end

local function BuildPicker()
  picker = CreateFrame("Frame", ADDON.."Picker", UIParent, "BackdropTemplate")
  picker:SetSize(310, 430); picker:SetPoint("RIGHT", UIParent, "RIGHT", -150, 0); picker:SetFrameStrata("DIALOG"); picker:SetFrameLevel(100); picker:Hide()
  picker:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize=16, insets={left=4,right=4,top=4,bottom=4}})
  picker.title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); picker.title:SetPoint("TOP", 0, -12); picker.title:SetText("选择技能")
  picker.close = CreateFrame("Button", nil, picker, "UIPanelCloseButton"); picker.close:SetPoint("TOPRIGHT", -2, -2)
  picker.scroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate"); picker.scroll:SetPoint("TOPLEFT", 12, -42); picker.scroll:SetPoint("BOTTOMRIGHT", -30, 12)
  picker.content = CreateFrame("Frame", nil, picker.scroll); picker.content:SetSize(260, 1); picker.scroll:SetScrollChild(picker.content)
  picker.rows = {}
  function picker:ShowFor(button)
    if self.target and self.target.targetHighlight then self.target.targetHighlight:Hide() end
    self.target = button
    button.targetHighlight:Show()
    self.title:SetText("正在设置第 " .. button.index .. " 个按钮")
    self:Show()
    for _, row in ipairs(self.rows) do row:Hide() end
    local spells = {}
    spells[#spells + 1] = { kind = "mount", spellID = MOUNT_SPELL, name = "随机偏好坐骑" }
    spells[#spells + 1] = { kind = "item", itemID = 6948, name = "炉石" }
    local recuperate = KnownSpell(RECUPERATE_SPELLS)
    if recuperate then spells[#spells + 1] = { kind = "spell", spellID = recuperate, name = "复原" } end
    local assistedSpell = GetAssistedSpell()
    if assistedSpell then
      spells[#spells + 1] = { kind = "assisted", spellID = assistedSpell, name = ASSISTED_COMBAT_LABEL or "一键辅助" }
    end
    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
      local playerBank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
      local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
      for slot = 1, 500 do
        local info = C_SpellBook.GetSpellBookItemInfo(slot, playerBank)
        if info and info.spellID and info.spellID ~= assistedSpell and (not spellType or info.itemType == spellType) then
          spells[#spells + 1] = { kind = "spell", spellID = info.spellID }
        end
      end
    end
    local y = -4
    for n, entry in ipairs(spells) do
      local spellID = entry.spellID
      local row = self.rows[n] or CreateFrame("Button", nil, self.content)
      self.rows[n] = row; row:SetSize(255, 42); row:SetPoint("TOPLEFT", 0, y); y = y - 44; row:Show()
      row.icon = row.icon or row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(34,34); row.icon:SetPoint("LEFT", 3, 0); row.icon:SetTexture(entry.itemID and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(entry.itemID) or spellID and C_Spell.GetSpellTexture(spellID) or 134400); row.icon:SetTexCoord(.08,.92,.08,.92)
      row.text = row.text or row:CreateFontString(nil,"OVERLAY","GameFontNormal"); row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0); row.text:SetJustifyH("LEFT"); row.text:SetText(entry.name or SpellName(spellID) or tostring(spellID))
      row:SetScript("OnClick", function() SetButtonAction(self.target, entry, true); self.target.targetHighlight:Hide(); self:Hide() end)
    end
    self.content:SetHeight(math.max(1, -y))
  end
end

SetEditMode = function(value)
  if InCombatLockdown() then
    print("WoWTouchUI: 战斗中不能切换设置模式。")
    return
  end
  editMode = value
  if not editShade then
    editShade = CreateFrame("Frame", ADDON.."EditShade", UIParent)
    editShade:SetAllPoints(UIParent)
    editShade:SetFrameStrata("DIALOG")
    editShade:SetFrameLevel(1)
    editShade:EnableMouse(true)
    editShade:EnableMouseWheel(true)
    editShade:SetScript("OnMouseDown", function() end)
    editShade:SetScript("OnMouseUp", function() end)
    editShade:SetScript("OnMouseWheel", function() end)
    local shade = editShade:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, .55)
    editShade:Hide()
  end
  if value then
    if microPanel then microPanel:Hide() end
    if settingsFrame then settingsFrame:Hide() end
    GameTooltip:Hide()
  end
  editShade:SetShown(value)
  if hint then hint:SetShown(value) end
  if editScaleSlider then
    editScaleSlider:SetValue(db.buttonScale)
    editScaleSlider:SetShown(value)
  end
  if editNamesButton then
    editNamesButton:SetText(db.showSpellNames and "技能名字：开" or "技能名字：关")
    editNamesButton:SetShown(value)
  end
  if exitEditButton then exitEditButton:SetShown(value) end
  if resetPositionsButton then resetPositionsButton:SetShown(value) end
  for _, button in ipairs(buttons) do
    button:SetFrameStrata(value and "DIALOG" or "MEDIUM")
    button:SetFrameLevel(value and 60 or 1)
    button:SetAlpha(1)
    button.border:SetShown(true)
    button.editHighlight:SetShown(value and (button.spellID or button.itemID or button.actionKind == "mount"))
    button.targetHighlight:SetShown(false)
    button.edit:SetShown(value)
  end
  if value then print("WoWTouchUI: 设置模式已开启，拖动按钮或点击按钮选择技能。") else picker:Hide(); print("WoWTouchUI: 设置模式已关闭。") end
end

local function Init()
  hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
    tooltip:SetOwner(parent, "ANCHOR_CURSOR_RIGHT")
  end)
  MigrateButtonSettings(WoWTouchUI_AccountDB, 4)
  MigrateButtonSettings(WoWTouchUI_CharacterDB, 2)
  CopyDefaults()
  enabled = not (type(WoWTouchUI_AccountDB) == "table" and WoWTouchUI_AccountDB.enabled == false)
  if not enabled then return end
  DisablePersonalResource()
  SetupMinimap()
  SetupBuffs()
  SetupBags()
  SetupMicroMenu()
  SetupChat()
  C_Timer.After(1, SetupMicroMenu)
  for i = 1, NUM_BUTTONS do CreateButton(i) end
  -- Materialize the four built-in actions in the per-character file on the
  -- first load, so every character has an explicit skill configuration.
  local characterButtons = type(WoWTouchUI_CharacterDB) == "table" and WoWTouchUI_CharacterDB.buttons
  for _, button in ipairs(buttons) do
    if type(characterButtons) ~= "table" or type(characterButtons[button.builtinID]) ~= "table" then
      SaveCharacterAction(button)
    end
  end
  BuildPicker()
  assistedTicker = C_Timer.NewTicker(0.1, UpdateAssistedIcons)
  hint = CreateFrame("Frame", ADDON.."EditHint", UIParent)
  hint:SetSize(520, 36)
  hint:SetPoint("CENTER", UIParent, "CENTER", 0, 105)
  hint:SetFrameStrata("DIALOG")
  hint:SetFrameLevel(100)
  hint:EnableMouse(false)
  hint:Hide()
  editScaleSlider = CreateFrame("Slider", ADDON.."EditScaleSlider", UIParent, "OptionsSliderTemplate")
  editScaleSlider:SetSize(260, 34)
  editScaleSlider:SetPoint("TOP", UIParent, "TOP", 0, -34)
  editScaleSlider:SetMinMaxValues(1, 1.5)
  editScaleSlider:SetValueStep(.05)
  editScaleSlider:SetObeyStepOnDrag(true)
  editScaleSlider:SetFrameStrata("DIALOG")
  editScaleSlider:SetFrameLevel(105)
  _G[editScaleSlider:GetName() .. "Low"]:SetText("1.0×")
  _G[editScaleSlider:GetName() .. "High"]:SetText("1.5×")
  _G[editScaleSlider:GetName() .. "Text"]:SetText("按钮大小")
  editScaleSlider:SetScript("OnValueChanged", function(_, value)
    value = math.floor(value * 20 + .5) / 20
    if value == db.buttonScale or InCombatLockdown() then return end
    db.buttonScale = value
    for _, button in ipairs(buttons) do UpdateButton(button) end
    SaveSettings()
  end)
  editScaleSlider:Hide()
  editNamesButton = CreateFrame("Button", ADDON.."EditNamesButton", UIParent, "UIPanelButtonTemplate")
  editNamesButton:SetSize(210, 42)
  editNamesButton:SetPoint("LEFT", editScaleSlider, "RIGHT", 18, 0)
  editNamesButton:SetFrameStrata("DIALOG")
  editNamesButton:SetFrameLevel(105)
  editNamesButton:SetScript("OnClick", function(self)
    db.showSpellNames = not db.showSpellNames
    self:SetText(db.showSpellNames and "技能名字：开" or "技能名字：关")
    for _, button in ipairs(buttons) do button.label:SetShown(db.showSpellNames) end
    SaveSettings()
  end)
  editNamesButton:Hide()
  exitEditButton = CreateFrame("Button", ADDON.."ExitEditButton", UIParent, "UIPanelButtonTemplate")
  exitEditButton:SetSize(240, 62)
  exitEditButton:SetPoint("BOTTOM", hint, "TOP", 0, 18)
  exitEditButton:SetFrameStrata("DIALOG")
  exitEditButton:SetFrameLevel(100)
  exitEditButton:RegisterForClicks("AnyUp")
  exitEditButton:SetText("退出编辑模式")
  exitEditButton:SetScript("OnClick", function() SetEditMode(false) end)
  exitEditButton:Hide()
  resetPositionsButton = CreateFrame("Button", ADDON.."ResetPositionsButton", UIParent, "UIPanelButtonTemplate")
  resetPositionsButton:SetSize(240, 62)
  resetPositionsButton:SetPoint("TOP", hint, "BOTTOM", 0, -18)
  resetPositionsButton:SetFrameStrata("DIALOG")
  resetPositionsButton:SetFrameLevel(100)
  resetPositionsButton:RegisterForClicks("AnyUp")
  resetPositionsButton:SetText("还原默认配置")
  resetPositionsButton:SetScript("OnClick", ResetButtonPositions)
  resetPositionsButton:Hide()
  initialized = true
  SlashCmdList.WOWTOUCHUI = function(msg)
    msg = (msg or ""):lower()
    if msg == "on" or msg == "开启" then WoWTouchUI_AccountDB.enabled = true; ReloadUI()
    elseif msg == "off" or msg == "关闭" then WoWTouchUI_AccountDB.enabled = false; ReloadUI()
    elseif msg == "edit" or msg == "设置" then SetEditMode(not editMode)
    elseif msg == "config" or msg == "设置面板" then OpenAddonSettings()
    elseif msg == "reset" or msg == "重置" then WoWTouchUI_AccountDB = nil; WoWTouchUI_CharacterDB = nil; CopyDefaults(); for _,b in ipairs(buttons) do b.db=db.buttons[b.index]; SetButtonAction(b,ButtonAction(b)); UpdateButton(b) end
    else print("WoWTouchUI: /wtui on 开启，/wtui off 关闭，/wtui edit 设置模式，/wtui reset 重置布局") end
  end
  print("WoWTouchUI 已加载。输入 /wtui edit 开始设置。")
end

local event = CreateFrame("Frame")
event:RegisterEvent("PLAYER_LOGIN")
event:RegisterEvent("PLAYER_ENTERING_WORLD")
event:RegisterEvent("SPELL_UPDATE_COOLDOWN")
event:RegisterEvent("SPELL_UPDATE_CHARGES")
event:RegisterEvent("SPELLS_CHANGED")
event:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
event:RegisterEvent("PLAYER_REGEN_ENABLED")
event:RegisterEvent("PLAYER_LOGOUT")
event:SetScript("OnEvent", function(_, name)
  if name == "PLAYER_LOGIN" then
    enabled = IsSavedEnabled()
    if not enabled then return end
    Init()
  elseif not enabled and name ~= "PLAYER_LOGOUT" then
    return
  elseif name == "PLAYER_LOGOUT" then
    -- Leave Blizzard chat layout untouched.
  elseif name == "PLAYER_ENTERING_WORLD" then
    if enabled and not InCombatLockdown() then
      SetupMinimap()
      DisablePersonalResource()
      SetupBuffs()
      SetupBags()
      SetupMicroMenu()
      C_Timer.After(1, SetupMicroMenu)
    end
  else
    if name == "SPELLS_CHANGED" or name == "PLAYER_SPECIALIZATION_CHANGED" or name == "PLAYER_REGEN_ENABLED" then RefreshAssistedButtons() end
    if name == "PLAYER_REGEN_ENABLED" then SetupBuffs() end
    UpdateAllCooldowns()
  end
end)










