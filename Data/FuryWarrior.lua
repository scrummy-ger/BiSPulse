--[[
  Fury Warrior BiS — Midnight Patch 12.1
  Source: Wowhead only
  Wowhead: https://www.wowhead.com/guide/classes/warrior/fury/bis-gear
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
  [251126] = entry({
    name = "Greathelm of Temptation",
    slot = "",
    drop = "",
    source = "Wowhead",
    wowhead = "mythic",
    rank = RANK.STRONG,
    note = nil,
    priority = nil,
  }),
  [251138] = entry({
    name = "Cinderfury Shoulderguards",
    slot = "",
    drop = "",
    source = "Wowhead",
    wowhead = "mythic",
    rank = RANK.STRONG,
    note = nil,
    priority = nil,
  }),
  [252258] = entry({
    name = "Sickening Signet Of Atroxus",
    slot = "Ring",
    drop = "Voidscar Arena",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268213] = entry({
    name = "Maze-roa, Warlord's Fury",
    slot = "Weapon",
    drop = "The Coiled Altar",
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
    name = "Raging Pauldrons of the Jade Warlord",
    slot = "Shoulders",
    drop = "The Coiled Altar",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268259] = entry({
    name = "Girdle Of Toxic Regret",
    slot = "Gloves",
    drop = "The Coiled Altar",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268260] = entry({
    name = "Greaves of the Jade Warlord",
    slot = "Legs",
    drop = "Vashnik the Malignant",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268265] = entry({
    name = "Aqirbane Reliquary",
    slot = "",
    drop = "Ula'tek",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [270173] = entry({
    name = "Zul'jin's Guillotine Technique",
    slot = "Trinket",
    drop = "The Coiled Altar",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [270175] = entry({
    name = "Voracious Heart Of Ula'tek",
    slot = "Trinket",
    drop = "Ula'tek",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [271457] = entry({
    name = "Jeweled Gauntlets of the Jade Warlord",
    slot = "",
    drop = "",
    source = "Wowhead",
    wowhead = "mythic",
    rank = RANK.STRONG,
    note = nil,
    priority = nil,
  }),
}

BiSPulseData:Register("WARRIOR", 2, {
  className = "Warrior",
  specName = "Fury",
  patch = "12.1",
  season = "Midnight Season 2",
  updated = "2026-08-24",
  primarySource = "Wowhead",
  guides = {
    wowhead = "https://www.wowhead.com/guide/classes/warrior/fury/bis-gear",
  },
  items = items,
})
