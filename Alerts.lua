local addon = BiSPulse
local L = BiSPulseLocale

local recent = {}
local RECENT_TTL = 8

local function AlreadyAlerted(itemID)
  local now = GetTime()
  local last = recent[itemID]
  if last and (now - last) < RECENT_TTL then
    return true
  end
  recent[itemID] = now
  return false
end

local function ShowRaidNotice(title, message)
  if not RaidNotice_AddMessage then
    return
  end
  local text = "|cffffd100" .. title .. "|r  " .. (message or "")
  RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.85, b = 0 })
end

function addon:AlertItem(itemID, itemLink, reason)
  local db = self:GetDB()
  if not db or not db.enabled or not db.alerts then
    return
  end

  local eval = self:BuildBestEvaluation(itemID, itemLink)
  if not eval then
    return
  end
  if not self:MeetsMinRank(eval.info.rank) then
    return
  end
  if not self:MeetsContentFilter(eval.info) then
    return
  end
  -- Skip toast if the player already has this item (bags/equipped/bank), unless opted in.
  if reason ~= "preview" and not db.alertIfOwned then
    local owned = self.PlayerOwnsItem and self:PlayerOwnsItem(itemID)
    if owned then
      return
    end
  end
  -- Skip clear item-level downgrades vs equipped (rings/trinkets: weaker slot).
  if reason ~= "preview" and not db.alertOnDowngrade then
    if eval.ilvlDelta and eval.ilvlDelta < 0 then
      return
    end
  end
  if AlreadyAlerted(itemID) then
    return
  end

  local info = eval.info
  local name = eval.itemLink or itemLink or info.name or ("item:" .. tostring(itemID))
  local rankLabel = self:RankLabel(info.rank)
  local title = (info.rank == "bis") and L["ALERT_BIS"] or L["ALERT_STRONG"]
  if eval.isOffspec then
    title = title .. " [" .. (eval.specName or L["OFFSPEC"] or "Offspec") .. "]"
  end
  local detail = rankLabel .. " · Score " .. eval.score
  local ilvlText = self:FormatIlvlCompare(eval)
  if ilvlText then
    detail = detail .. " · " .. ilvlText
  end

  if info.priority then
    detail = detail .. " · HIGH PRIORITY"
  end

  if db.customToast ~= false and self.ShowCustomToast then
    self:ShowCustomToast({
      itemID = itemID,
      itemLink = eval.itemLink or itemLink,
      eval = eval,
      duration = 3.5,
    })
  else
    ShowRaidNotice(title, name)
  end

  if db.raidWarning then
    ShowRaidNotice(title, name)
  end

  if db.chatAlerts then
    self:Print(L["ALERT_CHAT"]:format(title, name, rankLabel, detail))
  end

  if db.sound then
    PlaySound(SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST or 31578, "Master")
  end
end

local function ExtractItemFromLootMessage(msg)
  if not msg then
    return nil, nil
  end
  local link = msg:match("|Hitem:.-|h%[.-%]|h")
  if not link then
    -- reconstruct full link if partial
    link = msg:match("(|cff%x+|Hitem:.-|h%[.-%]|h|r)")
  end
  if not link then
    return nil, nil
  end
  local id = addon:GetItemIDFromLink(link)
  return id, link
end

local function After(delay, fn)
  if C_Timer and C_Timer.After then
    C_Timer.After(delay, fn)
  else
    fn()
  end
end

local function IsItemLootSlot(slot)
  local slotType = GetLootSlotType and GetLootSlotType(slot)
  if Enum and Enum.LootSlotType then
    if slotType == Enum.LootSlotType.Money or slotType == Enum.LootSlotType.Currency then
      return false
    end
    if slotType == Enum.LootSlotType.Item then
      return true
    end
  end
  if LOOT_SLOT_MONEY and slotType == LOOT_SLOT_MONEY then
    return false
  end
  if LOOT_SLOT_CURRENCY and slotType == LOOT_SLOT_CURRENCY then
    return false
  end
  return true
end

local function AlertFromLink(link, reason)
  if type(link) ~= "string" or not link:find("item:", 1, true) then
    return
  end
  local itemID = addon:GetItemIDFromLink(link)
  if itemID then
    addon:AlertItem(itemID, link, reason)
  end
end

-- Fires as soon as the loot list is on screen — not when you take the item.
function addon:ScanOpenLootForAlerts()
  local db = self:GetDB()
  if not db or not db.enabled or not db.alerts then
    return
  end
  local num = (GetNumLootItems and GetNumLootItems()) or 0
  for i = 1, num do
    if IsItemLootSlot(i) then
      local link = GetLootSlotLink and GetLootSlotLink(i)
      AlertFromLink(link, "lootwindow")
    end
  end
end

local function ScanOpenLootDelayed()
  addon:ScanOpenLootForAlerts()
  After(0.05, function()
    addon:ScanOpenLootForAlerts()
  end)
  After(0.25, function()
    addon:ScanOpenLootForAlerts()
  end)
  After(0.6, function()
    addon:ScanOpenLootForAlerts()
  end)
end

local function AlertLootRoll(rollID)
  if not rollID or not GetLootRollItemLink then
    return
  end
  local function try()
    AlertFromLink(GetLootRollItemLink(rollID), "lootroll")
  end
  try()
  After(0.15, try)
  After(0.4, try)
end

local function AlertLootHistoryDrop(encounterID, dropID)
  local api = C_LootHistory
  if not api then
    return
  end
  local info
  if dropID and api.GetDropInfo then
    info = api.GetDropInfo(dropID)
  elseif dropID and api.GetInfoForDrop then
    info = api.GetInfoForDrop(dropID)
  end
  if type(info) == "table" then
    AlertFromLink(info.itemHyperlink or info.itemLink or info.hyperlink, "loothistory")
    return
  end
  if encounterID and api.GetSortedDropsForEncounter then
    local drops = api.GetSortedDropsForEncounter(encounterID)
    if type(drops) == "table" then
      for _, drop in ipairs(drops) do
        if type(drop) == "table" then
          AlertFromLink(drop.itemHyperlink or drop.itemLink or drop.hyperlink, "loothistory")
        end
      end
    end
  end
end

local frame = CreateFrame("Frame")
local SafeRegisterEvent = BiSPulseSafeRegisterEvent or function(f, e)
  return pcall(f.RegisterEvent, f, e)
end
SafeRegisterEvent(frame, "CHAT_MSG_LOOT")
SafeRegisterEvent(frame, "SHOW_LOOT_TOAST")
SafeRegisterEvent(frame, "SHOW_LOOT_TOAST_UPGRADE")
SafeRegisterEvent(frame, "LOOT_READY")
SafeRegisterEvent(frame, "LOOT_OPENED")
SafeRegisterEvent(frame, "START_LOOT_ROLL")
SafeRegisterEvent(frame, "ENCOUNTER_LOOT_RECEIVED")
SafeRegisterEvent(frame, "LOOT_HISTORY_UPDATE_DROP")
SafeRegisterEvent(frame, "LOOT_HISTORY_FULL_UPDATE")
SafeRegisterEvent(frame, "PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(_, event, ...)
  local db = addon:GetDB()
  if not db or not db.enabled or not db.alerts then
    return
  end

  if event == "CHAT_MSG_LOOT" then
    local msg = ...
    if not msg then
      return
    end
    -- Self-loot patterns (enUS / deDE) and player-name fallback
    local playerName = UnitName("player")
    local isSelf = msg:find("You receive", 1, true)
      or msg:find("You create", 1, true)
      or msg:find("Ihr erhaltet", 1, true)
      or msg:find("Ihr bekommt", 1, true)
      or msg:find("Ihr stellt her", 1, true)
      or (playerName and msg:find(playerName, 1, true))
    -- onlyMine applies to chat loot only. The loot list / rolls always alert.
    if db.onlyMine and not isSelf then
      return
    end
    local itemID, link = ExtractItemFromLootMessage(msg)
    if itemID then
      addon:AlertItem(itemID, link, "loot")
    end
  elseif event == "SHOW_LOOT_TOAST" or event == "SHOW_LOOT_TOAST_UPGRADE" then
    local typeArg, link = ...
    -- SHOW_LOOT_TOAST payload differs by patch; try common shapes
    if type(typeArg) == "string" and typeArg:find("item:") then
      link = typeArg
    end
    if type(link) == "string" and link:find("item:") then
      AlertFromLink(link, "toast")
    end
  elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
    ScanOpenLootDelayed()
  elseif event == "START_LOOT_ROLL" then
    local rollID = ...
    AlertLootRoll(rollID)
  elseif event == "ENCOUNTER_LOOT_RECEIVED" then
    -- Payload varies by patch; find the item link / id.
    local a, b, c, d = ...
    local itemID, itemLink
    if type(c) == "string" and c:find("item:", 1, true) then
      itemLink, itemID = c, b
    elseif type(b) == "string" and b:find("item:", 1, true) then
      itemLink = b
    elseif type(d) == "string" and d:find("item:", 1, true) then
      itemLink = d
    end
    if itemLink then
      AlertFromLink(itemLink, "encounter")
    elseif type(itemID) == "number" then
      addon:AlertItem(itemID, nil, "encounter")
    end
  elseif event == "LOOT_HISTORY_UPDATE_DROP" then
    local encounterID, dropID = ...
    AlertLootHistoryDrop(encounterID, dropID)
  elseif event == "LOOT_HISTORY_FULL_UPDATE" then
    AlertLootHistoryDrop(...)
  end
end)

if LootFrame then
  LootFrame:HookScript("OnShow", function()
    ScanOpenLootDelayed()
  end)
end

pcall(function()
  hooksecurefunc("GroupLootFrame_OpenNewFrame", function(rollID)
    AlertLootRoll(rollID)
  end)
end)

-- Bag scan helper for testing / slash
function addon:ScanBagsForBiS()
  local found = 0
  local maxBag = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4)
  for bag = 0, maxBag do
    local slots = 0
    if C_Container and C_Container.GetContainerNumSlots then
      slots = C_Container.GetContainerNumSlots(bag) or 0
    elseif GetContainerNumSlots then
      slots = GetContainerNumSlots(bag) or 0
    end
    for slot = 1, slots do
      local link
      if C_Container and C_Container.GetContainerItemLink then
        link = C_Container.GetContainerItemLink(bag, slot)
      elseif GetContainerItemLink then
        link = GetContainerItemLink(bag, slot)
      end
      if link then
        local id = self:GetItemIDFromLink(link)
        local eval = id and self:BuildBestEvaluation(id, link)
        if eval and self:MeetsMinRank(eval.info.rank) then
          found = found + 1
          local tag = eval.isOffspec and (" [" .. (eval.specName or "OS") .. "]") or ""
          self:Print(("%s — %s (Score %d)%s"):format(link, self:RankLabel(eval.info.rank), eval.score, tag))
        end
      end
    end
  end
  if found == 0 then
    self:Print("No ranked BiS items found in bags.")
  end
end
