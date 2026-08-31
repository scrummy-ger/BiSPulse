--[[
  Augmentation Evoker BiS — Midnight Patch 12.1
  Source: Wowhead only
  Wowhead: https://www.wowhead.com/guide/classes/evoker/augmentation/bis-gear
]]

local RANK = BiSPulseData.RANK

local function entry(opts)
  return {
    name = opts.name,
    slot = opts.slot,
    drop = opts.drop,
    source = opts.source,
    wowhead = opts.wowhead,
    rank = opts.rank,
    note = opts.note,
    priority = opts.priority,
  }
end

local items = {
  [158366] = entry({
    name = "Charged Sandstone Band",
    slot = "Ring",
    drop = "Temple of Sethraliss",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [193752] = entry({
    name = "Galerattle Gauntlets",
    slot = "",
    drop = "",
    source = "Wowhead",
    wowhead = "mythic",
    rank = RANK.STRONG,
    note = nil,
    priority = nil,
  }),
  [239035] = entry({
    name = "Sethraliss' Fanged Helm",
    slot = "",
    drop = "",
    source = "Wowhead",
    wowhead = "mythic",
    rank = RANK.STRONG,
    note = nil,
    priority = nil,
  }),
  [250224] = entry({
    name = "Mindpiercer's Sigil",
    slot = "Trinket",
    drop = "Voidscar Arena",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268233] = entry({
    name = "Earthen Pillars of Calamity",
    slot = "Legs",
    drop = "Sszorak",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268249] = entry({
    name = "Vile Alchemist's Band",
    slot = "Ring",
    drop = "Vashnik the Malignant",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268253] = entry({
    name = "Calamitous Echo's Sundered Peaks",
    slot = "Shoulders",
    drop = "The Coiled Altar",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268254] = entry({
    name = "Serpentine Mixing Belt",
    slot = "Gloves",
    drop = "Vashnik the Malignant",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268265] = entry({
    name = "Aqirbane Reliquary",
    slot = "Head",
    drop = "Ula'tek",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [270164] = entry({
    name = "Gebbo's Bottomless Bag",
    slot = "Trinket",
    drop = "The Lost Explorers",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [271092] = entry({
    name = "Janthrazet The Soul Fang",
    slot = "Weapon",
    drop = "Ula'tek",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
}

BiSPulseData:Register("EVOKER", 3, {
  className = "Evoker",
  specName = "Augmentation",
  patch = "12.1",
  season = "Midnight Season 2",
  updated = "2026-08-31",
  primarySource = "Wowhead",
  guides = {
    wowhead = "https://www.wowhead.com/guide/classes/evoker/augmentation/bis-gear",
  },
  items = items,
})
