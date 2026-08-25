/**
 * Re-scrape weak placeholder specs into wowhead_browser_data.json
 */
import { chromium } from "playwright";
import fs from "node:fs";
import { parseGuide } from "./scrape_wowhead.mjs";

const TARGETS = [
  ["MarksmanshipHunter", "hunter", "marksmanship"],
  ["DevastationEvoker", "evoker", "devastation"],
  ["RetributionPaladin", "paladin", "retribution"],
  ["BrewmasterMonk", "monk", "brewmaster"],
  ["ShadowPriest", "priest", "shadow"],
];

const OUT = "wowhead_browser_data.json";
const prev = JSON.parse(fs.readFileSync(OUT, "utf8"));

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

for (const [stem, cls, spec] of TARGETS) {
  const url = `https://www.wowhead.com/guide/classes/${cls}/${spec}/bis-gear`;
  process.stdout.write(`${stem} ... `);
  let best = null;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 90000 });
      await page.waitForTimeout(2500);
      await page.waitForSelector('a[href*="item="]', { timeout: 35000 }).catch(() => {});
      let html = await page.content();
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
      const items = parseGuide(html);
      const ph = items.filter((i) => /^Item \d+$/i.test(i.name || "")).length;
      const pack = {
        count: items.length,
        withDrop: items.filter((i) => i.drop).length,
        placeholders: ph,
        items,
        url,
      };
      if (!best || pack.count > best.count || pack.placeholders < best.placeholders) {
        best = pack;
      }
      if (pack.count >= 8 && ph / Math.max(pack.count, 1) < 0.35) break;
    } catch (e) {
      console.log(`attempt ${attempt} FAIL ${e.message || e}`);
    }
    await page.waitForTimeout(1500 * attempt);
  }
  if (best && best.count > 0) {
    prev.out[stem] = best;
    console.log(
      `${best.count} items drop=${best.withDrop} ph=${best.placeholders}`
    );
  } else {
    console.log("KEEP previous");
  }
  await page.waitForTimeout(800);
}

prev.scrapedAt = new Date().toISOString().slice(0, 10);
prev.ok = Object.values(prev.out).filter((x) => x.count > 0).length;
prev.totalItems = Object.values(prev.out).reduce((n, p) => n + (p.count || 0), 0);
prev.placeholders = Object.values(prev.out).reduce(
  (n, p) => n + (p.placeholders || 0),
  0
);
fs.writeFileSync(OUT, JSON.stringify(prev, null, 2));
await browser.close();
console.log("updated", OUT, "ph=", prev.placeholders);
