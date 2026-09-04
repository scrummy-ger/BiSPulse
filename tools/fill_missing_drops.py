#!/usr/bin/env python3
"""Fill empty drop= in Data/*.lua from Wowhead JSON + known guide sources + cross-spec Lua."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "Data"
WH_JSON = ROOT / "tools" / "wowhead_browser_data.json"
CACHE = ROOT / "tools" / "drop_guide_cache.json"
ENTRY_RE = re.compile(r"\[(\d+)\] = entry\(\{([\s\S]*?)\}\),")

# Verified Overall BiS Source column (Wowhead BM Hunter guide, 2026-09-04).
GUIDE_DROPS: dict[int, str] = {
    159388: "Temple of Sethraliss",
    244581: "Leatherworking",
    244584: "Leatherworking",
    268207: "Ula'tek",
    268249: "Vashnik the Malignant",
    268253: "The Coiled Altar",
    268265: "Ula'tek",
    270165: "Entombed Sentinels",
    270173: "The Coiled Altar",
    270175: "Ula'tek",
    271490: "The Coiled Altar",
    271491: "The Coiled Altar",
    271492: "The Twin Fangs",
    271493: "King's Rest",
    271495: "Ula'tek",
    # Primal Sentry (S1 hunter tier) — Archon rows often lack drops
    249988: "Lightblinded Vanguard",  # Head
    249986: "Fallen-King Salhadaar",  # Shoulders
    249991: "Chimaerus",  # Chest
    249989: "Vorasius",  # Gloves
    249987: "Vaelgor & Ezzorak",  # Legs
}

# Obvious slot fixes when Archon/scrape mis-tags craft pieces.
SLOT_FIXES: dict[int, str] = {
    244584: "Wrist",  # Farstrider's Plated Bracers
}


def lua_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def load_wowhead_drops() -> dict[int, str]:
    out: dict[int, str] = {}
    if not WH_JSON.is_file():
        return out
    raw = json.loads(WH_JSON.read_text(encoding="utf-8"))
    for pack in (raw.get("out") or {}).values():
        for row in pack.get("items") or []:
            iid = int(row["id"])
            drop = (row.get("drop") or "").strip()
            if drop and (iid not in out or len(drop) > len(out[iid])):
                out[iid] = drop
    return out


def load_lua_drops() -> dict[int, str]:
    out: dict[int, str] = {}
    for path in sorted(DATA.glob("*.lua")):
        if path.name == "Registry.lua":
            continue
        text = path.read_text(encoding="utf-8")
        for m in ENTRY_RE.finditer(text):
            iid = int(m.group(1))
            body = m.group(2)
            dm = re.search(r'drop = "((?:\\.|[^"\\])*)"', body)
            drop = dm.group(1).replace('\\"', '"').strip() if dm else ""
            if drop and (iid not in out or len(drop) > len(out[iid])):
                out[iid] = drop
    return out


def load_cache() -> dict[int, str]:
    if not CACHE.is_file():
        return {}
    raw = json.loads(CACHE.read_text(encoding="utf-8"))
    return {int(k): str(v) for k, v in (raw or {}).items() if v}


def build_map() -> dict[int, str]:
    m: dict[int, str] = {}
    m.update(GUIDE_DROPS)
    m.update(load_wowhead_drops())
    m.update(load_lua_drops())
    m.update(load_cache())
    return m


def apply(drop_map: dict[int, str], dry_run: bool = False) -> tuple[int, int]:
    filled = 0
    slot_fixed = 0
    for path in sorted(DATA.glob("*.lua")):
        if path.name == "Registry.lua":
            continue
        text = path.read_text(encoding="utf-8")

        def repl(m: re.Match) -> str:
            nonlocal filled, slot_fixed
            iid = int(m.group(1))
            body = m.group(2)
            new_body = body

            dm = re.search(r'drop = "((?:\\.|[^"\\])*)"', body)
            drop = dm.group(1).replace('\\"', '"').strip() if dm else ""
            if not drop and iid in drop_map:
                new_body = re.sub(
                    r'drop = "(?:\\.|[^"\\])*"',
                    f'drop = "{lua_escape(drop_map[iid])}"',
                    new_body,
                    count=1,
                )
                filled += 1

            if iid in SLOT_FIXES:
                sm = re.search(r'slot = "((?:\\.|[^"\\])*)"', new_body)
                cur = sm.group(1) if sm else ""
                if cur != SLOT_FIXES[iid]:
                    new_body = re.sub(
                        r'slot = "(?:\\.|[^"\\])*"',
                        f'slot = "{SLOT_FIXES[iid]}"',
                        new_body,
                        count=1,
                    )
                    slot_fixed += 1

            if new_body == body:
                return m.group(0)
            return f"[{iid}] = entry({{{new_body}}}),"

        new_text = ENTRY_RE.sub(repl, text)
        if new_text != text and not dry_run:
            path.write_text(new_text, encoding="utf-8")
    return filled, slot_fixed


def main() -> int:
    dry = "--dry-run" in sys.argv
    drop_map = build_map()
    if not dry:
        CACHE.write_text(
            json.dumps({str(k): v for k, v in sorted(drop_map.items())}, indent=2, ensure_ascii=False)
            + "\n",
            encoding="utf-8",
        )
    print(f"Drop map: {len(drop_map)} ids")
    filled, slots = apply(drop_map, dry_run=dry)
    print(f"Filled drops: {filled}; slot fixes: {slots}" + (" (dry-run)" if dry else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
