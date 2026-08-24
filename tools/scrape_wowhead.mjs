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
  /^(Weapon|Weapons|Offhand|Off[- ]?Hand|Main[- ]?Hand|One[- ]?Hand|Two[- ]?Hand|Head|Helm|Neck|Shoulders?|Back|Cloak|Chest|Wrist|Wrists|Hands|Gloves|Waist|Belt|Legs|Feet|Boots|Finger|Ring|Trinkets?)$/i;

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
    .replace(/\s+/g, " ")
    .trim();
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
  const hardCap = 35000;
  if (end < 0 || end > hardCap) end = hardCap;
  return html.slice(start, start + 20 + end);
}

function parseOverall(html) {
  const chunk = bisChunk(html);
  const ordered = [];
  const seen = new Set();

  function push(id, name, slot, drop) {
    id = Number(id);
    if (!id || seen.has(id) || EMBELLISHMENTS.has(id)) return;
    seen.add(id);
    const entry = {
      id,
      name: stripMarkup(name) || `Item ${id}`,
      wowhead: "overall",
      rank: "bis",
    };
    if (slot) entry.slot = normalizeSlot(slot);
    if (drop) entry.drop = stripMarkup(drop);
    ordered.push(entry);
  }

  for (const tr of chunk.matchAll(/\[tr\]([\s\S]*?)\[\/tr\]/gi)) {
    const tds = [...tr[1].matchAll(/\[td\]([\s\S]*?)\[\/td\]/gi)].map((m) => m[1]);
    if (tds.length < 2) continue;
    const slotRaw = stripMarkup(tds[0]);
    if (!SLOT_RE.test(slotRaw)) continue;
    const itemM = tds[1].match(/\[item=(\d+)/i) || tr[1].match(/\[item=(\d+)/i);
    if (!itemM) continue;
    push(itemM[1], null, slotRaw, tds[2] || "");
  }

  const htmlRow =
    /<(?:td|th)[^>]*>\s*(?:<[^>]+>\s*)*([^<]{2,40}?)\s*(?:<\/[^>]+>\s*)*<\/(?:td|th)>\s*<(?:td|th)[^>]*>[\s\S]{0,800}?href="\/item=(\d+)\/([^"#?]+)"[^>]*>([^<]*)<\/a>[\s\S]{0,400}?<\/(?:td|th)>\s*<(?:td|th)[^>]*>([\s\S]*?)<\/(?:td|th)>/gi;
  for (const m of html.matchAll(htmlRow)) {
    const slotRaw = m[1].trim();
    if (!SLOT_RE.test(slotRaw)) continue;
    push(m[2], m[4] || m[3].replace(/-/g, " "), slotRaw, m[5]);
  }

  const bbRows =
    /\[td\](?:\[b\])?([^\[\]]+?)(?:\[\/b\])?\[\/td\][\s\S]{0,400}?\[item=(\d+)/gi;
  for (const m of chunk.matchAll(bbRows)) {
    const slotRaw = m[1].trim();
    if (!SLOT_RE.test(slotRaw.replace(/\[\/?b\]/gi, "").trim())) continue;
    push(m[2], null, slotRaw, null);
  }

  for (const m of chunk.matchAll(/\[item=(\d+)/gi)) {
    push(m[1], null, null, null);
  }

  const nameById = {};
  for (const m of chunk.matchAll(/href="\/item=(\d+)\/([^"#?]+)"[^>]*>([^<]*)</gi)) {
    const id = Number(m[1]);
    const text = (m[3] || "").trim();
    if (text) nameById[id] = text;
    else if (!nameById[id]) nameById[id] = m[2].replace(/-/g, " ");
  }
  for (const m of chunk.matchAll(/item=(\d+)/gi)) {
    push(Number(m[1]), nameById[Number(m[1])], null, null);
  }

  for (const entry of ordered) {
    if (entry.name && !entry.name.startsWith("Item ")) continue;
    const re = new RegExp(
      'href="/item=' + entry.id + '/([^"#?]+)"[^>]*>([^<]*)<',
      "i"
    );
    const mm = html.match(re);
    if (mm) {
      entry.name = (mm[2] || "").trim() || mm[1].replace(/-/g, " ");
    }
  }

  return ordered;
}

async function scrapeSpec(page, stem, cls, spec) {
  const url = `https://www.wowhead.com/guide/classes/${cls}/${spec}/bis-gear`;
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 90000 });
  const title = await page.title();
  if (/just a moment|attention required|access denied/i.test(title)) {
    await sleep(8000);
  }
  await page.waitForSelector('a[href*="/item="]', { timeout: 25000 }).catch(() => {});
  await sleep(400);
  const html = await page.content();
  if (html.length < 8000 || /403 ERROR|Request blocked/i.test(html)) {
    throw new Error("blocked or empty page");
  }
  const items = parseOverall(html);
  return { count: items.length, withDrop: items.filter((i) => i.drop).length, items, url };
}

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    locale: "en-US",
    userAgent:
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
  });
  const page = await context.newPage();
  await page.goto("https://www.wowhead.com/", { waitUntil: "domcontentloaded", timeout: 60000 }).catch(() => {});
  await sleep(1000);

  const out = {};
  const errors = {};
  for (const [stem, cls, spec] of SPECS) {
    process.stdout.write(`${stem} ... `);
    try {
      const pack = await scrapeSpec(page, stem, cls, spec);
      out[stem] = pack;
      console.log(`${pack.count} items (${pack.withDrop} drop)`);
      if (pack.count < 8) errors[stem] = `only ${pack.count} items`;
    } catch (e) {
      const msg = e && e.message ? e.message : String(e);
      errors[stem] = msg;
      out[stem] = { count: 0, items: [], error: msg };
      console.log(`FAIL ${msg}`);
    }
    await sleep(700);
  }

  await browser.close();

  const ok = Object.values(out).filter((x) => x.count > 0).length;
  const payload = {
    scrapedAt: new Date().toISOString().slice(0, 10),
    ok,
    errors,
    out,
  };
  fs.writeFileSync(OUT, JSON.stringify(payload, null, 2), "utf8");
  console.log(`\nWrote ${OUT} (${ok}/${SPECS.length} specs)`);
  if (ok < 36) {
    console.error("Too few specs scraped — not safe to regenerate Data/");
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
