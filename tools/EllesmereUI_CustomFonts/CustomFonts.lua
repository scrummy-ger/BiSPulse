--[[
  Ellesmere UI (EUI) — NOT ElvUI.
  Fonts in EllesmereUI\media\fonts\ only appear after registration in FONT_FILES + FONT_ORDER.
]]

local ADDON = "EllesmereUI_CustomFonts"
local MEDIA = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\"

local CUSTOM_FONTS = {
  ["Contrail One"] = "ContrailOne.ttf",
  ["Manrope"] = "Manrope.ttf",
}

local injected = false

local function msg(text, r, g, b)
  DEFAULT_CHAT_FRAME:AddMessage(
    "|cff05d29e" .. ADDON .. "|r: " .. text,
    r or 1, g or 1, b or 1
  )
end

local function inject()
  if injected then
    return true
  end

  local EUI = _G.EllesmereUI
  if not EUI or not EUI.FONT_FILES or not EUI.FONT_ORDER then
    return false
  end

  for name, file in pairs(CUSTOM_FONTS) do
    EUI.FONT_FILES[name] = file
  end

  local order = EUI.FONT_ORDER
  local names = {}
  for name in pairs(CUSTOM_FONTS) do
    names[#names + 1] = name
  end
  table.sort(names)

  local function inOrder(n)
    for _, entry in ipairs(order) do
      if entry == n then
        return true
      end
    end
    return false
  end

  local needAny = false
  for _, name in ipairs(names) do
    if not inOrder(name) then
      needAny = true
      break
    end
  end

  if needAny then
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
      if not inOrder(names[i]) then
        table.insert(order, insertAt, names[i])
      end
    end
  end

  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  if LSM then
    EUI._smFontPaths = EUI._smFontPaths or {}
    for name, file in pairs(CUSTOM_FONTS) do
      local path = MEDIA .. file
      LSM:Register(LSM.MediaType.FONT, name, path)
      EUI._smFontPaths[name] = path
    end
  end

  if EUI.InvalidateFontCache then
    EUI.InvalidateFontCache()
  end

  injected = true
  return true
end

local function tryInject(reason)
  if inject() then
    msg("Contrail One + Manrope registriert (" .. reason .. "). /eui -> Fonts -> Global Font waehlen, dann /reload")
    return true
  end
  return false
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "EllesmereUI" then
    tryInject("ADDON_LOADED")
  elseif event == "PLAYER_LOGIN" then
    if not injected then
      tryInject("PLAYER_LOGIN")
    end
  end
end)

SLASH_EUIFONTS1 = "/euifonts"
SlashCmdList.EUIFONTS = function()
  if not tryInject("slash") then
    msg("EllesmereUI noch nicht bereit — bitte /reload", 1, 0.3, 0.3)
    return
  end
  local EUI = EllesmereUI
  for name, file in pairs(CUSTOM_FONTS) do
    local registered = EUI.FONT_FILES[name] == file
    msg(name .. " -> " .. file .. (registered and " |cff00ff00OK|r" or " |cffff0000FEHLT|r"))
  end
  local global = EUI.GetFontsDB and EUI.GetFontsDB().global or "?"
  msg("Aktuell gewaehlte Global Font: |cffFFFF00" .. tostring(global) .. "|r")
end

-- Late load (LoadAfter EllesmereUI)
C_Timer.After(0, function()
  tryInject("init")
end)
