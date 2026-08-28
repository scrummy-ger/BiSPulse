#!/usr/bin/env python3
"""FLIPCYDE BM Hunter GSE → Midnight Season 2 update.

Based on decoded FLIPCYDE_BM_MIDNIGHT_ST_V1 (GSE 3327, single ST panel).
S2 changes:
  - COLLECTION export wrapper for current GSE import
  - GSE Versions format bumped to 3330
  - ST priority tuned for Pack Leader / Nature's Ally KC weave
  - AoE panel: Wild Thrash → BW → Barbed/KC/Cobra priority
  - Interval 3 on action blocks (script limit safety)
  - Alt = Mend Pet (unchanged)
  - CotW, trinkets, interrupts remain manual
"""
from __future__ import annotations

import base64
import zlib
from pathlib import Path

import cbor2

OUT = Path("/workspace/tools/FLIPCYDE_BM_MIDNIGHT_S2_export.txt")
SEQ_NAME = "FLIPCYDE_BM_MIDNIGHT_S2"

# Method Pack Leader 12.1
TALENT_ST = (
    "C0PAAAAAAAAAAAAAAAAAAAAAAAMmxwCsAzwQDbAAYGGzs8AzwMmZMDzMGzMmZGzYGmZGzYGM0MAAAAgZAAAYmZmBYmNCDzCYbAYA"
)
TALENT_MPLUS = (
    "C0PAAAAAAAAAAAAAAAAAAAAAAAMmxwCsBzwQDbAAYGPwMzsMzwMzMjZGMzYmhZGzMzYbmZYMDLDNDAAAAAAAAmHYMzAmZjAmFw2AwA"
)

HELP = (
    "S2 Pack Leader | Nature's Ally: Barbed/Cobra between every KC\n"
    "Alt=Mend Pet | CotW, trinkets, interrupts manual\n"
    "ST: BW → Barbed/KC weave | AoE: Wild Thrash → BW → cleave prio"
)

PET_PREFIX = (
    "/petassist",
    "/petattack [@target,harm,nodead]",
    "/cast [mod:alt,@pet,nodead] Mend Pet",
    "/stopmacro [mod]",
    "/stopmacro [channeling]",
)


def macro(*lines: str) -> bytes:
    text = "\n".join(lines)
    if len(text) > 255:
        raise ValueError(f"macro too long ({len(text)}): {text!r}")
    return text.encode("utf-8")


def pet_cast(spell: str) -> bytes:
    return macro(*PET_PREFIX, spell)


def block(kind: str, body: bytes, interval: int | None = None) -> dict:
    node = {b"Type": kind.encode(), b"type": b"macro", b"macro": body}
    if interval is not None:
        node[b"Interval"] = str(interval).encode()
    return node


def priority_loop(steps: list[str]) -> dict:
    loop: dict = {
        b"Type": b"Loop",
        b"Repeat": 2,
        b"StepFunction": b"Priority",
    }
    for i, spell in enumerate(steps, start=1):
        loop[i] = block("Action", pet_cast(spell), interval=3)
    return loop


# ST: BW first, then strict Barbed/KC/Barbed/KC/Cobra weave (Nature's Ally)
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

# AoE: Wild Thrash for Beast Cleave, then same KC weave (Icy Veins S2 opener)
AOE_STEPS = [
    "/cast Wild Thrash",
    "/cast Bestial Wrath",
    "/cast Barbed Shot",
    "/cast Kill Command",
    "/cast Barbed Shot",
    "/cast Kill Command",
    "/cast Cobra Shot",
    "/cast Kill Command",
    "/cast Cobra Shot",
]


def panel(label: str, steps: list[str]) -> dict:
    return {
        b"Label": label.encode(),
        b"Actions": [priority_loop(steps)],
        b"InbuiltVariables": [],
    }


def build_sequence() -> dict:
    return {
        b"Versions": [
            panel("Pack Leader ST", ST_STEPS),
            panel("Pack Leader AoE", AOE_STEPS),
        ],
        b"WeakAuras": {},
        b"LastUpdated": b"20260828",
        b"MetaData": {
            b"Name": SEQ_NAME.encode(),
            b"Author": b"Flipcyde / PROJECT CYDE / BiSPulse S2",
            b"GSEVersion": 3330,
            b"TOC": 120100,
            b"Help": HELP.encode(),
            b"Default": 1,
            b"SpecID": 253,
            b"ManualIntervention": True,
            b"Helplink": b"https://www.method.gg/guides/beast-mastery-hunter/playstyle-and-rotation",
            b"Talents": {
                b"Pack Leader ST": {
                    b"TalentSet": TALENT_ST.encode(),
                    b"Description": b"Method Pack Leader ST 12.1",
                },
                b"Pack Leader M+": {
                    b"TalentSet": TALENT_MPLUS.encode(),
                    b"Description": b"Method Pack Leader M+ 12.1",
                },
            },
            b"CYDERelease": b"MIDNIGHT_SEASON_2",
            b"CYDESourceName": b"FLIPCYDE_BM_MIDNIGHT_ST_V1",
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
    assert len(seq[b"Versions"]) == 2

    for ver in seq[b"Versions"]:
        loop = ver[b"Actions"][0]
        assert loop[b"StepFunction"] == b"Priority"
        kids = sorted(k for k in loop if isinstance(k, int))
        for k in kids:
            text = loop[k][b"macro"].decode()
            assert len(text) <= 255, f"step {k} too long: {len(text)}"
            assert "/petassist" in text
            assert loop[k][b"Interval"] == b"3"

    st_loop = seq[b"Versions"][0][b"Actions"][0]
    aoe_loop = seq[b"Versions"][1][b"Actions"][0]
    assert b"Bestial Wrath" in st_loop[1][b"macro"]
    assert b"Wild Thrash" in aoe_loop[1][b"macro"]

    print("Wrote", OUT, "len", len(export))
    print("panels:", [v[b"Label"].decode() for v in seq[b"Versions"]])
    print("ST steps:", len([k for k in st_loop if isinstance(k, int)]))
    print("AoE steps:", len([k for k in aoe_loop if isinstance(k, int)]))
    print(export)


if __name__ == "__main__":
    main()
