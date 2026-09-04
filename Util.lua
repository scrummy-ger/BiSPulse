BiSPulse = BiSPulse or {}

local function SafeRegisterEvent(frame, event)
  if not frame or not event then
    return false
  end
  if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event) then
    return false
  end
  local ok = pcall(frame.RegisterEvent, frame, event)
  return ok
end

BiSPulseSafeRegisterEvent = SafeRegisterEvent

BiSPulse.ICON = "Interface\\AddOns\\BiSPulse\\Media\\BiSPulseIcon"
BiSPulse.MINIMAP_ICON = "Interface\\AddOns\\BiSPulse\\Media\\BiSPulseMinimap"

-- Boss / encounter → raid or dungeon (Midnight S1 + S2). Longer keys first.
local VENOMOUS = "The Venomous Abyss"
local VOIDSPIRE = "The Voidspire"
local DREAMRIFT = "The Dreamrift"
local SPOREFALL = "Sporefall"
local MURDER_ROW = "Murder Row"
local VOIDSCAR = "Voidscar Arena"
local ALTAR_FANGS = "Altar of Fangs"
local DEN_NALORAKK = "Den of Nalorakk"
local BLINDING = "The Blinding Vale"
local KINGS_REST = "King's Rest"
local SETHRALISS = "Temple of Sethraliss"
local RUBY = "Ruby Life Pools"

local DROP_INSTANCE = {
  -- The Venomous Abyss (S2 raid)
  { "nek'zali the soulcoiler", VENOMOUS },
  { "vashnik the malignant", VENOMOUS },
  { "entombed sentinels", VENOMOUS },
  { "the lost explorers", VENOMOUS },
  { "the coiled altar", VENOMOUS },
  { "the twin fangs", VENOMOUS },
  { "lost explorers", VENOMOUS },
  { "coiled altar", VENOMOUS },
  { "twin fangs", VENOMOUS },
  { "breath of ula'tek", VENOMOUS },
  { "nek'zali", VENOMOUS },
  { "vashnik", VENOMOUS },
  { "sszorak", VENOMOUS },
  { "ula'tek", VENOMOUS },
  { "vexhul", VENOMOUS },
  { "ithraz", VENOMOUS },
  -- Altar of Fangs (S2 dungeon) — before short Zul'jan clash with raid lore
  { "the writhing coil", ALTAR_FANGS },
  { "writhing coil", ALTAR_FANGS },
  { "the hoardmonger", ALTAR_FANGS },
  { "nymrissa wavebinder", ALTAR_FANGS },
  { "nymrissa wavecaller", ALTAR_FANGS },
  { "rav'i", ALTAR_FANGS },
  { "zul'jan", ALTAR_FANGS },
  -- The Voidspire (S1 raid)
  { "lightblinded vanguard", VOIDSPIRE },
  { "fallen-king salhadaar", VOIDSPIRE },
  { "fallen king salhadaar", VOIDSPIRE },
  { "imperator averzian", VOIDSPIRE },
  { "vaelgor & ezzorak", VOIDSPIRE },
  { "vaelgor and ezzorak", VOIDSPIRE },
  { "crown of the cosmos", VOIDSPIRE },
  { "corewarden nysarra", VOIDSPIRE },
  { "lightwarden ruia", VOIDSPIRE },
  { "vaelgor", VOIDSPIRE },
  { "ezzorak", VOIDSPIRE },
  { "vorasius", VOIDSPIRE },
  { "belo'ren", VOIDSPIRE },
  { "lothraxion", VOIDSPIRE },
  -- The Dreamrift / Sporefall (S1)
  { "chimaerus", DREAMRIFT },
  { "rotmire", SPOREFALL },
  -- Murder Row
  { "xathuux the annihilator", MURDER_ROW },
  { "lithiel cinderfury", MURDER_ROW },
  { "zaen bladesorrow", MURDER_ROW },
  { "kystia manaheart", MURDER_ROW },
  { "xathuux", MURDER_ROW },
  -- Voidscar Arena
  { "charonus", VOIDSCAR },
  { "atroxus", VOIDSCAR },
  { "taz'rah", VOIDSCAR },
  -- Den of Nalorakk / Blinding Vale
  { "nalorakk", DEN_NALORAKK },
  { "ikuzz the light hunter", BLINDING },
  { "sentinel of winter", BLINDING },
  { "meittik", BLINDING },
  { "ziekket", BLINDING },
  { "emberdawn", BLINDING },
  -- Returning dungeons
  { "avatar of sethraliss", SETHRALISS },
  { "king dazar", KINGS_REST },
  { "mor'zahi", KINGS_REST },
}

-- Crafts / bare instance names: no extra parentheses (already the location).
local BARE_INSTANCES = {
  ["murder row"] = true,
  ["voidscar arena"] = true,
  ["altar of fangs"] = true,
  ["den of nalorakk"] = true,
  ["the blinding vale"] = true,
  ["blinding vale"] = true,
  ["temple of sethraliss"] = true,
  ["king's rest"] = true,
  ["kings' rest"] = true,
  ["ruby life pools"] = true,
  ["the venomous abyss"] = true,
  ["the voidspire"] = true,
  ["the dreamrift"] = true,
  ["sporefall"] = true,
  ["leatherworking"] = true,
  ["blacksmithing"] = true,
  ["tailoring"] = true,
  ["engineering"] = true,
  ["jewelcrafting"] = true,
  ["inscription"] = true,
  ["alchemy"] = true,
  ["crafting"] = true,
  ["crafting/misc"] = true,
  ["crafting/ misc"] = true,
  ["catalyst"] = true,
  ["tier set"] = true,
}

--- Append "(Raid/Dungeon)" after boss names when known (all ranks).
function BiSPulse.FormatDropSource(drop)
  if type(drop) ~= "string" or drop == "" then
    return drop
  end

  local cleaned = drop:gsub("%s*%([Rr]aid%)%s*$", ""):gsub("%s*%([Dd]ungeon%)%s*$", "")
  cleaned = cleaned:match("^%s*(.-)%s*$") or cleaned

  local key = cleaned:lower():gsub("%s+", " ")
  if BARE_INSTANCES[key] then
    return cleaned
  end
  if cleaned:find("%(", 1, true) then
    return cleaned
  end

  for _, row in ipairs(DROP_INSTANCE) do
    local boss, instance = row[1], row[2]
    if key == boss or key:find(boss, 1, true) then
      return cleaned .. " (" .. instance .. ")"
    end
  end
  return cleaned
end
