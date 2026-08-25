--[[ Badges on Blizzard loot frame slots ]]

local addon = BiSPulse
local L = BiSPulseLocale

local badges = {}

local function RankShort(rank)
  if rank == "bis" then
    return "BiS"
  elseif rank == "strong" then
    return "A"
  elseif rank == "alt" then
    return "B"
  end
  return "C"
end

local function HexToRGB(hex)
  hex = (hex or "ffffffff"):gsub("^ff", "")
  return (tonumber(hex:sub(1, 2), 16) or 255) / 255,
    (tonumber(hex:sub(3, 4), 16) or 255) / 255,
    (tonumber(hex:sub(5, 6), 16) or 255) / 255
end

local function GetOrCreateBadge(slotButton, index)
  local badge = badges[index]
  if badge and badge.parent == slotButton then
    return badge
  end

  badge = CreateFrame("Frame", nil, slotButton, "BackdropTemplate")
  badge:SetSize(28, 14)
  badge:SetPoint("TOPRIGHT", slotButton, "TOPRIGHT", 2, 2)
  badge:SetFrameLevel((slotButton:GetFrameLevel() or 1) + 10)
  badge:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  badge:SetBackdropColor(0, 0, 0, 0.85)
  badge:SetBackdropBorderColor(1, 0.82, 0.2, 1)

  local text = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  text:SetPoint("CENTER", 0, 0)
  text:SetText("BiS")
  text:SetTextColor(1, 0.85, 0.2)
  badge.text = text
  badge.parent = slotButton
  badges[index] = badge
  return badge
end

local function HideAllBadges()
  for _, badge in pairs(badges) do
    badge:Hide()
  end
end

local function ResolveLootButton(i)
  -- Classic/Retail loot button naming variants
  return _G["LootButton" .. i]
    or _G["LootFrameButton" .. i]
    or (LootFrame and LootFrame["LootButton" .. i])
end

function addon:UpdateLootBadges()
  local db = self:GetDB()
  if not db or not db.enabled or db.lootBadges == false then
    HideAllBadges()
    return
  end

  if not LootFrame or not LootFrame:IsShown() then
    HideAllBadges()
    return
  end

  local num = GetNumLootItems and GetNumLootItems() or 0
  for i = 1, math.max(num, 4) do
    local btn = ResolveLootButton(i)
    if btn then
      local badge = GetOrCreateBadge(btn, i)
      local link = GetLootSlotLink and GetLootSlotLink(i)
      local show = false
      if link and i <= num then
        local itemID = self:GetItemIDFromLink(link)
        local eval = itemID and self:BuildBestEvaluation(itemID, link)
        if eval and self:MeetsMinRank(eval.info.rank) and self:MeetsContentFilter(eval.info) then
          local r, g, b = HexToRGB(self:RankColor(eval.info.rank))
          badge:SetBackdropBorderColor(r, g, b, 1)
          local label = RankShort(eval.info.rank)
          if eval.isOffspec then
            label = label .. "+"
          end
          badge.text:SetText(label)
          badge.text:SetTextColor(r, g, b)
          badge:Show()
          show = true

          -- Soft glow behind icon if available
          if not btn.BiSPulseGlow then
            local glow = btn:CreateTexture(nil, "OVERLAY")
            glow:SetAllPoints()
            glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            glow:SetBlendMode("ADD")
            glow:SetAlpha(0.55)
            btn.BiSPulseGlow = glow
          end
          btn.BiSPulseGlow:SetVertexColor(r, g, b)
          btn.BiSPulseGlow:Show()
        elseif btn.BiSPulseGlow then
          btn.BiSPulseGlow:Hide()
        end
      elseif btn.BiSPulseGlow then
        btn.BiSPulseGlow:Hide()
      end
      if not show then
        badge:Hide()
      end
    end
  end
end

local frame = CreateFrame("Frame")
local SafeRegisterEvent = BiSPulseSafeRegisterEvent
SafeRegisterEvent(frame, "LOOT_READY")
SafeRegisterEvent(frame, "LOOT_OPENED")
SafeRegisterEvent(frame, "LOOT_CLOSED")
SafeRegisterEvent(frame, "LOOT_SLOT_CLEARED")

frame:SetScript("OnEvent", function(_, event)
  if event == "LOOT_CLOSED" then
    HideAllBadges()
    return
  end
  -- delay so Blizzard finishes laying out buttons / item links
  C_Timer.After(0.05, function()
    addon:UpdateLootBadges()
    if addon.ScanOpenLootForAlerts then
      addon:ScanOpenLootForAlerts()
    end
  end)
end)

if LootFrame then
  LootFrame:HookScript("OnShow", function()
    C_Timer.After(0.05, function()
      addon:UpdateLootBadges()
      if addon.ScanOpenLootForAlerts then
        addon:ScanOpenLootForAlerts()
      end
    end)
  end)
  LootFrame:HookScript("OnHide", HideAllBadges)
end
