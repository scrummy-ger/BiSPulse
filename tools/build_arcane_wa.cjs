#!/usr/bin/env node
/**
 * BiSPulse Arcane S2 tracker for ThisWeeksAuras / M33kAuras.
 * No custom Lua — only aura2 buff triggers (Midnight-safe).
 */
const fs = require("fs");
const path = require("path");

function loadParser() {
  for (const c of [
    path.join(__dirname, "node_modules/node-weakauras-parser"),
    "/tmp/node_modules/node-weakauras-parser",
  ]) {
    try {
      return require(c);
    } catch (_) {}
  }
  throw new Error("Install node-weakauras-parser first");
}

const { encodeSync, decodeSync } = loadParser();

function uid(seed) {
  return ("bps" + seed + "xxxxxxxx").slice(0, 11);
}

function baseStub(id, regionType) {
  return {
    id,
    uid: uid(id.replace(/\W/g, "").slice(0, 6)),
    regionType,
    internalVersion: 89,
    tocversion: 120100,
    authorOptions: [],
    config: {},
    information: {},
    conditions: [],
    actions: { init: {}, start: {}, finish: {} },
    animation: {
      start: { type: "none", duration_type: "seconds", easeType: "none", easeStrength: 3 },
      main: { type: "none", duration_type: "seconds", easeType: "none", easeStrength: 3 },
      finish: { type: "none", duration_type: "seconds", easeType: "none", easeStrength: 3 },
    },
    load: {
      size: { multi: {} },
      spec: { multi: {}, single: 1 },
      class: { multi: {}, single: "MAGE" },
      talent: { multi: {} },
      use_class: true,
      use_spec: true,
    },
  };
}

function iconAura({ id, spellId, label, xOffset, yOffset, stacksHint }) {
  const data = baseStub(id, "icon");
  Object.assign(data, {
    width: 56,
    height: 56,
    xOffset,
    yOffset,
    selfPoint: "CENTER",
    anchorPoint: "CENTER",
    anchorFrameType: "SCREEN",
    frameStrata: 1,
    icon: true,
    desaturate: false,
    iconSource: -1,
    color: [1, 1, 1, 1],
    zoom: 0,
    keepAspectRatio: false,
    cooldown: true,
    cooldownTextDisabled: false,
    cooldownSwipe: true,
    cooldownEdge: false,
    useCooldownModRate: true,
    inverse: false,
    alpha: 1,
    progressSource: [-1, ""],
    adjustedMax: "",
    adjustedMin: "",
    triggers: [
      {
        trigger: {
          type: "aura2",
          event: "Health",
          subeventPrefix: "SPELL",
          subeventSuffix: "_CAST_START",
          names: [],
          spellIds: [],
          unit: "player",
          debuffType: "HELPFUL",
          ownOnly: true,
          useName: false,
          useExactSpellId: true,
          auraspellids: [String(spellId)],
          matchesShowOn: "showOnActive",
          unitExists: false,
        },
        untrigger: {},
      },
    ],
    subRegions: [
      {
        type: "subtext",
        text_text: stacksHint ? `%s\n${label}` : label,
        text_visible: true,
        text_fontSize: 14,
        text_color: [1, 0.92, 0.45, 1],
        text_font: "Friz Quadrata TT",
        text_justify: "CENTER",
        text_selfPoint: "TOP",
        text_anchorPoint: "BOTTOM",
        text_anchorXOffset: 0,
        text_anchorYOffset: -2,
        text_shadowColor: [0, 0, 0, 1],
        text_shadowXOffset: 1,
        text_shadowYOffset: -1,
        text_automaticWidth: "Auto",
        text_fixedWidth: 100,
        text_wordWrap: "WordWrap",
        text_fontType: "OUTLINE",
      },
      {
        type: "subtext",
        text_text: "%s",
        text_visible: !!stacksHint,
        text_fontSize: 22,
        text_color: [0.55, 0.85, 1, 1],
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
        text_fixedWidth: 56,
        text_wordWrap: "WordWrap",
        text_fontType: "OUTLINE",
      },
      {
        type: "subborder",
        border_visible: true,
        border_color: [0.45, 0.2, 0.85, 1],
        border_edge: "Square Full White",
        border_offset: 0,
        border_size: 2,
      },
    ],
  });
  // parent set later
  return data;
}

const children = [
  iconAura({
    id: "BPS Arcane Salvo",
    spellId: 1242974,
    label: "SALVO",
    xOffset: -120,
    yOffset: -60,
    stacksHint: true,
  }),
  iconAura({
    id: "BPS Clearcasting",
    spellId: 263725,
    label: "CC → MISSILES",
    xOffset: -40,
    yOffset: -60,
    stacksHint: false,
  }),
  iconAura({
    id: "BPS Prismatic Bolt",
    spellId: 1295942,
    label: "PRISMATIC!",
    xOffset: 40,
    yOffset: -60,
    stacksHint: false,
  }),
  iconAura({
    id: "BPS Arcane Soul",
    spellId: 451038,
    label: "SOUL → BARRAGE",
    xOffset: 120,
    yOffset: -60,
    stacksHint: false,
  }),
  iconAura({
    id: "BPS Arcane Surge Buff",
    spellId: 365362,
    label: "SURGE",
    xOffset: -80,
    yOffset: -130,
    stacksHint: false,
  }),
  iconAura({
    id: "BPS Cumulative Power",
    spellId: 1296930,
    label: "4pc POWER",
    xOffset: 80,
    yOffset: -130,
    stacksHint: true,
  }),
];

const groupId = "BiSPulse Arcane S2 Trackers";
const group = baseStub(groupId, "group");
Object.assign(group, {
  controlledChildren: children.map((c) => c.id),
  xOffset: 0,
  yOffset: 0,
  selfPoint: "CENTER",
  anchorPoint: "CENTER",
  anchorFrameType: "SCREEN",
  frameStrata: 1,
  scale: 1,
  border: false,
  borderEdge: "Square Full White",
  borderOffset: 0,
  borderInset: 16,
  borderSize: 2,
  borderColor: [1, 1, 1, 0.5],
  backdropColor: [1, 1, 1, 0.5],
  groupIcon: "Interface\\Icons\\Spell_Arcane_ArcaneTorrent",
  desc:
    "Midnight S2 Arcane trackers (ThisWeeksAuras).\n" +
    "Spellslinger: Barrage at 20 Salvo | Sunfury: Missiles <12, Barrage at 12/25.\n" +
    "With GSE Semi: when SALVO hits threshold, hold Shift for Barrage.",
  triggers: [
    {
      trigger: {
        type: "aura2",
        names: [],
        spellIds: [],
        event: "Health",
        subeventPrefix: "SPELL",
        subeventSuffix: "_CAST_START",
        unit: "player",
        debuffType: "HELPFUL",
      },
      untrigger: {},
    },
  ],
});

for (const child of children) {
  child.parent = groupId;
}

const payload = {
  d: group,
  c: children,
  v: 2000,
  s: "12.1.0",
};

const encoded = encodeSync(payload);
const back = decodeSync(encoded);
if (!back.d || back.d.id !== groupId) throw new Error("group roundtrip failed");
if (!Array.isArray(back.c) || back.c.length !== children.length) {
  throw new Error("children roundtrip failed: " + typeof back.c);
}
for (const child of back.c) {
  const t = child.triggers[0] || child.triggers["1"];
  if (!t || t.trigger.type !== "aura2") throw new Error("child not aura2: " + child.id);
  if (!t.trigger.useExactSpellId) throw new Error("missing exact spell id: " + child.id);
}

const out = path.join(__dirname, "BiSPulse_Arcane_S2_Callout_WA.txt");
fs.writeFileSync(out, encoded + "\n");
console.log("Wrote", out, "len", encoded.length);
console.log("children", back.c.map((c) => c.id).join(" | "));
console.log(encoded);
