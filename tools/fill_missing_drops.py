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
    # Skulking Viper (Hunter S2 tier) — Venomous Abyss tokens, not M+
    271490: "The Lost Explorers",  # Shoulders
    271491: "Sszorak",  # Legs
    271492: "The Twin Fangs",  # Head
    271493: "Entombed Sentinels",  # Gloves — NOT King's Rest
    271495: "Vashnik the Malignant",  # Chest
    # Primal Sentry (S1 hunter tier) — Archon rows often lack drops
    249988: "Lightblinded Vanguard",  # Head
    249986: "Fallen-King Salhadaar",  # Shoulders
    249991: "Chimaerus",  # Chest
    249989: "Vorasius",  # Gloves
    249987: "Vaelgor & Ezzorak",  # Legs
    # Missing drop QA (2026-09-06)
    158370: "Adderis and Aspix",  # Twin-Strike Polearm — Temple of Sethraliss
    193755: "Kyrakka and Erkhart Stormvein",  # Backdraft Cleaver — Ruby Life Pools
    270169: "Hex Lord Malacrass",  # Hex Lord's Dooming Idol — Coiled Altar
    248583: "World Quest / Prey",  # Drum of Renewed Bonds
    251792: "Delves",  # Glorious Crusader's Keepsake
}

# Midnight S2 class tier sets (Venomous Abyss tokens by slot).
TIER_SET_NAME_RE = re.compile(
    r"(Skulking Viper|Baleful Grave-Knight|Abyssal Doomhound|Dreamwatcher|"
    r"Calamitous Echo|Primal Leywarden|Monkey King|Consecrated Flame|"
    r"Cosmic Penitent|Chosen Bloodslayer|Ophidian Oracle|Damned Necrolyte|"
    r"Jade Warlord)",
    re.I,
)
TIER_SLOT_BOSS: dict[str, str] = {
    "Head": "The Twin Fangs",
    "Shoulders": "The Lost Explorers",
    "Chest": "Vashnik the Malignant",
    "Gloves": "Entombed Sentinels",
    "Hands": "Entombed Sentinels",
    "Legs": "Sszorak",
}

# Canonical identity when scrapes mis-assign name/slot (column drift / wrong row).
# Only IDs that are a single real item across the game — not collided scrape rows.
ITEM_CANONICAL: dict[int, dict[str, str]] = {
    244584: {"name": "Farstrider's Plated Bracers", "slot": "Wrist"},
    251184: {"name": "Ironroot Collar", "slot": "Neck"},
    268216: {"name": "Cursed Reliquary Cincture", "slot": "Belt"},
    268251: {"name": "Amulet of the Twin Fangs", "slot": "Neck"},
    268265: {"name": "Aqirbane Reliquary", "slot": "Neck", "drop": "Ula'tek"},
    271490: {"name": "Jaws of the Skulking Viper", "slot": "Shoulders", "drop": "The Lost Explorers"},
    271491: {"name": "Skulking Viper's Coiled Legwraps", "slot": "Legs", "drop": "Sszorak"},
    271492: {"name": "Skulking Viper's Weeping Fangs", "slot": "Head", "drop": "The Twin Fangs"},
    271493: {"name": "Skulking Viper's Hidepiercers", "slot": "Gloves", "drop": "Entombed Sentinels"},
    271495: {"name": "Skulking Viper's Scuteplate", "slot": "Chest", "drop": "Vashnik the Malignant"},
}

# Backward-compatible alias used below.
SLOT_FIXES: dict[int, str] = {
    iid: meta["slot"] for iid, meta in ITEM_CANONICAL.items() if "slot" in meta
}

# High-confidence name → slot. First match wins. Prefer specific over ambiguous.
# Note: In Midnight, "Greaves" are Legs (not Boots). Boots use boots/treads/sabatons/…
_SLOT_NAME_RULES: list[tuple[str, re.Pattern[str], re.Pattern[str] | None]] = [
    (
        "Boots",
        re.compile(
            r"(boots|stompers|sabatons|treads|striders|footpads|slippers|walkers|"
            r"gaiters|buskins|warboots|scaleboots|soultreads|footguards)",
            re.I,
        ),
        re.compile(r"(legwraps|leggings|legguards|legplates|\bpants\b|chausses|cuisses|breeches)", re.I),
    ),
    (
        "Legs",
        re.compile(
            r"(legwraps|leggings|legguards|legplates|\bpants\b|kilt|chausses|cuisses|"
            r"breeches|\bgreaves\b|leg bindings)",
            re.I,
        ),
        re.compile(r"(boots|stompers|sabatons|treads|warboots|scaleboots|soultreads)", re.I),
    ),
    (
        "Wrist",
        re.compile(
            r"(bracers|wristbands|wristguards|vambraces|cuffs|armbands|armplates|wristwraps|"
            r"(?<!leg )bindings)",
            re.I,
        ),
        re.compile(r"(gloves|gauntlets|handguards|\bgrips\b|handwraps)", re.I),
    ),
    (
        "Gloves",
        re.compile(
            r"(gloves|gauntlets|handguards|\bgrips\b|handwraps|\bgrasps\b|deathgrips)",
            re.I,
        ),
        re.compile(r"(bracers|wristbands|wristguards|wristwraps)", re.I),
    ),
    (
        "Belt",
        re.compile(
            r"(\bbelt\b|girdle|cincture|waistguard|\bcord\b|\bsash\b|clasps|warbelt|waistwrap)",
            re.I,
        ),
        re.compile(r"(cloak|cape|drape|shawl)", re.I),
    ),
    (
        "Neck",
        re.compile(
            r"(amulet|necklace|choker|pendant|\breliquary\b|talisman|gorget|\bcollar\b|medallion)",
            re.I,
        ),
        re.compile(r"(cincture|girdle|\bbelt\b|bracer|glove|spaulders)", re.I),
    ),
    (
        "Ring",
        re.compile(r"(\bring\b|signet|\bloop\b|bubbleband|claw ring)", re.I),
        re.compile(r"(wristband|armband|headband)", re.I),
    ),
    (
        "Head",
        re.compile(
            r"(helm|helmet|hood|cowl|crown|casque|\bmask\b|visor|headpiece|coif|greathelm|warhelm)",
            re.I,
        ),
        re.compile(r"(cloak|cape|drape|shawl)", re.I),
    ),
    (
        "Shoulders",
        re.compile(r"(spaulders|pauldrons|shoulderguards|epaulets|shoulderplates|greatmantle)", re.I),
        None,
    ),
    (
        "Cloak",
        re.compile(
            r"(cloak|cape|\bdrape\b|\bshawl\b|\bpall\b|netherwrap|fireproof drape)",
            re.I,
        ),
        re.compile(r"(wristwrap|waistwrap|legwrap|handwrap|spirit shroud)", re.I),
    ),
    (
        "Chest",
        re.compile(
            r"(chestguard|chestplate|breastplate|tunic|hauberk|vestments|\brobe\b|dreadrobe|"
            r"cuirass|jerkin|raiment|warplate)",
            re.I,
        ),
        None,
    ),
]


def lua_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def infer_slot_from_name(name: str, current: str) -> str | None:
    """Return corrected slot when the item name strongly implies a different slot."""
    if not name:
        return None
    for want, pos, neg in _SLOT_NAME_RULES:
        if not pos.search(name):
            continue
        if neg and neg.search(name):
            continue
        if current != want:
            return want
        return None
    return None


def infer_tier_boss(name: str, slot: str) -> str | None:
    """S2 class tier pieces come from Venomous Abyss token bosses (or Catalyst)."""
    if not name or not slot:
        return None
    if not TIER_SET_NAME_RE.search(name):
        return None
    return TIER_SLOT_BOSS.get(slot)


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
    for iid, meta in ITEM_CANONICAL.items():
        if meta.get("drop"):
            m[iid] = meta["drop"]
    return m


def set_field(body: str, key: str, value: str) -> str:
    return re.sub(
        rf'{key} = "(?:\\.|[^"\\])*"',
        f'{key} = "{lua_escape(value)}"',
        body,
        count=1,
    )


def apply(drop_map: dict[int, str], dry_run: bool = False) -> tuple[int, int, int]:
    filled = 0
    slot_fixed = 0
    name_fixed = 0
    for path in sorted(DATA.glob("*.lua")):
        if path.name == "Registry.lua":
            continue
        text = path.read_text(encoding="utf-8")

        def repl(m: re.Match) -> str:
            nonlocal filled, slot_fixed, name_fixed
            iid = int(m.group(1))
            body = m.group(2)
            new_body = body

            dm = re.search(r'drop = "((?:\\.|[^"\\])*)"', body)
            drop = dm.group(1).replace('\\"', '"').strip() if dm else ""
            nm = re.search(r'name = "((?:\\.|[^"\\])*)"', body)
            name = nm.group(1).replace('\\"', '"') if nm else ""
            sm = re.search(r'slot = "((?:\\.|[^"\\])*)"', body)
            slot = sm.group(1) if sm else ""

            # Slot from name first so tier-boss mapping uses the corrected slot.
            inferred = infer_slot_from_name(name, slot)
            if inferred and inferred != slot:
                new_body = set_field(new_body, "slot", inferred)
                slot = inferred
                slot_fixed += 1

            canon = ITEM_CANONICAL.get(iid)
            if canon:
                # Only rewrite name when this ID is known-unique or already close.
                if canon.get("name") and name != canon["name"]:
                    # Avoid clobbering unrelated items on collided scrape IDs unless
                    # the current name is empty / placeholder / same set family.
                    if (
                        not name
                        or name.startswith("Item ")
                        or name.startswith("#")
                        or (canon["name"].split()[0] in name)
                        or ("Skulking Viper" in canon["name"] and "Skulking Viper" in name)
                    ):
                        new_body = set_field(new_body, "name", canon["name"])
                        name = canon["name"]
                        name_fixed += 1
                if canon.get("slot") and slot != canon["slot"]:
                    # Same guard: only if name matches canon family
                    if not name or name == canon.get("name") or (
                        canon.get("name") and canon["name"].split("'")[0][:8] in name
                    ):
                        new_body = set_field(new_body, "slot", canon["slot"])
                        slot = canon["slot"]
                        slot_fixed += 1

            # Tier set tokens: always use Venomous Abyss boss for that slot.
            want_drop = infer_tier_boss(name, slot)
            if not want_drop and canon and canon.get("drop"):
                if not name or name == canon.get("name") or (
                    canon.get("name") and "Skulking Viper" in name and "Skulking Viper" in canon["name"]
                ):
                    want_drop = canon["drop"]
            if not want_drop and not drop and iid in drop_map:
                want_drop = drop_map[iid]

            if want_drop and drop != want_drop:
                new_body = set_field(new_body, "drop", want_drop)
                drop = want_drop
                filled += 1

            if new_body == body:
                return m.group(0)
            return f"[{iid}] = entry({{{new_body}}}),"

        new_text = ENTRY_RE.sub(repl, text)
        if new_text != text and not dry_run:
            path.write_text(new_text, encoding="utf-8")
    return filled, slot_fixed, name_fixed


def fix_wowhead_json(dry_run: bool = False) -> int:
    if not WH_JSON.is_file():
        return 0
    raw = json.loads(WH_JSON.read_text(encoding="utf-8"))
    changed = 0
    for pack in (raw.get("out") or {}).values():
        for row in pack.get("items") or []:
            iid = int(row["id"])
            name = row.get("name") or ""
            slot = row.get("slot") or ""
            inferred = infer_slot_from_name(name, slot)
            if inferred:
                row["slot"] = inferred
                slot = inferred
                changed += 1
            tier = infer_tier_boss(name, slot)
            if tier and row.get("drop") != tier:
                row["drop"] = tier
                changed += 1
            canon = ITEM_CANONICAL.get(iid)
            if not canon:
                continue
            for key in ("name", "slot", "drop"):
                if key in canon and row.get(key) != canon[key]:
                    # Don't overwrite unrelated names on collided IDs
                    if key == "name" and name and name != canon["name"]:
                        if "Skulking Viper" not in name and "Skulking Viper" in canon["name"]:
                            continue
                    row[key] = canon[key]
                    changed += 1
    if changed and not dry_run:
        WH_JSON.write_text(json.dumps(raw, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return changed


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
    filled, slots, names = apply(drop_map, dry_run=dry)
    wh = fix_wowhead_json(dry_run=dry)
    print(
        f"Filled drops: {filled}; slot fixes: {slots}; name fixes: {names}; "
        f"wowhead json field fixes: {wh}" + (" (dry-run)" if dry else "")
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
