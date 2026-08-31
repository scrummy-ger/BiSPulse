--[[
  Mistweaver Monk BiS — Midnight Patch 12.1
  Source: Wowhead only
  Wowhead: https://www.wowhead.com/guide/classes/monk/mistweaver/bis-gear
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
  [159459] = entry({
    name = "Ritual Binder's Ring",
    slot = "Ring",
    drop = "Kings' Rest",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [159667] = entry({
    name = "Vessel Of Last Rites",
    slot = "Offhand",
    drop = "Kings' Rest",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [193763] = entry({
    name = "Fireproof Drape",
    slot = "Shoulders",
    drop = "Ruby Life Pools",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [251135] = entry({
    name = "Fury Fletched Armlets",
    slot = "Chest",
    drop = "Murder Row",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [251189] = entry({
    name = "Rootwalker Harness",
    slot = "Belt",
    drop = "The Blinding Vale",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268211] = entry({
    name = "Baleful Hexblade",
    slot = "Weapon",
    drop = "The Coiled Altar",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268247] = entry({
    name = "Breakwater Boots",
    slot = "Boots",
    drop = "Nymrissa Wavebinder",
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
  [268266] = entry({
    name = "Alluring Bubbleband",
    slot = "Ring",
    drop = "Nymrissa Wavebinder",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [270162] = entry({
    name = "Soulcoiler Ritual Vessel",
    slot = "Trinket",
    drop = "Nek'zali the Soulcoiler",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [270167] = entry({
    name = "Wavecaller's Seastone",
    slot = "Trinket",
    drop = "Nymrissa Wavebinder",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
}

BiSPulseData:Register("MONK", 2, {
  className = "Monk",
  specName = "Mistweaver",
  patch = "12.1",
  season = "Midnight Season 2",
  updated = "2026-08-31",
  primarySource = "Wowhead",
  guides = {
    wowhead = "https://www.wowhead.com/guide/classes/monk/mistweaver/bis-gear",
  },
  items = items,
})
