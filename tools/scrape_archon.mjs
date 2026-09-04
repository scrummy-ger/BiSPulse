/**
 * Scrape Archon.gg popular gear tables (Raid + Mythic+) into archon_browser_data.json.
 *
 *   cd tools
 *   node scrape_archon.mjs
 *
 * Cloudflare may show a human check on first visit — the scraper clicks through when possible.
 */
import { chromium } from "playwright";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(__dirname, "archon_browser_data.json");
const STATE = path.join(__dirname, ".archon_storage.json");

/** stem → [specSlug, classSlug] matching Archon URLs */
const SPECS = [
  ["BloodDeathKnight", "blood", "death-knight"],
  ["FrostDeathKnight", "frost", "death-knight"],
  ["UnholyDeathKnight", "unholy", "death-knight"],
  ["HavocDemonHunter", "havoc", "demon-hunter"],
  ["VengeanceDemonHunter", "vengeance", "demon-hunter"],
  ["DevourerDemonHunter", "devourer", "demon-hunter"],
  ["BalanceDruid", "balance", "druid"],
  ["FeralDruid", "feral", "druid"],
  ["GuardianDruid", "guardian", "druid"],
  ["RestorationDruid", "restoration", "druid"],
  ["DevastationEvoker", "devastation", "evoker"],
  ["PreservationEvoker", "preservation", "evoker"],
  ["AugmentationEvoker", "augmentation", "evoker"],
  ["BeastMasteryHunter", "beast-mastery", "hunter"],
  ["MarksmanshipHunter", "marksmanship", "hunter"],
  ["SurvivalHunter", "survival", "hunter"],
  ["ArcaneMage", "arcane", "mage"],
  ["FireMage", "fire", "mage"],
  ["FrostMage", "frost", "mage"],
  ["BrewmasterMonk", "brewmaster", "monk"],
  ["MistweaverMonk", "mistweaver", "monk"],
  ["WindwalkerMonk", "windwalker", "monk"],
  ["HolyPaladin", "holy", "paladin"],
  ["ProtectionPaladin", "protection", "paladin"],
  ["RetributionPaladin", "retribution", "paladin"],
  ["DisciplinePriest", "discipline", "priest"],
  ["HolyPriest", "holy", "priest"],
  ["ShadowPriest", "shadow", "priest"],
  ["AssassinationRogue", "assassination", "rogue"],
  ["OutlawRogue", "outlaw", "rogue"],
  ["SubtletyRogue", "subtlety", "rogue"],
  ["ElementalShaman", "elemental", "shaman"],
  ["EnhancementShaman", "enhancement", "shaman"],
  ["RestorationShaman", "restoration", "shaman"],
  ["AfflictionWarlock", "affliction", "warlock"],
  ["DemonologyWarlock", "demonology", "warlock"],
  ["DestructionWarlock", "destruction", "warlock"],
  ["ArmsWarrior", "arms", "warrior"],
  ["FuryWarrior", "fury", "warrior"],
  ["ProtectionWarrior", "protection", "warrior"],
];

const EMBELLISHMENTS = new Set([240167, 273060, 245790, 245786]);
const MIN_ITEM_ID = 220000;

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function normalizeSlot(headerHtml) {
  const s = String(headerHtml || "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();
  if (/main.?hand|weapon/.test(s)) return "Weapon";
  if (/off.?hand/.test(s)) return "Offhand";
  if (/trinket/.test(s)) return "Trinket";
  if (/ring/.test(s)) return "Ring";
  if (/head|helm/.test(s)) return "Head";
  if (/neck/.test(s)) return "Neck";
  if (/shoulder/.test(s)) return "Shoulders";
  if (/back|cloak|cape/.test(s)) return "Cloak";
  if (/chest/.test(s)) return "Chest";
  if (/wrist|bracer/.test(s)) return "Wrist";
  if (/hand|glove/.test(s)) return "Gloves";
  if (/waist|belt/.test(s)) return "Belt";
  if (/leg/.test(s)) return "Legs";
  if (/feet|boot/.test(s)) return "Boots";
  return "";
}

function parseItemMarkup(itemHtml) {
  const idM = String(itemHtml || "").match(/id=\{?(\d+)\}?/);
  const id = idM ? Number(idM[1]) : 0;
  const bis = /BadgeLabel>BiS</i.test(itemHtml) || />\s*BiS\s*</i.test(itemHtml);
  let name = String(itemHtml || "")
    .replace(/<BadgeLabel>[\s\S]*?<\/BadgeLabel>/gi, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/\s+/g, " ")
    .replace(/^BiS\s+/i, "")
    .trim();
  // Tooltip/markup sometimes leaves a leading "BiS " after strip
  name = name.replace(/^BiS\s+/i, "").trim();
  return { id, name, bis };
}

function parsePopularity(popHtml) {
  const m = String(popHtml || "").match(/([\d.]+)\s*%/);
  return m ? Number(m[1]) : 0;
}

function rankFromPopularity(pop, bis) {
  // Archon "BiS" badge is Wowhead-derived; treat as at least strong when present.
  if (bis) {
    if (pop >= 25) return "bis";
    return "strong";
  }
  if (pop >= 20) return "strong";
  if (pop >= 8) return "alt";
  if (pop >= 3) return "ok";
  return null;
}

function extractGearFromNextData(html) {
  const m = html.match(
    /<script id="__NEXT_DATA__" type="application\/json">([\s\S]*?)<\/script>/
  );
  if (!m) return { items: [], error: "no __NEXT_DATA__" };
  let data;
  try {
    data = JSON.parse(m[1]);
  } catch (e) {
    return { items: [], error: "bad __NEXT_DATA__ json" };
  }
  const page = data?.props?.pageProps?.page;
  if (!page) return { items: [], error: "no page props" };

  const items = [];
  const seen = new Set();

  const sections = page.sections || [];
  for (const sec of sections) {
    if (sec.component !== "BuildsGearTablesSection") continue;
    const tables = sec.props?.tables || [];
    for (const table of tables) {
      const slot = normalizeSlot(table.columns?.item?.header || "");
      const rows = Array.isArray(table.data) ? table.data : [];
      let kept = 0;
      for (const row of rows) {
        const { id, name, bis } = parseItemMarkup(row.item);
        if (!id || id < MIN_ITEM_ID || EMBELLISHMENTS.has(id) || seen.has(id)) continue;
        const pop = parsePopularity(row.popularity || row.popularityAndReportLink);
        const rank = rankFromPopularity(pop, bis);
        if (!rank) continue;
        // Cap alternatives per slot to keep lists usable
        if (kept >= 6 && !bis) continue;
        seen.add(id);
        kept += 1;
        items.push({
          id,
          name: name || `Item ${id}`,
          slot,
          popularity: pop,
          bis: !!bis,
          rank,
        });
      }
    }
  }

  return {
    items,
    lastUpdated: page.lastUpdated || null,
    totalParses: page.totalParses || 0,
  };
}

function gearUrl(specSlug, classSlug, zone) {
  if (zone === "mythic") {
    return `https://www.archon.gg/wow/builds/${specSlug}/${classSlug}/mythic-plus/gear-and-tier-set/10/all-dungeons/this-week`;
  }
  return `https://www.archon.gg/wow/builds/${specSlug}/${classSlug}/raid/gear-and-tier-set/mythic/all-bosses`;
}

async function dismissHumanCheck(page) {
  const sels = [
    "button:has-text('I am a human and not a bot')",
    "button:has-text('I am a human')",
    "#onetrust-accept-btn-handler",
  ];
  for (const sel of sels) {
    try {
      const btn = page.locator(sel).first();
      if (await btn.isVisible({ timeout: 1200 })) {
        await btn.click({ timeout: 3000 });
        await sleep(2500);
        return true;
      }
    } catch {
      /* ignore */
    }
  }
  return false;
}

async function waitForGuide(page) {
  for (let i = 0; i < 24; i++) {
    const title = await page.title();
    if (/just a moment|attention required|human verification/i.test(title)) {
      await dismissHumanCheck(page);
      await sleep(1500);
      continue;
    }
    const has = await page.locator("#__NEXT_DATA__").count();
    if (has > 0) {
      const html = await page.content();
      if (html.includes("BuildsGearTablesSection") || html.includes("ItemIcon")) {
        return html;
      }
    }
    await sleep(1000);
  }
  return await page.content();
}

async function scrapePack(page, stem, specSlug, classSlug, zone) {
  const url = gearUrl(specSlug, classSlug, zone);
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 90000 });
  await dismissHumanCheck(page);
  const html = await waitForGuide(page);
  if (/just a moment|human verification|access denied/i.test(await page.title())) {
    throw new Error("cloudflare blocked");
  }
  const parsed = extractGearFromNextData(html);
  if (!parsed.items.length) {
    throw new Error(parsed.error || "no gear items");
  }
  for (const it of parsed.items) {
    it.content = zone === "mythic" ? "mythic" : "raid";
  }
  return {
    count: parsed.items.length,
    lastUpdated: parsed.lastUpdated,
    totalParses: parsed.totalParses,
    items: parsed.items,
    url,
  };
}

async function main() {
  const only = process.argv.slice(2).filter((a) => !a.startsWith("-"));
  const specs = only.length
    ? SPECS.filter(([stem]) => only.includes(stem))
    : SPECS;

  const launchOpts = {
    headless: false,
    args: ["--disable-blink-features=AutomationControlled"],
  };
  // Prefer system Chrome when available — better Cloudflare pass rate.
  try {
    launchOpts.channel = "chrome";
  } catch {
    /* ignore */
  }

  const browser = await chromium.launch(launchOpts);
  const contextOpts = {
    locale: "en-US",
    userAgent:
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
    viewport: { width: 1440, height: 900 },
  };
  if (fs.existsSync(STATE)) {
    contextOpts.storageState = STATE;
  }
  const context = await browser.newContext(contextOpts);
  await context.addInitScript(() => {
    Object.defineProperty(navigator, "webdriver", { get: () => undefined });
  });
  const page = await context.newPage();

  // Warm homepage / CF
  await page.goto("https://www.archon.gg/wow", {
    waitUntil: "domcontentloaded",
    timeout: 90000,
  });
  await dismissHumanCheck(page);
  await sleep(2000);

  const previous = (() => {
    try {
      if (!fs.existsSync(OUT)) return {};
      return JSON.parse(fs.readFileSync(OUT, "utf8")).out || {};
    } catch {
      return {};
    }
  })();

  const out = {};
  const errors = {};

  for (const [stem, specSlug, classSlug] of specs) {
    process.stdout.write(`${stem} ... `);
    const pack = { raid: null, mythic: null, items: [] };
    try {
      pack.raid = await scrapePack(page, stem, specSlug, classSlug, "raid");
      await sleep(700);
      try {
        pack.mythic = await scrapePack(page, stem, specSlug, classSlug, "mythic");
      } catch (e) {
        pack.mythicError = e.message || String(e);
      }

      // Merge raid + mythic by id (higher popularity / better rank wins)
      const byId = new Map();
      const rankScore = { bis: 4, strong: 3, alt: 2, ok: 1 };
      for (const src of [pack.raid, pack.mythic]) {
        if (!src?.items) continue;
        for (const it of src.items) {
          const prev = byId.get(it.id);
          if (!prev) {
            byId.set(it.id, { ...it, wowhead: it.content });
            continue;
          }
          if ((rankScore[it.rank] || 0) > (rankScore[prev.rank] || 0)) {
            byId.set(it.id, {
              ...prev,
              ...it,
              wowhead: it.content,
              name: it.name || prev.name,
              slot: it.slot || prev.slot,
            });
          } else if ((it.popularity || 0) > (prev.popularity || 0)) {
            prev.popularity = it.popularity;
            if (!prev.slot && it.slot) prev.slot = it.slot;
          }
        }
      }
      pack.items = [...byId.values()];
      pack.count = pack.items.length;
      out[stem] = pack;
      console.log(
        `raid=${pack.raid?.count || 0} m+=${pack.mythic?.count || 0} merged=${pack.count}`
      );
    } catch (e) {
      const msg = e.message || String(e);
      errors[stem] = msg;
      if (previous[stem]?.items?.length) {
        out[stem] = { ...previous[stem], reused: true };
        console.log(`FAIL ${msg} — reused previous`);
      } else {
        out[stem] = { count: 0, items: [], error: msg };
        console.log(`FAIL ${msg}`);
      }
    }
    await sleep(500);
  }

  try {
    await context.storageState({ path: STATE });
  } catch {
    /* ignore */
  }
  await browser.close();

  const ok = Object.values(out).filter((x) => (x.count || 0) > 0).length;
  const totalItems = Object.values(out).reduce((n, p) => n + (p.count || 0), 0);
  const prevOk = Object.values(previous).filter((x) => (x.count || 0) > 0).length;
  // Never wipe a good scrape with a Cloudflare-empty run.
  if (ok === 0 && prevOk > 0) {
    console.error(
      `Refusing to overwrite ${OUT}: this run got 0 specs, previous had ${prevOk}.`
    );
    process.exitCode = 1;
    return;
  }
  const payload = {
    scrapedAt: new Date().toISOString().slice(0, 10),
    source: "archon.gg",
    ok,
    totalItems,
    errors,
    out,
  };
  fs.writeFileSync(OUT, JSON.stringify(payload, null, 2), "utf8");
  console.log(`\nWrote ${OUT} (${ok}/${specs.length} specs, items=${totalItems})`);
  if (ok < Math.min(20, Math.floor(specs.length * 0.5))) {
    console.error("Too few Archon specs scraped");
    process.exit(1);
  }
}

const isDirect =
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isDirect) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}

export { extractGearFromNextData, normalizeSlot, SPECS };
