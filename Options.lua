local addon = BiSPulse
local L = BiSPulseLocale

local panel

local function CreateCheckbox(parent, label, key, y)
  local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  cb:SetPoint("TOPLEFT", 16, y)
  cb.Text:SetText(label)
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

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(L["OPTS_TITLE"])

  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetWidth(520)
  sub:SetJustifyH("LEFT")
  sub:SetText(L["OPTS_SUBTITLE"])

  local checks = {}
  local y = -70
  local function add(label, key)
    local ok, cb = pcall(CreateCheckbox, panel, label, key, y)
    if ok and cb then
      checks[#checks + 1] = cb
      y = y - 28
    else
      -- Minimal fallback checkbox without template
      local btn = CreateFrame("CheckButton", nil, panel)
      btn:SetSize(26, 26)
      btn:SetPoint("TOPLEFT", 16, y)
      btn:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
      btn:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
      btn:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
      btn:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
      local text = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      text:SetPoint("LEFT", btn, "RIGHT", 4, 0)
      text:SetText(label)
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
      y = y - 28
    end
  end

  add(L["OPTS_ENABLED"], "enabled")
  add(L["OPTS_TOOLTIPS"], "tooltips")
  add(L["OPTS_ALERTS"], "alerts")
  add(L["OPTS_CUSTOM_TOAST"], "customToast")
  add(L["OPTS_RAID_WARNING"], "raidWarning")
  add(L["OPTS_LOOT_BADGES"], "lootBadges")
  add(L["OPTS_MINIMAP"], "minimap")
  add(L["OPTS_CHAT"], "chatAlerts")
  add(L["OPTS_SOUND"], "sound")
  add(L["OPTS_ONLY_MINE"], "onlyMine")
  add(L["OPTS_ALERT_IF_OWNED"], "alertIfOwned")
  add(L["OPTS_COUNT_BANK"], "countBankAsOwned")
  add(L["OPTS_ALERT_ON_DOWNGRADE"], "alertOnDowngrade")
  add(L["OPTS_TRACK_OFFSPEC"], "trackOffspec")
  panel.checks = checks

  local offspecLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  offspecLabel:SetPoint("TOPLEFT", 16, y - 8)
  offspecLabel:SetText(L["OPTS_OFFSPEC"])
  y = y - 36

  local offspecDropdown
  local hasOffspecDropdown = pcall(function()
    offspecDropdown = CreateFrame("Frame", "BiSPulseOffspecDropdown", panel, "UIDropDownMenuTemplate")
    offspecDropdown:SetPoint("TOPLEFT", offspecLabel, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(offspecDropdown, 200)
    UIDropDownMenu_Initialize(offspecDropdown, function()
      local info = UIDropDownMenu_CreateInfo()
      info.text = L["OPTS_OFFSPEC_AUTO"]
      info.value = 0
      info.func = function()
        addon:GetDB().offspecIndex = 0
        UIDropDownMenu_SetText(offspecDropdown, L["OPTS_OFFSPEC_AUTO"])
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
  end)

  if hasOffspecDropdown and offspecDropdown then
    panel.offspecDropdown = offspecDropdown
    y = y - 40
  else
    y = y - 8
  end

  local contentLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  contentLabel:SetPoint("TOPLEFT", 16, y - 8)
  contentLabel:SetText(L["OPTS_CONTENT_MODE"])

  local contentModes = {
    { value = "all", text = L["OPTS_CONTENT_ALL"] },
    { value = "overall", text = L["CONTENT_OVERALL"] },
    { value = "raid", text = L["CONTENT_RAID"] },
    { value = "mythic", text = L["CONTENT_MYTHIC"] },
  }

  local contentDropdown
  local hasContentDropdown = pcall(function()
    contentDropdown = CreateFrame("Frame", "BiSPulseContentModeDropdown", panel, "UIDropDownMenuTemplate")
    contentDropdown:SetPoint("TOPLEFT", contentLabel, "BOTTOMLEFT", -16, -8)
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
  end)

  if not hasContentDropdown then
    local cycle = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    cycle:SetSize(180, 24)
    cycle:SetPoint("TOPLEFT", contentLabel, "BOTTOMLEFT", 0, -8)
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

  local contentHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  if hasContentDropdown and contentDropdown then
    contentHint:SetPoint("TOPLEFT", contentDropdown, "BOTTOMLEFT", 20, -2)
  elseif panel.contentCycle then
    contentHint:SetPoint("TOPLEFT", panel.contentCycle, "BOTTOMLEFT", 0, -2)
  else
    contentHint:SetPoint("TOPLEFT", contentLabel, "BOTTOMLEFT", 0, -36)
  end
  contentHint:SetWidth(400)
  contentHint:SetJustifyH("LEFT")
  contentHint:SetText(L["OPTS_CONTENT_HINT"] or "")
  panel.contentHint = contentHint
  panel.contentDropdown = contentDropdown
  y = y - 70

  local rankLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  rankLabel:SetPoint("TOPLEFT", 16, y - 8)
  rankLabel:SetText(L["OPTS_MIN_RANK"])

  local ranks = {
    { value = "bis", text = L["RANK_BIS"] },
    { value = "strong", text = L["RANK_STRONG"] },
    { value = "alt", text = L["RANK_ALT"] },
    { value = "ok", text = L["RANK_OK"] },
  }

  local dropdown
  local hasDropdown = pcall(function()
    dropdown = CreateFrame("Frame", "BiSPulseMinRankDropdown", panel, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", rankLabel, "BOTTOMLEFT", -16, -8)
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
  end)

  if not hasDropdown then
    local cycle = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    cycle:SetSize(180, 24)
    cycle:SetPoint("TOPLEFT", rankLabel, "BOTTOMLEFT", 0, -8)
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

  local rankHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  if hasDropdown and dropdown then
    rankHint:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 20, -2)
  elseif panel.rankCycle then
    rankHint:SetPoint("TOPLEFT", panel.rankCycle, "BOTTOMLEFT", 0, -2)
  else
    rankHint:SetPoint("TOPLEFT", rankLabel, "BOTTOMLEFT", 0, -36)
  end
  rankHint:SetWidth(400)
  rankHint:SetJustifyH("LEFT")
  rankHint:SetText(L["OPTS_MIN_RANK_HINT"] or "")
  panel.rankHint = rankHint

  local btnY = y - 100
  local scanBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  scanBtn:SetSize(120, 24)
  scanBtn:SetPoint("TOPLEFT", 16, btnY)
  scanBtn:SetText(L["OPTS_SCAN"])
  scanBtn:SetScript("OnClick", function()
    addon:ScanBagsForBiS()
  end)

  local listBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  listBtn:SetSize(120, 24)
  listBtn:SetPoint("LEFT", scanBtn, "RIGHT", 8, 0)
  listBtn:SetText(L["OPTS_CHECKLIST"])
  listBtn:SetScript("OnClick", function()
    local ok, err = pcall(function()
      addon:ToggleChecklist()
    end)
    if not ok then
      addon:Print("Checklist button error: " .. tostring(err))
    end
  end)

  local toastBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  toastBtn:SetSize(120, 24)
  toastBtn:SetPoint("LEFT", listBtn, "RIGHT", 8, 0)
  toastBtn:SetText(L["OPTS_PREVIEW_TOAST"])
  toastBtn:SetScript("OnClick", function()
    addon:PreviewToast()
  end)

  local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", 16, btnY - 40)
  help:SetWidth(520)
  help:SetJustifyH("LEFT")
  panel.help = help

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
        UIDropDownMenu_SetText(panel.offspecDropdown, L["OPTS_OFFSPEC_AUTO"])
      else
        local label = L["OPTS_OFFSPEC_AUTO"]
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
    local footer = L["HELP"] .. "\n\n" .. L["OPTS_FOOTER"]
    if L["DATA_UPDATED"] then
      footer = footer .. "\n" .. L["DATA_UPDATED"]:format(stamp)
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
    panel:SetSize(560, 560)
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
