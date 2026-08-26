#!/usr/bin/env node
/**
 * Minimal single-icon Arcane S2 trackers for ThisWeeksAuras.
 * Includes subtle GSE modifier hints (Shift/Ctrl/Alt from Master_Arcanist-12.1).
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

const MACRO_KEY_AUTHOR_OPTION = {
  type: "string",
  key: "macroKey",
  name: "GSE-Makro-Taste",
  desc: "Taste deines Master_Arcanist-12.1 Makros (z.B. F1). Leer = MAKRO.",
  default: "",
  useDesc: true,
  width: 1,
};

const MACRO_KEY_CUSTOM_TEXT = `function()
  local key = aura_env.config and aura_env.config.macroKey
  if key and key ~= "" then return key end
  return "MAKRO"
end`;

function stacksSubRegion() {
  return {
    type: "subtext",
    text_text: "%s",
    text_visible: true,
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
  };
}

function labelSubRegion({ text, fontSize = 13, yOffset = -6 }) {
  return {
    type: "subtext",
    text_text: text,
    text_visible: true,
    text_fontSize: fontSize,
    text_color: [1, 0.92, 0.45, 1],
    text_font: "Friz Quadrata TT",
    text_justify: "CENTER",
    text_selfPoint: "TOP",
    text_anchorPoint: "BOTTOM",
    text_anchorXOffset: 0,
    text_anchorYOffset: yOffset,
    text_shadowColor: [0, 0, 0, 1],
    text_shadowXOffset: 1,
    text_shadowYOffset: -1,
    text_automaticWidth: "Auto",
    text_fixedWidth: 80,
    text_wordWrap: "WordWrap",
    text_fontType: "OUTLINE",
  };
}

function keySubRegion(text, { alpha = 0.55, fontSize = 10, yOffset = 3 } = {}) {
  return {
    type: "subtext",
    text_text: text,
    text_visible: true,
    text_fontSize: fontSize,
    text_color: [1, 1, 1, alpha],
    text_font: "Friz Quadrata TT",
    text_justify: "CENTER",
    text_selfPoint: "BOTTOM",
    text_anchorPoint: "BOTTOM",
    text_anchorXOffset: 0,
    text_anchorYOffset: yOffset,
    text_shadowColor: [0, 0, 0, 0.85],
    text_shadowXOffset: 1,
    text_shadowYOffset: -1,
    text_automaticWidth: "Auto",
    text_fixedWidth: 48,
    text_wordWrap: "WordWrap",
    text_fontType: "OUTLINE",
  };
}

/**
 * GSE Master_Arcanist-12.1 modifiers:
 *   Shift = Arcane Barrage (Salvo 20+ / Arcane Soul)
 *   Ctrl  = Arcane Orb
 *   Alt   = Arcane Surge
 * CC + Prismatic fire automatically in the macro loop (no modifier).
 */
function minimalIcon({
  id,
  spellId,
  label,
  xOffset = 0,
  yOffset = -80,
  stacks = false,
  keyHint = null,
  keyWhen = "always",
  keyAlpha = 0.55,
  macroKeyOption = false,
}) {
  const subRegions = [];
  const conditions = [];

  if (stacks) {
    subRegions.push(stacksSubRegion());
  }
  subRegions.push(labelSubRegion({ text: label, fontSize: stacks ? 12 : 13 }));

  let keySubIndex = null;
  if (keyHint) {
    keySubIndex = subRegions.length + 1;
    subRegions.push(keySubRegion(keyHint, { alpha: keyAlpha }));

    if (keyWhen === "stacks20") {
      conditions.push({
        check: { trigger: 1, variable: "stacks", op: ">=", value: "20" },
        changes: [
          { property: `sub.${keySubIndex}.text_visible`, value: true },
          { property: `sub.${keySubIndex}.text_color`, value: [1, 0.95, 0.55, 0.92] },
        ],
      });
      conditions.push({
        check: { trigger: 1, variable: "stacks", op: "<", value: "20" },
        changes: [
          { property: `sub.${keySubIndex}.text_visible`, value: true },
          { property: `sub.${keySubIndex}.text_color`, value: [1, 1, 1, 0.32] },
        ],
      });
    }
  }

  const authorOptions = macroKeyOption ? [MACRO_KEY_AUTHOR_OPTION] : [];
  const config = macroKeyOption ? { macroKey: "" } : {};

  return {
    id,
    uid: uid(id.replace(/\W/g, "").slice(0, 6)),
    regionType: "icon",
    internalVersion: 89,
    tocversion: 120100,
    authorOptions,
    config,
    customText: macroKeyOption ? MACRO_KEY_CUSTOM_TEXT : undefined,
    customTextUpdate: macroKeyOption ? "update" : undefined,
    information: {},
    conditions,
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
    cooldownTextDisabled: true,
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
    subRegions,
  };
}

const icons = [
  {
    file: "BiSPulse_Arcane_Salvo_WA.txt",
    id: "BPS Salvo",
    spellId: 1242974,
    label: "SALVO",
    stacks: true,
    keyHint: "SHIFT",
    keyWhen: "stacks20",
    keyAlpha: 0.32,
  },
  {
    file: "BiSPulse_Arcane_Clearcasting_WA.txt",
    id: "BPS Clearcasting",
    spellId: 263725,
    label: "CC",
    stacks: false,
    keyHint: "%c",
    keyAlpha: 0.7,
    macroKeyOption: true,
  },
  {
    file: "BiSPulse_Arcane_Prismatic_WA.txt",
    id: "BPS Prismatic",
    spellId: 1295942,
    label: "PRISMATIC",
    stacks: false,
    keyHint: "%c",
    keyAlpha: 0.7,
    macroKeyOption: true,
  },
  {
    file: "BiSPulse_Arcane_Soul_WA.txt",
    id: "BPS Arcane Soul",
    spellId: 451038,
    label: "SOUL",
    stacks: false,
    keyHint: "SHIFT",
    keyWhen: "always",
    keyAlpha: 0.75,
  },
];

const outDir = __dirname;
const lengths = [];

for (const spec of icons) {
  const data = minimalIcon(spec);
  const payload = { d: data, v: 2000, s: "12.1.0", m: "d" };
  const encoded = encodeSync(payload);
  const back = decodeSync(encoded);
  if (!back.d || back.d.id !== spec.id) throw new Error("roundtrip failed: " + spec.id);
  if (back.d.cooldownTextDisabled !== true) {
    throw new Error("cooldown text not disabled: " + spec.id);
  }
  const out = path.join(outDir, spec.file);
  fs.writeFileSync(out, encoded + "\n");
  lengths.push({ file: spec.file, len: encoded.length, id: spec.id });
}

const allPath = path.join(outDir, "BiSPulse_Arcane_S2_Import_All.txt");
const lines = [
  "# BiSPulse Arcane S2 — import ONE string at a time into ThisWeeksAuras",
  "# Copy the entire line after IMPORT: (no spaces, no line breaks)",
  "# Best: open the .txt file from GitHub raw link in Notepad, Ctrl+A, Ctrl+C",
  "#",
  "# Layout: stacks (center) | label (below icon) | key hint (icon bottom)",
  "# Cooldown numbers on the icon are disabled to avoid overlap.",
  "#",
  "# GSE key hints (Master_Arcanist-12.1):",
  "#   Salvo → SHIFT (dim below 20 stacks, bright at 20+) = Arcane Barrage",
  "#   Arcane Soul → SHIFT = Arcane Barrage",
  "#   Clearcasting + Prismatic → macro key (Custom Options: GSE-Makro-Taste, fallback MAKRO)",
  "#   Ctrl = Orb, Alt = Surge (not shown on these 4 icons)",
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
