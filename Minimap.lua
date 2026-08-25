--[[ Minimap button + BiS checklist window ]]

local addon = BiSPulse
local L = BiSPulseLocale
local DATA = BiSPulseData

local minimapBtn
local checklist
local ANGLE_DEFAULT = 220

local function SafeRegister(frame, event)
  if BiSPulseSafeRegisterEvent then
    return BiSPulseSafeRegisterEvent(frame, event)
  end
  return pcall(frame.RegisterEvent, frame, event)
end

local function GetItemIconTexture(itemID)
  if not itemID then
    return "Interface\\Icons\\INV_Misc_QuestionMark"
  end
  local tex
  if C_Item and C_Item.GetItemInfoInstant then
    tex = select(5, C_Item.GetItemInfoInstant(itemID))
  end
  if not tex and GetItemInfoInstant then
    tex = select(5, GetItemInfoInstant(itemID))
  end
  return tex or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function GetMinimapShapeSafe()
  if type(GetMinimapShape) == "function" then
    return GetMinimapShape() or "ROUND"
  end
  return "ROUND"
end

local function UpdateMinimapPosition()
  local db = addon:GetDB()
  if not db or not minimapBtn then
    return
  end
  local angle = math.rad(db.minimapAngle or ANGLE_DEFAULT)
  local x, y = math.cos(angle), math.sin(angle)
  local bound = 80
  local shape = GetMinimapShapeSafe()
  if shape ~= "ROUND" then
    local cos, sin = math.abs(x), math.abs(y)
    if cos > sin then
      bound = 80 / cos * 0.9
    else
      bound = 80 / sin * 0.9
    end
  end
  minimapBtn:ClearAllPoints()
  minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x * bound, y * bound)
end

local function CreateMinimapButton()
  if minimapBtn then
    return minimapBtn
  end

  local btn = CreateFrame("Button", "BiSPulseMinimapButton", Minimap)
  btn:SetSize(32, 32)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)
  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  btn:RegisterForClicks("AnyUp")
  btn:RegisterForDrag("LeftButton")

  local overlay = btn:CreateTexture(nil, "OVERLAY")
  overlay:SetSize(54, 54)
  overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  overlay:SetPoint("TOPLEFT", 0, 0)

  local icon = btn:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetTexture((BiSPulse and BiSPulse.MINIMAP_ICON) or "Interface\\AddOns\\BiSPulse\\Media\\BiSPulseMinimap")
  icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  btn.icon = icon

  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("BiSPulse", 0, 1, 0.59)
    GameTooltip:AddLine(L["MINIMAP_LEFT"], 1, 1, 1)
    GameTooltip:AddLine(L["MINIMAP_RIGHT"], 1, 1, 1)
    GameTooltip:AddLine(L["MINIMAP_DRAG"], 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", GameTooltip_Hide)

  btn:SetScript("OnClick", function(_, button)
    if button == "LeftButton" then
      addon:ToggleChecklist()
    elseif button == "RightButton" then
      addon:OpenOptions()
    end
  end)

  btn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      cx, cy = cx / scale, cy / scale
      local db = addon:GetDB()
      if db then
        db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
      end
      UpdateMinimapPosition()
    end)
  end)
  btn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)

  minimapBtn = btn
  UpdateMinimapPosition()
  return btn
end

function addon:UpdateMinimapButton()
  local db = self:GetDB()
  if not db then
    return
  end
  local ok, btn = pcall(CreateMinimapButton)
  if not ok or not btn then
    return
  end
  if db.minimap == false then
    btn:Hide()
  else
    btn:Show()
    UpdateMinimapPosition()
  end
end

-- Checklist -----------------------------------------------------------------

local function PlayerOwnsItem(itemID)
  return addon:PlayerOwnsItem(itemID)
end

local function BuildSortedEntries(pack)
  local list = {}
  if not pack or not pack.items then
    return list
  end
  for itemID, info in pairs(pack.items) do
    if info and not (info.slot == "Embellishment" or (info.note and info.note:find("Embellishment", 1, true))) then
      if addon:MeetsContentFilter(info) then
        -- Checklist shows BiS + Strong (and lower only if content extras).
        list[#list + 1] = { id = itemID, info = info }
      end
    end
  end
  table.sort(list, function(a, b)
    local sa = DATA.RANK_ORDER[a.info.rank] or 0
    local sb = DATA.RANK_ORDER[b.info.rank] or 0
    if sa ~= sb then
      return sa > sb
    end
    return (a.info.name or "") < (b.info.name or "")
  end)
  return list
end

local function EntryPassesChecklistFilters(entry, db)
  if not entry or not entry.info then
    return false
  end
  local rankFilter = (db and db.checklistRankFilter) or "all"
  if rankFilter ~= "all" and entry.info.rank ~= rankFilter then
    return false
  end
  local slotFilter = (db and db.checklistSlotFilter) or "all"
  if slotFilter ~= "all" then
    local slot = entry.info.slot or ""
    if slot ~= slotFilter then
      return false
    end
  end
  local q = (db and db.checklistSearch) or ""
  q = tostring(q):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if q ~= "" then
    local name = (entry.info.name or ""):lower()
    local drop = (entry.info.drop or ""):lower()
    if not name:find(q, 1, true) and not drop:find(q, 1, true) then
      return false
    end
  end
  return true
end

local function CollectSlotsFromPack(pack)
  local seen = {}
  local slots = {}
  if not pack or not pack.items then
    return slots
  end
  for _, info in pairs(pack.items) do
    local slot = info and info.slot
    if slot and slot ~= "" and slot ~= "Embellishment" and not seen[slot] then
      seen[slot] = true
      slots[#slots + 1] = slot
    end
  end
  table.sort(slots)
  return slots
end

local CHECKLIST_LAYOUT_REV = 4

local function EnsureChecklist()
  if checklist then
    if checklist.layoutRev == CHECKLIST_LAYOUT_REV then
      return checklist
    end
    checklist:Hide()
    checklist:SetParent(nil)
    checklist = nil
  end

  local f = CreateFrame("Frame", "BiSPulseChecklist", UIParent, "BackdropTemplate")
  f.layoutRev = CHECKLIST_LAYOUT_REV
  f:SetSize(460, 540)
  f:SetPoint("CENTER", UIParent, "CENTER", 180, 0)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetFrameLevel(1000)
  f:SetToplevel(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
  })
  f:SetBackdropColor(0.06, 0.07, 0.09, 0.97)
  f:Hide()

  if UISpecialFrames then
    tinsert(UISpecialFrames, "BiSPulseChecklist")
  end

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)
  close:SetFrameLevel((f:GetFrameLevel() or 1) + 20)
  close:EnableMouse(true)
  close:RegisterForClicks("AnyUp")
  close:SetScript("OnClick", function()
    f:Hide()
  end)
  if not close:GetNormalTexture() then
    close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
  end
  f.closeButton = close

  local mainBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  mainBtn:SetSize(72, 20)
  mainBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -36, -16)
  mainBtn:SetText(L["CHECKLIST_MAIN"] or "Main")
  mainBtn:SetScript("OnClick", function()
    local db = addon:GetDB()
    if db then
      db.checklistView = "main"
    end
    addon:RefreshChecklist()
  end)
  f.mainBtn = mainBtn

  local offBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  offBtn:SetSize(72, 20)
  offBtn:SetPoint("RIGHT", mainBtn, "LEFT", -6, 0)
  offBtn:SetText(L["CHECKLIST_OFFSPEC"] or "Offspec")
  offBtn:SetScript("OnClick", function()
    local db = addon:GetDB()
    if not db then
      return
    end
    if not db.trackOffspec then
      addon:Print(L["OFFSPEC_DISABLED"] or "Enable offspec tracking in options first.")
      return
    end
    if not addon:GetOffspecPack() then
      addon:Print(L["NO_OFFSPEC_DATA"] or "No offspec BiS data available.")
      return
    end
    db.checklistView = "off"
    addon:RefreshChecklist()
  end)
  f.offBtn = offBtn

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 18, -16)
  title:SetPoint("RIGHT", offBtn, "LEFT", -10, 0)
  title:SetJustifyH("LEFT")
  title:SetText(L["CHECKLIST_TITLE"] or "BiS Checklist")
  f.title = title

  local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", 18, -42)
  subtitle:SetPoint("RIGHT", f, "RIGHT", -16, 0)
  subtitle:SetJustifyH("LEFT")
  subtitle:SetWordWrap(true)
  f.subtitle = subtitle

  local progress = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  progress:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -6)
  f.progress = progress

  -- Filter row: rank + slot + search
  local rankBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  rankBtn:SetSize(100, 22)
  rankBtn:SetPoint("TOPLEFT", progress, "BOTTOMLEFT", 0, -8)
  local function SyncRankBtn()
    local db = addon:GetDB()
    local v = (db and db.checklistRankFilter) or "all"
    if v == "all" then
      rankBtn:SetText(L["CHECKLIST_FILTER_ALL"] or "All")
    else
      rankBtn:SetText(addon:RankLabel(v))
    end
  end
  rankBtn:SetScript("OnClick", function()
    local order = { "all", "bis", "strong", "alt", "ok" }
    local db = addon:GetDB()
    if not db then
      return
    end
    local current = db.checklistRankFilter or "all"
    local idx = 1
    for i, v in ipairs(order) do
      if v == current then
        idx = i
        break
      end
    end
    db.checklistRankFilter = order[(idx % #order) + 1]
    SyncRankBtn()
    addon:RefreshChecklist()
  end)
  f.rankFilterBtn = rankBtn
  f.SyncRankBtn = SyncRankBtn

  local slotBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  slotBtn:SetSize(100, 22)
  slotBtn:SetPoint("LEFT", rankBtn, "RIGHT", 6, 0)
  local function SyncSlotBtn()
    local db = addon:GetDB()
    local v = (db and db.checklistSlotFilter) or "all"
    if v == "all" then
      slotBtn:SetText(L["CHECKLIST_FILTER_ALL"] or "All")
    else
      slotBtn:SetText(v)
    end
  end
  slotBtn:SetScript("OnClick", function()
    local db = addon:GetDB()
    if not db then
      return
    end
    local pack = addon:GetChecklistPack()
    local slots = CollectSlotsFromPack(pack)
    local order = { "all" }
    for _, s in ipairs(slots) do
      order[#order + 1] = s
    end
    local current = db.checklistSlotFilter or "all"
    local idx = 1
    for i, v in ipairs(order) do
      if v == current then
        idx = i
        break
      end
    end
    db.checklistSlotFilter = order[(idx % #order) + 1]
    SyncSlotBtn()
    addon:RefreshChecklist()
  end)
  f.slotFilterBtn = slotBtn
  f.SyncSlotBtn = SyncSlotBtn

  local search = CreateFrame("EditBox", "BiSPulseChecklistSearch", f, "InputBoxTemplate")
  search:SetSize(200, 20)
  search:SetPoint("LEFT", slotBtn, "RIGHT", 10, 0)
  search:SetAutoFocus(false)
  search:SetMaxLetters(40)
  search:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  search:SetScript("OnTextChanged", function(self, userInput)
    if not userInput then
      return
    end
    local db = addon:GetDB()
    if db then
      db.checklistSearch = self:GetText() or ""
    end
    if addon._checklistSearchTimer then
      addon._checklistSearchTimer:Cancel()
    end
    addon._checklistSearchTimer = C_Timer.NewTimer(0.2, function()
      addon:RefreshChecklist()
    end)
  end)
  search:SetScript("OnEditFocusGained", function(self)
    if self:GetText() == "" then
      -- placeholder via fontstring below
    end
  end)
  f.searchBox = search

  local searchHint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  searchHint:SetPoint("LEFT", search, "LEFT", 6, 0)
  searchHint:SetText(L["CHECKLIST_SEARCH"] or "Search…")
  f.searchHint = searchHint
  search:HookScript("OnTextChanged", function(self)
    if f.searchHint then
      if (self:GetText() or "") == "" and not self:HasFocus() then
        f.searchHint:Show()
      else
        f.searchHint:Hide()
      end
    end
  end)
  search:HookScript("OnEditFocusGained", function()
    if f.searchHint then
      f.searchHint:Hide()
    end
  end)
  search:HookScript("OnEditFocusLost", function(self)
    if f.searchHint and (self:GetText() or "") == "" then
      f.searchHint:Show()
    end
  end)

  local scroll = CreateFrame("ScrollFrame", "BiSPulseChecklistScroll", f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 14, -128)
  scroll:SetPoint("BOTTOMRIGHT", -34, 48)
  f.scroll = scroll

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(380, 1)
  content.rows = {}
  scroll:SetScrollChild(content)
  f.content = content
  f.rows = content.rows

  local refreshBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  refreshBtn:SetSize(110, 22)
  refreshBtn:SetPoint("BOTTOMLEFT", 16, 14)
  refreshBtn:SetText(L["CHECKLIST_REFRESH"] or "Refresh")
  refreshBtn:SetScript("OnClick", function()
    addon:RefreshChecklist()
  end)

  local optsBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  optsBtn:SetSize(110, 22)
  optsBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 8, 0)
  optsBtn:SetText("Options")
  optsBtn:SetScript("OnClick", function()
    addon:OpenOptions()
  end)

  checklist = f
  return f
end

local function GetOrCreateRow(parent, index)
  if not parent.rows then
    parent.rows = {}
  end
  local row = parent.rows[index]
  if row then
    return row
  end

  row = CreateFrame("Button", nil, parent)
  row:SetSize(370, 40)
  row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight", "ADD")

  local check = row:CreateTexture(nil, "ARTWORK")
  check:SetSize(16, 16)
  check:SetPoint("LEFT", 4, 0)
  row.check = check

  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(28, 28)
  icon:SetPoint("LEFT", check, "RIGHT", 6, 0)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.icon = icon

  local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 2)
  name:SetPoint("RIGHT", row, "RIGHT", -8, 0)
  name:SetJustifyH("LEFT")
  name:SetWordWrap(false)
  row.name = name

  local drop = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  drop:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
  drop:SetPoint("RIGHT", row, "RIGHT", -8, 0)
  drop:SetJustifyH("LEFT")
  drop:SetWordWrap(false)
  drop:SetTextColor(0.65, 0.72, 0.82)
  row.drop = drop

  row:SetScript("OnEnter", function(self)
    if not self.itemID then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then
      GameTooltip:SetItemByID(self.itemID)
    else
      GameTooltip:SetHyperlink("item:" .. self.itemID)
    end
    if self.dropText and self.dropText ~= "" then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine((L["CHECKLIST_DROP"] or "Drops from") .. ": " .. self.dropText, 0.7, 0.85, 1)
    end
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", GameTooltip_Hide)

  parent.rows[index] = row
  return row
end

local function ResolveItemName(itemID, fallback)
  if C_Item and C_Item.GetItemNameByID then
    local n = C_Item.GetItemNameByID(itemID)
    if n and n ~= "" then
      return n
    end
  end
  local n = GetItemInfo(itemID)
  if n and n ~= "" then
    return n
  end
  if fallback and not tostring(fallback):find("^Item %d+$") and not tostring(fallback):find("^#%d+$") then
    return fallback
  end
  return fallback or ("#" .. tostring(itemID))
end

function addon:RefreshChecklist()
  local f = EnsureChecklist()
  local pack, _, _, isOff = self:GetChecklistPack()
  if not pack then
    f.subtitle:SetText(L["NO_SPEC_DATA"] or "No spec data")
    f.progress:SetText("")
    for _, row in ipairs(f.content.rows) do
      row:Hide()
    end
    return
  end

  local viewTag = isOff and (L["OFFSPEC"] or "Offspec") or (L["MAINSPEC"] or "Main")
  f.subtitle:SetText(("%s %s [%s] - %s - Wowhead %s"):format(
    pack.specName or "?",
    pack.className or "?",
    viewTag,
    pack.season or pack.patch or "?",
    pack.updated or "?"
  ))

  local db = self:GetDB()
  if f.mainBtn and f.offBtn then
    local onOff = db and db.checklistView == "off" and db.trackOffspec and self:GetOffspecPack()
    if onOff then
      f.offBtn:Disable()
      f.mainBtn:Enable()
    else
      f.mainBtn:Disable()
      f.offBtn:Enable()
    end
  end

  local entries = BuildSortedEntries(pack)
  local filtered = {}
  for _, entry in ipairs(entries) do
    if EntryPassesChecklistFilters(entry, db) then
      filtered[#filtered + 1] = entry
    end
  end
  entries = filtered

  if f.SyncRankBtn then
    f.SyncRankBtn()
  end
  if f.SyncSlotBtn then
    f.SyncSlotBtn()
  end
  if f.searchBox and db then
    local want = db.checklistSearch or ""
    if f.searchBox:GetText() ~= want and not f.searchBox:HasFocus() then
      f.searchBox:SetText(want)
    end
    if f.searchHint then
      if want == "" and not f.searchBox:HasFocus() then
        f.searchHint:Show()
      else
        f.searchHint:Hide()
      end
    end
  end

  local ownedCount = 0
  local y = 0
  local rows = f.content.rows

  for i, entry in ipairs(entries) do
    local row = GetOrCreateRow(f.content, i)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -y)
    row.itemID = entry.id

    local owned, where = PlayerOwnsItem(entry.id)
    if owned then
      ownedCount = ownedCount + 1
      row.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
      row:SetAlpha(1)
    else
      row.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
      row:SetAlpha(0.85)
    end

    row.icon:SetTexture(GetItemIconTexture(entry.id))
    row.name:SetText(ResolveItemName(entry.id, entry.info.name))
    if entry.info.rank == "bis" then
      row.name:SetTextColor(1, 0.85, 0.2)
    elseif entry.info.rank == "strong" then
      row.name:SetTextColor(0, 1, 0.59)
    else
      row.name:SetTextColor(0.85, 0.9, 1)
    end

    local dropParts = {}
    if entry.info.slot and entry.info.slot ~= "" then
      dropParts[#dropParts + 1] = entry.info.slot
    end
    if entry.info.drop and entry.info.drop ~= "" then
      dropParts[#dropParts + 1] = entry.info.drop
    end
    if owned and where == "equipped" then
      dropParts[#dropParts + 1] = (L["CHECKLIST_EQUIPPED"] or "equipped")
    elseif owned and where == "bags" then
      dropParts[#dropParts + 1] = (L["CHECKLIST_BAGS"] or "bags")
    elseif owned and where == "bank" then
      dropParts[#dropParts + 1] = (L["CHECKLIST_BANK"] or "bank")
    end
    local dropText = table.concat(dropParts, " · ")
    row.dropText = entry.info.drop or ""
    row.drop:SetText(dropText)
    row:Show()
    y = y + 42
  end

  for i = #entries + 1, #rows do
    rows[i]:Hide()
  end

  f.content:SetHeight(math.max(1, y))
  local progressFmt = L["CHECKLIST_PROGRESS"] or "Owned: %d / %d"
  f.progress:SetText(progressFmt:format(ownedCount, #entries))
end

function addon:ToggleChecklist()
  -- Drop broken cached frame from older builds
  if checklist and (not checklist.content or not checklist.content.rows) then
    checklist:Hide()
    checklist = nil
  end
  -- Migrate frames without drop line (pre-1.5.1)
  if checklist and checklist.content and checklist.content.rows and checklist.content.rows[1] and not checklist.content.rows[1].drop then
    checklist:Hide()
    checklist = nil
  end
  -- Migrate old frames that had a non-working close button
  if checklist and checklist.closeButton and not checklist.closeButton._bisAlertFixed then
    checklist:Hide()
    checklist = nil
  end
  local ok, err = pcall(function()
    local f = EnsureChecklist()
    if f.closeButton then
      f.closeButton._bisAlertFixed = true
    end
    if f:IsShown() then
      f:Hide()
      return
    end
    self:RefreshChecklist()
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(1000)
    f:Show()
    f:Raise()
    if f.closeButton then
      f.closeButton:SetFrameLevel(f:GetFrameLevel() + 20)
      f.closeButton:Raise()
    end
  end)
  if not ok then
    self:Print("Checklist error: " .. tostring(err))
  end
end

function addon:ShowChecklist()
  local ok, err = pcall(function()
    local f = EnsureChecklist()
    self:RefreshChecklist()
    f:Show()
    f:Raise()
  end)
  if not ok then
    self:Print("Checklist error: " .. tostring(err))
  end
end

local boot = CreateFrame("Frame")
SafeRegister(boot, "PLAYER_LOGIN")
SafeRegister(boot, "PLAYER_EQUIPMENT_CHANGED")
SafeRegister(boot, "BAG_UPDATE_DELAYED")
boot:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    addon:UpdateMinimapButton()
  elseif checklist and checklist:IsShown() then
    pcall(function()
      addon:RefreshChecklist()
    end)
  end
end)
