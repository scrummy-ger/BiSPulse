-- Manual patch for EllesmereUI.lua (alternative to the companion addon).
-- File: World of Warcraft\_retail_\Interface\AddOns\EllesmereUI\EllesmereUI.lua
-- Search: EllesmereUI.FONT_FILES = {
--
-- 1) Add inside FONT_FILES (filename must match media\fonts\ on disk):
--
--   ["Contrail One"] = "Contrail One.ttf",
--
-- 2) Add inside FONT_ORDER (before Blizzard fonts):
--
--   "Contrail One",
--
-- Example FONT_FILES block after patch:
--[[
EllesmereUI.FONT_FILES = {
 ["Expressway"] = "Expressway.TTF",
 ...
 ["KMT Ninja Naruto"] = "KMT Ninja Naruto.ttf",
 ["Contrail One"] = "Contrail One.ttf",
 ["Friz Quadrata"] = nil,
 ...
}
--]]
--
-- Example FONT_ORDER line after patch:
--[[
 "KMT Kimberley", "KMT Ninja Naruto", "Contrail One",
 "Friz Quadrata", "Arial", "Morpheus", "Skurri",
--]]
--
-- WoW must be closed while editing. After save: start WoW -> /eui -> Fonts -> Global Font.
-- NOTE: EllesmereUI updates overwrite EllesmereUI.lua — prefer tools/EllesmereUI_CustomFonts/
