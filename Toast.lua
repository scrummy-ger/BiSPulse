--[[ Custom BiS toast: icon + rank + score, ~3.5s ]]

local addon = BiSPulse
local L = BiSPulseLocale

local toast
local hideAt = 0
local fadeStart = 0
local QUEUE = {}
local showing = false

local function HexToRGB(hex)
  hex = hex or "ffffffff"
  hex = hex:gsub("^ff", "")
  local r = tonumber(hex:sub(1, 2), 16) or 255
  local g = tonumber(hex:sub(3, 4), 16) or 255
  local b = tonumber(hex:sub(5, 6), 16) or 255
  return r / 255, g / 255, b / 255
end

local function GetItemIcon(itemID, itemLink)
  local tex
  if itemLink and C_Item and C_Item.GetItemInfoInstant then
    tex = select(5, C_Item.GetItemInfoInstant(itemLink))
  end
  if not tex and itemLink and GetItemInfoInstant then
    tex = select(5, GetItemInfoInstant(itemLink))
  end
  if not tex and itemID and GetItemInfoInstant then
    tex = select(5, GetItemInfoInstant(itemID))
  end
  return tex or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function EnsureToast()
  if toast then
    return toast
  end

  toast = CreateFrame("Frame", "BiSPulseToast", UIParent, "BackdropTemplate")
  toast:SetSize(360, 86)
  toast:SetPoint("TOP", UIParent, "TOP", 0, -140)
  toast:SetFrameStrata("FULLSCREEN_DIALOG")
  toast:SetFrameLevel(500)
  toast:Hide()
  toast:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  toast:SetBackdropColor(0.05, 0.07, 0.1, 0.94)
  toast:SetBackdropBorderColor(1, 0.82, 0.2, 0.95)

  local glow = toast:CreateTexture(nil, "BACKGROUND", nil, -1)
  glow:SetPoint("TOPLEFT", -12, 12)
  glow:SetPoint("BOTTOMRIGHT", 12, -12)
  glow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
  glow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
  glow:SetAlpha(0.35)
  toast.glow = glow

  local iconBg = CreateFrame("Frame", nil, toast, "BackdropTemplate")
  iconBg:SetSize(54, 54)
  iconBg:SetPoint("LEFT", 12, 2)
  iconBg:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  iconBg:SetBackdropColor(0, 0, 0, 0.8)
  iconBg:SetBackdropBorderColor(1, 0.82, 0.2, 1)
  toast.iconBg = iconBg

  local icon = iconBg:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", 2, -2)
  icon:SetPoint("BOTTOMRIGHT", -2, 2)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  toast.icon = icon

  -- Text column: title -> name -> detail -> score bar (no overlap)
  local title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", iconBg, "TOPRIGHT", 12, 2)
  title:SetPoint("RIGHT", toast, "RIGHT", -14, 0)
  title:SetJustifyH("LEFT")
  title:SetTextColor(1, 0.85, 0.2)
  toast.title = title

  local itemName = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  itemName:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
  itemName:SetPoint("RIGHT", toast, "RIGHT", -14, 0)
  itemName:SetJustifyH("LEFT")
  itemName:SetWordWrap(false)
  toast.itemName = itemName

  local detail = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  detail:SetPoint("TOPLEFT", itemName, "BOTTOMLEFT", 0, -3)
  detail:SetPoint("RIGHT", toast, "RIGHT", -14, 0)
  detail:SetJustifyH("LEFT")
  detail:SetTextColor(0.75, 0.85, 0.95)
  toast.detail = detail

  local scoreBarBg = CreateFrame("Frame", nil, toast, "BackdropTemplate")
  scoreBarBg:SetHeight(5)
  scoreBarBg:SetPoint("TOPLEFT", detail, "BOTTOMLEFT", 0, -6)
  scoreBarBg:SetPoint("RIGHT", toast, "RIGHT", -14, 0)
  scoreBarBg:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  scoreBarBg:SetBackdropColor(0.15, 0.15, 0.18, 1)
  scoreBarBg:SetBackdropBorderColor(0, 0, 0, 1)
  toast.scoreBarBg = scoreBarBg

  local scoreBar = scoreBarBg:CreateTexture(nil, "ARTWORK")
  scoreBar:SetPoint("TOPLEFT", 1, -1)
  scoreBar:SetPoint("BOTTOMLEFT", 1, 1)
  scoreBar:SetWidth(1)
  scoreBar:SetColorTexture(1, 0.82, 0.2, 1)
  toast.scoreBar = scoreBar

  toast:SetScript("OnUpdate", function(self)
    local now = GetTime()
    local fadeInDur = 0.18
    local fadeOutDur = 0.45
    if now < fadeStart + fadeInDur then
      self:SetAlpha((now - fadeStart) / fadeInDur)
    elseif now >= hideAt then
      self:Hide()
      self:SetAlpha(1)
      showing = false
      addon:PumpToastQueue()
    else
      local remain = hideAt - now
      if remain < fadeOutDur then
        self:SetAlpha(math.max(0, remain / fadeOutDur))
      else
        self:SetAlpha(1)
      end
    end
  end)

  return toast
end

function addon:PumpToastQueue()
  if showing or #QUEUE == 0 then
    return
  end
  local nextToast = table.remove(QUEUE, 1)
  self:ShowCustomToast(nextToast)
end

function addon:ShowCustomToast(payload)
  local db = self:GetDB()
  if db and db.customToast == false then
    return
  end
  if not payload or not payload.eval then
    return
  end

  if showing then
    QUEUE[#QUEUE + 1] = payload
    if #QUEUE > 5 then
      table.remove(QUEUE, 1)
    end
    return
  end

  local f = EnsureToast()
  local eval = payload.eval
  local info = eval.info
  local colorHex = self:RankColor(info.rank)
  local r, g, b = HexToRGB(colorHex)

  f:SetBackdropBorderColor(r, g, b, 0.95)
  f.glow:SetVertexColor(r, g, b)
  f.iconBg:SetBackdropBorderColor(r, g, b, 1)
  f.icon:SetTexture(GetItemIcon(payload.itemID, payload.itemLink))

  -- ASCII only: WoW fonts often lack ★ and similar glyphs
  local title = (info.rank == "bis") and L["ALERT_BIS"] or L["ALERT_STRONG"]
  if eval.isOffspec then
    title = title .. " |cff66bbff[" .. (eval.specName or L["OFFSPEC"] or "Offspec") .. "]|r"
  end
  if info.priority then
    title = title .. " |cffff6600[Prio]|r"
  end
  f.title:SetText(title)
  f.title:SetTextColor(r, g, b)

  local displayName = info.name
  if payload.itemLink then
    displayName = payload.itemLink:match("%[(.-)%]") or displayName
  end
  f.itemName:SetText(displayName or "?")

  local parts = {
    self:RankLabel(info.rank),
    L["SCORE"] .. " " .. eval.score,
  }
  if eval.isOffspec and eval.specName then
    parts[#parts + 1] = eval.specName
  end
  local ilvlText = self.FormatIlvlCompare and self:FormatIlvlCompare(eval)
  if ilvlText then
    parts[#parts + 1] = ilvlText
  end
  -- Use " - " instead of middle-dot; safer across fonts
  f.detail:SetText(table.concat(parts, " - "))

  -- Fill bar relative to current bar background width
  local barWidth = f.scoreBarBg:GetWidth()
  if not barWidth or barWidth < 10 then
    barWidth = 250
  end
  f.scoreBar:SetWidth(math.max(6, (barWidth - 2) * (eval.score / 100)))
  f.scoreBar:SetColorTexture(r, g, b, 1)

  fadeStart = GetTime()
  hideAt = fadeStart + (payload.duration or 3.5)
  showing = true
  f:SetAlpha(0)
  f:Show()
end

function addon:PreviewToast()
  local pack = self:GetPlayerPack()
  if not pack then
    self:Print(L["NO_SPEC_DATA"])
    return
  end
  local sampleID
  for id, info in pairs(pack.items) do
    if info.rank == "bis" and info.priority then
      sampleID = id
      break
    end
  end
  if not sampleID then
    for id, info in pairs(pack.items) do
      if info.rank == "bis" then
        sampleID = id
        break
      end
    end
  end
  if not sampleID then
    self:Print("No BiS sample item.")
    return
  end
  local _, sampleLink = GetItemInfo(sampleID)
  local eval = self:BuildEvaluation(sampleID, sampleLink)
  if eval then
    -- Force recreate next toast layout after code updates
    if toast then
      toast:Hide()
      toast = nil
      showing = false
    end
    self:ShowCustomToast({
      itemID = sampleID,
      itemLink = sampleLink or eval.itemLink,
      eval = eval,
      duration = 4,
    })
  end
end
