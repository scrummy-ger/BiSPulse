"""Build Master Arcanist Arcane Mage GSE for Midnight Season 2 / 12.1.

Approximates Method Spellslinger priority + Salvo/Clearcasting rules.
GSE cannot read Arcane Salvo stacks — Semi panel uses Shift for Barrage.

Source priority: Method Arcane Mage 12.1 + user priority list.
Talents: Method Spellslinger ST / M+.
"""
from __future__ import annotations

import base64
import zlib
from pathlib import Path

import cbor2

OUT = Path("/workspace/tools/Master_Arcanist_Arcane_S2_export.txt")

BLAST = 30451  # Prismatic Bolt overrides this button when procced
BARRAGE = 44425
MISSILES = 5143
ORB = 153626
SURGE = 365350
TOTM = 321507
EVOCATION = 12051

TALENT_ST = (
    "C4DAAAAAAAAAAAAAAAAAAAAAAMzwYZmZmFMDamxAAAwAAgAmZmZZZmJWAAYDzMzM2sMzMzyMGjZmBLMzMzMDAwAAAMzsAAmBADzMD"
)
TALENT_MPLUS = (
    "C4DAAAAAAAAAAAAAAAAAAAAAAMzwYZmZmFMDamxAAAwAAgAmZmZZZmJWAAYbwMzwmlZMjZMmZmZGWYmZmZGAgBAAYmZDAMDAGmZG"
)

HELP = (
    "S2 Spellslinger | Shift=Barrage (Salvo 20+) | Ctrl=Orb | Alt=Surge\n"
    "TotM+Surge auto on CD | Missiles on Clearcasting | Blast fills (Prismatic Bolt)\n"
    "Semi: hold Shift at 20 Salvo | Auto: Barrage on interval (less precise)"
)


def mods(extra: str) -> str:
    return (
        f"/cast [mod:shift,nochanneling] {BARRAGE}\n"
        f"/cast [mod:ctrl,nochanneling] {ORB}\n"
        f"/cast [mod:alt,nochanneling] {SURGE}\n"
        f"{extra}"
    )


def action(macro: str, *, interval: int | None = None, repeat: bool = False) -> dict:
    node: dict = {
        b"Type": b"Repeat" if repeat else b"Action",
        b"type": b"macro",
        b"macro": macro.encode(),
    }
    if interval is not None:
        node[b"Interval"] = str(interval).encode()
    return node


def make_loop(blocks: list[tuple], *, sequential: bool = False) -> dict:
    loop: dict = {
        b"Type": b"Loop",
        b"Repeat": 1,
        b"StepFunction": b"Sequential" if sequential else b"Priority",
    }
    for i, (macro, interval, is_repeat) in enumerate(blocks, start=1):
        loop[i] = action(macro, interval=interval, repeat=is_repeat)
    return loop


def panel(label: str, blocks: list[tuple]) -> dict:
    return {
        b"Label": label.encode(),
        b"Actions": [make_loop(blocks)],
        b"InbuiltVariables": {b"Combat": True},
    }


def panel_st_semi() -> dict:
    return panel(
        "ST Semi (Shift Barrage)",
        [
            (mods(f"/cast [nochanneling] {TOTM}"), 2, True),
            (mods(f"/cast [nochanneling] {SURGE}"), 2, False),
            (mods(f"/cast [nochanneling] {MISSILES}"), 2, True),
            (mods(f"/cast [nochanneling] {ORB}"), 3, False),
            (mods(f"/cast [nochanneling] {BLAST}"), 1, True),
            (mods(f"/cast [nochanneling] {BLAST}"), None, False),
            (mods(f"/cast [nochanneling] {BLAST}"), None, False),
            (mods(f"/cast [nochanneling] {ORB}"), None, False),
            (mods(f"/cast [nochanneling] {BLAST}"), None, False),
            (mods(f"/cast [nochanneling] {EVOCATION}"), 8, True),
        ],
    )


def panel_st_auto() -> dict:
    return panel(
        "ST Auto",
        [
            (mods(f"/cast [nochanneling] {TOTM}"), 2, True),
            (mods(f"/cast [nochanneling] {SURGE}"), 2, False),
            (mods(f"/cast [nochanneling] {MISSILES}"), 2, True),
            (mods(f"/cast [nochanneling] {ORB}"), 3, False),
            (mods(f"/cast [nochanneling] {BARRAGE}"), 5, False),
            (mods(f"/cast [nochanneling] {BLAST}"), 1, True),
            (mods(f"/cast [nochanneling] {BLAST}"), None, False),
            (mods(f"/cast [nochanneling] {BLAST}"), None, False),
            (mods(f"/cast [nochanneling] {ORB}"), None, False),
            (mods(f"/cast [nochanneling] {BLAST}"), None, False),
            (mods(f"/cast [nochanneling] {EVOCATION}"), 8, True),
        ],
    )


def panel_aoe() -> dict:
    return panel(
        "AoE Auto",
        [
            (mods(f"/cast [nochanneling] {TOTM}"), 2, True),
            (mods(f"/cast [nochanneling] {SURGE}"), 2, False),
            (mods(f"/cast [nochanneling] {ORB}"), 2, True),
            (mods(f"/cast [nochanneling] {MISSILES}"), 2, True),
            (mods(f"/cast [nochanneling] {BARRAGE}"), 4, False),
            (mods(f"/cast [nochanneling] {BLAST}"), 1, True),
            (mods(f"/cast [nochanneling] {BLAST}"), None, False),
            (mods(f"/cast [nochanneling] {ORB}"), None, False),
            (mods(f"/cast [nochanneling] {BLAST}"), None, False),
            (mods(f"/cast [nochanneling] {EVOCATION}"), 8, True),
        ],
    )


def build_sequence() -> dict:
    return {
        b"Versions": [panel_st_semi(), panel_st_auto(), panel_aoe()],
        b"WeakAuras": {},
        b"LastUpdated": b"20260826",
        b"MetaData": {
            b"Name": b"Master_Arcanist-12.1",
            b"Author": b"Vinimagis@Stormrage / BiSPulse S2",
            b"GSEVersion": 3330,
            b"TOC": 120100,
            b"Help": HELP.encode(),
            b"Default": 1,
            b"SpecID": 62,
            b"ManualIntervention": True,
            b"EnforceCompatability": True,
            b"Talents": {
                b"Spellslinger ST": {
                    b"TalentSet": TALENT_ST.encode(),
                    b"Description": b"Method Spellslinger Single Target 12.1",
                },
                b"Spellslinger M+": {
                    b"TalentSet": TALENT_MPLUS.encode(),
                    b"Description": b"Method Spellslinger Mythic+ / Raid Cleave 12.1",
                },
            },
            b"Helplink": b"https://www.method.gg/guides/arcane-mage/playstyle-and-rotation",
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
            b"Sequences": {b"Master_Arcanist-12.1": build_sequence()},
        },
    }
    export = encode_gse3(collection)
    OUT.write_text(export + "\n", encoding="utf-8")

    obj = cbor2.loads(zlib.decompress(base64.b64decode(export[6:]), -15))
    seq = obj[b"payload"][b"Sequences"][b"Master_Arcanist-12.1"]
    assert b"Versions" in seq and b"Macros" not in seq
    assert len(seq[b"Versions"]) == 3
    text = str(obj)
    assert "319836" not in text and "1229376" not in text
    assert str(BLAST) in text and str(BARRAGE) in text and str(TOTM) in text
    print("Wrote", OUT, "len", len(export))
    print("panels:", [v[b"Label"].decode() for v in seq[b"Versions"]])
    print(export)


if __name__ == "__main__":
    main()
