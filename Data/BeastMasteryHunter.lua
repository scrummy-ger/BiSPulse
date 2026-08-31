--[[
  Beast Mastery Hunter BiS — Midnight Patch 12.1
  Source: Wowhead only
  Wowhead: https://www.wowhead.com/guide/classes/hunter/beast-mastery/bis-gear
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
  [244581] = entry({
    name = "Farstrider's Trophy Belt",
    slot = "Gloves",
    drop = "Leatherworking",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [244584] = entry({
    name = "Farstrider's Plated Bracers",
    slot = "Chest",
    drop = "Leatherworking",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [252258] = entry({
    name = "Sickening Signet of Atroxus",
    slot = "Ring",
    drop = "Voidscar Arena",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268207] = entry({
    name = "Caustic Repose Greatbow",
    slot = "Weapon",
    drop = "Ula'tek",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
  [268233] = entry({
    name = "Ferocious Scaleboots",
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
    name = "Silken Voodoo Drape",
    slot = "Shoulders",
    drop = "The Coiled Altar",
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
    name = "Voracious Heart of Ula'tek",
    slot = "Trinket",
    drop = "Ula'tek",
    source = "Wowhead",
    wowhead = "overall",
    rank = RANK.BIS,
    note = nil,
    priority = true,
  }),
}

BiSPulseData:Register("HUNTER", 1, {
  className = "Hunter",
  specName = "Beast Mastery",
  patch = "12.1",
  season = "Midnight Season 2",
  updated = "2026-08-31",
  primarySource = "Wowhead",
  guides = {
    wowhead = "https://www.wowhead.com/guide/classes/hunter/beast-mastery/bis-gear",
  },
  items = items,
})
