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
  // Rendered item links
  for (const m of html.matchAll(
    /href="\/item=(\d+)\/([^"#?]+)"[^>]*>([^<]*)</gi
  )) {
    const id = Number(m[1]);
    const text = (m[3] || "").trim();
    if (text && !isPlaceholderName(text)) names[id] = text;
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
  // Alternate gatherer key order
  for (const m of html.matchAll(
    /name_enus"\s*:\s*"((?:\\.|[^"\\])*)"[^{}]{0,200}?"(\d{5,7})"/gi
  )) {
    /* skip noisy reverse matches */
  }
  return names;
}

function bisChunk(html) {
  const startPats = [
    /Overall BiS/i,
    /Best-in-Slot Gear for/i,
    /Best in Slot Gear for/i,
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
      if (abs >= 25000) {
        start = abs;
        break;
      }
      from = abs + 1;
    }
    if (start >= 0) break;
  }
  if (start < 0) {
    const i = html.slice(40000).search(/\[item=\d+/i);
    start = i >= 0 ? 40000 + i - 200 : 40000;
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
  const hardCap = 40000;
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
      tds[1].match(/href="\/item=\d+\/[^"]+"[^>]*>([^<]+)/i)?.[1] ||
      null;
    rows.push({
      id: Number(itemM[1]),
      name: nameFromCell,
      slot: slotRaw,
      drop: tds[2] || "",
    });
  }

  const htmlRow =
    /<(?:td|th)[^>]*>\s*(?:<[^>]+>\s*)*([^<]{2,40}?)\s*(?:<\/[^>]+>\s*)*<\/(?:td|th)>\s*<(?:td|th)[^>]*>[\s\S]{0,900}?href="\/item=(\d+)\/([^"#?]+)"[^>]*>([^<]*)<\/a>[\s\S]{0,500}?<\/(?:td|th)>\s*<(?:td|th)[^>]*>([\s\S]*?)<\/(?:td|th)>/gi;
  for (const m of html.matchAll(htmlRow)) {
    const slotRaw = m[1].trim();
    if (!SLOT_RE.test(slotRaw)) continue;
    rows.push({
      id: Number(m[2]),
      name: m[4] || slugToName(m[3]),
      slot: slotRaw,
      drop: m[5],
    });
  }

  // Item | Source only (no slot column) — common in "Raid Drops" tables
  const itemSource =
    /href="\/item=(\d+)\/([^"#?]+)"[^>]*>([^<]*)<\/a>[\s\S]{0,200}?<(?:td|th)[^>]*>([\s\S]{2,120}?)<\/(?:td|th)>/gi;
  for (const m of html.matchAll(itemSource)) {
    const drop = stripMarkup(m[4]);
    if (!drop || SLOT_RE.test(drop) || drop.length > 80) continue;
    if (/^[\d.%\s]+$/.test(drop)) continue;
    rows.push({
      id: Number(m[1]),
      name: m[3] || slugToName(m[2]),
      slot: null,
      drop,
    });
  }

  return rows;
}

function parseOverall(html) {
  const chunk = bisChunk(html);
  const nameById = buildNameIndex(html);
  const ordered = [];
  const byId = new Map();

  function upsert(id, name, slot, drop, { allowNew = true } = {}) {
    id = Number(id);
    if (!id || EMBELLISHMENTS.has(id)) return;
    let entry = byId.get(id);
    if (!entry) {
      if (!allowNew) return;
      entry = {
        id,
        name: "",
        wowhead: "overall",
        rank: "bis",
      };
      byId.set(id, entry);
      ordered.push(entry);
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
    const cleanDrop = stripMarkup(drop);
    if (cleanDrop) {
      if (!entry.drop || cleanDrop.length > entry.drop.length) entry.drop = cleanDrop;
    }
  }

  // 1) Overall BiS chunk — defines which items are BiS (order matters)
  for (const row of extractGearRows(chunk)) {
    upsert(row.id, row.name, row.slot, row.drop);
  }
  for (const m of chunk.matchAll(/\[item=(\d+)/gi)) {
    upsert(m[1], null, null, null);
  }
  for (const m of chunk.matchAll(/href="\/item=(\d+)\/([^"#?]+)"[^>]*>([^<]*)</gi)) {
    upsert(m[1], m[3] || slugToName(m[2]), null, null);
  }

  // 2) Rest of guide (Raid Drops / Dungeons / Crafting) — enrich slot+drop only
  for (const row of extractGearRows(html)) {
    upsert(row.id, row.name, row.slot, row.drop, { allowNew: false });
  }

  // Fill missing names from page-wide index / slug
  for (const entry of ordered) {
    if (isPlaceholderName(entry.name) && nameById[entry.id]) {
      entry.name = nameById[entry.id];
    }
    if (isPlaceholderName(entry.name)) {
      const slugM = html.match(
        new RegExp(`href="/item=${entry.id}/([^"#?]+)"`, "i")
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
  const items = parseOverall(html);
  if (items.length === 0) {
    throw new Error("no BiS items parsed");
  }
  const placeholders = items.filter((i) => /^Item \d+$/i.test(i.name || "")).length;
  return {
    count: items.length,
    withDrop: items.filter((i) => i.drop).length,
    placeholders,
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
        `${pack.count} items (${pack.withDrop} drop, ${pack.placeholders} ph)`
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

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
