"""Build Master Arcanist Arcane Mage GSE for Midnight S2.

Restores the proven light Vinimagis layout (few Actions + Priority loop) so
the sequence actually advances. Prismatic Bolt is tried before each filler;
Arcane Surge is Alt-only (never auto).
"""
from __future__ import annotations

import base64
import zlib
from pathlib import Path

import cbor2

OUT = Path("/workspace/tools/Master_Arcanist_Arcane_S2_export.txt")

BLAST = 30451
PRISMATIC = 1295942  # must cast by ID — Blast ID does not fire the proc
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
    "S2 Spellslinger | Prismatic before filler (no overcap)\n"
    "Shift=Barrage (Salvo 20+) | Ctrl=Orb | Alt=Surge (manual only)\n"
    "Auto: TotM, Missiles (CC), Orb, Blast, Evocation"
)


def b(s: str) -> bytes:
    return s.encode("utf-8")


def macro(*lines: str) -> bytes:
    text = "\n".join(lines)
    assert len(text) <= 255, f"macro too long ({len(text)}): {text!r}"
    return text.encode("utf-8")


def block(kind: str, body: bytes, interval: int | None = None) -> dict:
    node = {
        b"Type": b(kind),
        b"type": b"macro",
        b"macro": body,
    }
    if interval is not None:
        node[b"Interval"] = b(str(interval))
    return node


MOD_BARRAGE = f"/cast [mod:shift,nochanneling] {BARRAGE}"
MOD_ORB = f"/cast [mod:ctrl,nochanneling] {ORB}"
MOD_SURGE = f"/cast [mod:alt,nochanneling] {SURGE}"
CAST_PRISMATIC = f"/cast [nochanneling] {PRISMATIC}"


def combat(*casts: str) -> bytes:
    """Mods + Prismatic, then the filler cast(s). Always ends with a usable filler."""
    return macro(MOD_BARRAGE, MOD_ORB, MOD_SURGE, CAST_PRISMATIC, *casts)


def panel_st() -> dict:
    """Light ST panel — matches the layout that imported and ran cleanly."""
    evoc = block(
        "Repeat",
        macro(f"/cast [nochanneling] {EVOCATION}"),
        interval=3,
    )
    # TotM only here (not on every filler press — that stalled the rotation)
    cds = block(
        "Action",
        macro(
            MOD_BARRAGE,
            MOD_ORB,
            MOD_SURGE,
            f"/cast [nochanneling] {TOTM}",
        ),
        interval=3,
    )
    loop = {
        b"Type": b"Loop",
        b"Repeat": 2,
        b"StepFunction": b"Priority",
        1: block(
            "Action",
            combat(f"/castsequence [nochanneling] {BLAST}"),
            interval=3,
        ),
        2: block(
            "Action",
            combat(f"/castsequence [nochanneling] {MISSILES}"),
            interval=3,
        ),
        3: block(
            "Action",
            combat(f"/cast [nochanneling] {ORB}"),
            interval=3,
        ),
    }
    return {
        b"Label": b"Spellslinger",
        b"Actions": [evoc, cds, loop],
        b"InbuiltVariables": [],
    }


def panel_aoe() -> dict:
    """AoE: Orb before Missiles; same light shell."""
    evoc = block(
        "Repeat",
        macro(f"/cast [nochanneling] {EVOCATION}"),
        interval=3,
    )
    cds = block(
        "Action",
        macro(
            MOD_BARRAGE,
            MOD_ORB,
            MOD_SURGE,
            f"/cast [nochanneling] {TOTM}",
        ),
        interval=3,
    )
    loop = {
        b"Type": b"Loop",
        b"Repeat": 2,
        b"StepFunction": b"Priority",
        1: block(
            "Action",
            combat(f"/cast [nochanneling] {ORB}"),
            interval=3,
        ),
        2: block(
            "Action",
            combat(f"/castsequence [nochanneling] {MISSILES}"),
            interval=3,
        ),
        3: block(
            "Action",
            combat(f"/castsequence [nochanneling] {BLAST}"),
            interval=3,
        ),
    }
    return {
        b"Label": b"Spellslinger AoE",
        b"Actions": [evoc, cds, loop],
        b"InbuiltVariables": [],
    }


def build_sequence() -> dict:
    return {
        b"Versions": [panel_st(), panel_aoe()],
        b"WeakAuras": {},
        b"LastUpdated": b"20260827",
        b"MetaData": {
            b"Name": b"Master_Arcanist-12.1",
            b"Author": b"Vinimagis@Stormrage / BiSPulse S2",
            b"GSEVersion": 3330,
            b"TOC": 120100,
            b"Help": HELP.encode(),
            b"Default": 1,
            b"SpecID": 62,
            b"ManualIntervention": True,
            b"Talents": {
                b"Spellslinger ST": {
                    b"TalentSet": TALENT_ST.encode(),
                    b"Description": b"Method Spellslinger ST 12.1",
                },
                b"Spellslinger M+": {
                    b"TalentSet": TALENT_MPLUS.encode(),
                    b"Description": b"Method Spellslinger M+ 12.1",
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
    assert len(seq[b"Versions"]) == 2
    for ver in seq[b"Versions"]:
        assert len(ver[b"Actions"]) == 3
        for node in ver[b"Actions"]:
            if b"macro" in node:
                assert len(node[b"macro"]) <= 255
            if node.get(b"Type") == b"Loop":
                kids = [k for k in node if isinstance(k, int)]
                assert kids == [1, 2, 3]
                for k in kids:
                    text = node[k][b"macro"].decode()
                    assert len(text) <= 255
                    assert str(PRISMATIC) in text
                    assert f"/cast [nochanneling] {SURGE}" not in text
                    assert str(TOTM) not in text, "TotM must not block filler steps"
    sample = seq[b"Versions"][0][b"Actions"][2][1][b"macro"].decode()
    print("Wrote", OUT, "len", len(export))
    print("panels:", [v[b"Label"].decode() for v in seq[b"Versions"]])
    print("ST step1:\n" + sample)
    print(export)


if __name__ == "__main__":
    main()
