-- Forces speech-bubble text to 12pt. Works on default Blizzard bubbles
-- when ElvUI bubble skinning is disabled or broken (Midnight 12.x).
local FONT_SIZE = 12
local FONT = "Fonts\\FRIZQT__.TTF"

local function skinBubble(bubble)
    if not bubble or not bubble.GetRegions then return end

    -- 9.x+ nests the FontString inside a child frame
    local frames = { bubble }
    if bubble.GetChildren then
        local child = bubble:GetChildren()
        if child then frames[#frames + 1] = child end
    end

    for _, frame in ipairs(frames) do
        for i = 1, frame:GetNumRegions() do
            local region = select(i, frame:GetRegions())
            if region and region:GetObjectType() == "FontString" then
                local _, size = region:GetFont()
                if size ~= FONT_SIZE then
                    region:SetFont(FONT, FONT_SIZE, "")
                end
            end
        end
    end
end

local function skinAll()
    if not C_ChatBubbles or not C_ChatBubbles.GetAllChatBubbles then return end
    for _, bubble in ipairs(C_ChatBubbles.GetAllChatBubbles()) do
        skinBubble(bubble)
    end
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 0.05 then return end
    self.elapsed = 0
    skinAll()
end)

SLASH_BUBBLEFONT121 = "/bubblefont"
SlashCmdList["BUBBLEFONT12"] = function(msg)
    local n = tonumber(msg)
    if n and n >= 8 and n <= 24 then
        FONT_SIZE = n
        print("|cff00ff00BubbleFont12:|r Größe auf " .. n .. " gesetzt.")
    else
        print("|cff00ff00BubbleFont12:|r Aktuelle Größe: " .. FONT_SIZE .. " (Befehl: /bubblefont 12)")
    end
end
