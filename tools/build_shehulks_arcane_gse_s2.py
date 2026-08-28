#!/usr/bin/env python3
"""SheHulks Arcane Mage GSE → Midnight Season 2 update.

Based on decoded SheHulks_ARC_-_1_Button (GSE 3302 / Macros layout).
S2 changes:
  - GSE Versions format (3330) for current GSE import
  - Prismatic Bolt 1295942 before every filler (no overcap)
  - Arcane Surge: Alt only — never auto (pack-end waste)
  - Shift=Barrage | Ctrl=Orb | Alt=Surge
  - Removes obsolete Frostbolt (116) / unknown 319836 filler
"""
from __future__ import annotations

import base64
import zlib
from pathlib import Path

import cbor2

OUT = Path("/workspace/tools/SheHulks_ARC_S2_export.txt")
SEQ_NAME = "SheHulks_ARC_-_1_Button"

BLAST = 30451
PRISMATIC = 1295942
BARRAGE = 44425
MISSILES = 5143
ORB = 153626
SURGE = 365350
TOTM = 321507
EVOCATION = 12051
MIRROR = 55342
BARRIER = 235450  # Prismatic Barrier — kept from original as optional def

# Original SheHulk talent loadout from import string
TALENT_SHEHULK = (
    "C4DAJHMkDNl9e4q1zfgySSx9jPjhZbWwMjZmFgZmxYamxMAAAAAAMQAQAzMbLLLzMxCAAAAAAbAsMGGzysMMMmZmZmZmZmxMGD"
)
TALENT_ST = (
    "C4DAAAAAAAAAAAAAAAAAAAAAAMzwYZmZmFMDamxAAAwAAgAmZmZZZmJWAAYDzMzM2sMzMzyMGjZmBLMzMzMDAwAAAMzsAAmBADzMD"
)
TALENT_MPLUS = (
    "C4DAAAAAAAAAAAAAAAAAAAAAAMzwYZmZmFMDamxAAAwAAgAmZmZZZmJWAAYbwMzwmlZMjZMmZmZGWYmZmZGAgBAAYmZDAMDAGmZG"
)

HELP = (
    "SheHulks S2 | Prismatic ASAP | Alt=Surge ONLY (no auto Surge)\n"
    "Shift=Barrage | Ctrl=Orb | Mirror+Trinkets on keypress\n"
    "Auto: TotM, Missiles, Orb, Blast, Evocation, Barrier"
)


def macro(*lines: str) -> bytes:
    text = "\n".join(lines)
    if len(text) > 255:
        raise ValueError(f"macro too long ({len(text)}): {text!r}")
    return text.encode("utf-8")


def block(kind: str, body: bytes, interval: int | None = None) -> dict:
    node = {b"Type": kind.encode(), b"type": b"macro", b"macro": body}
    if interval is not None:
        node[b"Interval"] = str(interval).encode()
    return node


MOD_BARRAGE = f"/cast [mod:shift,nochanneling] {BARRAGE}"
MOD_ORB = f"/cast [mod:ctrl,nochanneling] {ORB}"
MOD_SURGE = f"/cast [mod:alt,nochanneling] {SURGE}"
CAST_PRISMATIC = f"/cast [nochanneling] {PRISMATIC}"


def combat(*casts: str) -> bytes:
    return macro(MOD_BARRAGE, MOD_ORB, MOD_SURGE, CAST_PRISMATIC, *casts)


def panel_st() -> dict:
    evoc = block("Repeat", macro(f"/cast [nochanneling] {EVOCATION}"), interval=3)
    cds = block(
        "Action",
        macro(MOD_BARRAGE, MOD_ORB, MOD_SURGE, CAST_PRISMATIC, f"/cast [nochanneling] {TOTM}"),
        interval=3,
    )
    barrier = block(
        "Repeat",
        macro(f"/cast [nochanneling] {BARRIER}"),
        interval=5,
    )
    loop = {
        b"Type": b"Loop",
        b"Repeat": 2,
        b"StepFunction": b"Priority",
        1: block("Action", combat(f"/castsequence [nochanneling] {BLAST}"), interval=3),
        2: block("Action", combat(f"/castsequence [nochanneling] {MISSILES}"), interval=3),
        3: block("Action", combat(f"/cast [nochanneling] {ORB}"), interval=3),
    }
    return {
        b"Label": b"Spellslinger",
        b"Actions": [evoc, cds, barrier, loop],
        b"InbuiltVariables": [],
    }


def panel_aoe() -> dict:
    evoc = block("Repeat", macro(f"/cast [nochanneling] {EVOCATION}"), interval=3)
    cds = block(
        "Action",
        macro(MOD_BARRAGE, MOD_ORB, MOD_SURGE, CAST_PRISMATIC, f"/cast [nochanneling] {TOTM}"),
        interval=3,
    )
    loop = {
        b"Type": b"Loop",
        b"Repeat": 2,
        b"StepFunction": b"Priority",
        1: block("Action", combat(f"/cast [nochanneling] {ORB}"), interval=3),
        2: block("Action", combat(f"/castsequence [nochanneling] {MISSILES}"), interval=3),
        3: block("Action", combat(f"/castsequence [nochanneling] {BLAST}"), interval=3),
    }
    return {
        b"Label": b"Spellslinger AoE",
        b"Actions": [evoc, cds, loop],
        b"InbuiltVariables": [],
    }


def build_sequence() -> dict:
    return {
        b"Versions": [panel_st(), panel_aoe()],
        b"KeyPress": [
            b"/targetenemy [noharm][dead]",
            b"/cast [nochanneling] Mirror Image",
            b"/cast Auto Attack",
            b"/use [@player,nochanneling,combat] 13",
            b"/use [@player,nochanneling,combat] 14",
        ],
        b"WeakAuras": {},
        b"LastUpdated": b"20260828",
        b"MetaData": {
            b"Name": SEQ_NAME.encode(),
            b"Author": b"SheHulk / BiSPulse S2",
            b"GSEVersion": 3330,
            b"TOC": 120100,
            b"Help": HELP.encode(),
            b"Default": 1,
            b"SpecID": 62,
            b"ManualIntervention": True,
            b"Helplink": b"https://discord.gg/XH2A78Ny",
            b"Talents": {
                b"SheHulk Loadout": {
                    b"TalentSet": TALENT_SHEHULK.encode(),
                    b"Description": b"Original SheHulks import",
                },
                b"Spellslinger ST": {
                    b"TalentSet": TALENT_ST.encode(),
                    b"Description": b"Method Spellslinger ST 12.1",
                },
                b"Spellslinger M+": {
                    b"TalentSet": TALENT_MPLUS.encode(),
                    b"Description": b"Method Spellslinger M+ 12.1",
                },
            },
        },
    }


def encode_gse3(obj: dict) -> str:
    raw = cbor2.dumps(obj)
    c = zlib.compressobj(9, zlib.DEFLATED, -15)
    compressed = c.compress(raw) + c.flush()
    return "!GSE3!" + base64.b64encode(compressed).decode("ascii")


def main() -> None:
    collection = {
        b"type": b"COLLECTION",
        b"payload": {
            b"Variables": {},
            b"Macros": [],
            b"ElementCount": 1,
            b"Sequences": {SEQ_NAME.encode(): build_sequence()},
        },
    }
    export = encode_gse3(collection)
    OUT.write_text(export + "\n", encoding="utf-8")

    obj = cbor2.loads(zlib.decompress(base64.b64decode(export[6:]), -15))
    seq = obj[b"payload"][b"Sequences"][SEQ_NAME.encode()]
    assert b"Versions" in seq and b"Macros" not in seq
    assert b"KeyPress" in seq
    assert len(seq[b"KeyPress"]) == 5

    for ver in seq[b"Versions"]:
        for node in ver[b"Actions"]:
            if b"macro" in node:
                assert len(node[b"macro"].decode()) <= 255
            if node.get(b"Type") == b"Loop":
                for k in (1, 2, 3):
                    assert str(PRISMATIC) in node[k][b"macro"].decode()
        cds = ver[b"Actions"][1][b"macro"].decode()
        assert str(PRISMATIC) in cds
        assert f"/cast [nochanneling] {SURGE}" not in cds.replace(
            f"[mod:alt,nochanneling] {SURGE}", ""
        )

    print("Wrote", OUT, "len", len(export))
    print("KeyPress:", [k.decode() for k in seq[b"KeyPress"]])
    print(export)


if __name__ == "__main__":
    main()
