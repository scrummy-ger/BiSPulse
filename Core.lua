BiSPulse = BiSPulse or {}

local addon = BiSPulse
local L = BiSPulseLocale
local DATA = BiSPulseData

local defaults = {
  enabled = true,
  tooltips = true,
  alerts = true,
  chatAlerts = true,
  sound = true,
  onlyMine = false,
  alertIfOwned = false,
  countBankAsOwned = false,
  alertOnDowngrade = false,
  trackOffspec = false,
  offspecIndex = 0, -- 0 = auto (first other spec of your class)
  checklistView = "main", -- "main" | "off"
  contentMode = "all", -- all | overall | raid | mythic
  checklistRankFilter = "all", -- all | bis | strong | alt | ok
  checklistSlotFilter = "all",
  checklistSearch = "",
  checklistMissingOnly = false,
  checklistSort = "rank", -- rank | name | slot | missing
  minRank = "strong", -- bis | strong | alt | ok
  customToast = true,
  raidWarning = false,
  lootBadges = true,
  minimap = true,
  minimapAngle = 220,
}

local function CopyDefaults(src, dst)
  if type(src) ~= "table" then
    return {}
  end
  dst = dst or {}
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = CopyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

function addon:GetDB()
  return BiSPulseDB
end
addon.GetDB = addon.GetDB

function addon:Print(msg)
  print("|cff00ff96BiSPulse|r: " .. tostring(msg))
end

function addon:GetPlayerPack()
  local _, classFile = UnitClass("player")
  local specIndex = GetSpecialization()
  if not classFile or not specIndex then
    return nil, classFile, specIndex
  end
  return DATA:GetPack(classFile, specIndex), classFile, specIndex
end

-- Other specializations of the player's class that have BiS data.
function addon:GetClassSpecChoices(includeMain)
  local _, classFile = UnitClass("player")
  local main = GetSpecialization()
  local byClass = classFile and DATA.specs and DATA.specs[classFile]
  local out = {}
  if not byClass then
    return out, classFile, main
  end
  for i = 1, 4 do
    local pack = byClass[i]
    if pack and (includeMain or i ~= main) then
      out[#out + 1] = {
        index = i,
        name = pack.specName or ("Spec " .. i),
        pack = pack,
        isMain = (i == main),
      }
    end
  end
  return out, classFile, main
end

-- Resolved offspec index, or nil if tracking is off / unavailable.
function addon:GetOffspecIndex()
  local db = self:GetDB()
  if not db or not db.trackOffspec then
    return nil
  end
  local _, classFile = UnitClass("player")
  local main = GetSpecialization()
  local byClass = classFile and DATA.specs and DATA.specs[classFile]
  if not byClass or not main then
    return nil
  end
  local want = tonumber(db.offspecIndex) or 0
  if want > 0 and want ~= main and byClass[want] then
    return want
  end
  for i = 1, 4 do
    if i ~= main and byClass[i] then
      return i
    end
  end
  return nil
end

function addon:GetOffspecPack()
  local idx = self:GetOffspecIndex()
  if not idx then
    return nil, nil, nil
  end
  local _, classFile = UnitClass("player")
  return DATA:GetPack(classFile, idx), classFile, idx
end

-- Pack shown in the checklist (main or configured offspec).
function addon:GetChecklistPack()
  local db = self:GetDB()
  if db and db.checklistView == "off" and db.trackOffspec then
    local pack, classFile, idx = self:GetOffspecPack()
    if pack then
      return pack, classFile, idx, true
    end
  end
  local pack, classFile, idx = self:GetPlayerPack()
  return pack, classFile, idx, false
end

-- Days since pack.updated (YYYY-MM-DD). Wowhead lists cannot refresh in-game.
function addon:GetPackAgeDays(pack)
  if not pack or type(pack.updated) ~= "string" then
    return nil
  end
  local y, m, d = pack.updated:match("^(%d+)%-(%d+)%-(%d+)$")
  if not y then
    return nil
  end
  local thenT = time({
    year = tonumber(y),
    month = tonumber(m),
    day = tonumber(d),
    hour = 12,
  })
  if not thenT then
    return nil
  end
  return math.max(0, math.floor((time() - thenT) / 86400))
end

function addon:GetItemIDFromLink(link)
  if not link then
    return nil
  end
  local id = link:match("item:(%d+)")
  return id and tonumber(id) or nil
end

-- Equipped or in bags (not bank). Returns hyperlink + where.
local function ContainerItemLink(bag, slot)
  if C_Container and C_Container.GetContainerItemLink then
    return C_Container.GetContainerItemLink(bag, slot)
  end
  if GetContainerItemLink then
    return GetContainerItemLink(bag, slot)
  end
  return nil
end

local function ContainerNumSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then
    return C_Container.GetContainerNumSlots(bag) or 0
  end
  if GetContainerNumSlots then
    return GetContainerNumSlots(bag) or 0
  end
  return 0
end

local function ScanBagsForItem(self, itemID, bags, where)
  for _, bag in ipairs(bags) do
    if bag ~= nil then
      local slots = ContainerNumSlots(bag)
      for slot = 1, slots do
        local link = ContainerItemLink(bag, slot)
        if link and self:GetItemIDFromLink(link) == itemID then
          return link, where
        end
      end
    end
  end
  return nil, nil
end

local function CollectBankBagIDs()
  local bags = {}
  local function add(id)
    if id == nil then
      return
    end
    for _, existing in ipairs(bags) do
      if existing == id then
        return
      end
    end
    bags[#bags + 1] = id
  end

  -- Classic bank container + bank bags
  if BANK_CONTAINER ~= nil then
    add(BANK_CONTAINER)
  end
  if REAGENTBANK_CONTAINER ~= nil then
    add(REAGENTBANK_CONTAINER)
  end
  local bagSlots = NUM_BAG_SLOTS or 4
  local bankSlots = NUM_BANKBAGSLOTS or 7
  for i = bagSlots + 1, bagSlots + bankSlots do
    add(i)
  end

  -- Modern Enum.BagIndex (bank / account bank tabs) when present
  local BagIndex = Enum and Enum.BagIndex
  if BagIndex then
    for key, id in pairs(BagIndex) do
      if type(id) == "number" and type(key) == "string" then
        if key:find("Bank", 1, true) or key:find("Account", 1, true) or key:find("Reagent", 1, true) then
          add(id)
        end
      end
    end
  end

  return bags
end

function addon:FindOwnedItem(itemID)
  if not itemID then
    return nil, nil
  end
  for slot = 1, 19 do
    local link = GetInventoryItemLink("player", slot)
    if link and self:GetItemIDFromLink(link) == itemID then
      return link, "equipped"
    end
  end

  local wornBags = {}
  local maxBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
  for bag = 0, maxBag do
    wornBags[#wornBags + 1] = bag
  end
  local link, where = ScanBagsForItem(self, itemID, wornBags, "bags")
  if link then
    return link, where
  end

  local db = self:GetDB()
  if db and db.countBankAsOwned then
    link, where = ScanBagsForItem(self, itemID, CollectBankBagIDs(), "bank")
    if link then
      return link, where
    end
  end

  return nil, nil
end

function addon:PlayerOwnsItem(itemID)
  local link, where = self:FindOwnedItem(itemID)
  return link ~= nil, where
end

function addon:GetEquippedItemLevel(slotId)
  local link = GetInventoryItemLink("player", slotId)
  if not link then
    return nil, nil
  end
  local ilvl = GetDetailedItemLevelInfo(link) or 0
  return ilvl, self:GetItemIDFromLink(link)
end

local INVTYPE_TO_SLOTS = {
  INVTYPE_HEAD = { 1 },
  INVTYPE_NECK = { 2 },
  INVTYPE_SHOULDER = { 3 },
  INVTYPE_BODY = { 4 },
  INVTYPE_CHEST = { 5 },
  INVTYPE_ROBE = { 5 },
  INVTYPE_WAIST = { 6 },
  INVTYPE_LEGS = { 7 },
  INVTYPE_FEET = { 8 },
  INVTYPE_WRIST = { 9 },
  INVTYPE_HAND = { 10 },
  INVTYPE_FINGER = { 11, 12 },
  INVTYPE_TRINKET = { 13, 14 },
  INVTYPE_CLOAK = { 15 },
  INVTYPE_WEAPON = { 16, 17 },
  INVTYPE_2HWEAPON = { 16 },
  INVTYPE_WEAPONMAINHAND = { 16 },
  INVTYPE_WEAPONOFFHAND = { 17 },
  INVTYPE_HOLDABLE = { 17 },
  INVTYPE_RANGED = { 16 },
  INVTYPE_RANGEDRIGHT = { 16 },
  INVTYPE_SHIELD = { 17 },
}

function addon:GetCompareSlots(itemLinkOrID)
  local invType
  if C_Item and C_Item.GetItemInfoInstant then
    invType = select(4, C_Item.GetItemInfoInstant(itemLinkOrID or ""))
  end
  if not invType and type(itemLinkOrID) == "string" then
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemLinkOrID)
    invType = equipLoc
  elseif not invType and type(itemLinkOrID) == "number" and GetItemInfo then
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemLinkOrID)
    invType = equipLoc
  end
  return INVTYPE_TO_SLOTS[invType]
end

-- GetItemInfo(itemID) returns a catalog template without season/raid bonus IDs.
-- That template's ilvl is far below a real drop and must not be compared to equipped gear.
function addon:ItemLinkHasInstanceData(link)
  if type(link) ~= "string" then
    return false
  end
  local payload = link:match("item:([^|]+)")
  if not payload then
    return false
  end
  local parts = { strsplit(":", payload) }
  -- item:id:ench:gem:gem:gem:gem:suffix:unique:level:spec:modMask:context:numBonusIDs:...
  local itemContext = tonumber(parts[12]) or 0
  local numBonusIDs = tonumber(parts[13]) or 0
  return numBonusIDs > 0 or itemContext > 0
end

function addon:ResolveItemLink(itemID, itemLink)
  -- Prefer a real drop/owned hyperlink (bonus IDs / item context). Never use a
  -- catalog template for ilvl math — that is what produced fake -76 deltas.
  if self:ItemLinkHasInstanceData(itemLink) then
    return itemLink
  end
  local owned = self:FindOwnedItem(itemID)
  if owned then
    return owned
  end
  if type(itemLink) == "string" and itemLink:find("item:", 1, true) then
    return itemLink
  end
  if itemID and GetItemInfo then
    local _, link = GetItemInfo(itemID)
    return link
  end
  return nil
end

function addon:FormatIlvlCompare(eval)
  if not eval then
    return nil
  end
  if eval.ilvlDelta ~= nil then
    if eval.ilvlDelta > 0 then
      return L["HIGHER_ILVL"]:format(eval.ilvlDelta)
    elseif eval.ilvlDelta < 0 then
      return L["LOWER_ILVL"]:format(math.abs(eval.ilvlDelta))
    end
    return L["SAME_ILVL"]
  end
  if eval.equippedIlvl == nil then
    return L["NOT_EQUIPPED"]
  end
  return L["VS_EQUIPPED_ILVL"]:format(eval.equippedIlvl)
end

function addon:BuildEvaluation(itemID, itemLink, pack, opts)
  opts = opts or {}
  if not pack then
    pack = self:GetPlayerPack()
  end
  if not pack then
    return nil
  end

  local info = DATA:LookupItem(pack, itemID)
  if not info then
    return nil
  end

  local score = DATA.RANK_SCORE[info.rank] or 50
  local link = self:ResolveItemLink(itemID, itemLink)
  local canCompareIlvl = self:ItemLinkHasInstanceData(link)

  local ilvlDelta, equippedIlvl, newIlvl
  local slots = self:GetCompareSlots(link or itemID)
  if slots then
    local weakestEquipped
    for _, slotId in ipairs(slots) do
      local eqIlvl = self:GetEquippedItemLevel(slotId)
      if eqIlvl and (not weakestEquipped or eqIlvl < weakestEquipped) then
        -- Rings / trinkets / dual wield: compare vs the weaker slot
        weakestEquipped = eqIlvl
      end
    end
    if weakestEquipped then
      equippedIlvl = weakestEquipped
      if canCompareIlvl then
        newIlvl = (link and GetDetailedItemLevelInfo(link)) or 0
        if newIlvl and newIlvl > 0 then
          ilvlDelta = newIlvl - weakestEquipped
        end
      end
    end
  end

  return {
    pack = pack,
    info = info,
    score = score,
    ilvlDelta = ilvlDelta,
    equippedIlvl = equippedIlvl,
    itemIlvl = newIlvl,
    itemLink = link,
    isOffspec = opts.isOffspec and true or false,
    specName = pack.specName,
    specIndex = opts.specIndex,
  }
end

-- Mainspec first; if offspec tracking is on, also consider that pack (higher score wins, ties → main).
function addon:BuildBestEvaluation(itemID, itemLink)
  local mainPack, _, mainIdx = self:GetPlayerPack()
  local mainEval = mainPack
    and self:BuildEvaluation(itemID, itemLink, mainPack, { isOffspec = false, specIndex = mainIdx })

  local db = self:GetDB()
  if not db or not db.trackOffspec then
    return mainEval
  end

  local osPack, _, osIdx = self:GetOffspecPack()
  if not osPack or osIdx == mainIdx then
    return mainEval
  end

  local osEval = self:BuildEvaluation(itemID, itemLink, osPack, { isOffspec = true, specIndex = osIdx })
  if mainEval and osEval then
    if (osEval.score or 0) > (mainEval.score or 0) then
      return osEval
    end
    return mainEval
  end
  return mainEval or osEval
end

function addon:RankLabel(rank)
  if rank == "bis" then
    return L["RANK_BIS"]
  elseif rank == "strong" then
    return L["RANK_STRONG"]
  elseif rank == "alt" then
    return L["RANK_ALT"]
  end
  return L["RANK_OK"]
end

function addon:RankColor(rank)
  if rank == "bis" then
    return "ffffd100"
  elseif rank == "strong" then
    return "ff00ff96"
  elseif rank == "alt" then
    return "ff66bbff"
  end
  return "ffaaaaaa"
end

function addon:ContentLabel(key)
  if key == "overall" then
    return L["CONTENT_OVERALL"]
  elseif key == "raid" then
    return L["CONTENT_RAID"]
  elseif key == "mythic" then
    return L["CONTENT_MYTHIC"]
  elseif key == "trinket" then
    return L["CONTENT_TRINKET"]
  elseif key == "alt" then
    return L["RANK_ALT"]
  end
  return nil
end

function addon:MeetsMinRank(rank)
  local minRank = (self:GetDB() and self:GetDB().minRank) or "strong"
  local have = DATA.RANK_ORDER[rank] or 0
  local need = DATA.RANK_ORDER[minRank] or 3
  return have >= need
end

-- Content filter: Overall (+ trinket) is always the baseline.
-- raid/mythic modes additionally include their tagged extras and hide the other.
function addon:MeetsContentFilter(info)
  if not info then
    return false
  end
  local mode = (self:GetDB() and self:GetDB().contentMode) or "all"
  if mode == "all" then
    return true
  end
  local wh = info.wowhead
  if type(wh) ~= "string" or wh == "" then
    wh = "overall"
  end
  -- Ignore full guide URLs sometimes stored by older generators
  if wh:find("http", 1, true) then
    wh = "overall"
  end
  if mode == "overall" then
    return wh == "overall" or wh == "trinket"
  end
  if mode == "raid" then
    return wh == "overall" or wh == "trinket" or wh == "raid"
  end
  if mode == "mythic" then
    return wh == "overall" or wh == "trinket" or wh == "mythic"
  end
  return true
end

local guideLinksFrame

local function CopyText(text)
  if not text or text == "" then
    return false
  end
  if CopyToClipboard then
    CopyToClipboard(text)
    return true
  end
  return false
end

local function EnsureGuideLinksFrame()
  if guideLinksFrame then
    return guideLinksFrame
  end

  local f = CreateFrame("Frame", "BiSPulseGuideLinks", UIParent, "BackdropTemplate")
  f:SetSize(520, 220)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetFrameLevel(1200)
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  f:SetBackdropColor(0.05, 0.05, 0.06, 0.98)
  f:SetBackdropBorderColor(0.15, 0.85, 0.35, 1)
  f:Hide()

  if UISpecialFrames then
    tinsert(UISpecialFrames, "BiSPulseGuideLinks")
  end

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetTextColor(0.95, 0.97, 1.0, 1)
  f.title = title

  local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  hint:SetPoint("RIGHT", f, "RIGHT", -48, 0)
  hint:SetJustifyH("LEFT")
  hint:SetTextColor(0.55, 0.58, 0.62, 1)
  hint:SetText(L["GUIDE_COPY_HINT"] or "Click Copy, or select a URL and press Ctrl+C.")
  f.hint = hint

  local close = CreateFrame("Button", nil, f, "BackdropTemplate")
  close:SetSize(24, 24)
  close:SetPoint("TOPRIGHT", -10, -10)
  close:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  close:SetBackdropColor(0.09, 0.09, 0.10, 1)
  close:SetBackdropBorderColor(0.28, 0.28, 0.30, 1)
  local closeFs = close:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  closeFs:SetPoint("CENTER")
  closeFs:SetText("X")
  closeFs:SetTextColor(0.92, 0.94, 0.96, 1)
  close:SetScript("OnClick", function()
    f:Hide()
  end)
  close:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(0.15, 0.85, 0.35, 1)
  end)
  close:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0.28, 0.28, 0.30, 1)
  end)

  f.rows = {}
  for i = 1, 4 do
    local row = CreateFrame("Frame", nil, f)
    row:SetHeight(36)
    row:SetPoint("LEFT", 16, 0)
    row:SetPoint("RIGHT", -16, 0)
    if i == 1 then
      row:SetPoint("TOP", hint, "BOTTOM", 0, -14)
    else
      row:SetPoint("TOP", f.rows[i - 1], "BOTTOM", 0, -8)
    end

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetTextColor(0.15, 0.85, 0.35, 1)
    row.label = label

    local eb = CreateFrame("EditBox", nil, row, "BackdropTemplate")
    eb:SetHeight(24)
    eb:SetPoint("TOPLEFT", 0, -14)
    eb:SetPoint("RIGHT", -78, -14)
    eb:SetAutoFocus(false)
    eb:SetFontObject(GameFontHighlightSmall)
    eb:SetTextInsets(8, 8, 0, 0)
    eb:SetTextColor(0.92, 0.94, 0.96, 1)
    eb:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
    })
    eb:SetBackdropColor(0.09, 0.09, 0.10, 1)
    eb:SetBackdropBorderColor(0.28, 0.28, 0.30, 1)
    eb:SetScript("OnEditFocusGained", function(self)
      self:HighlightText()
      self:SetBackdropBorderColor(0.15, 0.85, 0.35, 1)
    end)
    eb:SetScript("OnEditFocusLost", function(self)
      self:SetBackdropBorderColor(0.28, 0.28, 0.30, 1)
    end)
    eb:SetScript("OnEscapePressed", function(self)
      self:ClearFocus()
      f:Hide()
    end)
    eb:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
    end)
    eb:SetScript("OnTextChanged", function(self, userInput)
      if userInput and self._url and self:GetText() ~= self._url then
        local pos = self:GetCursorPosition()
        self:SetText(self._url)
        self:SetCursorPosition(math.min(pos or 0, #self._url))
        self:HighlightText()
      end
    end)
    row.edit = eb

    local copy = CreateFrame("Button", nil, row, "BackdropTemplate")
    copy:SetSize(70, 24)
    copy:SetPoint("RIGHT", 0, -14)
    copy:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
    })
    copy:SetBackdropColor(0.09, 0.09, 0.10, 1)
    copy:SetBackdropBorderColor(0.28, 0.28, 0.30, 1)
    local copyFs = copy:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    copyFs:SetPoint("CENTER")
    copyFs:SetText(L["GUIDE_COPY"] or "Copy")
    copyFs:SetTextColor(0.92, 0.94, 0.96, 1)
    copy.text = copyFs
    copy:SetScript("OnEnter", function(self)
      self:SetBackdropBorderColor(0.15, 0.85, 0.35, 1)
    end)
    copy:SetScript("OnLeave", function(self)
      self:SetBackdropBorderColor(0.28, 0.28, 0.30, 1)
    end)
    copy:SetScript("OnClick", function(self)
      local url = row.edit._url or row.edit:GetText() or ""
      if CopyText(url) then
        self.text:SetText(L["GUIDE_COPIED_SHORT"] or "Copied!")
        self.text:SetTextColor(0.15, 0.85, 0.35, 1)
        C_Timer.After(1.2, function()
          if self.text then
            self.text:SetText(L["GUIDE_COPY"] or "Copy")
            self.text:SetTextColor(0.92, 0.94, 0.96, 1)
          end
        end)
      else
        row.edit:SetFocus()
        row.edit:HighlightText()
      end
    end)
    row.copy = copy
    f.rows[i] = row
  end

  guideLinksFrame = f
  return f
end

function addon:PrintGuideLinks(pack)
  pack = pack or (addon.GetChecklistPack and addon:GetChecklistPack()) or (addon.GetPlayerPack and addon:GetPlayerPack())
  if not pack or not pack.guides then
    addon:Print(L["NO_SPEC_DATA"] or "No guide links for this spec.")
    return
  end

  local g = pack.guides
  local links = {}
  if g.wowhead then
    links[#links + 1] = { label = L["SOURCE_WOWHEAD"] or "Wowhead", url = g.wowhead }
  end
  if g.archonRaid then
    links[#links + 1] = {
      label = (L["SOURCE_ARCHON"] or "Archon") .. " Raid",
      url = g.archonRaid,
    }
  end
  if g.archonMythic then
    links[#links + 1] = {
      label = (L["SOURCE_ARCHON"] or "Archon") .. " Mythic+",
      url = g.archonMythic,
    }
  end
  if #links == 0 then
    addon:Print(L["NO_SPEC_DATA"] or "No guide links for this spec.")
    return
  end

  local f = EnsureGuideLinksFrame()
  local specName = ""
  if pack.specName and pack.className then
    specName = pack.specName .. " " .. pack.className
  elseif pack.specName then
    specName = pack.specName
  end
  f.title:SetText((L["GUIDE_LINKS_TITLE"] or "Guide links") .. (specName ~= "" and (" — " .. specName) or ""))

  local yPad = 70 + (#links * 44)
  f:SetHeight(math.max(160, yPad))

  for i, row in ipairs(f.rows) do
    local link = links[i]
    if link then
      row.label:SetText(link.label)
      row.edit._url = link.url
      row.edit:SetText(link.url)
      row.edit:SetCursorPosition(0)
      row.copy.text:SetText(L["GUIDE_COPY"] or "Copy")
      row.copy.text:SetTextColor(0.92, 0.94, 0.96, 1)
      row:Show()
    else
      row:Hide()
    end
  end

  f:Show()
  f:Raise()
  -- Focus first URL so Ctrl+C works immediately.
  if f.rows[1] and f.rows[1]:IsShown() then
    f.rows[1].edit:SetFocus()
    f.rows[1].edit:HighlightText()
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "BiSPulse" then
    BiSPulseDB = CopyDefaults(defaults, BiSPulseDB)
    -- 1.5.2: loot-list alerts should not be gated by "only mine"
    if (BiSPulseDB.settingsRev or 0) < 152 then
      BiSPulseDB.onlyMine = false
      BiSPulseDB.settingsRev = 152
    end
    addon.db = BiSPulseDB
  elseif event == "PLAYER_LOGIN" then
    addon:Print(L["LOADED"])
    local pack = addon:GetPlayerPack()
    if pack then
      local n = 0
      if pack.items then
        for _ in pairs(pack.items) do
          n = n + 1
        end
      end
      addon:Print(("%s %s — %s (%s) — %d tracked items — Wowhead %s"):format(
        pack.specName, pack.className, pack.patch, pack.season, n, pack.updated or "?"
      ))
      local age = addon:GetPackAgeDays(pack)
      if age and age >= 14 then
        addon:Print(L["DATA_STALE"]:format(age, pack.updated))
      end
    else
      addon:Print(L["NO_SPEC_DATA"])
    end
    -- Visible confirmation for first load / troubleshooting
    if RaidNotice_AddMessage then
      RaidNotice_AddMessage(RaidWarningFrame, "|cff00ff96BiSPulse|r active — /bp list", ChatTypeInfo["SYSTEM"] or { r = 0, g = 1, b = 0.6 })
    end
  end
end)

SLASH_BISPULSE1 = "/bispulse"
SLASH_BISPULSE2 = "/bp"
SlashCmdList["BISPULSE"] = function(msg)
  msg = strtrim(string.lower(msg or ""))
  if msg == "reset" then
    BiSPulseDB = CopyDefaults(defaults, {})
    addon.db = BiSPulseDB
    addon:Print("Defaults restored.")
    return
  end
  if msg == "scan" then
    if addon.ScanBagsForBiS then
      addon:ScanBagsForBiS()
    end
    return
  end
  if msg == "list" or msg == "checklist" then
    if addon.ToggleChecklist then
      addon:ToggleChecklist()
    end
    return
  end
  if msg == "toast" then
    if addon.PreviewToast then
      addon:PreviewToast()
    end
    return
  end
  if msg == "help" then
    addon:Print(L["HELP"])
    return
  end
  if addon.OpenOptions then
    addon:OpenOptions()
  else
    addon:Print(L["HELP"])
  end
end
