#!/usr/bin/env python3
"""FLIPCYDE BM Hunter GSE → Midnight Season 2 (import-compatible).

Exports in Flipcyde's native [name, sequence] GSE3 format (same as the
originals that import cleanly), NOT COLLECTION — some GSE builds reject
multi-sequence COLLECTIONS or exotic Meta fields.

Sources:
  - FLIPCYDE_BM_MIDNIGHT_ST_V1
  - FLIPCYDE_BM_MIDNIGHT_AOE_V1
"""
from __future__ import annotations

import base64
import zlib
from pathlib import Path

import cbor2

OUT = Path("/workspace/tools/FLIPCYDE_BM_MIDNIGHT_S2_export.txt")
OUT_ST = Path("/workspace/tools/FLIPCYDE_BM_MIDNIGHT_S2_ST.txt")
OUT_AOE = Path("/workspace/tools/FLIPCYDE_BM_MIDNIGHT_S2_AOE.txt")

SEQ_ST = "FLIPCYDE_BM_MIDNIGHT_S2_ST"
SEQ_AOE = "FLIPCYDE_BM_MIDNIGHT_S2_AOE"

PET_PREFIX = (
    "/petassist",
    "/petattack [@target,harm,nodead]",
    "/cast [mod:alt,@pet,nodead] Mend Pet",
    "/stopmacro [mod]",
    "/stopmacro [channeling]",
)

# Method ST: Nature's Ally weave — never KC back-to-back
ST_STEPS = [
    "/cast Bestial Wrath",
    "/cast Barbed Shot",
    "/cast Kill Command",
    "/cast [known:Black Arrow] Black Arrow; Barbed Shot",
    "/cast Kill Command",
    "/cast Barbed Shot",
    "/cast Kill Command",
    "/cast Cobra Shot",
    "/cast Kill Command",
    "/cast [known:Dire Beast] Dire Beast; Cobra Shot",
    "/cast Cobra Shot",
]

# Method AoE: Thrash -> BW -> Thrash (Apex pet cleave) -> weave
AOE_STEPS = [
    "/cast Wild Thrash",
    "/cast Bestial Wrath",
    "/cast Wild Thrash",
    "/cast Barbed Shot",
    "/cast Kill Command",
    "/cast Barbed Shot",
    "/cast Kill Command",
    "/cast Cobra Shot",
    "/cast Kill Command",
    "/cast [known:Dire Beast] Dire Beast; Cobra Shot",
    "/cast Cobra Shot",
]


def macro(*lines: str) -> bytes:
    text = "\n".join(lines)
    if len(text) > 255:
        raise ValueError(f"macro too long ({len(text)}): {text!r}")
    return text.encode("utf-8")


def pet_action(spell: str) -> dict:
    # Match Flipcyde key order: macro, Type, type (no Interval — originals omit it)
    return {
        b"macro": macro(*PET_PREFIX, spell),
        b"Type": b"Action",
        b"type": b"macro",
    }


def priority_loop(steps: list[str], repeat: int = 2) -> dict:
    loop: dict = {
        b"Type": b"Loop",
        b"Repeat": repeat,
        b"StepFunction": b"Priority",
    }
    for i, spell in enumerate(steps, start=1):
        loop[i] = pet_action(spell)
    return loop


def build_sequence(
    name: str,
    label: str,
    steps: list[str],
    help_txt: str,
    source: str,
    checksum: str,
) -> list:
    """Flipcyde native payload: [name, sequence_table]."""
    seq = {
        b"WeakAuras": [],
        b"Versions": [
            {
                b"InbuiltVariables": [],
                b"Actions": [priority_loop(steps)],
                b"Label": label.encode("ascii"),
            }
        ],
        b"LastUpdated": b"20260828000000",
        b"MetaData": {
            b"Author": b"Flipcyde / PROJECT CYDE / BiSPulse S2",
            b"Default": 1,
            b"Dependencies": {
                b"Variables": [],
                b"Macros": [],
                b"Sequences": [],
            },
            b"EnforceCompatability": True,
            b"GSEVersion": 3330,
            b"ManualIntervention": True,
            b"Name": name.encode("ascii"),
            b"SpecID": 253,
            b"TOC": 120100,
            b"HelpTxt": help_txt.encode("ascii"),
            b"CYDEValidation": b"STATIC_ONLY_12_1",
            b"CYDESourceName": source.encode("ascii"),
            b"CYDERelease": b"MIDNIGHT_SEASON_2",
            b"Checksum": checksum.encode("ascii"),
        },
    }
    return [name.encode("ascii"), seq]


def encode_gse3(obj) -> str:
    raw = cbor2.dumps(obj)
    c = zlib.compressobj(9, zlib.DEFLATED, -15)
    compressed = c.compress(raw) + c.flush()
    return "!GSE3!" + base64.b64encode(compressed).decode("ascii")


def validate(export: str, expect_first: bytes) -> None:
    obj = cbor2.loads(zlib.decompress(base64.b64decode(export[6:]), -15))
    assert isinstance(obj, list) and len(obj) == 2
    name, seq = obj
    assert isinstance(name, bytes)
    assert b"Versions" in seq and b"Macros" not in seq
    assert b"HelpTxt" in seq[b"MetaData"]
    assert isinstance(seq[b"WeakAuras"], list)
    loop = seq[b"Versions"][0][b"Actions"][0]
    assert expect_first in loop[1][b"macro"]
    kids = sorted(k for k in loop if isinstance(k, int))
    prev_kc = False
    for k in kids:
        text = loop[k][b"macro"].decode("ascii")
        assert len(text) <= 255
        assert "Mend Pet" in text
        is_kc = text.rstrip().endswith("/cast Kill Command")
        assert not (prev_kc and is_kc), f"KC back-to-back at {k}"
        prev_kc = is_kc
        # Round-trip ASCII only (import safety)
        text.encode("ascii")


def main() -> None:
    st = build_sequence(
        SEQ_ST,
        "Pack Leader ST",
        ST_STEPS,
        "S2 Pack Leader ST. Nature Ally weave: Barbed/Cobra between every KC. "
        "Alt=Mend Pet. CotW/trinkets/interrupts manual.",
        "FLIPCYDE_BM_MIDNIGHT_ST_V1",
        "v2:st-natures-ally",
    )
    aoe = build_sequence(
        SEQ_AOE,
        "Pack Leader AoE",
        AOE_STEPS,
        "S2 Pack Leader AoE. Wild Thrash then BW then Thrash, then Barbed/KC weave. "
        "Alt=Mend Pet. CotW/trinkets/interrupts manual.",
        "FLIPCYDE_BM_MIDNIGHT_AOE_V1",
        "v2:aoe-thrash-bw",
    )

    st_export = encode_gse3(st)
    aoe_export = encode_gse3(aoe)
    validate(st_export, b"Bestial Wrath")
    validate(aoe_export, b"Wild Thrash")

    OUT_ST.write_text(st_export + "\n", encoding="ascii")
    OUT_AOE.write_text(aoe_export + "\n", encoding="ascii")
    # Combined file: two lines, import one at a time
    OUT.write_text(st_export + "\n\n" + aoe_export + "\n", encoding="ascii")

    print("Wrote", OUT_ST, "len", len(st_export))
    print("Wrote", OUT_AOE, "len", len(aoe_export))
    print("ST:")
    print(st_export)
    print()
    print("AOE:")
    print(aoe_export)


if __name__ == "__main__":
    main()
