--[[
  Balance Druid BiS — Midnight Patch 12.1
  Source: Wowhead only
  Wowhead: https://www.wowhead.com/guide/classes/druid/balance/bis-gear
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
  [250215] = entry({
    name = "Freightrunner's Flask",
    slot = "",
    drop = "",
    source = "Wowhead",
    wowhead = "mythic",
    rank = RANK.STRONG,
    note = nil,
    priority = nil,
  }),
  [251159] = entry({
    name = "War Trial Vestments",
    slot = "Cloak",
    drop = "Den of Nalorakk",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [252258] = entry({
    name = "Sickening Signet of Atroxus",
    slot = "",
    drop = "",
    source = "Wowhead",
    wowhead = "mythic",
    rank = RANK.STRONG,
    note = nil,
    priority = nil,
  }),
  [268234] = entry({
    name = "Silvermoon Agent's Deflectors",
    slot = "Wrist",
    drop = "Sszorak",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268246] = entry({
    name = "Frothing Venom Spaulders",
    slot = "Neck",
    drop = "The Lost Explorers",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268261] = entry({
    name = "Bespittled Slitherslippers",
    slot = "",
    drop = "The Twin Fangs",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [270164] = entry({
    name = "Gebbo's Bottomless Bag",
    slot = "",
    drop = "",
    source = "Wowhead",
    wowhead = "mythic",
    rank = RANK.STRONG,
    note = nil,
    priority = nil,
  }),
  [270167] = entry({
    name = "Wavecallers Seastone",
    slot = "",
    drop = "Nymrissa Wavecaller",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [271092] = entry({
    name = "Janthrazet The Soul Fang",
    slot = "",
    drop = "Ula'tek",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [273796] = entry({
    name = "Vile Vial Of Volatile Venom",
    slot = "Trinket",
    drop = "Altar of Fangs",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
}

BiSPulseData:Register("DRUID", 1, {
  className = "Druid",
  specName = "Balance",
  patch = "12.1",
  season = "Midnight Season 2",
  updated = "2026-08-25",
  primarySource = "Wowhead",
  guides = {
    wowhead = "https://www.wowhead.com/guide/classes/druid/balance/bis-gear",
  },
  items = items,
})
