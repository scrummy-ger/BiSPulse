#!/usr/bin/env node
/**
 * Build BiSPulse Arcane Mage Season 2 rotation-callout WeakAura.
 * Requires: npm i node-weakauras-parser (checked from /tmp or local node_modules)
 */
const fs = require("fs");
const path = require("path");

function loadParser() {
  const candidates = [
    path.join(__dirname, "node_modules/node-weakauras-parser"),
    "/tmp/node_modules/node-weakauras-parser",
  ];
  for (const c of candidates) {
    try {
      return require(c);
    } catch (_) {}
  }
  throw new Error("Install node-weakauras-parser first");
}

const { encodeSync, decodeSync } = loadParser();

const CUSTOM = `
-- BiSPulse Arcane Mage S2 rotation callout
-- Spellslinger: Barrage at 20 Salvo | Sunfury: Missiles <12, Barrage at 12/25
function(allstates, event, ...)
  local SALVO = 1242974
  local CLEARCASTING = 263725
  local PRISMATIC = 1295942
  local ARCANE_SOUL = 451038
  local SURGE_BUFF = 365362
  local CUMULATIVE = 1296930
  local TOTM_DEBUFF = 210824
  local ORB = 153626
  local SURGE_SPELL = 365350
  local TOTM_SPELL = 321507

  local function auraStacks(spellId)
    local a = C_UnitAuras.GetPlayerAuraBySpellID(spellId)
    if not a then return 0 end
    return a.applications or 1
  end

  local function hasAura(spellId)
    return C_UnitAuras.GetPlayerAuraBySpellID(spellId) ~= nil
  end

  local function targetHasDebuff(spellId)
    if not UnitExists("target") then return false end
    local i = 1
    while true do
      local a = C_UnitAuras.GetAuraDataByIndex("target", i, "HARMFUL|PLAYER")
      if not a then break end
      if a.spellId == spellId then return true end
      i = i + 1
    end
    return false
  end

  local function spellReady(spellId)
    local cd = C_Spell.GetSpellCooldown(spellId)
    if not cd then return false end
    local rem = (cd.startTime or 0) + (cd.duration or 0) - GetTime()
    return rem <= 0 or (cd.duration or 0) <= 1.5
  end

  if UnitIsDeadOrGhost("player") then
    if allstates[""] and allstates[""].show then
      allstates[""].show = false
      allstates[""].changed = true
      return true
    end
    return false
  end

  local show =
    UnitAffectingCombat("player")
    or (UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target"))
  if not show then
    if allstates[""] and allstates[""].show then
      allstates[""].show = false
      allstates[""].changed = true
      return true
    end
    return false
  end

  local mode = (aura_env.config and aura_env.config.hero) or 1
  local isSunfury = mode == 2
  local barrageAt = isSunfury and 25 or 20
  local missilesBelow = isSunfury and 12 or 15

  local salvo = auraStacks(SALVO)
  local powerType = (Enum and Enum.PowerType and Enum.PowerType.ArcaneCharges) or 16
  local charges = UnitPower("player", powerType) or 0
  local cc = hasAura(CLEARCASTING)
  local prismatic = hasAura(PRISMATIC)
  local soul = hasAura(ARCANE_SOUL)
  local surgeUp = hasAura(SURGE_BUFF)
  local cumulative = auraStacks(CUMULATIVE)
  local totm = targetHasDebuff(TOTM_DEBUFF)
  local orbReady = spellReady(ORB)
  local surgeReady = spellReady(SURGE_SPELL)
  local totmReady = spellReady(TOTM_SPELL)

  local rec, icon

  if surgeReady and not surgeUp then
    rec, icon = "SURGE", 365350
  elseif totmReady and not totm then
    rec, icon = "TOUCH", 321507
  elseif soul then
    rec, icon = "BARRAGE", 44425
  elseif prismatic and ((not cc) or cumulative >= 6) then
    rec, icon = "PRISMATIC", 1295942
  elseif cc and salvo < missilesBelow then
    rec, icon = "MISSILES", 5143
  elseif prismatic then
    rec, icon = "PRISMATIC", 1295942
  elseif (not isSunfury and salvo >= 20)
      or (isSunfury and (salvo >= 25 or (cc and salvo >= 12))) then
    rec, icon = "BARRAGE", 44425
  elseif charges <= 0 and orbReady then
    rec, icon = "ORB", 153626
  elseif charges < 3 and orbReady then
    rec, icon = "ORB", 153626
  else
    rec, icon = "BLAST", 30451
  end

  local ccTag = cc and " CC" or ""
  local name = string.format("%s | S%d/%d C%d%s", rec, salvo, barrageAt, charges, ccTag)
  local tex = (C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(icon)) or GetSpellTexture(icon) or icon

  local prev = allstates[""]
  local changed = (not prev) or prev.name ~= name or prev.icon ~= tex or not prev.show
  allstates[""] = {
    show = true,
    changed = changed,
    progressType = "static",
    autoHide = false,
    name = name,
    icon = tex,
    spellId = icon,
    stacks = salvo,
    index = 1,
  }
  return true
end
`.trim();

const wa = {
  d: {
    id: "BiSPulse Arcane S2 Callout",
    uid: "bpsArcS2Call01",
    regionType: "icon",
    anchorPoint: "CENTER",
    selfPoint: "CENTER",
    xOffset: 0,
    yOffset: -80,
    frameStrata: 1,
    frameStrataForGroup: 1,
    width: 72,
    height: 72,
    zoom: 0,
    icon: true,
    cooldown: false,
    cooldownTextDisabled: true,
    keepAspectRatio: true,
    color: [1, 1, 1, 1],
    desaturate: false,
    alpha: 1,
    tocversion: 120100,
    internalVersion: 87,
    version: 1,
    authorOptions: [
      {
        type: "select",
        name: "hero",
        display: "Hero Talent Priority",
        values: {
          1: "Spellslinger (Barrage @ 20 Salvo)",
          2: "Sunfury (Barrage @ 12/25)",
        },
        default: 1,
        width: 1.5,
      },
    ],
    information: { forceEvents: false },
    config: { hero: 1 },
    authorMode: false,
    customText: "",
    load: {
      use_class: true,
      class: { single: "MAGE" },
      use_spec: true,
      spec: { single: 1 },
      use_never: false,
      size: { multi: [] },
    },
    triggers: {
      1: {
        trigger: {
          type: "custom",
          custom_type: "stateupdate",
          check: "event",
          events:
            "UNIT_AURA:player UNIT_AURA:target PLAYER_TARGET_CHANGED UNIT_POWER_UPDATE:player SPELL_UPDATE_COOLDOWN_START SPELL_UPDATE_COOLDOWN_END PLAYER_REGEN_DISABLED PLAYER_REGEN_ENABLED UNIT_SPELLCAST_SUCCEEDED:player",
          custom: CUSTOM,
          custom_hide: "custom",
          customVariables: "",
        },
        untrigger: {},
      },
      activeTriggerMode: -10,
      customTriggerLogic: "",
      disjunctive: "all",
    },
    conditions: [],
    actions: {
      init: [],
      start: {
        do_sound: false,
        sound: "Interface\\\\AddOns\\\\WeakAuras\\\\Media\\\\Sounds\\\\AirHorn.ogg",
        sound_channel: "Master",
      },
      finish: [],
    },
    animation: {
      start: {
        type: "none",
        easeType: "none",
        duration_type: "timed",
        duration: 0,
        easeStrength: 3,
      },
      main: {
        type: "none",
        easeType: "none",
        duration_type: "timed",
        duration: 0,
        easeStrength: 3,
      },
      finish: {
        type: "none",
        easeType: "none",
        duration_type: "timed",
        duration: 0,
        easeStrength: 3,
      },
    },
    subRegions: [
      {
        type: "subtext",
        text_text: "%n",
        text_visible: true,
        text_fontSize: 18,
        text_color: [1, 0.92, 0.4, 1],
        text_font: "Friz Quadrata TT",
        text_justify: "CENTER",
        text_selfPoint: "TOP",
        text_anchorPoint: "BOTTOM",
        text_anchorXOffset: 0,
        text_anchorYOffset: -4,
        text_shadowColor: [0, 0, 0, 1],
        text_shadowXOffset: 1,
        text_shadowYOffset: -1,
        text_automaticWidth: "Auto",
        text_fixedWidth: 220,
        text_wordWrap: "WordWrap",
        text_fontType: "OUTLINE",
      },
      {
        type: "subtext",
        text_text: "%s",
        text_visible: true,
        text_fontSize: 22,
        text_color: [0.6, 0.85, 1, 1],
        text_font: "Friz Quadrata TT",
        text_justify: "CENTER",
        text_selfPoint: "CENTER",
        text_anchorPoint: "CENTER",
        text_anchorXOffset: 0,
        text_anchorYOffset: 0,
        text_shadowColor: [0, 0, 0, 1],
        text_shadowXOffset: 1,
        text_shadowYOffset: -1,
        text_automaticWidth: "Auto",
        text_fixedWidth: 64,
        text_wordWrap: "WordWrap",
        text_fontType: "OUTLINE",
      },
      {
        type: "subborder",
        border_visible: true,
        border_color: [0.5, 0.2, 0.9, 1],
        border_edge: "Square Full White",
        border_offset: 0,
        border_size: 2,
      },
    ],
  },
  wagoID: null,
  v: 2000,
  s: "12.1.0",
};

const encoded = encodeSync(wa);
const back = decodeSync(encoded);
if (!back.d || back.d.id !== wa.d.id) throw new Error("roundtrip failed");
if (!String(back.d.triggers[1].trigger.custom).includes("1242974")) {
  throw new Error("custom trigger missing Salvo id");
}

const out = path.join(__dirname, "BiSPulse_Arcane_S2_Callout_WA.txt");
fs.writeFileSync(out, encoded + "\n");
console.log("Wrote", out, "len", encoded.length);
console.log(encoded);
