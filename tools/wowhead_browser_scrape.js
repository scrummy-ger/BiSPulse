/**
 * Run inside Wowhead via CDP Runtime.evaluate (awaitPromise).
 * Fetches all class BiS guides and extracts Overall BiS item IDs.
 * Handles both rendered HTML tables and Wowhead BBCode [item=ID] lists.
 */
(async () => {
  const specs = [
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
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  const SLOT_RE =
    /^(Weapon|Weapons|Offhand|Off[- ]?Hand|Main[- ]?Hand|One[- ]?Hand|Two[- ]?Hand|Head|Helm|Neck|Shoulders?|Back|Cloak|Chest|Wrist|Wrists|Hands|Gloves|Waist|Belt|Legs|Feet|Boots|Finger|Ring|Trinkets?)$/i;

  function normalizeSlot(raw) {
    const s = String(raw || "")
      .replace(/\[\/?b\]/gi, "")
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
    return raw;
  }

  function bisChunk(html) {
    // Prefer content headings (skip early title/nav matches).
    const startPats = [
      /Overall BiS/i,
      /Best-in-Slot Gear for/i,
      /Best in Slot Gear for/i,
      /Best in Slot Enhancement/i,
      /Best in Slot [^<\n]{0,40} Gear/i,
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
        // Title/meta usually sits < 25k; BiS body is later.
        if (abs >= 25000) {
          start = abs;
          break;
        }
        from = abs + 1;
      }
      if (start >= 0) break;
    }
    if (start < 0) {
      // Fallback: first [item=] after mid-page
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
      /Best [^<\n]{0,40} Trinkets/i,
    ];
    let end = -1;
    const rest = html.slice(start + 20);
    for (const p of endPats) {
      const i = rest.search(p);
      if (i >= 0 && (end < 0 || i < end)) end = i;
    }
    const hardCap = 25000;
    if (end < 0 || end > hardCap) end = hardCap;
    return html.slice(start, start + 20 + end);
  }

  function parseOverall(html) {
    const chunk = bisChunk(html);
    const ordered = [];
    const seen = new Set();

    function push(id, name, slot) {
      id = Number(id);
      if (!id || seen.has(id) || EMBELLISHMENTS.has(id)) return;
      seen.add(id);
      const entry = {
        id,
        name: (name || "").trim() || "Item " + id,
        wowhead: "overall",
        rank: "bis",
      };
      if (slot) entry.slot = normalizeSlot(slot);
      ordered.push(entry);
    }

    // 1) BBCode slot tables: [td]Weapon[/td] ... [item=12345 ...]
    const bbRows =
      /\[td\](?:\[b\])?([^\[\]]+?)(?:\[\/b\])?\[\/td\][\s\S]{0,400}?\[item=(\d+)/gi;
    for (const m of chunk.matchAll(bbRows)) {
      const slotRaw = m[1].trim();
      if (!SLOT_RE.test(slotRaw.replace(/\[\/?b\]/gi, "").trim())) continue;
      push(m[2], null, slotRaw);
    }

    // 2) Any remaining BBCode items in chunk (order preserved)
    for (const m of chunk.matchAll(/\[item=(\d+)/gi)) {
      push(m[1], null, null);
    }

    // 3) Rendered HTML slot tables
    const htmlRows =
      /<(?:td|th)[^>]*>\s*(?:<[^>]+>\s*)*([^<]{2,40}?)\s*(?:<\/[^>]+>\s*)*<\/(?:td|th)>\s*<(?:td|th)[^>]*>[\s\S]{0,500}?href="\/item=(\d+)\/([^"#?]+)"[^>]*>([^<]*)</gi;
    for (const m of html.matchAll(htmlRows)) {
      const slotRaw = m[1].trim();
      if (!SLOT_RE.test(slotRaw)) continue;
      push(m[2], m[4] || m[3].replace(/-/g, " "), slotRaw);
    }

    // 4) Fallback: HTML item links only inside BiS chunk
    const nameById = {};
    for (const m of chunk.matchAll(
      /href="\/item=(\d+)\/([^"#?]+)"[^>]*>([^<]*)</gi
    )) {
      const id = Number(m[1]);
      const text = (m[3] || "").trim();
      if (text) nameById[id] = text;
      else if (!nameById[id]) nameById[id] = m[2].replace(/-/g, " ");
    }
    for (const m of chunk.matchAll(/item=(\d+)/gi)) {
      const id = Number(m[1]);
      push(id, nameById[id], null);
    }

    // Fill names for BBCode-only entries from full page HTML if possible
    for (const entry of ordered) {
      if (entry.name && !entry.name.startsWith("Item ")) continue;
      const re = new RegExp(
        'href="/item=' + entry.id + '/([^"#?]+)"[^>]*>([^<]*)<',
        "i"
      );
      const mm = html.match(re);
      if (mm) {
        entry.name = (mm[2] || "").trim() || mm[1].replace(/-/g, " ");
      } else {
        const re2 = new RegExp("href=\"/item=" + entry.id + "/([^\"#?]+)\"", "i");
        const mm2 = html.match(re2);
        if (mm2) entry.name = mm2[1].replace(/-/g, " ");
      }
    }

    return ordered;
  }

  const out = {};
  const errors = {};
  for (const [stem, cls, spec] of specs) {
    const url = `https://www.wowhead.com/guide/classes/${cls}/${spec}/bis-gear`;
    try {
      const r = await fetch(url, { credentials: "include" });
      if (!r.ok) throw new Error("HTTP " + r.status);
      const html = await r.text();
      const items = parseOverall(html);
      out[stem] = { count: items.length, items, url };
    } catch (e) {
      errors[stem] = String(e && e.message ? e.message : e);
      out[stem] = { count: 0, items: [], url, error: errors[stem] };
    }
    await sleep(300);
  }
  return JSON.stringify({
    out,
    errors,
    ok: Object.values(out).filter((x) => x.count > 0).length,
  });
})()
