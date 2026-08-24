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
  alertOnDowngrade = false,
  trackOffspec = false,
  offspecIndex = 0, -- 0 = auto (first other spec of your class)
  checklistView = "main", -- "main" | "off"
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
  local maxBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
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
      if link and self:GetItemIDFromLink(link) == itemID then
        return link, "bags"
      end
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
