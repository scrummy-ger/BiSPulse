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

local function ParsePopularity(info)
  if not info then
    return nil
  end
  if type(info.popularity) == "number" then
    return info.popularity
  end
  if info.note then
    local pct = info.note:match("^Archon%s+([%d%.]+)%%")
    if pct then
      return tonumber(pct)
    end
  end
  return nil
end

local function BuildSortedEntries(pack, sortMode)
  local list = {}
  if not pack or not pack.items then
    return list
  end
  for itemID, info in pairs(pack.items) do
    if info and not (info.slot == "Embellishment" or (info.note and info.note:find("Embellishment", 1, true))) then
      if addon:MeetsContentFilter(info) then
        list[#list + 1] = { id = itemID, info = info }
      end
    end
  end
  sortMode = sortMode or "rank"
  table.sort(list, function(a, b)
    if sortMode == "name" then
      local na, nb = a.info.name or "", b.info.name or ""
      if na ~= nb then
        return na < nb
      end
    elseif sortMode == "slot" then
      local sa, sb = a.info.slot or "", b.info.slot or ""
      if sa ~= sb then
        return sa < sb
      end
    elseif sortMode == "missing" then
      local oa = PlayerOwnsItem(a.id) and 1 or 0
      local ob = PlayerOwnsItem(b.id) and 1 or 0
      if oa ~= ob then
        return oa < ob -- missing first
      end
    end
    local ra = DATA.RANK_ORDER[a.info.rank] or 0
    local rb = DATA.RANK_ORDER[b.info.rank] or 0
    if ra ~= rb then
      return ra > rb
    end
    local pa, pb = ParsePopularity(a.info) or -1, ParsePopularity(b.info) or -1
    if pa ~= pb then
      return pa > pb
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
  if db and db.checklistMissingOnly then
    if PlayerOwnsItem(entry.id) then
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

local function CollectSlotsFromPack(pack, rankFilter)
  local seen = {}
  local slots = {}
  if not pack or not pack.items then
    return slots
  end
  rankFilter = rankFilter or "all"
  for _, info in pairs(pack.items) do
    if info and addon:MeetsContentFilter(info) then
      if rankFilter == "all" or info.rank == rankFilter then
        local slot = info.slot
        if slot and slot ~= "" and slot ~= "Embellishment" and not seen[slot] then
          seen[slot] = true
          slots[#slots + 1] = slot
        end
      end
    end
  end
  table.sort(slots)
  return slots
end

local function ShortRankLabel(rank)
  if rank == "all" then
    return L["CHECKLIST_FILTER_ALL"] or "All"
  elseif rank == "bis" then
    return L["CHECKLIST_RANK_BIS"] or "BiS"
  elseif rank == "strong" then
    return L["CHECKLIST_RANK_STRONG"] or "Strong"
  elseif rank == "alt" then
    return L["CHECKLIST_RANK_ALT"] or "Alt"
  elseif rank == "ok" then
    return L["CHECKLIST_RANK_OK"] or "Niche"
  end
  return addon:RankLabel(rank)
end

-- Flat dark / green accent skin (inspired by modern addon UIs like GRIP-EMS).
local SKIN = {
  bg = { 0.05, 0.05, 0.06, 0.98 },
  panel = { 0.09, 0.09, 0.10, 1 },
  border = { 0.28, 0.28, 0.30, 1 },
  accent = { 0.15, 0.85, 0.35, 1 },
  text = { 0.92, 0.94, 0.96, 1 },
  muted = { 0.55, 0.58, 0.62, 1 },
  title = { 0.95, 0.97, 1.0, 1 },
}

local function SkinBackdrop(frame, bg, border, edgeSize)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = edgeSize or 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  local c = bg or SKIN.bg
  frame:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
  local b = border or SKIN.border
  frame:SetBackdropBorderColor(b[1], b[2], b[3], b[4] or 1)
end

-- Small down-caret drawn with textures (WoW fonts often lack ▾ and show □).
local function AttachDropCaret(parent)
  local caret = CreateFrame("Frame", nil, parent)
  caret:SetSize(10, 6)
  caret:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
  local function arm(rot, ox)
    local t = caret:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(1, 1, 1, 1)
    t:SetSize(7, 1.25)
    t:SetPoint("CENTER", caret, "CENTER", ox, 0.5)
    if t.SetRotation then
      t:SetRotation(math.rad(rot))
    end
    return t
  end
  caret.left = arm(38, -1.6)
  caret.right = arm(-38, 1.6)
  function caret:SetMuted(muted)
    local c = muted and SKIN.muted or SKIN.accent
    if self.left then
      self.left:SetColorTexture(c[1], c[2], c[3], 1)
    end
    if self.right then
      self.right:SetColorTexture(c[1], c[2], c[3], 1)
    end
  end
  caret:SetMuted(true)
  parent.caret = caret
  return caret
end

local function CreateFlatDrop(parent, width, height, initialText)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(width, height)
  SkinBackdrop(b, SKIN.panel, SKIN.border, 1)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("LEFT", 10, 0)
  fs:SetPoint("RIGHT", -22, 0)
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(false)
  fs:SetText(initialText or "")
  fs:SetTextColor(SKIN.text[1], SKIN.text[2], SKIN.text[3], 1)
  b.text = fs
  AttachDropCaret(b)
  b:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(SKIN.accent[1], SKIN.accent[2], SKIN.accent[3], 1)
    if self.caret then
      self.caret:SetMuted(false)
    end
  end)
  b:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(SKIN.border[1], SKIN.border[2], SKIN.border[3], 1)
    if self.caret then
      self.caret:SetMuted(true)
    end
  end)
  function b:SetLabel(text)
    if self.text then
      self.text:SetText(text or "")
    end
  end
  return b
end

local flatMenu

local function IsUnderFrame(frame, node)
  local cur = node
  while cur do
    if cur == frame then
      return true
    end
    cur = cur.GetParent and cur:GetParent() or nil
  end
  return false
end

local function MouseOverFlatMenuOrAnchor()
  if not flatMenu then
    return false
  end
  local foci = (GetMouseFoci and GetMouseFoci()) or nil
  if foci and #foci > 0 then
    for _, focus in ipairs(foci) do
      if IsUnderFrame(flatMenu, focus) then
        return true
      end
      if flatMenu.anchor and IsUnderFrame(flatMenu.anchor, focus) then
        return true
      end
    end
    return false
  end
  local focus = GetMouseFocus and GetMouseFocus() or nil
  if focus then
    return IsUnderFrame(flatMenu, focus) or (flatMenu.anchor and IsUnderFrame(flatMenu.anchor, focus))
  end
  return (flatMenu:IsMouseOver() and true or false)
    or (flatMenu.anchor and flatMenu.anchor:IsMouseOver() and true or false)
end

local function HideFlatMenu()
  if not flatMenu then
    return
  end
  flatMenu:UnregisterEvent("GLOBAL_MOUSE_DOWN")
  flatMenu:Hide()
end

local function DiscardFlatMenu()
  HideFlatMenu()
  if flatMenu then
    flatMenu:SetParent(nil)
    flatMenu = nil
  end
end

local function ShowFlatMenu(anchor, entries)
  if not flatMenu then
    -- Anonymous + TOOLTIP strata: stays above checklist SetToplevel raises.
    flatMenu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    flatMenu:SetFrameStrata("TOOLTIP")
    flatMenu:SetFrameLevel(100)
    flatMenu:SetClampedToScreen(true)
    flatMenu:EnableMouse(true)
    SkinBackdrop(flatMenu, SKIN.bg, SKIN.accent, 1)
    flatMenu.buttons = {}
    flatMenu:SetScript("OnHide", function(self)
      self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
      for _, btn in ipairs(self.buttons) do
        btn:Hide()
      end
    end)
    flatMenu:SetScript("OnEvent", function(self, event)
      if event ~= "GLOBAL_MOUSE_DOWN" or not self:IsShown() then
        return
      end
      -- Defer so button MouseDown/OnClick can run before we dismiss.
      C_Timer.After(0, function()
        if not flatMenu or not flatMenu:IsShown() then
          return
        end
        if not MouseOverFlatMenuOrAnchor() then
          HideFlatMenu()
        end
      end)
    end)
  end

  flatMenu.anchor = anchor
  flatMenu:UnregisterEvent("GLOBAL_MOUSE_DOWN")
  local width = math.max(anchor:GetWidth() or 120, 120)
  local y = -6
  local i = 0
  for _, entry in ipairs(entries or {}) do
    i = i + 1
    local btn = flatMenu.buttons[i]
    if not btn then
      btn = CreateFrame("Button", nil, flatMenu, "BackdropTemplate")
      btn:SetHeight(26)
      btn:EnableMouse(true)
      btn:RegisterForClicks("LeftButtonDown")
      SkinBackdrop(btn, SKIN.panel, { 0.09, 0.09, 0.10, 0 }, 1)
      local accent = btn:CreateTexture(nil, "ARTWORK")
      accent:SetWidth(2)
      accent:SetPoint("TOPLEFT", 0, 0)
      accent:SetPoint("BOTTOMLEFT", 0, 0)
      accent:SetColorTexture(SKIN.accent[1], SKIN.accent[2], SKIN.accent[3], 1)
      accent:Hide()
      btn.accent = accent
      local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      fs:SetPoint("LEFT", 12, 0)
      fs:SetPoint("RIGHT", -10, 0)
      fs:SetJustifyH("LEFT")
      btn.text = fs
      btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.08, 0.16, 0.10, 1)
        self:SetBackdropBorderColor(SKIN.accent[1], SKIN.accent[2], SKIN.accent[3], 0.5)
      end)
      btn:SetScript("OnLeave", function(self)
        if self._checked then
          self:SetBackdropColor(0.07, 0.12, 0.09, 1)
        else
          self:SetBackdropColor(SKIN.panel[1], SKIN.panel[2], SKIN.panel[3], 1)
        end
        self:SetBackdropBorderColor(0.09, 0.09, 0.10, 0)
      end)
      -- LeftButtonDown: select before deferred outside-click dismiss runs.
      btn:SetScript("OnClick", function(self)
        local func = self._menuFunc
        HideFlatMenu()
        if func then
          func()
        end
      end)
      flatMenu.buttons[i] = btn
    end
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", 6, y)
    btn:SetPoint("TOPRIGHT", -6, y)
    btn:SetFrameLevel((flatMenu:GetFrameLevel() or 1) + 5)
    btn.text:SetText(entry.text or "")
    btn._checked = entry.checked and true or false
    if btn.accent then
      if entry.checked then
        btn.accent:Show()
        btn:SetBackdropColor(0.07, 0.12, 0.09, 1)
        btn.text:SetTextColor(SKIN.accent[1], SKIN.accent[2], SKIN.accent[3], 1)
      else
        btn.accent:Hide()
        btn:SetBackdropColor(SKIN.panel[1], SKIN.panel[2], SKIN.panel[3], 1)
        btn.text:SetTextColor(SKIN.text[1], SKIN.text[2], SKIN.text[3], 1)
      end
    end
    btn._menuFunc = entry.func
    btn:Show()
    y = y - 28
  end
  for j = i + 1, #flatMenu.buttons do
    flatMenu.buttons[j]:Hide()
  end

  flatMenu:SetSize(width + 4, math.abs(y) + 8)
  flatMenu:ClearAllPoints()
  flatMenu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  flatMenu:SetFrameStrata("TOOLTIP")
  flatMenu:SetFrameLevel(100)
  flatMenu:Show()
  -- Ignore the opening click; listen for the next outside click.
  C_Timer.After(0, function()
    if flatMenu and flatMenu:IsShown() then
      flatMenu:RegisterEvent("GLOBAL_MOUSE_DOWN")
    end
  end)
end

local CHECKLIST_LAYOUT_REV = 15

local function NextChecklistFrameName()
  addon._checklistFrameSeq = (addon._checklistFrameSeq or 0) + 1
  return "BiSPulseChecklist_" .. tostring(addon._checklistFrameSeq)
end

local function CreateFlatButton(parent, width, height, label)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(width, height)
  SkinBackdrop(b, SKIN.panel, SKIN.border, 1)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("CENTER")
  fs:SetText(label or "")
  fs:SetTextColor(SKIN.text[1], SKIN.text[2], SKIN.text[3], 1)
  b.text = fs
  b:SetScript("OnEnter", function(self)
    if not self:IsEnabled() then
      return
    end
    self:SetBackdropBorderColor(SKIN.accent[1], SKIN.accent[2], SKIN.accent[3], 1)
  end)
  b:SetScript("OnLeave", function(self)
    if self._active then
      self:SetBackdropBorderColor(SKIN.accent[1], SKIN.accent[2], SKIN.accent[3], 1)
    else
      self:SetBackdropBorderColor(SKIN.border[1], SKIN.border[2], SKIN.border[3], 1)
    end
  end)
  b:SetScript("OnDisable", function(self)
    if self.text then
      self.text:SetTextColor(SKIN.muted[1], SKIN.muted[2], SKIN.muted[3], 1)
    end
  end)
  b:SetScript("OnEnable", function(self)
    if self.text then
      self.text:SetTextColor(SKIN.text[1], SKIN.text[2], SKIN.text[3], 1)
    end
  end)
  function b:SetActive(active)
    self._active = active and true or false
    if active then
      self:SetBackdropBorderColor(SKIN.accent[1], SKIN.accent[2], SKIN.accent[3], 1)
      self:SetBackdropColor(0.08, 0.16, 0.10, 1)
    else
      self:SetBackdropBorderColor(SKIN.border[1], SKIN.border[2], SKIN.border[3], 1)
      self:SetBackdropColor(SKIN.panel[1], SKIN.panel[2], SKIN.panel[3], 1)
    end
  end
  return b
end

local function EnsureChecklist()
  if checklist then
    if checklist.layoutRev == CHECKLIST_LAYOUT_REV then
      return checklist
    end
    checklist:Hide()
    checklist:SetParent(nil)
    checklist = nil
    DiscardFlatMenu()
  end

  -- Unique frame name avoids CreateFrame collisions when the layout is rebuilt mid-session.
  local frameName = NextChecklistFrameName()
  local f = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
  f.layoutRev = CHECKLIST_LAYOUT_REV
  f:SetSize(480, 580)
  f:SetPoint("CENTER", UIParent, "CENTER", 180, 0)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetFrameLevel(1000)
  f:SetToplevel(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  SkinBackdrop(f, SKIN.bg, SKIN.accent, 1)
  f:Hide()
  f:HookScript("OnHide", function()
    HideFlatMenu()
  end)

  if UISpecialFrames then
    tinsert(UISpecialFrames, frameName)
  end

  local close = CreateFlatButton(f, 24, 24, "X")
  close:SetPoint("TOPRIGHT", -10, -10)
  close:SetFrameLevel((f:GetFrameLevel() or 1) + 20)
  if close.text then
    close.text:SetFontObject(GameFontNormalLarge)
  end
  close:SetScript("OnClick", function()
    f:Hide()
  end)
  f.closeButton = close

  local mainBtn = CreateFlatButton(f, 64, 24, L["CHECKLIST_MAIN"] or "Main")
  mainBtn:SetPoint("TOPRIGHT", close, "TOPLEFT", -8, 0)
  mainBtn:SetScript("OnClick", function()
    local db = addon:GetDB()
    if db then
      db.checklistView = "main"
    end
    addon:RefreshChecklist()
  end)
  f.mainBtn = mainBtn

  local offBtn = CreateFlatButton(f, 72, 24, L["CHECKLIST_OFFSPEC"] or "Offspec")
  offBtn:SetPoint("RIGHT", mainBtn, "LEFT", -6, 0)
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
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetPoint("RIGHT", offBtn, "LEFT", -10, 0)
  title:SetJustifyH("LEFT")
  title:SetText(L["CHECKLIST_TITLE"] or "BiS Checklist")
  title:SetTextColor(SKIN.title[1], SKIN.title[2], SKIN.title[3], 1)
  f.title = title

  local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", 16, -40)
  subtitle:SetPoint("RIGHT", f, "RIGHT", -16, 0)
  subtitle:SetJustifyH("LEFT")
  subtitle:SetWordWrap(true)
  subtitle:SetTextColor(SKIN.muted[1], SKIN.muted[2], SKIN.muted[3], 1)
  f.subtitle = subtitle

  local progress = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  progress:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -6)
  progress:SetTextColor(SKIN.accent[1], SKIN.accent[2], SKIN.accent[3], 1)
  f.progress = progress

  -- Filter row: flat rank / slot / sort drops
  local rankDrop
  local slotDrop

  local function SyncRankDrop()
    if not rankDrop or not rankDrop.SetLabel then
      return
    end
    local db = addon:GetDB()
    rankDrop:SetLabel(ShortRankLabel((db and db.checklistRankFilter) or "all"))
  end

  local function SyncSlotDrop()
    if not slotDrop or not slotDrop.SetLabel then
      return
    end
    local db = addon:GetDB()
    local v = (db and db.checklistSlotFilter) or "all"
    if v == "all" then
      slotDrop:SetLabel(L["CHECKLIST_FILTER_ALL"] or "All")
    else
      slotDrop:SetLabel(v)
    end
  end

  local function SortLabel(mode)
    if mode == "name" then
      return L["CHECKLIST_SORT_NAME"] or "Name"
    elseif mode == "slot" then
      return L["CHECKLIST_SORT_SLOT"] or "Slot"
    elseif mode == "missing" then
      return L["CHECKLIST_SORT_MISSING"] or "Missing first"
    end
    return L["CHECKLIST_SORT_RANK"] or "Rank"
  end

  local function SyncSortDrop()
    if not f.sortDrop or not f.sortDrop.SetLabel then
      return
    end
    local db = addon:GetDB()
    f.sortDrop:SetLabel(SortLabel((db and db.checklistSort) or "rank"))
  end

  rankDrop = CreateFlatDrop(f, 100, 28, ShortRankLabel("all"))
  rankDrop:SetPoint("TOPLEFT", progress, "BOTTOMLEFT", 0, -8)
  rankDrop:SetScript("OnClick", function(self)
    if flatMenu and flatMenu:IsShown() and flatMenu.anchor == self then
      HideFlatMenu()
      return
    end
    local current = (addon:GetDB() and addon:GetDB().checklistRankFilter) or "all"
    local order = {
      { value = "all", text = L["CHECKLIST_FILTER_ALL"] or "All" },
      { value = "bis", text = ShortRankLabel("bis") },
      { value = "strong", text = ShortRankLabel("strong") },
      { value = "alt", text = ShortRankLabel("alt") },
      { value = "ok", text = ShortRankLabel("ok") },
    }
    local entries = {}
    for _, row in ipairs(order) do
      entries[#entries + 1] = {
        text = row.text,
        checked = current == row.value,
        func = function()
          local db = addon:GetDB()
          if not db then
            return
          end
          db.checklistRankFilter = row.value
          db.checklistSlotFilter = "all"
          SyncRankDrop()
          SyncSlotDrop()
          addon:RefreshChecklist()
        end,
      }
    end
    ShowFlatMenu(self, entries)
  end)
  f.rankFilterDrop = rankDrop
  f.SyncRankBtn = SyncRankDrop
  SyncRankDrop()

  slotDrop = CreateFlatDrop(f, 110, 28, L["CHECKLIST_FILTER_ALL"] or "All")
  slotDrop:SetPoint("LEFT", rankDrop, "RIGHT", 8, 0)
  slotDrop:SetScript("OnClick", function(self)
    if flatMenu and flatMenu:IsShown() and flatMenu.anchor == self then
      HideFlatMenu()
      return
    end
    local db = addon:GetDB()
    local pack = addon:GetChecklistPack()
    local slots = CollectSlotsFromPack(pack, (db and db.checklistRankFilter) or "all")
    local current = (db and db.checklistSlotFilter) or "all"
    local entries = {
      {
        text = L["CHECKLIST_FILTER_ALL"] or "All",
        checked = current == "all",
        func = function()
          local d = addon:GetDB()
          if d then
            d.checklistSlotFilter = "all"
          end
          SyncSlotDrop()
          addon:RefreshChecklist()
        end,
      },
    }
    for _, s in ipairs(slots) do
      local slotValue = s
      entries[#entries + 1] = {
        text = slotValue,
        checked = current == slotValue,
        func = function()
          local d = addon:GetDB()
          if d then
            d.checklistSlotFilter = slotValue
          end
          SyncSlotDrop()
          addon:RefreshChecklist()
        end,
      }
    end
    ShowFlatMenu(self, entries)
  end)
  f.slotFilterDrop = slotDrop
  f.SyncSlotBtn = SyncSlotDrop
  SyncSlotDrop()

  local sortDrop = CreateFlatDrop(f, 120, 28, SortLabel("rank"))
  sortDrop:SetPoint("LEFT", slotDrop, "RIGHT", 8, 0)
  sortDrop:SetScript("OnClick", function(self)
    if flatMenu and flatMenu:IsShown() and flatMenu.anchor == self then
      HideFlatMenu()
      return
    end
    local current = (addon:GetDB() and addon:GetDB().checklistSort) or "rank"
    local order = {
      { value = "rank", text = SortLabel("rank") },
      { value = "name", text = SortLabel("name") },
      { value = "slot", text = SortLabel("slot") },
      { value = "missing", text = SortLabel("missing") },
    }
    local entries = {}
    for _, row in ipairs(order) do
      entries[#entries + 1] = {
        text = row.text,
        checked = current == row.value,
        func = function()
          local db = addon:GetDB()
          if db then
            db.checklistSort = row.value
          end
          SyncSortDrop()
          addon:RefreshChecklist()
        end,
      }
    end
    ShowFlatMenu(self, entries)
  end)
  f.sortDrop = sortDrop
  f.SyncSortDrop = SyncSortDrop
  SyncSortDrop()

  -- Full-width search row (fixes overflow against the right edge)
  local search = CreateFrame("EditBox", nil, f, "BackdropTemplate")
  search:SetHeight(28)
  search:SetPoint("TOPLEFT", 16, -118)
  search:SetPoint("TOPRIGHT", -16, -118)
  search:SetAutoFocus(false)
  search:SetMaxLetters(40)
  search:SetFontObject(GameFontHighlight)
  search:SetTextInsets(10, 10, 0, 0)
  search:SetTextColor(SKIN.text[1], SKIN.text[2], SKIN.text[3], 1)
  SkinBackdrop(search, SKIN.panel, SKIN.border, 1)
  search:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  search:SetScript("OnEditFocusGained", function(self)
    self:SetBackdropBorderColor(SKIN.accent[1], SKIN.accent[2], SKIN.accent[3], 1)
    if f.searchHint then
      f.searchHint:Hide()
    end
  end)
  search:SetScript("OnEditFocusLost", function(self)
    self:SetBackdropBorderColor(SKIN.border[1], SKIN.border[2], SKIN.border[3], 1)
    if f.searchHint and (self:GetText() or "") == "" then
      f.searchHint:Show()
    end
  end)
  search:SetScript("OnTextChanged", function(self, userInput)
    if f.searchHint then
      if (self:GetText() or "") == "" and not self:HasFocus() then
        f.searchHint:Show()
      else
        f.searchHint:Hide()
      end
    end
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
  f.searchBox = search

  local searchHint = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  searchHint:SetPoint("LEFT", search, "LEFT", 10, 0)
  searchHint:SetText(L["CHECKLIST_SEARCH"] or "Search...")
  searchHint:SetTextColor(SKIN.muted[1], SKIN.muted[2], SKIN.muted[3], 1)
  f.searchHint = searchHint

  local missingCb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  missingCb:SetPoint("TOPLEFT", search, "BOTTOMLEFT", -4, -6)
  missingCb:SetSize(24, 24)
  missingCb:SetScript("OnClick", function(self)
    local db = addon:GetDB()
    if db then
      db.checklistMissingOnly = self:GetChecked() and true or false
    end
    addon:RefreshChecklist()
  end)
  f.missingOnlyCheck = missingCb
  local missingLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  missingLabel:SetPoint("LEFT", missingCb, "RIGHT", 2, 0)
  missingLabel:SetText(L["CHECKLIST_MISSING_ONLY"] or "Only missing")
  missingLabel:SetTextColor(SKIN.text[1], SKIN.text[2], SKIN.text[3], 1)
  f.missingOnlyLabel = missingLabel

  local empty = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  empty:SetPoint("TOP", f, "TOP", 0, -250)
  empty:SetWidth(400)
  empty:SetJustifyH("CENTER")
  empty:SetTextColor(SKIN.muted[1], SKIN.muted[2], SKIN.muted[3], 1)
  empty:Hide()
  f.emptyLabel = empty

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 14, -178)
  scroll:SetPoint("BOTTOMRIGHT", -34, 52)
  f.scroll = scroll

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(420, 1)
  content.rows = {}
  scroll:SetScrollChild(content)
  f.content = content
  f.rows = content.rows

  local refreshBtn = CreateFlatButton(f, 110, 28, L["CHECKLIST_REFRESH"] or "Refresh")
  refreshBtn:SetPoint("BOTTOMLEFT", 16, 14)
  refreshBtn:SetScript("OnClick", function()
    addon:RefreshChecklist()
  end)

  local optsBtn = CreateFlatButton(f, 110, 28, L["CHECKLIST_OPTIONS"] or "Options")
  optsBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 8, 0)
  optsBtn:SetScript("OnClick", function()
    addon:OpenOptions()
  end)

  local guidesBtn = CreateFlatButton(f, 110, 28, L["CHECKLIST_GUIDES"] or "Guides")
  guidesBtn:SetPoint("LEFT", optsBtn, "RIGHT", 8, 0)
  guidesBtn:SetScript("OnClick", function()
    if addon.PrintGuideLinks then
      addon:PrintGuideLinks()
    end
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

  row = CreateFrame("Button", nil, parent, "BackdropTemplate")
  row:SetSize(420, 42)
  SkinBackdrop(row, { 0.07, 0.07, 0.08, 0.0 }, { 0.07, 0.07, 0.08, 0.0 }, 1)
  row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
  local ht = row:GetHighlightTexture()
  if ht then
    ht:SetVertexColor(0.15, 0.85, 0.35)
    ht:SetAlpha(0.12)
  end

  local check = row:CreateTexture(nil, "ARTWORK")
  check:SetSize(16, 16)
  check:SetPoint("LEFT", 6, 0)
  row.check = check

  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(28, 28)
  icon:SetPoint("LEFT", check, "RIGHT", 8, 0)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.icon = icon

  local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 2)
  name:SetPoint("RIGHT", row, "RIGHT", -10, 0)
  name:SetJustifyH("LEFT")
  name:SetWordWrap(false)
  row.name = name

  local drop = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  drop:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
  drop:SetPoint("RIGHT", row, "RIGHT", -10, 0)
  drop:SetJustifyH("LEFT")
  drop:SetWordWrap(false)
  drop:SetTextColor(0.55, 0.58, 0.62)
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
    if f.mainBtn.Enable then
      f.mainBtn:Enable()
      f.offBtn:Enable()
    end
    if f.mainBtn.SetActive then
      f.mainBtn:SetActive(not onOff)
      f.offBtn:SetActive(onOff and true or false)
    end
  end

  local entries = BuildSortedEntries(pack, (db and db.checklistSort) or "rank")
  -- Drop slot filter if it has no matches for the current rank (avoids "empty" screens).
  if db and db.checklistSlotFilter and db.checklistSlotFilter ~= "all" then
    local slots = CollectSlotsFromPack(pack, db.checklistRankFilter or "all")
    local okSlot = false
    for _, s in ipairs(slots) do
      if s == db.checklistSlotFilter then
        okSlot = true
        break
      end
    end
    if not okSlot then
      db.checklistSlotFilter = "all"
    end
  end

  local filtered = {}
  for _, entry in ipairs(entries) do
    if EntryPassesChecklistFilters(entry, db) then
      filtered[#filtered + 1] = entry
    end
  end
  entries = filtered

  if f.missingOnlyCheck and db then
    f.missingOnlyCheck:SetChecked(db.checklistMissingOnly and true or false)
  end
  if f.SyncSortDrop then
    f.SyncSortDrop()
  end
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

  if f.emptyLabel then
    if #entries == 0 then
      f.emptyLabel:SetText(L["CHECKLIST_EMPTY"] or "No items match these filters.")
      f.emptyLabel:Show()
    else
      f.emptyLabel:Hide()
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
    local dropSrc = entry.info.drop or ""
    if dropSrc ~= "" then
      dropSrc = (BiSPulse.FormatDropSource and BiSPulse.FormatDropSource(dropSrc)) or dropSrc
      dropParts[#dropParts + 1] = dropSrc
    end
    local pop = ParsePopularity(entry.info)
    if pop then
      dropParts[#dropParts + 1] = string.format("%.0f%%", pop)
    end
    if owned and where == "equipped" then
      dropParts[#dropParts + 1] = (L["CHECKLIST_EQUIPPED"] or "equipped")
    elseif owned and where == "bags" then
      dropParts[#dropParts + 1] = (L["CHECKLIST_BAGS"] or "bags")
    elseif owned and where == "bank" then
      dropParts[#dropParts + 1] = (L["CHECKLIST_BANK"] or "bank")
    end
    local dropText = table.concat(dropParts, " · ")
    row.dropText = dropSrc
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
  -- Drop broken / outdated cached frames
  if checklist then
    local stale = (not checklist.content)
      or (not checklist.content.rows)
      or (checklist.layoutRev or 0) < CHECKLIST_LAYOUT_REV
      or (checklist.content.rows[1] and not checklist.content.rows[1].drop)
    if stale then
      checklist:Hide()
      checklist:SetParent(nil)
      checklist = nil
      DiscardFlatMenu()
    end
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
