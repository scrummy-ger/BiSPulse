--[[
  Frost Mage BiS — Midnight Patch 12.1
  Source: Wowhead only
  Wowhead: https://www.wowhead.com/guide/classes/mage/frost/bis-gear
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
    name = "Primal Leywarden's Manaflux",
    slot = "Shoulders",
    drop = "The Coiled Altar",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268255] = entry({
    name = "Cackling Soultreads",
    slot = "Legs",
    drop = "The Coiled Altar",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268263] = entry({
    name = "Frostscale's Mystic Frond",
    slot = "Offhand",
    drop = "Nymrissa Wavecaller",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268265] = entry({
    name = "Crown of the Primal Leywarden",
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
  [270167] = entry({
    name = "Wavecaller's Seastone",
    slot = "Trinket",
    drop = "Nymrissa Wavecaller",
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
  [273649] = entry({
    name = "Stormbound Emblem of Dazar",
    slot = "",
    drop = "",
    source = "Wowhead",
    wowhead = "mythic",
    rank = RANK.STRONG,
    note = nil,
    priority = nil,
  }),
  [273785] = entry({
    name = "Primordial Robe of Rites",
    slot = "",
    drop = "",
    source = "Wowhead",
    wowhead = "mythic",
    rank = RANK.STRONG,
    note = nil,
    priority = nil,
  }),
  [273796] = entry({
    name = "Vile Vial of Volatile Venom",
    slot = "",
    drop = "",
    source = "Wowhead",
    wowhead = "mythic",
    rank = RANK.STRONG,
    note = nil,
    priority = nil,
  }),
}

BiSPulseData:Register("MAGE", 3, {
  className = "Mage",
  specName = "Frost",
  patch = "12.1",
  season = "Midnight Season 2",
  updated = "2026-08-25",
  primarySource = "Wowhead",
  guides = {
    wowhead = "https://www.wowhead.com/guide/classes/mage/frost/bis-gear",
  },
  items = items,
})
