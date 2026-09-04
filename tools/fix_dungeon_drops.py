#!/usr/bin/env python3
"""Replace dungeon-only drop= with boss names so UI can show Boss (Instance)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "Data"
ENTRY_RE = re.compile(r"\[(\d+)\] = entry\(\{([\s\S]*?)\}\),")

BOSS_BY_ID: dict[int, str] = {
    251132: "Zaen Bladesorrow",  # Speakeasy Shroud
    265337: "Engineering",  # Aln'hara Sprigshot
    273796: "Rav'i",  # Vile Vial of Volatile Venom
    249988: "Lightblinded Vanguard",
    249986: "Fallen-King Salhadaar",
    249991: "Chimaerus",
    249989: "Vorasius",
    249987: "Vaelgor & Ezzorak",
}

BOSS_BY_NAME: dict[str, str] = {
    "Speakeasy Shroud": "Zaen Bladesorrow",
    "Freightrunner's Flask": "Zaen Bladesorrow",
    "Manaheart's Binding Flame": "Kystia Manaheart",
    "Resonant Bellowstone": "Xathuux the Annihilator",
    "Unstable Felheart Crystal": "Lithiel Cinderfury",
    "Pendant of Malefic Fury": "Lithiel Cinderfury",
    "Vile Vial of Volatile Venom": "Rav'i",
    "Coiled Fangstone": "Rav'i",
    "Knot of Writhing Serpents": "The Writhing Coil",
    "Tattered Amani War Banner": "Zul'jan",
    "Aln'hara Sprigshot": "Engineering",
    "Sickening Signet of Atroxus": "Atroxus",
    "Mindpiercer's Sigil": "Charonus",
    "Tumor of the Swarm": "Charonus",
    "Void Execution Mandate": "Charonus",
}

WEAK = {
    "",
    "Murder Row",
    "Altar of Fangs",
    "Voidscar Arena",
    "Den of Nalorakk",
    "The Blinding Vale",
    "Blinding Vale",
    "Temple of Sethraliss",
    "King's Rest",
    "Kings' Rest",
    "Ruby Life Pools",
    "Tier Set",
    "The Voidspire",
    "The Dreamrift",
    "Sporefall",
    "The Venomous Abyss",
}


def lua_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def main() -> int:
    changed = 0
    for path in sorted(DATA.glob("*.lua")):
        if path.name == "Registry.lua":
            continue
        text = path.read_text(encoding="utf-8")

        def repl(m: re.Match) -> str:
            nonlocal changed
            iid = int(m.group(1))
            body = m.group(2)
            nm = re.search(r'name = "((?:\\.|[^"\\])*)"', body)
            name = nm.group(1).replace('\\"', '"') if nm else ""
            dm = re.search(r'drop = "((?:\\.|[^"\\])*)"', body)
            drop = (dm.group(1).replace('\\"', '"') if dm else "").strip()

            want = BOSS_BY_ID.get(iid) or BOSS_BY_NAME.get(name)
            if not want or drop == want:
                return m.group(0)
            if drop and drop not in WEAK:
                return m.group(0)

            new_body = re.sub(
                r'drop = "(?:\\.|[^"\\])*"',
                f'drop = "{lua_escape(want)}"',
                body,
                count=1,
            )
            changed += 1
            return f"[{iid}] = entry({{{new_body}}}),"

        new_text = ENTRY_RE.sub(repl, text)
        if new_text != text:
            path.write_text(new_text, encoding="utf-8")

    print(f"Updated {changed} drop fields to boss names")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
