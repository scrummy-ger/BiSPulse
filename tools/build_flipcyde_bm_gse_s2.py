#!/usr/bin/env python3
"""Patch Flipcyde BM originals in-place for Midnight S2.

Keeps the exact Flipcyde GSE payload shape (metadata, key order, GSE 3327)
so import matches what already works — only the priority casts change.
"""
from __future__ import annotations

import base64
import zlib
from pathlib import Path

import cbor2

OUT_ST = Path("/workspace/tools/FLIPCYDE_BM_MIDNIGHT_S2_ST.txt")
OUT_AOE = Path("/workspace/tools/FLIPCYDE_BM_MIDNIGHT_S2_AOE.txt")
OUT = Path("/workspace/tools/FLIPCYDE_BM_MIDNIGHT_S2_export.txt")

ORIG_ST = (
    "!GSE3!1VbNbttGEK6TpomNPECa0xxyVGRTBoTEvkQW9UNblASRkW0YBrEiR9ZCy11md6nEQA5Ojvl5"
    "CvdSoEWfpo+SY9EO6ShOgCTtzTVPw5md4TffN+Ds64P77Z43bB66rWjHj3zP7XudbhgFYTR2fvH2kc0b"
    "uWbmrDtGbbiS5tX50JOTnAs7ZpqziUBz1mnEtoz97oanGbo9pbL2CDNk9kYvsJi1c1me6A41V5rb05Xz"
    "VspirQ7er2domTHc2LXStJbFczh6Ypk+QVuZMZ1WpEqQJcdr6zEzFo5SlWwxYStP6PwyBj7KBIZIVYx"
    "VWVm8PHn8hSOeMSlRcHmyrLaDxnImYF8zOyvhty+6cS3ZFyhvLNG+vXK0TE8wgWCm7Dew3lxifXfVWP"
    "e4ENBUacpk8g2wPy7B/nbVYI/mUj2XWzui+GxDa/X8GD572f4PzN+6Tsz/dI1G+vZ1IvbOEuyv/5ORd"
    "rlG+suR5xgu7W1qY6LZ92hfvU60ry3BvrlqsP/Ka6vHJigOHvg8kfxkZiEgQZSEGowdeAkB1RIIYQl3"
    "r0cln2YJs5j0axu1+sYjp75RPl2fmnOZZX+0G7mdKb3fFjyLTxOEdRiOBrutZgjFYu+4OGW5sCs9l1a"
    "yTFDGHM25d7m/236By5x5AT7LKUyusCWnSsdIrGf0jQkXtLU/7HaC1seLwM93/x75TOZMeNKiXqAs2v"
    "zg9lmK37tUtIMMY8+991czHDTv/7Dy54NOF0UWvrCHK6tfpcSUhDy80A+yjzcIiJXGKjSEBZIY08yaT"
    "5JVv9zqwA1wGYs8waQKTUbDpKZgZwj7XCQVsJrLOVpToVPUis6zwk5witLwBZKdqgWm1CF5uclQGKBJ"
    "BGJK5UUG5LbkBzSmjEtIS16qEND08RicWtWBmDJ4oeM2aEriKcKCicJDtBUIpbLUU5oJtFjtF+SNP8U"
    "PIAgbodeMBv3eYeTUIicaPe2Hnt+K+oOwsMuEQOUkWaGAXwhQkF9wvjm6DDZnGM9Nnu4tnK3Nx5vOFG"
    "uP9orwCAVxjuGlWq1GMOhHNdKs+3lWrf64Pqkn038A"
)

ORIG_AOE = (
    "!GSE3!xVVNb9tGEK3b9CNGf0DbXObQnirLkmoYQXKJQlISY4kyRFqyEQTEihyZCy932d2lUgM5uP0r"
    "7rXIr8lPyTFoZ+nYcYA6JwfmhYOZHb2384ZPfx0+GIzDfe/ID9Knk3QS+lE4HCVpfxqk8+7f4QLZSb/"
    "WzJyN5qgNV9L8eb4fymXNhZ0zzdlSoDkb9jPb1P7xk9MK/bFS1WCGFTK7MY4tVoNaNidG+5orze3pxn"
    "lQskyrw4PtCi0zhhu72YTWsuwEnj+xTB+jbRVMly2pcmT5i81tY1XV9MHzrGBSouDymPIZMxYWXOSQF"
    "MS2aGgMLlj5luILtC8vUee3h7rHhQBPlSWT+Q2wX32Gyz5leok5xIWyN6Deu0Rd3CIqGsuZgIVm9qYh"
    "f30n0n5zN9J+eyfSfndH0t6/xE1uD9fnGgmcwhtANz8DqKeWmn1qwsGYLVEc/jLhueTHhYWYGCoJPZh"
    "34RX0VQC9XyFpgM3emH7zoMqZxTzqdXq7nYfd3U7zjCbE02eWvR70a1sovRgIXmWnOcI27M+mzwIvAW"
    "e/Qx9XrBbklz75psxRZhzNefjBZAcTR8ychTH+XlOZUkkgV0pnSDtaEcaSC7LWt8+GcfDerX/8/t/Zh"
    "MmaiVBa1GuU7p5v/YiV+EnrH8QVZqH/wzsvmXo/fbHx5ufhCEWV/GGPNl7871DsS7VVidpsXagB1Xun"
    "h0xpbF//glsffVit6/sOlPh4E0FjhnyN9HZ/J3SOZMeysubxNRWBG7AFglAvqXnrCnvFuNiyhVb1cdE"
    "GjxGsWjUnHZ8WWM3lCSnYAu7mo+vKxTmuUBoCpbhUayxpbJTlpkJhGoo0flW7DqhtM3SiVzIuoWyG3Y"
    "aYtpNn0O21u5BRB3fL8Rg0NfESYc2Ey5AWjrmkC2QkoUCL7cgpMr+qH0Kc9JPQS6fR+Cjt9tJuOjuIk"
    "nASpNE0cXHTEKua9sDJGjlVnaKNkLuzD1WvwOzE1OXeuvtotUSGvZ2He648Q0FCYnK1A3HQj6dR2qNF"
    "GF3v2ll2fmM7u53/AA=="
)

# ST prefix from original (includes Alt Mend Pet)
ST_PREFIX = (
    "/petassist\n"
    "/petattack [@target,harm,nodead]\n"
    "/cast [mod:alt,@pet,nodead] Mend Pet\n"
    "/stopmacro [mod]\n"
    "/stopmacro [channeling]\n"
)

# AoE gets same Mend Pet treatment as ST for consistency
AOE_PREFIX = ST_PREFIX

# ST: keep Flipcyde 10-step length; ensure Nature's Ally weave (already mostly correct)
ST_CASTS = [
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
]

# AoE: 10 steps like original; Thrash before BW; weave between KC
AOE_CASTS = [
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
]


def decode(s: str):
    return cbor2.loads(zlib.decompress(base64.b64decode(s[6:]), -15))


def encode(obj) -> str:
    raw = cbor2.dumps(obj)
    c = zlib.compressobj(9, zlib.DEFLATED, -15)
    return "!GSE3!" + base64.b64encode(c.compress(raw) + c.flush()).decode("ascii")


def make_action(prefix: str, cast: str) -> dict:
    text = prefix + cast
    assert len(text) <= 255, len(text)
    return {
        b"macro": text.encode("utf-8"),
        b"Type": b"Action",
        b"type": b"macro",
    }


def patch(orig: str, new_name: str, label: str, prefix: str, casts: list[str], help_txt: str) -> str:
    name, seq = decode(orig)
    assert isinstance(name, bytes)

    # Rename
    seq[b"MetaData"][b"Name"] = new_name.encode("ascii")
    seq[b"MetaData"][b"HelpTxt"] = help_txt.encode("ascii")
    seq[b"MetaData"][b"Author"] = b"Flipcyde / PROJECT CYDE / BiSPulse S2"
    seq[b"MetaData"][b"CYDERelease"] = b"MIDNIGHT_SEASON_2"
    seq[b"MetaData"][b"CYDEValidation"] = b"STATIC_ONLY_12_1"
    # Keep GSEVersion from original (3327) — proven importable
    seq[b"LastUpdated"] = b"20260828000000"

    ver = seq[b"Versions"][0]
    ver[b"Label"] = label.encode("ascii")
    loop = ver[b"Actions"][0]
    assert loop[b"Type"] == b"Loop"

    # Remove old int steps, write new ones (same count as casts)
    for k in list(loop.keys()):
        if isinstance(k, int):
            del loop[k]
    for i, cast in enumerate(casts, start=1):
        loop[i] = make_action(prefix, cast)

    payload = [new_name.encode("ascii"), seq]
    export = encode(payload)

    # Validate round-trip
    n2, s2 = decode(export)
    assert n2 == new_name.encode("ascii")
    loop2 = s2[b"Versions"][0][b"Actions"][0]
    kids = sorted(k for k in loop2 if isinstance(k, int))
    assert kids == list(range(1, len(casts) + 1))
    prev_kc = False
    for k in kids:
        last = loop2[k][b"macro"].decode().split("\n")[-1]
        assert last == casts[k - 1]
        is_kc = last == "/cast Kill Command"
        assert not (prev_kc and is_kc)
        prev_kc = is_kc
        assert len(loop2[k][b"macro"]) <= 255
    return export


def main() -> None:
    st = patch(
        ORIG_ST,
        "FLIPCYDE_BM_MIDNIGHT_S2_ST",
        "Midnight Season 2 | Single Target",
        ST_PREFIX,
        ST_CASTS,
        "S2 Pack Leader ST. Nature Ally: Barbed/Cobra between every KC. "
        "Alt=Mend Pet. CotW/trinkets/interrupts manual.",
    )
    aoe = patch(
        ORIG_AOE,
        "FLIPCYDE_BM_MIDNIGHT_S2_AOE",
        "Midnight Season 2 | AoE 2+ Targets",
        AOE_PREFIX,
        AOE_CASTS,
        "S2 Pack Leader AoE. Wild Thrash, then BW, then Thrash, then Barbed/KC weave. "
        "Alt=Mend Pet. CotW/trinkets/interrupts manual.",
    )

    OUT_ST.write_text(st + "\n", encoding="ascii")
    OUT_AOE.write_text(aoe + "\n", encoding="ascii")
    OUT.write_text(st + "\n\n" + aoe + "\n", encoding="ascii")

    print("ST len", len(st))
    print(st)
    print()
    print("AOE len", len(aoe))
    print(aoe)


if __name__ == "__main__":
    main()
