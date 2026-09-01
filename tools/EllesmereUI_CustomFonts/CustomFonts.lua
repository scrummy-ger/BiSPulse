--[[
  EllesmereUI only lists fonts that are registered in EllesmereUI.lua:
    EllesmereUI.FONT_FILES  (display name -> filename in media\fonts\)
    EllesmereUI.FONT_ORDER  (dropdown order)

  Dropping .ttf files into EllesmereUI\media\fonts\ alone does NOT add them to the picker.
  This companion addon injects your custom fonts at load time so EllesmereUI updates
  do not wipe the registration.

  Edit CUSTOM_FONTS below: key = name in dropdown, value = exact filename on disk.
]]

local ADDON = "EllesmereUI_CustomFonts"
local MEDIA = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\"

-- Display name -> filename (must match the file in EllesmereUI\media\fonts\)
local CUSTOM_FONTS = {
  ["Contrail One"] = "Contrail One.ttf",
  -- Add more fonts you copied into media\fonts\:
  -- ["My Font"] = "MyFont-FileName.ttf",
}

local function sortedNames()
  local names = {}
  for name in pairs(CUSTOM_FONTS) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

local function alreadyInOrder(order, name)
  for _, entry in ipairs(order) do
    if entry == name then
      return true
    end
  end
  return false
end

local function inject()
  local EUI = _G.EllesmereUI
  if not EUI or not EUI.FONT_FILES or not EUI.FONT_ORDER then
    return false
  end

  for name, file in pairs(CUSTOM_FONTS) do
    EUI.FONT_FILES[name] = file
  end

  local order = EUI.FONT_ORDER
  local names = sortedNames()
  local needSection = false
  for _, name in ipairs(names) do
    if not alreadyInOrder(order, name) then
      needSection = true
      break
    end
  end

  if needSection then
    local insertAt = #order + 1
    for i, entry in ipairs(order) do
      if entry == "Friz Quadrata" then
        insertAt = i
        break
      end
    end

    if order[insertAt - 1] ~= "---" then
      table.insert(order, insertAt, "---")
      insertAt = insertAt + 1
    end

    for i = #names, 1, -1 do
      local name = names[i]
      if not alreadyInOrder(order, name) then
        table.insert(order, insertAt, name)
      end
    end
  end

  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  if LSM then
    if not EUI._smFontPaths then
      EUI._smFontPaths = {}
    end
    for name, file in pairs(CUSTOM_FONTS) do
      local path = MEDIA .. file
      LSM:Register(LSM.MediaType.FONT, name, path)
      EUI._smFontPaths[name] = path
    end
  end

  if EUI.InvalidateFontCache then
    EUI.InvalidateFontCache()
  end

  return true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, addonName)
  if addonName == "EllesmereUI" then
    inject()
  end
end)

-- EllesmereUI already loaded when we start (Dependencies load order)
if inject() then
  print("|cff05d29e" .. ADDON .. "|r: custom fonts registered.")
end
