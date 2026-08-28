-- Speech bubble font size for Midnight retail.
-- Ellesmere UI has no setting for this; ElvUI only works when bubble skinning is enabled.
local ADDON = "BubbleFont12"
local db

local function initDB()
    BubbleFont12DB = BubbleFont12DB or {}
    if BubbleFont12DB.fontSize == nil then
        BubbleFont12DB.fontSize = 12
    end
    db = BubbleFont12DB
end

local MAX_WIDTH = 300

local function isBubbleFrame(frame)
    if not frame or frame:GetObjectType() ~= "Frame" then return false end
    if frame.isChatBubble == false then return false end
    if frame.isChatBubble then return true end
    local backdrop = frame.GetBackdrop and frame:GetBackdrop()
    if backdrop and backdrop.bgFile == "Interface\\Tooltips\\ChatBubble-Background" then
        frame.isChatBubble = true
        return true
    end
    return false
end

local function eachFontString(frame, fn)
    if not frame then return end

    local function scan(f)
        if f.GetRegions then
            for i = 1, f:GetNumRegions() do
                local region = select(i, f:GetRegions())
                if region and region:GetObjectType() == "FontString" then
                    fn(f, region)
                end
            end
        end
        if f.GetChildren then
            local child = f:GetChildren()
            if child and child ~= f then
                scan(child)
            end
        end
    end

    scan(frame)
end

local function formatBubble(frame, fontstring)
    if not frame:IsShown() then
        fontstring._bf12Last = nil
        return
    end

    local text = fontstring:GetText() or ""
    if text == "" then return end

    local fontPath = (ChatFrame1 and ChatFrame1.GetFont and select(1, ChatFrame1:GetFont())) or "Fonts\\FRIZQT__.TTF"
    local _, _, flags = fontstring:GetFont()
    fontstring:SetFont(fontPath, db.fontSize, flags or "")

    if text ~= fontstring._bf12Last then
        fontstring._bf12Last = text
        MAX_WIDTH = math.max(frame:GetWidth() or 0, MAX_WIDTH)
        fontstring:SetText(text)
        fontstring:SetWidth(math.min(fontstring:GetStringWidth(), MAX_WIDTH - 14))
    end
end

local function scanBubbles()
    if C_ChatBubbles and C_ChatBubbles.GetAllChatBubbles then
        local ok, bubbles = pcall(C_ChatBubbles.GetAllChatBubbles, true)
        if ok and bubbles then
            for _, bubble in pairs(bubbles) do
                eachFontString(bubble, formatBubble)
            end
        end
    end

    for i = 1, WorldFrame:GetNumChildren() do
        local frame = select(i, WorldFrame:GetChildren())
        if isBubbleFrame(frame) then
            eachFontString(frame, formatBubble)
        end
    end
end

local ticker = CreateFrame("Frame")
ticker.elapsed = 0
ticker:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < 0.08 then return end
    self.elapsed = 0
    scanBubbles()
end)

local function printStatus()
    print("|cff00ff00" .. ADDON .. "|r: Schriftgröße " .. db.fontSize .. " (Befehl: /bubblefont 12)")
end

SLASH_BUBBLEFONT121 = "/bubblefont"
SlashCmdList["BUBBLEFONT12"] = function(msg)
    msg = msg and strtrim(msg) or ""
    if msg == "test" then
        printStatus()
        print("|cff00ff00" .. ADDON .. "|r: Bubbles gefunden (API): " .. tostring(C_ChatBubbles and C_ChatBubbles.GetAllChatBubbles ~= nil))
        scanBubbles()
        return
    end
    local n = tonumber(msg)
    if n and n >= 8 and n <= 24 then
        db.fontSize = n
        printStatus()
        scanBubbles()
    else
        printStatus()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        initDB()
    elseif event == "PLAYER_LOGIN" then
        initDB()
        C_Timer.After(2, printStatus)
    end
end)
