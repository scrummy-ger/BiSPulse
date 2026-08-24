#!/usr/bin/env python3
"""
Generate BiSPulse Data/*.lua for all Retail specs.

Source: Wowhead BiS guides only (Overall BiS / Best-in-Slot lists).
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "Data"
OUT_JSON = ROOT / "tools" / "scraped_bis.json"

UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
)

SPECS = [
    ("DEATHKNIGHT", 1, "blood-death-knight", "death-knight", "blood", "Death Knight", "Blood"),
    ("DEATHKNIGHT", 2, "frost-death-knight", "death-knight", "frost", "Death Knight", "Frost"),
    ("DEATHKNIGHT", 3, "unholy-death-knight", "death-knight", "unholy", "Death Knight", "Unholy"),
    ("DEMONHUNTER", 1, "havoc-demon-hunter", "demon-hunter", "havoc", "Demon Hunter", "Havoc"),
    ("DEMONHUNTER", 2, "vengeance-demon-hunter", "demon-hunter", "vengeance", "Demon Hunter", "Vengeance"),
    ("DEMONHUNTER", 3, "devourer-demon-hunter", "demon-hunter", "devourer", "Demon Hunter", "Devourer"),
    ("DRUID", 1, "balance-druid", "druid", "balance", "Druid", "Balance"),
    ("DRUID", 2, "feral-druid", "druid", "feral", "Druid", "Feral"),
    ("DRUID", 3, "guardian-druid", "druid", "guardian", "Druid", "Guardian"),
    ("DRUID", 4, "restoration-druid", "druid", "restoration", "Druid", "Restoration"),
    ("EVOKER", 1, "devastation-evoker", "evoker", "devastation", "Evoker", "Devastation"),
    ("EVOKER", 2, "preservation-evoker", "evoker", "preservation", "Evoker", "Preservation"),
    ("EVOKER", 3, "augmentation-evoker", "evoker", "augmentation", "Evoker", "Augmentation"),
    ("HUNTER", 1, "beast-mastery-hunter", "hunter", "beast-mastery", "Hunter", "Beast Mastery"),
    ("HUNTER", 2, "marksmanship-hunter", "hunter", "marksmanship", "Hunter", "Marksmanship"),
    ("HUNTER", 3, "survival-hunter", "hunter", "survival", "Hunter", "Survival"),
    ("MAGE", 1, "arcane-mage", "mage", "arcane", "Mage", "Arcane"),
    ("MAGE", 2, "fire-mage", "mage", "fire", "Mage", "Fire"),
    ("MAGE", 3, "frost-mage", "mage", "frost", "Mage", "Frost"),
    ("MONK", 1, "brewmaster-monk", "monk", "brewmaster", "Monk", "Brewmaster"),
    ("MONK", 2, "mistweaver-monk", "monk", "mistweaver", "Monk", "Mistweaver"),
    ("MONK", 3, "windwalker-monk", "monk", "windwalker", "Monk", "Windwalker"),
    ("PALADIN", 1, "holy-paladin", "paladin", "holy", "Paladin", "Holy"),
    ("PALADIN", 2, "protection-paladin", "paladin", "protection", "Paladin", "Protection"),
    ("PALADIN", 3, "retribution-paladin", "paladin", "retribution", "Paladin", "Retribution"),
    ("PRIEST", 1, "discipline-priest", "priest", "discipline", "Priest", "Discipline"),
    ("PRIEST", 2, "holy-priest", "priest", "holy", "Priest", "Holy"),
    ("PRIEST", 3, "shadow-priest", "priest", "shadow", "Priest", "Shadow"),
    ("ROGUE", 1, "assassination-rogue", "rogue", "assassination", "Rogue", "Assassination"),
    ("ROGUE", 2, "outlaw-rogue", "rogue", "outlaw", "Rogue", "Outlaw"),
    ("ROGUE", 3, "subtlety-rogue", "rogue", "subtlety", "Rogue", "Subtlety"),
    ("SHAMAN", 1, "elemental-shaman", "shaman", "elemental", "Shaman", "Elemental"),
    ("SHAMAN", 2, "enhancement-shaman", "shaman", "enhancement", "Shaman", "Enhancement"),
    ("SHAMAN", 3, "restoration-shaman", "shaman", "restoration", "Shaman", "Restoration"),
    ("WARLOCK", 1, "affliction-warlock", "warlock", "affliction", "Warlock", "Affliction"),
    ("WARLOCK", 2, "demonology-warlock", "warlock", "demonology", "Warlock", "Demonology"),
    ("WARLOCK", 3, "destruction-warlock", "warlock", "destruction", "Warlock", "Destruction"),
    ("WARRIOR", 1, "arms-warrior", "warrior", "arms", "Warrior", "Arms"),
    ("WARRIOR", 2, "fury-warrior", "warrior", "fury", "Warrior", "Fury"),
    ("WARRIOR", 3, "protection-warrior", "warrior", "protection", "Warrior", "Protection"),
]

ITEM_HREF_RE = re.compile(
    r'href="(?:https?:)?//(?:www\.)?wowhead\.com/(?:ptr(?:-\d+)?/)?item=(\d+)/([^"?#]+)"[^>]*>([^<]*)<',
    re.I,
)
ITEM_HREF_RE2 = re.compile(
    r'href="(?:https?:)?//(?:www\.)?wowhead\.com/(?:ptr(?:-\d+)?/)?item=(\d+)/([^"?#]+)',
    re.I,
)
ITEM_BB_RE = re.compile(r"\[item=(\d+)(?:[^\]]*)\]", re.I)
ITEM_ANY_RE = re.compile(r"item=(\d+)", re.I)

EMBELLISHMENT_IDS = {
    240167,  # Arcanoweave Lining
    273060,  # Hunter's Ritual Stone
    245790,  # Thalassian Missive of the Peerless
}

STEMS = {
    ("DEATHKNIGHT", 1): "BloodDeathKnight",
    ("DEATHKNIGHT", 2): "FrostDeathKnight",
    ("DEATHKNIGHT", 3): "UnholyDeathKnight",
    ("DEMONHUNTER", 1): "HavocDemonHunter",
    ("DEMONHUNTER", 2): "VengeanceDemonHunter",
    ("DEMONHUNTER", 3): "DevourerDemonHunter",
    ("DRUID", 1): "BalanceDruid",
    ("DRUID", 2): "FeralDruid",
    ("DRUID", 3): "GuardianDruid",
    ("DRUID", 4): "RestorationDruid",
    ("EVOKER", 1): "DevastationEvoker",
    ("EVOKER", 2): "PreservationEvoker",
    ("EVOKER", 3): "AugmentationEvoker",
    ("HUNTER", 1): "BeastMasteryHunter",
    ("HUNTER", 2): "MarksmanshipHunter",
    ("HUNTER", 3): "SurvivalHunter",
    ("MAGE", 1): "ArcaneMage",
    ("MAGE", 2): "FireMage",
    ("MAGE", 3): "FrostMage",
    ("MONK", 1): "BrewmasterMonk",
    ("MONK", 2): "MistweaverMonk",
    ("MONK", 3): "WindwalkerMonk",
    ("PALADIN", 1): "HolyPaladin",
    ("PALADIN", 2): "ProtectionPaladin",
    ("PALADIN", 3): "RetributionPaladin",
    ("PRIEST", 1): "DisciplinePriest",
    ("PRIEST", 2): "HolyPriest",
    ("PRIEST", 3): "ShadowPriest",
    ("ROGUE", 1): "AssassinationRogue",
    ("ROGUE", 2): "OutlawRogue",
    ("ROGUE", 3): "SubtletyRogue",
    ("SHAMAN", 1): "ElementalShaman",
    ("SHAMAN", 2): "EnhancementShaman",
    ("SHAMAN", 3): "RestorationShaman",
    ("WARLOCK", 1): "AfflictionWarlock",
    ("WARLOCK", 2): "DemonologyWarlock",
    ("WARLOCK", 3): "DestructionWarlock",
    ("WARRIOR", 1): "ArmsWarrior",
    ("WARRIOR", 2): "FuryWarrior",
    ("WARRIOR", 3): "ProtectionWarrior",
}


COOKIE_JAR = Path(tempfile.gettempdir()) / "bispulse_wowhead_cookies.txt"


def curl_bin() -> str:
    return "curl.exe" if os.name == "nt" else "curl"


def fetch(url: str) -> str:
    """Fetch URL. Wowhead is CloudFront-protected — prefer curl with cookie jar."""
    if "wowhead.com" in url:
        return fetch_wowhead(url)
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "text/html"})
    with urllib.request.urlopen(req, timeout=45) as resp:
        return resp.read().decode("utf-8", errors="replace")


def fetch_wowhead(url: str) -> str:
    COOKIE_JAR.parent.mkdir(parents=True, exist_ok=True)
    out = Path(tempfile.gettempdir()) / "bispulse_wowhead_page.html"
    curl = curl_bin()
    cmd = [
        curl,
        "-sL",
        "--max-time",
        "45",
        "-A",
        UA,
        "-H",
        "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "-H",
        "Accept-Language: en-US,en;q=0.9",
        "-H",
        "Referer: https://www.wowhead.com/",
        "-c",
        str(COOKIE_JAR),
        "-b",
        str(COOKIE_JAR),
        "-o",
        str(out),
        url,
    ]
    subprocess.run(cmd, check=False, capture_output=True)
    html = out.read_text(encoding="utf-8", errors="replace")
    if len(html) < 5000 or "403 ERROR" in html or "Request blocked" in html:
        # Warm up homepage once, retry
        warm = Path(tempfile.gettempdir()) / "bispulse_wowhead_warm.html"
        subprocess.run(
            [
                curl, "-sL", "--max-time", "30", "-A", UA,
                "-c", str(COOKIE_JAR), "-b", str(COOKIE_JAR),
                "-o", str(warm), "https://www.wowhead.com/",
            ],
            check=False,
            capture_output=True,
        )
        time.sleep(0.8)
        subprocess.run(cmd, check=False, capture_output=True)
        html = out.read_text(encoding="utf-8", errors="replace")
    if len(html) < 5000 or "403 ERROR" in html or "Request blocked" in html:
        raise RuntimeError("Wowhead blocked request (CloudFront 403)")
    return html


def slug_to_name(slug: str) -> str:
    parts = [p for p in slug.replace("_", "-").split("-") if p]
    name = " ".join(p[:1].upper() + p[1:] for p in parts)
    reps = [
        (" Ulatek", " Ula'tek"),
        ("Ulatek", "Ula'tek"),
        (" Zuljins ", " Zul'jin's "),
        ("Zuljins ", "Zul'jin's "),
        (" Amanmuso", " Aman'muso"),
        ("Amanmuso", "Aman'muso"),
        (" Doomhounds ", " Doomhound's "),
        (" Agents ", " Agent's "),
        (" Alchemists ", " Alchemist's "),
        (" Warlords ", " Warlord's "),
        (" Spellbreakers ", " Spellbreaker's "),
        ("Spellbreakers ", "Spellbreaker's "),
        (" Sandshined ", " Sand-Shined "),
        ("Sandshined ", "Sand-Shined "),
        (" Sand Shined ", " Sand-Shined "),
    ]
    for a, b in reps:
        name = name.replace(a, b)
    return name


def _rank_score(rank: str) -> int:
    return {"bis": 4, "strong": 3, "alt": 2, "ok": 1}.get(rank, 0)


def build_name_map(html: str) -> dict[int, str]:
    names: dict[int, str] = {}
    for m in ITEM_HREF_RE.finditer(html):
        iid = int(m.group(1))
        text = (m.group(3) or "").strip()
        if text and iid not in names:
            names[iid] = text
    for m in ITEM_HREF_RE2.finditer(html):
        iid = int(m.group(1))
        if iid not in names:
            names[iid] = slug_to_name(m.group(2))
    return names


def _extract_section_items(html: str, start_pat: str, end_pats: list[str]) -> list[tuple[int, str]]:
    start = re.search(start_pat, html, re.I)
    if not start:
        return []
    end_pos = len(html)
    for ep in end_pats:
        m = re.search(ep, html[start.end() : start.end() + 40000], re.I)
        if m:
            end_pos = min(end_pos, start.end() + m.start())
    chunk = html[start.start() : end_pos]
    names = build_name_map(chunk)
    out: list[tuple[int, str]] = []
    seen: set[int] = set()
    # Prefer ordered BBCode / item= occurrences
    for m in ITEM_ANY_RE.finditer(chunk):
        iid = int(m.group(1))
        if iid in seen:
            continue
        seen.add(iid)
        out.append((iid, names.get(iid) or f"Item {iid}"))
    return out


def parse_wowhead_bis(html: str) -> dict[int, dict]:
    """Primary Wowhead Overall BiS (+ raid/m+ when headings exist)."""
    items: dict[int, dict] = {}
    names = build_name_map(html)

    def upsert(iid: int, section: str, rank: str, name: str | None = None):
        if iid in EMBELLISHMENT_IDS:
            section, rank = "alt", "alt"
            note = "Embellishment / craft reagent"
            slot = "Embellishment"
        else:
            note = None
            slot = ""
        display = name or names.get(iid) or f"Item {iid}"
        prev = items.get(iid)
        if not prev or _rank_score(rank) > _rank_score(prev["rank"]):
            items[iid] = {
                "name": display,
                "wowhead": section,
                "method": None,
                "rank": rank,
                "source": "Wowhead",
                "note": note,
                "slot": slot,
            }
        else:
            if not prev.get("wowhead"):
                prev["wowhead"] = section

    # Overall BiS (BBCode guide body)
    for iid, name in _extract_section_items(
        html,
        r"Overall BiS",
        [
            r'h2 toc=\\?"Raid Drops\\?"',
            r"Crafted Gear",
            r"Best .* Trinkets",
            r"Trinket Tier List",
            r"Raid BiS",
            r"Mythic\+ BiS",
        ],
    ):
        upsert(iid, "overall", "bis", name)

    # HTML rendered overall table fallback / supplement
    m = re.search(r"<td>(?:Weapon|Head|Neck)</td>\s*<td><a href=\"/item=", html)
    if m:
        chunk = html[m.start() : m.start() + 9000]
        for mm in re.finditer(
            r"<td>([^<]+)</td>\s*<td><a href=\"/item=(\d+)/[^\"]+\"[^>]*>([^<]*)</a>",
            chunk,
        ):
            slot, iid_s, text = mm.group(1), mm.group(2), mm.group(3).strip()
            if slot.lower() in {"weapon", "offhand", "head", "neck", "shoulder", "shoulders",
                                 "cloak", "chest", "wrist", "gloves", "belt", "legs", "boots",
                                 "ring", "trinket"}:
                upsert(int(iid_s), "overall", "bis", text or None)

    # Optional secondary wowhead lists
    for iid, name in _extract_section_items(
        html,
        r"Raid BiS|Raid Best",
        [r"Mythic\+ BiS", r"Crafted Gear", r"Trinket"],
    ):
        if iid not in items or items[iid]["rank"] != "bis":
            upsert(iid, "raid", "strong", name)

    for iid, name in _extract_section_items(
        html,
        r"Mythic\+ BiS|M\+ BiS|Mythic Plus BiS",
        [r"Crafted Gear", r"Trinket Tier", r"Embellish"],
    ):
        if iid not in items or items[iid]["rank"] != "bis":
            upsert(iid, "mythic", "strong", name)

    return items


def lua_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def load_existing_lua_meta(stem: str) -> dict[int, dict]:
    """Keep better names/drops from the previous Data/*.lua when a scrape is weaker."""
    path = DATA_DIR / f"{stem}.lua"
    if not path.is_file():
        return {}
    text = path.read_text(encoding="utf-8")
    out: dict[int, dict] = {}
    for m in re.finditer(
        r"\[(\d+)\] = entry\(\{([\s\S]*?)\}\),",
        text,
    ):
        iid = int(m.group(1))
        body = m.group(2)
        name_m = re.search(r'name = "((?:\\.|[^"\\])*)"', body)
        drop_m = re.search(r'drop = "((?:\\.|[^"\\])*)"', body)
        slot_m = re.search(r'slot = "((?:\\.|[^"\\])*)"', body)
        name = name_m.group(1).replace('\\"', '"') if name_m else ""
        drop = drop_m.group(1).replace('\\"', '"') if drop_m else ""
        slot = slot_m.group(1).replace('\\"', '"') if slot_m else ""
        out[iid] = {"name": name, "drop": drop, "slot": slot}
    return out


def merge_preserve_quality(new_items: dict[int, dict], stem: str) -> dict[int, dict]:
    prev = load_existing_lua_meta(stem)
    for iid, info in new_items.items():
        old = prev.get(iid) or {}
        name = info.get("name") or ""
        if (not name or re.match(r"^Item \d+$", name)) and old.get("name") and not re.match(
            r"^Item \d+$", old["name"]
        ):
            info["name"] = old["name"]
        if not (info.get("drop") or "").strip() and (old.get("drop") or "").strip():
            info["drop"] = old["drop"]
        if not (info.get("slot") or "").strip() and (old.get("slot") or "").strip():
            info["slot"] = old["slot"]
    return new_items


def write_lua(spec_meta, items: dict[int, dict], wowhead_url: str, updated: str | None = None) -> Path:
    class_file, spec_index, _, _, _, class_name, spec_name = spec_meta
    stem = STEMS[(class_file, spec_index)]
    path = DATA_DIR / f"{stem}.lua"

    lines = [
        f"--[[",
        f"  {spec_name} {class_name} BiS — Midnight Patch 12.1",
        f"  Source: Wowhead only",
        f"  Wowhead: {wowhead_url}",
        f"]]",
        "",
        "local RANK = BiSPulseData.RANK",
        "",
        "local function entry(opts)",
        "  return {",
        "    name = opts.name,",
        "    slot = opts.slot,",
        "    drop = opts.drop,",
        "    source = opts.source,",
        "    wowhead = opts.wowhead,",
        "    rank = opts.rank,",
        "    note = opts.note,",
        "    priority = opts.priority,",
        "  }",
        "end",
        "",
        "local items = {",
    ]

    for item_id in sorted(items.keys()):
        info = items[item_id]
        wowhead = info.get("wowhead")
        rank = info.get("rank", "alt")
        rank_const = {
            "bis": "RANK.BIS",
            "strong": "RANK.STRONG",
            "alt": "RANK.ALT",
            "ok": "RANK.OK",
        }.get(rank, "RANK.ALT")
        wowhead_lua = "nil" if not wowhead else f'"{wowhead}"'
        priority = "true" if info.get("priority") else "nil"
        note = info.get("note") or None
        note_lua = "nil" if not note else f'"{lua_escape(note)}"'
        drop = info.get("drop") or ""
        lines.append(f"  [{item_id}] = entry({{")
        lines.append(f'    name = "{lua_escape(info.get("name", "Item"))}",')
        lines.append(f'    slot = "{lua_escape(info.get("slot", ""))}",')
        lines.append(f'    drop = "{lua_escape(drop)}",')
        lines.append(f'    source = "{lua_escape(info.get("source", "Wowhead"))}",')
        lines.append(f"    wowhead = {wowhead_lua},")
        lines.append(f"    rank = {rank_const},")
        lines.append(f"    note = {note_lua},")
        lines.append(f"    priority = {priority},")
        lines.append("  }),")

    lines.extend(
        [
            "}",
            "",
            f'BiSPulseData:Register("{class_file}", {spec_index}, {{',
            f'  className = "{class_name}",',
            f'  specName = "{spec_name}",',
            f'  patch = "12.1",',
            f'  season = "Midnight Season 2",',
            f'  updated = "{updated or date.today().isoformat()}",',
            f'  primarySource = "Wowhead",',
            "  guides = {",
            f'    wowhead = "{wowhead_url}",',
            "  },",
            "  items = items,",
            "})",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def update_toc(stems: list[str]) -> None:
    toc = ROOT / "BiSPulse.toc"
    text = toc.read_text(encoding="utf-8")
    header_end = text.split("Data/Registry.lua")[0] + "Data/Registry.lua\n"
    data_lines = "\n".join(f"Data/{s}.lua" for s in stems)
    footer = """
Core.lua
Tooltip.lua
Toast.lua
Alerts.lua
LootBadges.lua
Minimap.lua
Options.lua
"""
    header_end = re.sub(
        r"## Notes: .*",
        "## Notes: Wowhead BiS rankings for all Retail specs.",
        header_end,
    )
    header_end = re.sub(
        r"## Notes-deDE: .*",
        "## Notes-deDE: BiS-Rankings von Wowhead — alle Retail-Specs.",
        header_end,
    )
    toc.write_text(header_end + data_lines + footer, encoding="utf-8")


def load_wowhead_browser_json(path: Path) -> dict[str, dict[int, dict]]:
    """Convert tools/wowhead_browser_data.json → stem → {itemId: entry}."""
    raw = json.loads(path.read_text(encoding="utf-8"))
    payload = raw.get("out", raw)
    by_stem: dict[str, dict[int, dict]] = {}
    for stem, pack in payload.items():
        items: dict[int, dict] = {}
        for row in pack.get("items") or []:
            iid = int(row["id"])
            if iid in EMBELLISHMENT_IDS:
                continue
            items[iid] = {
                "name": row.get("name") or f"Item {iid}",
                "wowhead": row.get("wowhead") or "overall",
                "method": None,
                "rank": row.get("rank") or "bis",
                "source": "Wowhead",
                "note": None,
                "slot": row.get("slot") or "",
                "drop": row.get("drop") or "",
            }
        by_stem[stem] = items
    return by_stem


def finalize_wowhead_items(wh_items: dict[int, dict]) -> dict[int, dict]:
    """Normalize Wowhead-only pack (priority flags)."""
    out: dict[int, dict] = {}
    for iid, info in wh_items.items():
        entry = dict(info)
        entry["method"] = None
        entry["source"] = "Wowhead"
        if entry.get("rank") == "bis" and entry.get("slot") != "Embellishment":
            entry["priority"] = True
        else:
            entry["priority"] = False
        out[iid] = entry
    return out


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="Generate BiSPulse Data/*.lua from Wowhead")
    parser.add_argument(
        "--wowhead-json",
        type=Path,
        default=ROOT / "tools" / "wowhead_browser_data.json",
        help="Pre-scraped Wowhead JSON (browser CDP). Missing → live fetch (may 403).",
    )
    args = parser.parse_args()

    DATA_DIR.mkdir(exist_ok=True)
    (ROOT / "tools").mkdir(exist_ok=True)
    scraped: dict = {}
    stems_order: list[str] = []

    wh_by_stem: dict[str, dict[int, dict]] = {}
    if args.wowhead_json.is_file():
        wh_by_stem = load_wowhead_browser_json(args.wowhead_json)
        print(f"Loaded Wowhead JSON: {args.wowhead_json} ({len(wh_by_stem)} specs)")
    else:
        print("No Wowhead JSON — will attempt live Wowhead fetch (may 403).")

    for spec in SPECS:
        class_file, spec_index, _method_slug, wh_class, wh_spec, class_name, spec_name = spec
        wowhead_url = f"https://www.wowhead.com/guide/classes/{wh_class}/{wh_spec}/bis-gear"
        stem = STEMS[(class_file, spec_index)]
        print(f"Building {spec_name} {class_name} ...")

        wh_items: dict[int, dict] = {}

        if stem in wh_by_stem and wh_by_stem[stem]:
            wh_items = wh_by_stem[stem]
            print(f"  Wowhead items: {len(wh_items)} (json)")
        else:
            try:
                wh_html = fetch(wowhead_url)
                wh_items = parse_wowhead_bis(wh_html)
                print(f"  Wowhead items: {len(wh_items)}")
            except Exception as e:
                print(f"  Wowhead FAIL: {e}")

        stems_order.append(stem)
        if not wh_items:
            print("  KEEP existing (empty scrape)")
            continue

        items = finalize_wowhead_items(wh_items)
        items = merge_preserve_quality(items, stem)
        path = write_lua(spec, items, wowhead_url)
        scraped[stem] = {
            "count": len(items),
            "wowhead_overall": sum(1 for v in items.values() if v.get("wowhead") == "overall"),
            "sources": ["Wowhead"],
            "file": path.name,
        }

    update_toc(stems_order)
    OUT_JSON.write_text(json.dumps(scraped, indent=2), encoding="utf-8")
    print(f"\nWrote {len(stems_order)} spec files. TOC updated.")


if __name__ == "__main__":
    main()
