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

# Ignore pre-Midnight parse noise from Archon (old raids/dungeons).
MIN_ITEM_ID = 220000


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


MIN_GUIDE_OFFSET = 80000


def _extract_section_items(html: str, start_pat: str, end_pats: list[str]) -> list[tuple[int, str]]:
    start = None
    for pat in [start_pat] if isinstance(start_pat, str) else start_pat:
        m = re.search(pat, html[MIN_GUIDE_OFFSET:], re.I)
        if m:
            start = MIN_GUIDE_OFFSET + m.start()
            break
    if start is None:
        # Fallback: last occurrence in full page (skip early TOC).
        for pat in [start_pat] if isinstance(start_pat, str) else start_pat:
            last = None
            for m in re.finditer(pat, html, re.I):
                last = m.start()
            if last is not None and last >= MIN_GUIDE_OFFSET // 2:
                start = last
                break
    if start is None:
        return []
    end_pos = len(html)
    for ep in end_pats:
        m = re.search(ep, html[start + 20 : start + 20 + 40000], re.I)
        if m:
            end_pos = min(end_pos, start + 20 + m.start())
    chunk = html[start:end_pos]
    names = build_name_map(chunk)
    out: list[tuple[int, str]] = []
    seen: set[int] = set()
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
        [r"Best Gear from Raids", r"Best Raid Items", r"Raid BiS", r"Raid Drops"],
        [
            r"Best Gear from Mythic",
            r"Best .* Trinkets",
            r"Trinket Tier List",
            r"Crafted Gear",
            r"Set Bonuses",
        ],
    ):
        if iid not in items or items[iid]["rank"] != "bis":
            upsert(iid, "raid", "strong", name)

    for iid, name in _extract_section_items(
        html,
        [
            r"Best Gear from Mythic",
            r"Mythic\+ BiS",
            r"M\+ BiS",
            r"Mythic Plus BiS",
            r"Mythic\+ Drops",
        ],
        [
            r"Best .* Trinkets",
            r"Trinket Tier List",
            r"Crafted Gear",
            r"Embellish",
        ],
    ):
        if iid not in items or items[iid]["rank"] != "bis":
            upsert(iid, "mythic", "strong", name)

    # Trinket tier widget + headings (S/A/B/C)
    tier_chunk_m = re.search(
        r"Trinket Tier List|Best .{0,40}Trinkets", html[MIN_GUIDE_OFFSET:], re.I
    )
    if tier_chunk_m:
        chunk = html[MIN_GUIDE_OFFSET + tier_chunk_m.start() : MIN_GUIDE_OFFSET + tier_chunk_m.start() + 45000]
        end = re.search(
            r"Embellish|Crafted Gear|Stat Priority|Consumable|Talent|Rotation|Set Bonuses",
            chunk[40:],
            re.I,
        )
        if end:
            chunk = chunk[: 40 + end.start()]
        for block in re.split(r'<div class="tier-list-tier">', chunk, flags=re.I)[1:]:
            label_m = re.search(
                r'class="tier-label[^"]*"[^>]*>\s*([SABCD])\+?\s*</div>', block, re.I
            )
            if not label_m:
                continue
            letter = label_m.group(1).upper()
            rank = {"S": "bis", "A": "strong", "B": "alt", "C": "ok", "D": "ok"}.get(
                letter, "alt"
            )
            content_m = re.search(r'class="tier-content"[^>]*>([\s\S]*)', block, re.I)
            slice_ = content_m.group(1) if content_m else block
            end_m = re.search(r'<div class="tier-list-tier">|<h[234]\b', slice_, re.I)
            if end_m:
                slice_ = slice_[: end_m.start()]
            for m in ITEM_ANY_RE.finditer(slice_[:12000]):
                iid = int(m.group(1))
                note = f"{letter} Tier"
                prev = items.get(iid)
                if not prev or _rank_score(rank) > _rank_score(prev["rank"]):
                    upsert(iid, "trinket", rank, names.get(iid))
                    if iid in items:
                        items[iid]["note"] = note
                        items[iid]["slot"] = items[iid].get("slot") or "Trinket"

    # Trinket tier headings (legacy BBCode)
    tier_chunk_m = re.search(
        r"Trinket Tier List|Best .{0,40}Trinkets", html, re.I
    )
    if tier_chunk_m:
        chunk = html[tier_chunk_m.start() : tier_chunk_m.start() + 45000]
        end = re.search(
            r"Embellish|Crafted Gear|Stat Priority|Consumable|Talent|Rotation",
            chunk[40:],
            re.I,
        )
        if end:
            chunk = chunk[: 40 + end.start()]
        for hm in re.finditer(
            r"(?:^|\n|>|\])\s*(?:\[b\])?\s*([SABCD])\+?\s*[-–—]?\s*Tier",
            chunk,
            re.I,
        ):
            letter = hm.group(1).upper()
            rank = {"S": "bis", "A": "strong", "B": "alt", "C": "ok", "D": "ok"}.get(
                letter, "alt"
            )
            # slice until next tier heading
            rest = chunk[hm.end() :]
            nxt = re.search(
                r"(?:^|\n|>|\])\s*(?:\[b\])?\s*[SABCD]\+?\s*[-–—]?\s*Tier",
                rest,
                re.I,
            )
            slice_ = rest[: nxt.start()] if nxt else rest[:8000]
            for iid, name in [
                (int(m.group(1)), names.get(int(m.group(1))) or f"Item {m.group(1)}")
                for m in ITEM_ANY_RE.finditer(slice_)
            ]:
                note = f"{letter} Tier"
                prev = items.get(iid)
                if not prev or _rank_score(rank) > _rank_score(prev["rank"]):
                    upsert(iid, "trinket", rank, name)
                    if iid in items:
                        items[iid]["note"] = note
                        items[iid]["slot"] = items[iid].get("slot") or "Trinket"

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
        rank_m = re.search(r"rank = RANK\.(\w+)", body)
        rank_map = {"BIS": "bis", "STRONG": "strong", "ALT": "alt", "OK": "ok"}
        rank = rank_map.get(rank_m.group(1), "") if rank_m else ""
        out[iid] = {"name": name, "drop": drop, "slot": slot, "rank": rank}
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
        # Keep a stronger prior rank only if scrape omitted rank (shouldn't happen).
        if not info.get("rank") and old.get("rank"):
            info["rank"] = old["rank"]
    return new_items


def build_global_drop_map(wh_by_stem: dict[str, dict[int, dict]]) -> dict[int, str]:
    """Cross-spec drop text from Wowhead packs (longer string wins)."""
    drops: dict[int, str] = {}
    for items in wh_by_stem.values():
        for iid, info in items.items():
            d = (info.get("drop") or "").strip()
            if d and (iid not in drops or len(d) > len(drops[iid])):
                drops[iid] = d
    for path in DATA_DIR.glob("*.lua"):
        if path.name == "Registry.lua":
            continue
        for iid, meta in load_existing_lua_meta(path.stem).items():
            d = (meta.get("drop") or "").strip()
            if d and (iid not in drops or len(d) > len(drops[iid])):
                drops[iid] = d
    return drops


def apply_drop_map(items: dict[int, dict], drop_map: dict[int, str]) -> None:
    for iid, info in items.items():
        if not (info.get("drop") or "").strip() and iid in drop_map:
            info["drop"] = drop_map[iid]

def write_lua(
    spec_meta,
    items: dict[int, dict],
    wowhead_url: str,
    updated: str | None = None,
    archon_urls: dict[str, str] | None = None,
) -> Path:
    class_file, spec_index, _, _, _, class_name, spec_name = spec_meta
    stem = STEMS[(class_file, spec_index)]
    path = DATA_DIR / f"{stem}.lua"

    sources = sorted(
        {
            (info.get("source") or "Wowhead")
            for info in items.values()
            if info.get("source")
        }
    )
    if any("Archon" in s for s in sources) and any("Wowhead" in s for s in sources):
        primary = "Wowhead + Archon"
        source_line = "  Source: Wowhead BiS + Archon popularity"
    elif any("Archon" in s for s in sources):
        primary = "Archon"
        source_line = "  Source: Archon.gg popularity"
    else:
        primary = "Wowhead"
        source_line = "  Source: Wowhead only"

    lines = [
        f"--[[",
        f"  {spec_name} {class_name} BiS — Midnight Patch 12.1",
        source_line,
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
        "    popularity = opts.popularity,",
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
        pop = info.get("popularity")
        if isinstance(pop, (int, float)):
            pop_lua = f"{float(pop):.1f}"
        else:
            pop_lua = "nil"
        lines.append(f"  [{item_id}] = entry({{")
        lines.append(f'    name = "{lua_escape(info.get("name", "Item"))}",')
        lines.append(f'    slot = "{lua_escape(info.get("slot", ""))}",')
        lines.append(f'    drop = "{lua_escape(drop)}",')
        lines.append(f'    source = "{lua_escape(info.get("source", "Wowhead"))}",')
        lines.append(f"    wowhead = {wowhead_lua},")
        lines.append(f"    rank = {rank_const},")
        lines.append(f"    note = {note_lua},")
        lines.append(f"    popularity = {pop_lua},")
        lines.append(f"    priority = {priority},")
        lines.append("  }),")

    guide_lines = [
        "  guides = {",
        f'    wowhead = "{wowhead_url}",',
    ]
    if archon_urls:
        if archon_urls.get("raid"):
            guide_lines.append(f'    archonRaid = "{archon_urls["raid"]}",')
        if archon_urls.get("mythic"):
            guide_lines.append(f'    archonMythic = "{archon_urls["mythic"]}",')
    guide_lines.append("  },")

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
            f'  primarySource = "{primary}",',
            *guide_lines,
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
        "## Notes: Wowhead + Archon BiS rankings for all Retail specs.",
        header_end,
    )
    header_end = re.sub(
        r"## Notes-deDE: .*",
        "## Notes-deDE: BiS-Rankings von Wowhead + Archon — alle Retail-Specs.",
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
                "note": row.get("note") or None,
                "slot": row.get("slot") or "",
                "drop": row.get("drop") or "",
            }
        by_stem[stem] = items
    # Drop empty packs so callers keep existing Lua files.
    return {stem: items for stem, items in by_stem.items() if items}


def load_archon_browser_json(path: Path) -> dict[str, dict]:
    """Convert tools/archon_browser_data.json → stem → {items, urls}."""
    if not path.is_file():
        return {}
    raw = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(raw, dict) and raw.get("ok") == 0:
        print("Archon JSON ok=0 — skipping (keep Wowhead-only).")
        return {}
    payload = raw.get("out", raw)
    by_stem: dict[str, dict] = {}
    for stem, pack in payload.items():
        items: dict[int, dict] = {}
        for row in pack.get("items") or []:
            iid = int(row["id"])
            if iid in EMBELLISHMENT_IDS or iid < MIN_ITEM_ID:
                continue
            pop = row.get("popularity")
            note = f"Archon {pop:.1f}%" if isinstance(pop, (int, float)) else None
            items[iid] = {
                "name": row.get("name") or f"Item {iid}",
                "wowhead": row.get("wowhead") or row.get("content") or "raid",
                "method": None,
                "rank": row.get("rank") or "alt",
                "source": "Archon",
                "note": note,
                "slot": row.get("slot") or "",
                "drop": row.get("drop") or "",
                "popularity": pop,
            }
        if not items:
            continue
        by_stem[stem] = {
            "items": items,
            "urls": {
                "raid": (pack.get("raid") or {}).get("url"),
                "mythic": (pack.get("mythic") or {}).get("url"),
            },
        }
    return by_stem


def merge_archon_into_wowhead(
    wh_items: dict[int, dict], archon_items: dict[int, dict]
) -> dict[int, dict]:
    """Keep Wowhead ranks; add Archon alternatives; mark consensus."""
    out = {iid: dict(info) for iid, info in wh_items.items()}
    for iid, a in archon_items.items():
        if iid in out:
            prev = out[iid]
            src = prev.get("source") or "Wowhead"
            if "Archon" not in src:
                prev["source"] = "Wowhead + Archon"
            if not (prev.get("slot") or "").strip() and (a.get("slot") or "").strip():
                prev["slot"] = a["slot"]
            # Never downgrade Wowhead rank; optionally bump strong←alt if Archon is hot
            if _rank_score(a.get("rank") or "") > _rank_score(prev.get("rank") or ""):
                # Only bump non-bis Wowhead entries when Archon is clearly popular
                if prev.get("rank") != "bis" and (a.get("popularity") or 0) >= 20:
                    prev["rank"] = a["rank"]
            if a.get("note") and not prev.get("note"):
                prev["note"] = a["note"]
        else:
            entry = dict(a)
            entry["source"] = "Archon"
            out[iid] = entry
    return out


def finalize_wowhead_items(wh_items: dict[int, dict]) -> dict[int, dict]:
    """Normalize pack (priority flags). Preserve scrape ranks."""
    out: dict[int, dict] = {}
    for iid, info in wh_items.items():
        entry = dict(info)
        entry["method"] = None
        if not entry.get("source"):
            entry["source"] = "Wowhead"
        rank = (entry.get("rank") or "bis").lower()
        if rank not in {"bis", "strong", "alt", "ok"}:
            rank = "bis"
        entry["rank"] = rank
        if rank == "bis" and entry.get("slot") != "Embellishment":
            entry["priority"] = True
        else:
            entry["priority"] = False
        out[iid] = entry
    return out


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(
        description="Generate BiSPulse Data/*.lua from Wowhead (+ optional Archon)"
    )
    parser.add_argument(
        "--wowhead-json",
        type=Path,
        default=ROOT / "tools" / "wowhead_browser_data.json",
        help="Pre-scraped Wowhead JSON (browser CDP). Missing → live fetch (may 403).",
    )
    parser.add_argument(
        "--archon-json",
        type=Path,
        default=ROOT / "tools" / "archon_browser_data.json",
        help="Pre-scraped Archon popularity JSON (optional).",
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

    archon_by_stem = load_archon_browser_json(args.archon_json)
    if archon_by_stem:
        print(f"Loaded Archon JSON: {args.archon_json} ({len(archon_by_stem)} specs)")
    else:
        print("No Archon JSON — Wowhead-only lists.")

    drop_map = build_global_drop_map(wh_by_stem)
    print(f"Global drop map: {len(drop_map)} item ids")

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
        if not wh_items and stem not in archon_by_stem:
            print("  KEEP existing (empty scrape)")
            continue

        items = finalize_wowhead_items(wh_items) if wh_items else {}
        archon_urls = None
        if stem in archon_by_stem:
            apack = archon_by_stem[stem]
            before = len(items)
            items = merge_archon_into_wowhead(items, apack["items"])
            items = finalize_wowhead_items(items)
            archon_urls = apack.get("urls")
            print(
                f"  Archon merge: +{len(items) - before} new "
                f"(now {len(items)} total)"
            )

        items = merge_preserve_quality(items, stem)
        apply_drop_map(items, drop_map)
        path = write_lua(spec, items, wowhead_url, archon_urls=archon_urls)
        scraped[stem] = {
            "count": len(items),
            "wowhead_overall": sum(
                1 for v in items.values() if v.get("wowhead") == "overall"
            ),
            "archon": sum(1 for v in items.values() if "Archon" in (v.get("source") or "")),
            "sources": sorted(
                {(v.get("source") or "Wowhead") for v in items.values()}
            ),
            "file": path.name,
        }

    update_toc(stems_order)
    OUT_JSON.write_text(json.dumps(scraped, indent=2), encoding="utf-8")
    print(f"\nWrote {len(stems_order)} spec files. TOC updated.")


if __name__ == "__main__":
    main()
