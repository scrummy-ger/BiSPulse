/**
 * Headless Wowhead Overall-BiS scrape (Playwright).
 * Writes tools/wowhead_browser_data.json for scrape_method_bis.py.
 *
 *   cd tools
 *   npm install
 *   npx playwright install chromium
 *   node scrape_wowhead.mjs
 */
import { chromium } from "playwright";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(__dirname, "wowhead_browser_data.json");

const SPECS = [
  ["BloodDeathKnight", "death-knight", "blood"],
  ["FrostDeathKnight", "death-knight", "frost"],
  ["UnholyDeathKnight", "death-knight", "unholy"],
  ["HavocDemonHunter", "demon-hunter", "havoc"],
  ["VengeanceDemonHunter", "demon-hunter", "vengeance"],
  ["DevourerDemonHunter", "demon-hunter", "devourer"],
  ["BalanceDruid", "druid", "balance"],
  ["FeralDruid", "druid", "feral"],
  ["GuardianDruid", "druid", "guardian"],
  ["RestorationDruid", "druid", "restoration"],
  ["DevastationEvoker", "evoker", "devastation"],
  ["PreservationEvoker", "evoker", "preservation"],
  ["AugmentationEvoker", "evoker", "augmentation"],
  ["BeastMasteryHunter", "hunter", "beast-mastery"],
  ["MarksmanshipHunter", "hunter", "marksmanship"],
  ["SurvivalHunter", "hunter", "survival"],
  ["ArcaneMage", "mage", "arcane"],
  ["FireMage", "mage", "fire"],
  ["FrostMage", "mage", "frost"],
  ["BrewmasterMonk", "monk", "brewmaster"],
  ["MistweaverMonk", "monk", "mistweaver"],
  ["WindwalkerMonk", "monk", "windwalker"],
  ["HolyPaladin", "paladin", "holy"],
  ["ProtectionPaladin", "paladin", "protection"],
  ["RetributionPaladin", "paladin", "retribution"],
  ["DisciplinePriest", "priest", "discipline"],
  ["HolyPriest", "priest", "holy"],
  ["ShadowPriest", "priest", "shadow"],
  ["AssassinationRogue", "rogue", "assassination"],
  ["OutlawRogue", "rogue", "outlaw"],
  ["SubtletyRogue", "rogue", "subtlety"],
  ["ElementalShaman", "shaman", "elemental"],
  ["EnhancementShaman", "shaman", "enhancement"],
  ["RestorationShaman", "shaman", "restoration"],
  ["AfflictionWarlock", "warlock", "affliction"],
  ["DemonologyWarlock", "warlock", "demonology"],
  ["DestructionWarlock", "warlock", "destruction"],
  ["ArmsWarrior", "warrior", "arms"],
  ["FuryWarrior", "warrior", "fury"],
  ["ProtectionWarrior", "warrior", "protection"],
];

const EMBELLISHMENTS = new Set([240167, 273060, 245790]);

const SLOT_RE =
  /^(Weapon|Weapons|Offhand|Off[- ]?Hand|Main[- ]?Hand|One[- ]?Hand|Two[- ]?Hand|[12]H(?:\s*Weapon)?|MH|OH|Head|Helm|Neck|Shoulders?|Back|Cloak|Chest|Wrist|Wrists|Hands|Gloves|Waist|Belt|Legs|Feet|Boots|Finger|Ring|Trinkets?)$/i;

/** Relative or absolute Wowhead item href (source only — clone per use). */
const ITEM_HREF_SRC =
  'href="(?:https?:\\/\\/(?:www|de|fr|es|pt|ru|ko|cn)\\.wowhead\\.com)?\\/item=(\\d+)\\/([^"#?]+)"';

function itemHrefMatches(html) {
  return html.matchAll(new RegExp(ITEM_HREF_SRC, "gi"));
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function normalizeSlot(raw) {
  const s = String(raw || "")
    .replace(/\[\/?b\]/gi, "")
    .replace(/<[^>]+>/g, "")
    .trim()
    .toLowerCase();
  if (/weapon|main.?hand|one.?hand|two.?hand/.test(s)) return "Weapon";
  if (/off.?hand/.test(s)) return "Offhand";
  if (/head|helm/.test(s)) return "Head";
  if (/neck/.test(s)) return "Neck";
  if (/shoulder/.test(s)) return "Shoulders";
  if (/cloak|back/.test(s)) return "Cloak";
  if (/chest/.test(s)) return "Chest";
  if (/wrist/.test(s)) return "Wrist";
  if (/glove|hands/.test(s)) return "Gloves";
  if (/belt|waist/.test(s)) return "Belt";
  if (/legs/.test(s)) return "Legs";
  if (/boot|feet/.test(s)) return "Boots";
  if (/ring|finger/.test(s)) return "Ring";
  if (/trinket/.test(s)) return "Trinket";
  return String(raw || "").replace(/<[^>]+>/g, "").trim();
}

function stripMarkup(s) {
  return String(s || "")
    .replace(/\[url=[^\]]+\]([\s\S]*?)\[\/url\]/gi, "$1")
    .replace(/\[\/?\w+[^\]]*\]/g, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&larr;|&rarr;|←|→/g, "<-")
    .replace(/\s+/g, " ")
    .trim();
}

function slugToName(slug) {
  if (!slug) return "";
  let name = String(slug)
    .replace(/_/g, "-")
    .split("-")
    .filter(Boolean)
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join(" ");
  const reps = [
    [" Ulatek", " Ula'tek"],
    ["Ulatek", "Ula'tek"],
    [" Zuljins ", " Zul'jin's "],
    ["Zuljins ", "Zul'jin's "],
    [" Amanmuso", " Aman'muso"],
    ["Amanmuso", "Aman'muso"],
    [" Spellbreakers ", " Spellbreaker's "],
    ["Spellbreakers ", "Spellbreaker's "],
    [" Warlords ", " Warlord's "],
    [" Doomhounds ", " Doomhound's "],
  ];
  for (const [a, b] of reps) name = name.replace(a, b);
  return name;
}

function isPlaceholderName(name) {
  return !name || /^Item \d+$/i.test(String(name).trim());
}

function buildNameIndex(html) {
  const names = {};
  // Rendered item links (relative or absolute)
  for (const m of html.matchAll(
    /href="(?:https?:\/\/(?:www|de|fr|es|pt|ru|ko|cn)\.wowhead\.com)?\/item=(\d+)\/([^"#?]+)"[^>]*>([\s\S]*?)<\/a>/gi
  )) {
    const id = Number(m[1]);
    const inner = m[3] || "";
    const text =
      (inner.match(/class="tinyicontxt"[^>]*>([^<]+)/i) || [])[1] ||
      (inner.match(/alt="([^"]+)"/i) || [])[1] ||
      stripMarkup(inner);
    if (text && !isPlaceholderName(text)) names[id] = text.trim();
    else if (!names[id]) names[id] = slugToName(m[2]);
  }
  // WH.Gatherer blobs (name_enus)
  for (const m of html.matchAll(
    /"(\d{5,7})"\s*:\s*\{[^{}]{0,500}?name_enus"\s*:\s*"((?:\\.|[^"\\])*)"/gi
  )) {
    const id = Number(m[1]);
    try {
      const text = JSON.parse(`"${m[2]}"`);
      if (text && !isPlaceholderName(text)) names[id] = text;
    } catch {
      /* ignore */
    }
  }
  return names;
}

function bisChunk(html) {
  const startPats = [
    /Overall BiS/i,
    /Best-in-Slot Gear for/i,
    /Best in Slot Gear for/i,
    /Best[- ]in[- ]Slot/i,
    /toc=\\"BiS Gear\\"/i,
    /toc="BiS Gear"/i,
  ];
  let start = -1;
  for (const p of startPats) {
    let from = 0;
    while (from < html.length) {
      const slice = html.slice(from);
      const i = slice.search(p);
      if (i < 0) break;
      const abs = from + i;
      // Prefer body content (skip early nav/chrome), but accept earlier for short pages
      if (abs >= 15000 || from > 0) {
        start = abs;
        break;
      }
      from = abs + 1;
    }
    if (start >= 0) break;
  }
  if (start < 0) {
    const slice = html.slice(20000);
    let i = slice.search(/\[item=\d+/i);
    if (i < 0) {
      i = slice.search(/\/item=\d+\//i);
    }
    start = i >= 0 ? 20000 + i - 200 : 20000;
  }

  const endPats = [
    /toc=\\"Raid Drops\\"/i,
    /toc="Raid Drops"/i,
    /Best Gear from Raids/i,
    /Best Raid Items/i,
    /Best Gear to Catalyze/i,
    /Crafted Gear/i,
    /Trinket Tier List/i,
  ];
  let end = -1;
  const rest = html.slice(start + 20);
  for (const p of endPats) {
    const i = rest.search(p);
    if (i >= 0 && (end < 0 || i < end)) end = i;
  }
  const hardCap = 50000;
  if (end < 0 || end > hardCap) end = hardCap;
  return html.slice(start, start + 20 + end);
}

function cleanDrop(raw) {
  let drop = stripMarkup(raw);
  if (!drop) return "";
  // Common Wowhead junk in source cells
  drop = drop
    .replace(/\s*[|·•]\s*/g, " / ")
    .replace(/\s+/g, " ")
    .trim();
  if (!drop || drop.length > 80) return "";
  if (SLOT_RE.test(drop)) return "";
  if (/^[\d.%\s/+-]+$/.test(drop)) return "";
  if (/^(source|drop|location|where|item|name|slot|tier)$/i.test(drop)) return "";
  // Normalize crafting labels
  if (/blacksmithing/i.test(drop) && /craft/i.test(drop)) return "Blacksmithing";
  if (/leatherworking/i.test(drop) && /craft/i.test(drop)) return "Leatherworking";
  if (/tailoring/i.test(drop) && /craft/i.test(drop)) return "Tailoring";
  if (/jewelcrafting|inscription|engineering|alchemy/i.test(drop) && /craft/i.test(drop)) {
    const prof = drop.match(
      /(Blacksmithing|Leatherworking|Tailoring|Jewelcrafting|Inscription|Engineering|Alchemy)/i
    );
    if (prof) return prof[1].replace(/^\w/, (c) => c.toUpperCase());
  }
  if (/^crafting(\/misc)?$/i.test(drop) || /^crafted$/i.test(drop)) return "Crafting";
  if (/^tier set$/i.test(drop)) return "Tier Set";
  return drop;
}

function rankScore(rank) {
  return { bis: 4, strong: 3, alt: 2, ok: 1 }[rank] || 0;
}

function tierLetterToRank(letter) {
  const t = String(letter || "")
    .trim()
    .toUpperCase();
  if (t === "S" || t === "S+" || t === "SS") return "bis";
  if (t === "A" || t === "A+" || t === "A-") return "strong";
  if (t === "B" || t === "B+" || t === "B-") return "alt";
  if (t === "C" || t === "C+" || t === "D" || t === "F") return "ok";
  return null;
}

const MIN_GUIDE_OFFSET = 80000;

function sectionChunk(html, startPats, endPats, hardCap = 35000) {
  let start = -1;
  // Prefer first matching pattern in priority order, but only in guide body (skip TOC/nav).
  for (const p of startPats) {
    const slice = html.slice(MIN_GUIDE_OFFSET);
    const i = slice.search(p);
    if (i >= 0) {
      start = MIN_GUIDE_OFFSET + i;
      break;
    }
  }
  if (start < 0) {
    // Fallback: last occurrence (TOC often appears before the real heading).
    for (const p of startPats) {
      let last = -1;
      let from = 0;
      while (from < html.length) {
        const slice = html.slice(from);
        const i = slice.search(p);
        if (i < 0) break;
        last = from + i;
        from = last + 1;
      }
      if (last >= MIN_GUIDE_OFFSET / 2) {
        start = last;
        break;
      }
    }
  }
  if (start < 0) return "";

  const rest = html.slice(start + 20);
  let end = -1;
  for (const p of endPats) {
    const i = rest.search(p);
    if (i >= 0 && (end < 0 || i < end)) end = i;
  }
  if (end < 0 || end > hardCap) end = hardCap;
  return html.slice(start, start + 20 + end);
}

/** Pull Slot | Item | Source rows from BBCode + HTML tables. */
function extractGearRows(html) {
  const rows = [];

  for (const tr of html.matchAll(/\[tr\]([\s\S]*?)\[\/tr\]/gi)) {
    const tds = [...tr[1].matchAll(/\[td\]([\s\S]*?)\[\/td\]/gi)].map((m) => m[1]);
    if (tds.length < 2) continue;
    const slotRaw = stripMarkup(tds[0]);
    if (!SLOT_RE.test(slotRaw)) continue;
    const itemM = tds[1].match(/\[item=(\d+)/i) || tr[1].match(/\[item=(\d+)/i);
    if (!itemM) continue;
    const nameFromCell =
      tds[1].match(/\[item=\d+[^\]]*\]([^\[]+)/i)?.[1] ||
      tds[1].match(/tinyicontxt"[^>]*>([^<]+)/i)?.[1] ||
      null;
    rows.push({
      id: Number(itemM[1]),
      name: nameFromCell,
      slot: slotRaw,
      drop: cleanDrop(tds[2] || ""),
    });
  }

  // HTML table rows — absolute or relative item URLs, name may be in nested span/img
  const htmlRow =
    /<(?:td|th)[^>]*>\s*(?:<[^>]+>\s*)*([^<]{2,40}?)\s*(?:<\/[^>]+>\s*)*<\/(?:td|th)>\s*<(?:td|th)[^>]*>[\s\S]{0,1200}?href="(?:https?:\/\/(?:www|de|fr|es|pt|ru|ko|cn)\.wowhead\.com)?\/item=(\d+)\/([^"#?]+)"[\s\S]{0,800}?<\/(?:td|th)>\s*<(?:td|th)[^>]*>([\s\S]*?)<\/(?:td|th)>/gi;
  for (const m of html.matchAll(htmlRow)) {
    const slotRaw = stripMarkup(m[1]);
    if (!SLOT_RE.test(slotRaw)) continue;
    const cell = m[0];
    const name =
      (cell.match(/tinyicontxt"[^>]*>([^<]+)/i) || [])[1] ||
      (cell.match(/alt="([^"]+)"/i) || [])[1] ||
      slugToName(m[3]);
    rows.push({
      id: Number(m[2]),
      name,
      slot: slotRaw,
      drop: cleanDrop(m[4]),
    });
  }

  // Item | Source only (no slot column)
  const itemSource =
    /href="(?:https?:\/\/(?:www|de|fr|es|pt|ru|ko|cn)\.wowhead\.com)?\/item=(\d+)\/([^"#?]+)"[\s\S]{0,400}?<(?:td|th)[^>]*>([\s\S]{2,160}?)<\/(?:td|th)>/gi;
  for (const m of html.matchAll(itemSource)) {
    const drop = cleanDrop(m[3]);
    if (!drop) continue;
    rows.push({
      id: Number(m[1]),
      name: slugToName(m[2]),
      slot: null,
      drop,
    });
  }

  return rows;
}

function extractItemIds(html) {
  const ids = [];
  const seen = new Set();
  for (const m of html.matchAll(/\[item=(\d+)/gi)) {
    const id = Number(m[1]);
    if (!id || seen.has(id) || EMBELLISHMENTS.has(id)) continue;
    seen.add(id);
    ids.push(id);
  }
  for (const m of itemHrefMatches(html)) {
    const id = Number(m[1]);
    if (!id || seen.has(id) || EMBELLISHMENTS.has(id)) continue;
    seen.add(id);
    ids.push(id);
  }
  return ids;
}

/** Trinket tier lists: S/A/B(/C) headings, tables, or Wowhead tier-list widget. */
function extractTrinketTierRows(html) {
  const chunk = sectionChunk(
    html,
    [
      /Trinket Tier List/i,
      /Best .* Trinkets in/i,
      /Best .* Trinkets/i,
      /Trinket Tier/i,
      /toc=\\"Trinkets\\"/i,
      /toc="Trinkets"/i,
    ],
    [
      /Embellish/i,
      /Crafted Gear/i,
      /Stat Priority/i,
      /Consumable/i,
      /Talent/i,
      /Rotation/i,
      /Set Bonuses/i,
      /toc=\\"Stat/i,
    ],
    45000
  );
  if (!chunk) return [];

  const rows = [];

  // New Wowhead widget: <div class="tier-list-tier"><div class="tier-label">S</div>…
  const tierBlocks = chunk.split(/<div class="tier-list-tier">/i).slice(1);
  for (const block of tierBlocks) {
    const labelM = block.match(/class="tier-label[^"]*"[^>]*>\s*([SABCD])\+?\s*<\/div>/i);
    if (!labelM) continue;
    const letter = labelM[1].toUpperCase();
    const rank = tierLetterToRank(letter);
    if (!rank) continue;
    const contentM = block.match(/class="tier-content"[^>]*>([\s\S]*)/i);
    const slice = contentM ? contentM[1] : block;
    const endM = slice.search(/<div class="tier-list-tier">|<h[234]\b/i);
    const tierSlice = endM >= 0 ? slice.slice(0, endM) : slice.slice(0, 12000);
    for (const id of extractItemIds(tierSlice)) {
      rows.push({ id, rank, note: `${letter} Tier`, slot: "Trinket" });
    }
  }

  // Heading-based: ### S Tier / [b]A Tier[/b] then items until next tier
  const headingRe =
    /(?:^|\n|\r|>|\])\s*(?:\[b\])?\s*([SABCD])\+?\s*[-–—]?\s*Tier(?:\s*List)?(?:\[\/b\])?/gi;
  const matches = [...chunk.matchAll(headingRe)];
  for (let i = 0; i < matches.length; i++) {
    const letter = matches[i][1];
    const rank = tierLetterToRank(letter);
    if (!rank) continue;
    const from = matches[i].index + matches[i][0].length;
    const to = i + 1 < matches.length ? matches[i + 1].index : chunk.length;
    const slice = chunk.slice(from, to);
    for (const id of extractItemIds(slice)) {
      rows.push({ id, rank, note: `${letter.toUpperCase()} Tier`, slot: "Trinket" });
    }
  }

  // Table: Tier letter in first cell, item in second
  for (const tr of chunk.matchAll(/\[tr\]([\s\S]*?)\[\/tr\]/gi)) {
    const tds = [...tr[1].matchAll(/\[td\]([\s\S]*?)\[\/td\]/gi)].map((m) =>
      stripMarkup(m[1])
    );
    if (tds.length < 2) continue;
    const rank = tierLetterToRank(tds[0].replace(/tier/i, "").trim());
    const itemM = tr[1].match(/\[item=(\d+)/i);
    if (!rank || !itemM) continue;
    rows.push({
      id: Number(itemM[1]),
      rank,
      note: `${tds[0].trim()} Tier`.replace(/\s+Tier Tier/i, " Tier"),
      slot: "Trinket",
    });
  }

  return rows;
}

function parseGuide(html) {
  const chunk = bisChunk(html);
  const nameById = buildNameIndex(html);
  const ordered = [];
  const byId = new Map();

  function upsert(id, name, slot, drop, rank, wowhead, note, { allowNew = true } = {}) {
    id = Number(id);
    if (!id || EMBELLISHMENTS.has(id)) return;
    let entry = byId.get(id);
    if (!entry) {
      if (!allowNew) return;
      entry = {
        id,
        name: "",
        wowhead: wowhead || "overall",
        rank: rank || "bis",
      };
      byId.set(id, entry);
      ordered.push(entry);
    } else {
      // Higher rank wins; never downgrade Overall BiS.
      if (rank && rankScore(rank) > rankScore(entry.rank)) {
        entry.rank = rank;
        if (wowhead) entry.wowhead = wowhead;
      }
    }
    const cleanName = stripMarkup(name);
    if (cleanName && !isPlaceholderName(cleanName)) {
      if (isPlaceholderName(entry.name) || cleanName.length >= (entry.name || "").length) {
        entry.name = cleanName;
      }
    }
    if (slot) {
      const ns = normalizeSlot(slot);
      if (ns && (!entry.slot || entry.slot === "")) entry.slot = ns;
    }
    const cd = cleanDrop(drop);
    if (cd) {
      if (!entry.drop || cd.length >= entry.drop.length) entry.drop = cd;
    }
    if (note && !entry.note) entry.note = note;
  }

  // 1) Overall BiS chunk — BiS (order matters)
  for (const row of extractGearRows(chunk)) {
    upsert(row.id, row.name, row.slot, row.drop, "bis", "overall");
  }
  for (const m of chunk.matchAll(/\[item=(\d+)/gi)) {
    upsert(m[1], null, null, null, "bis", "overall");
  }
  for (const m of itemHrefMatches(chunk)) {
    upsert(m[1], slugToName(m[2]), null, null, "bis", "overall");
  }

  // 2) Trinket tier list — Strong/Alt/Ok (and S-tier as BiS if not already)
  for (const row of extractTrinketTierRows(html)) {
    upsert(row.id, null, row.slot, null, row.rank, "trinket", row.note, {
      allowNew: true,
    });
  }

  // 3) Raid / Mythic+ BiS sections — Strong if not already Overall BiS
  const secondarySections = [
    {
      wowhead: "raid",
      start: [
        /Best Gear from Raids/i,
        /Best Raid Items/i,
        /Raid BiS/i,
        /Raid Drops/i,
      ],
      end: [
        /Best Gear from Mythic/i,
        /Best .* Trinkets/i,
        /Trinket Tier List/i,
        /Crafted Gear/i,
        /Set Bonuses/i,
      ],
    },
    {
      wowhead: "mythic",
      start: [
        /Best Gear from Mythic/i,
        /Mythic\+ BiS/i,
        /M\+ BiS/i,
        /Mythic Plus BiS/i,
        /Mythic\+ Drops/i,
      ],
      end: [
        /Best .* Trinkets/i,
        /Trinket Tier List/i,
        /Crafted Gear/i,
        /Embellish/i,
        /Stat Priority/i,
      ],
    },
  ];
  for (const sec of secondarySections) {
    const secHtml = sectionChunk(html, sec.start, sec.end, 30000);
    if (!secHtml) continue;
    for (const row of extractGearRows(secHtml)) {
      upsert(row.id, row.name, row.slot, row.drop, "strong", sec.wowhead, null, {
        allowNew: true,
      });
    }
    for (const id of extractItemIds(secHtml)) {
      upsert(id, null, null, null, "strong", sec.wowhead, null, { allowNew: true });
    }
  }

  // 4) Rest of guide — enrich slot+drop on known items only
  for (const row of extractGearRows(html)) {
    upsert(row.id, row.name, row.slot, row.drop, null, null, null, { allowNew: false });
  }

  // Fill missing names from page-wide index / slug
  for (const entry of ordered) {
    if (isPlaceholderName(entry.name) && nameById[entry.id]) {
      entry.name = nameById[entry.id];
    }
    if (isPlaceholderName(entry.name)) {
      const slugM = html.match(
        new RegExp(
          String.raw`href="(?:https?:\/\/(?:www|de|fr|es|pt|ru|ko|cn)\.wowhead\.com)?\/item=${entry.id}\/([^"#?]+)"`,
          "i"
        )
      );
      if (slugM) entry.name = slugToName(slugM[1]);
    }
    if (isPlaceholderName(entry.name)) {
      entry.name = `Item ${entry.id}`;
    }
  }

  return ordered;
}

async function dismissConsent(page) {
  const sels = [
    "#onetrust-accept-btn-handler",
    "button:has-text('Accept All')",
    "button:has-text('Accept all')",
    "button:has-text('I Agree')",
  ];
  for (const sel of sels) {
    try {
      const btn = page.locator(sel).first();
      if (await btn.isVisible({ timeout: 800 })) {
        await btn.click({ timeout: 2000 });
        await sleep(400);
        return;
      }
    } catch {
      /* ignore */
    }
  }
}

async function scrapeSpecOnce(page, stem, cls, spec) {
  const url = `https://www.wowhead.com/guide/classes/${cls}/${spec}/bis-gear`;
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 90000 });
  const title = await page.title();
  if (/just a moment|attention required|access denied|cloudflare/i.test(title)) {
    await sleep(12000);
  }
  await dismissConsent(page);
  await page.waitForSelector('a[href*="/item="]', { timeout: 35000 }).catch(() => {});
  // Guide body often hydrates after first paint.
  await sleep(1800);
  await page
    .waitForFunction(
      () => (document.body?.innerText || "").length > 4000,
      null,
      { timeout: 15000 }
    )
    .catch(() => {});
  let html = await page.content();
  // Prefer live Gatherer names when available in the page context.
  try {
    const gathererNames = await page.evaluate(() => {
      const out = {};
      try {
        const data =
          (window.WH &&
            WH.Gatherer &&
            typeof WH.Gatherer.getData === "function" &&
            WH.Gatherer.getData(3)) ||
          null;
        if (data && typeof data === "object") {
          for (const [id, row] of Object.entries(data)) {
            const n = row && (row.name_enus || row.name || row.name_en);
            if (n) out[id] = n;
          }
        }
      } catch (e) {
        /* ignore */
      }
      return out;
    });
    if (gathererNames && Object.keys(gathererNames).length) {
      const extra = Object.entries(gathererNames)
        .map(
          ([id, name]) =>
            `<a href="/item=${id}/x">${String(name).replace(/</g, "")}</a>`
        )
        .join("\n");
      html = html + "\n<!--gatherer-->\n" + extra;
    }
  } catch {
    /* ignore */
  }
  if (
    html.length < 8000 ||
    /403 ERROR|Request blocked|Just a moment|cf-browser-verification/i.test(html)
  ) {
    throw new Error("blocked or empty page");
  }
  const items = parseGuide(html);
  if (items.length === 0) {
    throw new Error("no BiS items parsed");
  }
  const placeholders = items.filter((i) => /^Item \d+$/i.test(i.name || "")).length;
  const byRank = { bis: 0, strong: 0, alt: 0, ok: 0 };
  for (const i of items) byRank[i.rank] = (byRank[i.rank] || 0) + 1;
  return {
    count: items.length,
    withDrop: items.filter((i) => i.drop).length,
    placeholders,
    byRank,
    items,
    url,
  };
}

async function scrapeSpec(page, stem, cls, spec) {
  let lastErr = null;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const pack = await scrapeSpecOnce(page, stem, cls, spec);
      if (pack.count >= 8) return pack;
      lastErr = new Error(`only ${pack.count} items`);
    } catch (e) {
      lastErr = e;
    }
    await sleep(1500 * attempt);
  }
  throw lastErr || new Error("scrape failed");
}

function loadPreviousOut() {
  try {
    if (!fs.existsSync(OUT)) return {};
    const prev = JSON.parse(fs.readFileSync(OUT, "utf8"));
    return prev.out || {};
  } catch {
    return {};
  }
}

async function main() {
  const browser = await chromium.launch({
    headless: true,
    args: ["--disable-blink-features=AutomationControlled"],
  });
  const context = await browser.newContext({
    locale: "en-US",
    userAgent:
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
    viewport: { width: 1440, height: 900 },
  });
  await context.addInitScript(() => {
    Object.defineProperty(navigator, "webdriver", { get: () => undefined });
  });
  const page = await context.newPage();
  await page.goto("https://www.wowhead.com/", { waitUntil: "domcontentloaded", timeout: 60000 }).catch(() => {});
  await sleep(2000);
  await dismissConsent(page);

  const previous = loadPreviousOut();
  const out = {};
  const errors = {};
  for (const [stem, cls, spec] of SPECS) {
    process.stdout.write(`${stem} ... `);
    try {
      const pack = await scrapeSpec(page, stem, cls, spec);
      out[stem] = pack;
      console.log(
        `${pack.count} items (${pack.withDrop} drop, ${pack.placeholders} ph` +
          (pack.byRank
            ? `, bis=${pack.byRank.bis || 0}/strong=${pack.byRank.strong || 0}/alt=${pack.byRank.alt || 0}`
            : "") +
          `)`
      );
      if (pack.count < 8) errors[stem] = `only ${pack.count} items`;
    } catch (e) {
      const msg = e && e.message ? e.message : String(e);
      errors[stem] = msg;
      const prev = previous[stem];
      if (prev && (prev.count || 0) > 0 && Array.isArray(prev.items) && prev.items.length) {
        out[stem] = { ...prev, reused: true };
        console.log(`FAIL ${msg} — reused previous (${prev.count} items)`);
      } else {
        out[stem] = { count: 0, items: [], placeholders: 0, error: msg };
        console.log(`FAIL ${msg}`);
      }
    }
    await sleep(900);
  }

  await browser.close();

  const ok = Object.values(out).filter((x) => x.count > 0).length;
  const totalItems = Object.values(out).reduce((n, p) => n + (p.count || 0), 0);
  const totalPh = Object.values(out).reduce((n, p) => n + (p.placeholders || 0), 0);
  const freshOk = Object.values(out).filter((x) => x.count > 0 && !x.reused).length;
  const payload = {
    scrapedAt: new Date().toISOString().slice(0, 10),
    ok,
    freshOk,
    totalItems,
    placeholders: totalPh,
    errors,
    out,
  };
  fs.writeFileSync(OUT, JSON.stringify(payload, null, 2), "utf8");
  console.log(
    `\nWrote ${OUT} (${ok}/${SPECS.length} specs, fresh=${freshOk}, ph=${totalPh}/${totalItems})`
  );
  if (ok < 36) {
    console.error("Too few specs available (fresh+reused) — not safe to regenerate Data/");
    process.exit(1);
  }
  if (totalItems > 0 && totalPh / totalItems > 0.45) {
    console.error("Placeholder name rate too high — aborting");
    process.exit(1);
  }
  if (freshOk === 0) {
    console.error("No fresh specs scraped this run — aborting to avoid no-op PR noise");
    process.exit(1);
  }
}

const isDirectRun =
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);

if (isDirectRun) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}

export { parseGuide, extractGearRows, bisChunk, cleanDrop, extractTrinketTierRows, sectionChunk };
