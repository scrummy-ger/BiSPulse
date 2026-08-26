#!/usr/bin/env node
/**
 * Arcane S2 GSE callout auras for ThisWeeksAuras.
 * Shows icons only when rotation says to act — with matching GSE modifier hints.
 *
 * Master_Arcanist-12.1: Shift=Barrage | Ctrl=Orb | Alt=Surge | no mod = macro loop
 * Method Spellslinger ST: Barrage @20 Salvo, Missiles if CC & <15 Salvo, Prismatic priority
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

const MACRO_KEY_OPTION = {
  type: "input",
  key: "macroKey",
  default: "1",
  name: "GSE-Makro Taste",
  useDesc: false,
  width: 1,
};

function aura2Trigger(spellId, { stacksMin = null } = {}) {
  const t = {
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
  };
  if (stacksMin != null) {
    t.useStacks = true;
    t.stacksOperator = ">=";
    t.stacks = String(stacksMin);
  }
  return t;
}

function subtext(text, anchor, opts = {}) {
  const {
    fontSize = 13,
    color = [1, 0.92, 0.45, 1],
    visible = true,
    yOffset = 0,
    xOffset = 0,
  } = opts;
  const [selfPoint, anchorPoint] = anchor.split("/");
  return {
    type: "subtext",
    text_text: text,
    text_visible: visible,
    text_fontSize: fontSize,
    text_color: color,
    text_font: "Friz Quadrata TT",
    text_justify: "CENTER",
    text_selfPoint: selfPoint,
    text_anchorPoint: anchorPoint,
    text_anchorXOffset: xOffset,
    text_anchorYOffset: yOffset,
    text_shadowColor: [0, 0, 0, 1],
    text_shadowXOffset: 1,
    text_shadowYOffset: -1,
    text_automaticWidth: "Auto",
    text_fixedWidth: 100,
    text_wordWrap: "WordWrap",
    text_fontType: "OUTLINE",
  };
}

function calloutAura({
  id,
  spellId,
  xOffset = 0,
  yOffset = -80,
  triggers,
  triggerCombination = "any",
  conditions = [],
  actionLabel,
  keyLine,
  showStacks = false,
  stacksMin = null,
}) {
  const triggerList = triggers || [{ trigger: aura2Trigger(spellId, { stacksMin }), untrigger: {} }];

  const subRegions = [];
  if (showStacks) {
    subRegions.push(
      subtext("%s", "CENTER/CENTER", { fontSize: 24, color: [1, 0.85, 0.2, 1] })
    );
  }
  subRegions.push(
    subtext(actionLabel, "TOP/BOTTOM", { fontSize: 13, yOffset: -4, color: [1, 0.92, 0.45, 1] })
  );
  subRegions.push(
    subtext(keyLine, "TOP/BOTTOM", {
      fontSize: 15,
      yOffset: -20,
      color: [0.75, 1, 0.85, 1],
    })
  );

  return {
    id,
    uid: uid(id.replace(/\W/g, "").slice(0, 6)),
    regionType: "icon",
    internalVersion: 89,
    tocversion: 120100,
    authorOptions: [MACRO_KEY_OPTION],
    config: {},
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
    cooldown: false,
    cooldownTextDisabled: true,
    cooldownSwipe: false,
    cooldownEdge: false,
    useCooldownModRate: true,
    inverse: false,
    alpha: 1,
    progressSource: [-1, ""],
    adjustedMax: "",
    adjustedMin: "",
    numTriggers: triggerList.length,
    triggerCombination,
    triggers: triggerList,
    subRegions,
  };
}

// Salvo: only @20 stacks → Shift+Barrage (Method #2, Polished Focus)
const salvo = calloutAura({
  id: "BPS Salvo",
  spellId: 1242974,
  xOffset: -90,
  stacksMin: 20,
  showStacks: true,
  actionLabel: "BARRAGE",
  keyLine: "SHIFT+%macroKey",
});

// Soul window → Shift+Barrage spam (Method / Icy: Barrage during Arcane Soul)
const soul = calloutAura({
  id: "BPS Arcane Soul",
  spellId: 451038,
  xOffset: 90,
  actionLabel: "BARRAGE",
  keyLine: "SHIFT+%macroKey",
});

// CC → macro only (GSE auto Missiles). If Salvo @20 also shows, SHIFT wins.
const cc = calloutAura({
  id: "BPS Clearcasting",
  spellId: 263725,
  xOffset: -30,
  actionLabel: "MISSILES",
  keyLine: "%macroKey",
});

// Prismatic proc → macro only (Method #1/#4 priority)
const prismatic = calloutAura({
  id: "BPS Prismatic",
  spellId: 1295942,
  xOffset: 30,
  actionLabel: "PRISMATIC",
  keyLine: "%macroKey",
});

const icons = [
  { file: "BiSPulse_Arcane_Salvo_WA.txt", data: salvo },
  { file: "BiSPulse_Arcane_Clearcasting_WA.txt", data: cc },
  { file: "BiSPulse_Arcane_Prismatic_WA.txt", data: prismatic },
  { file: "BiSPulse_Arcane_Soul_WA.txt", data: soul },
];

const outDir = __dirname;
const lengths = [];

for (const spec of icons) {
  const payload = { d: spec.data, v: 2000, s: "12.1.0", m: "d" };
  const encoded = encodeSync(payload);
  const back = decodeSync(encoded);
  if (!back.d || back.d.id !== spec.data.id) throw new Error("roundtrip failed: " + spec.data.id);
  fs.writeFileSync(path.join(outDir, spec.file), encoded + "\n");
  lengths.push({ file: spec.file, len: encoded.length, id: spec.data.id });
}

const allPath = path.join(outDir, "BiSPulse_Arcane_S2_Import_All.txt");
const lines = [
  "# BiSPulse Arcane S2 GSE Callouts — ThisWeeksAuras",
  "# Raw file → Notepad Ctrl+A → Import (one at a time)",
  "# In /twa → Aura wählen → GSE-Makro Taste eintragen (z.B. 1, F1, R)",
  "#",
  "# Logik (Method Spellslinger + Master_Arcanist-12.1):",
  "#   Salvo @20     → erscheint nur bei 20 Stacks → SHIFT + Makro = Barrage",
  "#   Arcane Soul   → SHIFT + Makro = Barrage spam",
  "#   Clearcasting  → Makro (Missiles auto) — ausgeblendet bei Salvo 20+",
  "#   Prismatic!    → Makro (sofort casten)",
  "",
  ...icons.map((spec) => {
    const encoded = fs.readFileSync(path.join(outDir, spec.file), "utf8").trim();
    return `## ${spec.data.id}\nIMPORT:\n${encoded}\n`;
  }),
];
fs.writeFileSync(allPath, lines.join("\n"));

console.log("Wrote Arcane GSE callout imports:");
for (const row of lengths) {
  console.log(`  ${row.file}: ${row.len} chars (${row.id})`);
}
