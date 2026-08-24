local addon = BiSPulse
local L = BiSPulseLocale

local function AddEvalLines(tooltip, eval)
  if not eval then
    return
  end

  local info = eval.info
  local color = addon:RankColor(info.rank)
  local rankText = addon:RankLabel(info.rank)
  local specTag = eval.specName and ("  |cffaaaaaa" .. eval.specName .. "|r") or ""
  if eval.isOffspec then
    specTag = "  |cff66bbff" .. (eval.specName or L["OFFSPEC"] or "Offspec") .. "|r"
  end

  tooltip:AddLine(" ")
  tooltip:AddLine("|cff00ff96" .. L["TOOLTIP_HEADER"] .. "|r" .. specTag .. "  |c" .. color .. rankText .. "|r")

  local sources = {}
  if info.wowhead then
    local label = addon:ContentLabel(info.wowhead)
    table.insert(sources, L["SOURCE_WOWHEAD"] .. (label and (": " .. label) or ""))
  end
  if #sources > 0 then
    tooltip:AddLine(table.concat(sources, "  ·  "), 0.75, 0.85, 0.95)
  end

  tooltip:AddDoubleLine(L["SCORE"], tostring(eval.score) .. " / 100", 0.7, 0.7, 0.7, 1, 1, 1)

  if info.source then
    tooltip:AddLine(info.source, 0.55, 0.55, 0.55)
  end

  if info.note then
    tooltip:AddLine(info.note, 0.9, 0.75, 0.4, true)
  end

  if info.priority then
    tooltip:AddLine("|cffff6600Voidcore / high priority target|r", 1, 0.4, 0)
  end

  local deltaText = addon:FormatIlvlCompare(eval)
  if deltaText then
    if eval.ilvlDelta ~= nil then
      tooltip:AddDoubleLine(L["EQUIPPED_COMPARE"], deltaText, 0.7, 0.7, 0.7, 0.9, 0.9, 0.9)
    else
      tooltip:AddLine(deltaText, 0.6, 0.9, 0.6)
    end
  end

  local pack = eval.pack
  if pack and pack.statPriority then
    tooltip:AddLine("Stats: " .. table.concat(pack.statPriority, " > "), 0.5, 0.5, 0.5)
  end
end

local function ProcessTooltip(tooltip, itemID, itemLink)
  local db = addon:GetDB()
  if not db or not db.enabled or not db.tooltips then
    return
  end
  if not itemID then
    return
  end

  local mainPack, _, mainIdx = addon:GetPlayerPack()
  local mainEval = mainPack
    and addon:BuildEvaluation(itemID, itemLink, mainPack, { isOffspec = false, specIndex = mainIdx })

  local osEval
  if db.trackOffspec then
    local osPack, _, osIdx = addon:GetOffspecPack()
    if osPack and osIdx ~= mainIdx then
      osEval = addon:BuildEvaluation(itemID, itemLink, osPack, { isOffspec = true, specIndex = osIdx })
    end
  end

  if not mainEval and not osEval then
    return
  end

  if mainEval then
    AddEvalLines(tooltip, mainEval)
  end
  if osEval then
    AddEvalLines(tooltip, osEval)
  end
  tooltip:Show()
end

local function OnTooltipSetItem(tooltip)
  if not tooltip or tooltip.BiSPulseDone then
    return
  end

  local _, link = tooltip:GetItem()
  if not link then
    -- Retail sometimes needs this fallback
    local info = tooltip.GetTooltipData and tooltip:GetTooltipData()
    if info and info.id then
      tooltip.BiSPulseDone = true
      ProcessTooltip(tooltip, info.id, nil)
    end
    return
  end

  local itemID = addon:GetItemIDFromLink(link)
  tooltip.BiSPulseDone = true
  ProcessTooltip(tooltip, itemID, link)
end

local function ClearFlag(tooltip)
  if tooltip then
    tooltip.BiSPulseDone = nil
  end
end

-- Modern tooltip API (Dragonflight+)
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    local db = addon:GetDB()
    if not db or not db.enabled or not db.tooltips then
      return
    end
    if not data or not data.id then
      return
    end
    local link
    if data.guid and C_Item and C_Item.GetItemLinkByGUID then
      link = C_Item.GetItemLinkByGUID(data.guid)
    end
    ProcessTooltip(tooltip, data.id, link)
  end)
else
  -- Fallback for older clients
  GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
  GameTooltip:HookScript("OnTooltipCleared", function(self)
    ClearFlag(self)
  end)
  if ItemRefTooltip then
    ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    ItemRefTooltip:HookScript("OnTooltipCleared", function(self)
      ClearFlag(self)
    end)
  end
end
