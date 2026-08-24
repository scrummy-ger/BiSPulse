--[[
  Brewmaster Monk BiS — Midnight Patch 12.1
  Source: Wowhead only
  Wowhead: https://www.wowhead.com/guide/classes/monk/brewmaster/bis-gear
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
  [159304] = entry({
    name = "Goldfeather Boots",
    slot = "Boots",
    drop = "Kings' Rest",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [244576] = entry({
    name = "Silvermoon Agent's Deflectors",
    slot = "Wrist",
    drop = "Leatherworking",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [251148] = entry({
    name = "Pilfered Precious Band",
    slot = "Ring",
    drop = "Den of Nalorakk",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [251513] = entry({
    name = "Loa Worshiper's Band",
    slot = "Ring",
    drop = "Jewelcrafting",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268253] = entry({
    name = "Silken Voodoo Drape",
    slot = "Cloak",
    drop = "The Coiled Altar",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268256] = entry({
    name = "Sash of the Forlorn Vessel",
    slot = "Belt",
    drop = "The Coiled Altar",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268265] = entry({
    name = "Aqirbane Reliquary",
    slot = "Neck",
    drop = "Ula'tek",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [271517] = entry({
    name = "Item 271517",
    slot = "Shoulders",
    drop = "Catalyst|Mythic+|Vault",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [271518] = entry({
    name = "Item 271518",
    slot = "Legs",
    drop = "Catalyst|Raid|Vault",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [271519] = entry({
    name = "Item 271519",
    slot = "Head",
    drop = "Catalyst|Raid|Vault",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [271520] = entry({
    name = "Item 271520",
    slot = "Gloves",
    drop = "Catalyst|Mythic+|Vault",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [271522] = entry({
    name = "Item 271522",
    slot = "Chest",
    drop = "Catalyst|Mythic+|Vault",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
}

BiSPulseData:Register("MONK", 1, {
  className = "Monk",
  specName = "Brewmaster",
  patch = "12.1",
  season = "Midnight Season 2",
  updated = "2026-08-22",
  primarySource = "Wowhead",
  guides = {
    wowhead = "https://www.wowhead.com/guide/classes/monk/brewmaster/bis-gear",
  },
  items = items,
})
