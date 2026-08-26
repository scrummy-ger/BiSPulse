#!/usr/bin/env node
/**
 * Minimal single-icon Arcane S2 trackers for ThisWeeksAuras.
 * Shorter import strings = less truncation when copying from chat/PR.
 */
const fs = require("fs");
const path = require("path");
const { encodeSync, decodeSync } = loadParser();

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

function uid(seed) {
  return ("bps" + seed + "xxxxxxxx").slice(0, 11);
}

function minimalIcon({ id, spellId, label, xOffset = 0, yOffset = -80, stacks = false }) {
  return {
    id,
    uid: uid(id.replace(/\W/g, "").slice(0, 6)),
    regionType: "icon",
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
    subRegions: stacks
      ? [
          {
            type: "subtext",
            text_text: `%s\n${label}`,
            text_visible: true,
            text_fontSize: 18,
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
            text_fixedWidth: 80,
            text_wordWrap: "WordWrap",
            text_fontType: "OUTLINE",
          },
        ]
      : [
          {
            type: "subtext",
            text_text: label,
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
            text_fixedWidth: 80,
            text_wordWrap: "WordWrap",
            text_fontType: "OUTLINE",
          },
        ],
  };
}

const icons = [
  { file: "BiSPulse_Arcane_Salvo_WA.txt", id: "BPS Salvo", spellId: 1242974, label: "SALVO", stacks: true },
  { file: "BiSPulse_Arcane_Clearcasting_WA.txt", id: "BPS Clearcasting", spellId: 263725, label: "CC", stacks: false },
  { file: "BiSPulse_Arcane_Prismatic_WA.txt", id: "BPS Prismatic", spellId: 1295942, label: "PRISMATIC", stacks: false },
  { file: "BiSPulse_Arcane_Soul_WA.txt", id: "BPS Arcane Soul", spellId: 451038, label: "SOUL", stacks: false },
];

const outDir = __dirname;
const lengths = [];

for (const spec of icons) {
  const data = minimalIcon(spec);
  const payload = { d: data, v: 2000, s: "12.1.0", m: "d" };
  const encoded = encodeSync(payload);
  const back = decodeSync(encoded);
  if (!back.d || back.d.id !== spec.id) throw new Error("roundtrip failed: " + spec.id);
  const out = path.join(outDir, spec.file);
  fs.writeFileSync(out, encoded + "\n");
  lengths.push({ file: spec.file, len: encoded.length, id: spec.id });
}

const allPath = path.join(outDir, "BiSPulse_Arcane_S2_Import_All.txt");
const lines = [
  "# BiSPulse Arcane S2 — import ONE string at a time into ThisWeeksAuras",
  "# Copy the entire line after IMPORT: (no spaces, no line breaks)",
  "# Best: open the .txt file from GitHub raw link in Notepad, Ctrl+A, Ctrl+C",
  "",
  ...icons.map((spec) => {
    const encoded = fs.readFileSync(path.join(outDir, spec.file), "utf8").trim();
    return `## ${spec.id}\nIMPORT:\n${encoded}\n`;
  }),
];
fs.writeFileSync(allPath, lines.join("\n"));

console.log("Wrote minimal Arcane WA imports:");
for (const row of lengths) {
  console.log(`  ${row.file}: ${row.len} chars (${row.id})`);
}
console.log("Combined guide:", allPath);
