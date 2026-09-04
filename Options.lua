local addon = BiSPulse
local L = BiSPulseLocale

local panel

local function LabelOr(key, fallback)
  local t = L[key]
  if type(t) == "string" and t ~= "" then
    return t
  end
  return fallback or key
end

local function CreateCheckbox(parent, label, key, y)
  local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  cb:SetPoint("TOPLEFT", 16, y)
  local text = label or key or ""
  if cb.Text then
    cb.Text:SetText(text)
  elseif cb.text then
    cb.text:SetText(text)
  else
    local fs = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    fs:SetText(text)
    cb.Text = fs
  end
  cb:SetScript("OnClick", function(self)
    local db = addon:GetDB()
    db[key] = self:GetChecked() and true or false
    if key == "minimap" and addon.UpdateMinimapButton then
      addon:UpdateMinimapButton()
    end
    if key == "trackOffspec" then
      if not db.trackOffspec then
        db.checklistView = "main"
      end
      if addon.RefreshChecklist then
        addon:RefreshChecklist()
      end
    end
    if key == "countBankAsOwned" and addon.RefreshChecklist then
      addon:RefreshChecklist()
    end
  end)
  cb.bisKey = key
  return cb
end

function addon:OpenOptions()
  if not panel then
    self:BuildOptions()
  end
  if Settings and Settings.OpenToCategory and panel.settingsCategory then
    Settings.OpenToCategory(panel.settingsCategory:GetID())
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  else
    if panel:IsShown() then
      panel:Hide()
    else
      panel:Show()
    end
  end
end

function addon:BuildOptions()
  if panel then
    return
  end

  panel = CreateFrame("Frame", "BiSPulseOptionsPanel", UIParent)
  panel.name = "BiSPulse"
  panel:Hide()

  local scroll = CreateFrame("ScrollFrame", "BiSPulseOptionsScroll", panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -8)
  scroll:SetPoint("BOTTOMRIGHT", -28, 8)

  local body = CreateFrame("Frame", nil, scroll)
  body:SetSize(540, 1)
  scroll:SetScrollChild(body)
  panel.body = body
  panel.scroll = scroll

  local title = body:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -8)
  title:SetText(LabelOr("OPTS_TITLE", "BiSPulse Options"))

  local sub = body:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  sub:SetWidth(500)
  sub:SetJustifyH("LEFT")
  sub:SetText(LabelOr("OPTS_SUBTITLE", "Wowhead BiS"))

  local checks = {}
  local y = -52
  local function add(label, key)
    local text = label
    if type(text) ~= "string" or text == "" then
      text = key
    end
    local ok, cb = pcall(CreateCheckbox, body, text, key, y)
    if ok and cb then
      checks[#checks + 1] = cb
      y = y - 24
    else
      local btn = CreateFrame("CheckButton", nil, body)
      btn:SetSize(26, 26)
      btn:SetPoint("TOPLEFT", 16, y)
      btn:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
      btn:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
      btn:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
      btn:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
      local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      fs:SetPoint("LEFT", btn, "RIGHT", 4, 0)
      fs:SetText(text)
      btn.Text = fs
      btn:SetScript("OnClick", function(self)
        addon:GetDB()[key] = self:GetChecked() and true or false
        if key == "minimap" and addon.UpdateMinimapButton then
          addon:UpdateMinimapButton()
        end
        if key == "trackOffspec" then
          local db = addon:GetDB()
          if not db.trackOffspec then
            db.checklistView = "main"
          end
          if addon.RefreshChecklist then
            addon:RefreshChecklist()
          end
        end
        if key == "countBankAsOwned" and addon.RefreshChecklist then
          addon:RefreshChecklist()
        end
      end)
      btn.bisKey = key
      checks[#checks + 1] = btn
      y = y - 24
    end
  end

  add(LabelOr("OPTS_ENABLED", "Enable BiSPulse"), "enabled")
  add(LabelOr("OPTS_TOOLTIPS", "Show ranking on item tooltips"), "tooltips")
  add(LabelOr("OPTS_ALERTS", "Show loot alerts"), "alerts")
  add(LabelOr("OPTS_CUSTOM_TOAST", "Show custom toast"), "customToast")
  add(LabelOr("OPTS_RAID_WARNING", "Also show classic raid warning"), "raidWarning")
  add(LabelOr("OPTS_LOOT_BADGES", "Show BiS badges on loot window"), "lootBadges")
  add(LabelOr("OPTS_MINIMAP", "Show minimap button"), "minimap")
  add(LabelOr("OPTS_CHAT", "Also print alerts to chat"), "chatAlerts")
  add(LabelOr("OPTS_SOUND", "Play alert sound"), "sound")
  add(LabelOr("OPTS_ONLY_MINE", "Only alert for my loot"), "onlyMine")
  add(LabelOr("OPTS_ALERT_IF_OWNED", "Also alert if I already own the item"), "alertIfOwned")
  add(LabelOr("OPTS_COUNT_BANK", "Count bank (and warband bank) as owned"), "countBankAsOwned")
  add(LabelOr("OPTS_ALERT_ON_DOWNGRADE", "Also alert on lower item level than equipped"), "alertOnDowngrade")
  add(LabelOr("OPTS_TRACK_OFFSPEC", "Also alert for offspec BiS"), "trackOffspec")
  panel.checks = checks

  local offspecLabel = body:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  offspecLabel:SetPoint("TOPLEFT", 16, y - 6)
  offspecLabel:SetText(LabelOr("OPTS_OFFSPEC", "Offspec to track"))
  y = y - 30

  local offspecDropdown
  local hasOffspecDropdown = pcall(function()
    offspecDropdown = CreateFrame("Frame", "BiSPulseOffspecDropdown", body, "UIDropDownMenuTemplate")
    offspecDropdown:SetPoint("TOPLEFT", offspecLabel, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(offspecDropdown, 200)
    UIDropDownMenu_Initialize(offspecDropdown, function()
      local info = UIDropDownMenu_CreateInfo()
      info.text = LabelOr("OPTS_OFFSPEC_AUTO", "Auto")
      info.value = 0
      info.func = function()
        addon:GetDB().offspecIndex = 0
        UIDropDownMenu_SetText(offspecDropdown, LabelOr("OPTS_OFFSPEC_AUTO", "Auto"))
        if addon.RefreshChecklist then
          addon:RefreshChecklist()
        end
      end
      UIDropDownMenu_AddButton(info)
      local choices = addon:GetClassSpecChoices(true)
      for _, choice in ipairs(choices) do
        local cinfo = UIDropDownMenu_CreateInfo()
        cinfo.text = choice.name
        cinfo.value = choice.index
        cinfo.func = function()
          addon:GetDB().offspecIndex = choice.index
          UIDropDownMenu_SetText(offspecDropdown, choice.name)
          if addon.RefreshChecklist then
            addon:RefreshChecklist()
          end
        end
        UIDropDownMenu_AddButton(cinfo)
      end
    end)
    UIDropDownMenu_SetText(offspecDropdown, LabelOr("OPTS_OFFSPEC_AUTO", "Auto"))
  end)

  if hasOffspecDropdown and offspecDropdown then
    panel.offspecDropdown = offspecDropdown
    y = y - 40
  else
    y = y - 8
  end

  local contentLabel = body:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  contentLabel:SetPoint("TOPLEFT", 16, y - 4)
  contentLabel:SetText(LabelOr("OPTS_CONTENT_MODE", "Content filter"))

  local contentModes = {
    { value = "all", text = LabelOr("OPTS_CONTENT_ALL", "All lists") },
    { value = "overall", text = LabelOr("CONTENT_OVERALL", "Overall") },
    { value = "raid", text = LabelOr("CONTENT_RAID", "Raid") },
    { value = "mythic", text = LabelOr("CONTENT_MYTHIC", "Mythic+") },
  }

  local contentDropdown
  local hasContentDropdown = pcall(function()
    contentDropdown = CreateFrame("Frame", "BiSPulseContentModeDropdown", body, "UIDropDownMenuTemplate")
    contentDropdown:SetPoint("TOPLEFT", contentLabel, "BOTTOMLEFT", -16, -4)
    UIDropDownMenu_SetWidth(contentDropdown, 180)
    UIDropDownMenu_Initialize(contentDropdown, function()
      for _, m in ipairs(contentModes) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = m.text
        info.value = m.value
        info.func = function()
          addon:GetDB().contentMode = m.value
          UIDropDownMenu_SetText(contentDropdown, m.text)
          if addon.RefreshChecklist then
            addon:RefreshChecklist()
          end
        end
        UIDropDownMenu_AddButton(info)
      end
    end)
    UIDropDownMenu_SetText(contentDropdown, contentModes[1].text)
  end)

  if not hasContentDropdown then
    local cycle = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
    cycle:SetSize(180, 22)
    cycle:SetPoint("TOPLEFT", contentLabel, "BOTTOMLEFT", 0, -4)
    local function sync()
      local current = addon:GetDB().contentMode or "all"
      for _, m in ipairs(contentModes) do
        if m.value == current then
          cycle:SetText(m.text)
          return
        end
      end
    end
    cycle:SetScript("OnClick", function()
      local order = { "all", "overall", "raid", "mythic" }
      local current = addon:GetDB().contentMode or "all"
      local idx = 1
      for i, v in ipairs(order) do
        if v == current then
          idx = i
          break
        end
      end
      addon:GetDB().contentMode = order[(idx % #order) + 1]
      sync()
      if addon.RefreshChecklist then
        addon:RefreshChecklist()
      end
    end)
    sync()
    panel.contentCycle = cycle
  end

  local contentHint = body:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  if hasContentDropdown and contentDropdown then
    contentHint:SetPoint("TOPLEFT", contentDropdown, "BOTTOMLEFT", 20, 0)
  elseif panel.contentCycle then
    contentHint:SetPoint("TOPLEFT", panel.contentCycle, "BOTTOMLEFT", 0, -2)
  else
    contentHint:SetPoint("TOPLEFT", contentLabel, "BOTTOMLEFT", 0, -30)
  end
  contentHint:SetWidth(480)
  contentHint:SetJustifyH("LEFT")
  contentHint:SetText(LabelOr("OPTS_CONTENT_HINT", "Overall BiS always counts."))
  panel.contentHint = contentHint
  panel.contentDropdown = contentDropdown
  y = y - 62

  local rankLabel = body:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  rankLabel:SetPoint("TOPLEFT", 16, y - 4)
  rankLabel:SetText(LabelOr("OPTS_MIN_RANK", "Minimum rank to alert"))

  local ranks = {
    { value = "bis", text = LabelOr("RANK_BIS", "Best in Slot") },
    { value = "strong", text = LabelOr("RANK_STRONG", "Strong Upgrade") },
    { value = "alt", text = LabelOr("RANK_ALT", "Solid Alternative") },
    { value = "ok", text = LabelOr("RANK_OK", "Situational / Niche") },
  }

  local dropdown
  local hasDropdown = pcall(function()
    dropdown = CreateFrame("Frame", "BiSPulseMinRankDropdown", body, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", rankLabel, "BOTTOMLEFT", -16, -4)
    UIDropDownMenu_SetWidth(dropdown, 180)
    UIDropDownMenu_Initialize(dropdown, function()
      for _, r in ipairs(ranks) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = r.text
        info.value = r.value
        info.func = function()
          addon:GetDB().minRank = r.value
          UIDropDownMenu_SetText(dropdown, r.text)
        end
        UIDropDownMenu_AddButton(info)
      end
    end)
    UIDropDownMenu_SetText(dropdown, ranks[2].text)
  end)

  if not hasDropdown then
    local cycle = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
    cycle:SetSize(180, 22)
    cycle:SetPoint("TOPLEFT", rankLabel, "BOTTOMLEFT", 0, -4)
    local function sync()
      local current = addon:GetDB().minRank or "strong"
      for _, r in ipairs(ranks) do
        if r.value == current then
          cycle:SetText(r.text)
          return
        end
      end
    end
    cycle:SetScript("OnClick", function()
      local order = { "bis", "strong", "alt", "ok" }
      local current = addon:GetDB().minRank or "strong"
      local idx = 1
      for i, v in ipairs(order) do
        if v == current then
          idx = i
          break
        end
      end
      addon:GetDB().minRank = order[(idx % #order) + 1]
      sync()
    end)
    sync()
    panel.rankCycle = cycle
  end

  local rankHint = body:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  if hasDropdown and dropdown then
    rankHint:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 20, 0)
  elseif panel.rankCycle then
    rankHint:SetPoint("TOPLEFT", panel.rankCycle, "BOTTOMLEFT", 0, -2)
  else
    rankHint:SetPoint("TOPLEFT", rankLabel, "BOTTOMLEFT", 0, -30)
  end
  rankHint:SetWidth(480)
  rankHint:SetJustifyH("LEFT")
  rankHint:SetText(LabelOr("OPTS_MIN_RANK_HINT", "Applies to toast and loot badges."))
  panel.rankHint = rankHint

  local btnY = y - 70
  local scanBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
  scanBtn:SetSize(120, 24)
  scanBtn:SetPoint("TOPLEFT", 16, btnY)
  scanBtn:SetText(LabelOr("OPTS_SCAN", "Scan bags"))
  scanBtn:SetScript("OnClick", function()
    addon:ScanBagsForBiS()
  end)

  local listBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
  listBtn:SetSize(120, 24)
  listBtn:SetPoint("LEFT", scanBtn, "RIGHT", 8, 0)
  listBtn:SetText(LabelOr("OPTS_CHECKLIST", "Checklist"))
  listBtn:SetScript("OnClick", function()
    local ok, err = pcall(function()
      addon:ToggleChecklist()
    end)
    if not ok then
      addon:Print("Checklist button error: " .. tostring(err))
    end
  end)

  local toastBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
  toastBtn:SetSize(120, 24)
  toastBtn:SetPoint("LEFT", listBtn, "RIGHT", 8, 0)
  toastBtn:SetText(LabelOr("OPTS_PREVIEW_TOAST", "Preview toast"))
  toastBtn:SetScript("OnClick", function()
    addon:PreviewToast()
  end)

  local guidesBtn = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
  guidesBtn:SetSize(120, 24)
  guidesBtn:SetPoint("TOPLEFT", scanBtn, "BOTTOMLEFT", 0, -8)
  guidesBtn:SetText(LabelOr("OPTS_GUIDES", "Guide links"))
  guidesBtn:SetScript("OnClick", function()
    if addon.PrintGuideLinks then
      addon:PrintGuideLinks()
    end
  end)

  local help = body:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", 16, btnY - 68)
  help:SetWidth(500)
  help:SetJustifyH("LEFT")
  panel.help = help

  body:SetHeight(math.abs(btnY) + 160)

  panel.refresh = function()
    local db = addon:GetDB()
    for _, cb in ipairs(panel.checks) do
      cb:SetChecked(db[cb.bisKey] and true or false)
    end
    if hasDropdown and dropdown and UIDropDownMenu_SetText then
      local current = db.minRank or "strong"
      for _, r in ipairs(ranks) do
        if r.value == current then
          UIDropDownMenu_SetText(dropdown, r.text)
          break
        end
      end
    end
    if panel.contentDropdown and UIDropDownMenu_SetText then
      local current = db.contentMode or "all"
      for _, m in ipairs(contentModes) do
        if m.value == current then
          UIDropDownMenu_SetText(panel.contentDropdown, m.text)
          break
        end
      end
    elseif panel.contentCycle then
      local current = db.contentMode or "all"
      for _, m in ipairs(contentModes) do
        if m.value == current then
          panel.contentCycle:SetText(m.text)
          break
        end
      end
    end
    if panel.offspecDropdown and UIDropDownMenu_SetText then
      local idx = tonumber(db.offspecIndex) or 0
      if idx <= 0 then
        UIDropDownMenu_SetText(panel.offspecDropdown, LabelOr("OPTS_OFFSPEC_AUTO", "Auto"))
      else
        local label = LabelOr("OPTS_OFFSPEC_AUTO", "Auto")
        local choices = addon:GetClassSpecChoices(true)
        for _, choice in ipairs(choices) do
          if choice.index == idx then
            label = choice.name
            break
          end
        end
        UIDropDownMenu_SetText(panel.offspecDropdown, label)
      end
    end
    local pack = addon.GetPlayerPack and addon:GetPlayerPack() or nil
    local stamp = (pack and pack.updated) or "?"
    local footer = LabelOr("HELP", "/bispulse") .. "\n\n" .. LabelOr("OPTS_FOOTER", "")
    if L["DATA_UPDATED"] then
      footer = footer .. "\n" .. L["DATA_UPDATED"]:format(stamp)
    end
    if pack and pack.guides then
      local bits = {}
      if pack.guides.wowhead then
        bits[#bits + 1] = (L["SOURCE_WOWHEAD"] or "Wowhead")
      end
      if pack.guides.archonRaid or pack.guides.archonMythic then
        bits[#bits + 1] = (L["SOURCE_ARCHON"] or "Archon")
      end
      if #bits > 0 then
        footer = footer .. "\n" .. (L["OPTS_GUIDES_HINT"] or "Guide links:") .. " " .. table.concat(bits, " · ")
      end
    end
    if panel.help then
      panel.help:SetText(footer)
    end
  end

  panel:SetScript("OnShow", function(self)
    if self.refresh then
      self.refresh()
    end
  end)

  local registered = false
  if Settings and Settings.RegisterCanvasLayoutCategory then
    local ok, category = pcall(function()
      local cat = Settings.RegisterCanvasLayoutCategory(panel, "BiSPulse")
      Settings.RegisterAddOnCategory(cat)
      return cat
    end)
    if ok and category then
      panel.settingsCategory = category
      registered = true
    end
  end
  if not registered and InterfaceOptions_AddCategory then
    pcall(InterfaceOptions_AddCategory, panel)
    registered = true
  end
  if not registered then
    panel:SetSize(580, 520)
    panel:SetPoint("CENTER")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.08, 0.1, 0.95)
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    if close.Text then
      close.Text:SetText("")
    end
    close:SetText("")
  end

  addon.optionsPanel = panel
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
  local ok, err = pcall(function()
    addon:BuildOptions()
  end)
  if not ok then
    addon:Print("Options init failed: " .. tostring(err))
  end
end)
