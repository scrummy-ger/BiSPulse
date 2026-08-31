#!/usr/bin/env python3
"""Build Assassination Rogue GRIP-EMS imports for Midnight Season 2 (Deathstalker).

Native !EMS1! format, Deflate level 6 (GRIP-compatible).

Design notes (why not Garrote-first Priority):
  Garrote and Rupture have no real cooldown — if they sit at the top of a
  Priority list, GRIP will spam them every GCD whenever you have Energy and
  never reach Envenom/builders. Same trap for Crimson Tempest in AoE.

  Sustain Priority only uses spells gated by CP or a real CD.
  Bleeds live on Ctrl (castsequence). Burst CDs live on Alt.
"""
from __future__ import annotations

import base64
import time
import zlib
from pathlib import Path

import cbor2

ROOT = Path(__file__).resolve().parent

# Spell IDs
GARROTE = 703
RUPTURE = 1943
ENVENOM = 32645
MUTILATE = 1329
AMBUSH = 8676
FOK = 51723
CRIMSON = 121411
DEATHMARK = 360194
KINGSBANE = 385627
VANISH = 1856
THISTLE = 381623
SHIV = 5938
KICK = 1766

# Shift = interrupt (CD-gated)
# Alt = Deathstalker burst package (all CD-gated; safe to hold)
# Ctrl = bleed maintain via castsequence (tap/hold briefly — do not park on Ctrl)
KEYPRESS_ST = (
    f"/cast [mod:shift] {{spell:{KICK}}}\n"
    f"/cast [mod:alt] {{spell:{VANISH}}}\n"
    f"/cast [mod:alt] {{spell:{DEATHMARK}}}\n"
    "/use [mod:alt] 13\n"
    "/use [mod:alt] 14\n"
    f"/cast [mod:alt] {{spell:{KINGSBANE}}}\n"
    f"/cast [mod:alt] {{spell:{THISTLE}}}\n"
    f"/castsequence [mod:ctrl] reset=combat/15 {{spell:{GARROTE}}}, {{spell:{RUPTURE}}}\n"
    "/startattack\n"
    "/targetenemy [noharm][dead]"
)

KEYPRESS_AOE = (
    f"/cast [mod:shift] {{spell:{KICK}}}\n"
    f"/cast [mod:alt] {{spell:{VANISH}}}\n"
    f"/cast [mod:alt] {{spell:{DEATHMARK}}}\n"
    "/use [mod:alt] 13\n"
    "/use [mod:alt] 14\n"
    f"/cast [mod:alt] {{spell:{KINGSBANE}}}\n"
    f"/cast [mod:alt] {{spell:{THISTLE}}}\n"
    f"/castsequence [mod:ctrl] reset=combat/15 {{spell:{GARROTE}}}, "
    f"{{spell:{CRIMSON}}}, {{spell:{RUPTURE}}}\n"
    "/startattack\n"
    "/targetenemy [noharm][dead]"
)

# CP/CD-gated only — Envenom needs CP; Ambush needs Blindside/stealth; Shiv has CD
STEPS_ST = [
    f"/cast [nochanneling] {{spell:{ENVENOM}}}",
    f"/cast [nochanneling] {{spell:{AMBUSH}}}",
    f"/cast [nochanneling] {{spell:{MUTILATE}}}",
    f"/cast [nochanneling] {{spell:{SHIV}}}",
]

STEPS_AOE = [
    f"/cast [nochanneling] {{spell:{ENVENOM}}}",
    f"/cast [nochanneling] {{spell:{FOK}}}",
    f"/cast [nochanneling] {{spell:{AMBUSH}}}",
    f"/cast [nochanneling] {{spell:{MUTILATE}}}",
    f"/cast [nochanneling] {{spell:{SHIV}}}",
]

HELP = (
    b"Spam = Envenom/builders only (Garrote-first Priority is a DPS trap).\n"
    b"Shift=Kick | Alt=Vanish+Deathmark+Kingsbane+Thistle+trinkets\n"
    b"Ctrl=Bleeds (ST: Garrote>Rupture | AoE: Garrote>Crimson>Rupture)\n"
    b"Burst: Alt -> quick Ctrl Garrote (Improved) -> spam | Feint manual\n"
    b"100ms + auto-adjust. Deathstalker S2."
)

DESC = (
    b"Deathstalker Assassination Rogue Midnight S2 v2. "
    b"Sustain Priority + Alt burst + Ctrl bleeds. Icy Veins/Method 12.1."
)


def encode_ems(obj) -> str:
    buf = cbor2.dumps(obj)
    c = zlib.compressobj(6, zlib.DEFLATED, -15)
    return "!EMS1!" + base64.b64encode(c.compress(buf) + c.flush()).decode("ascii")


def base_sequence(now: int) -> dict:
    return {
        b"description": DESC,
        b"help": HELP,
        b"helplink": b"https://www.icy-veins.com/wow/assassination-rogue-pve-dps-rotation-cooldowns-abilities",
        b"icon": b"ability_rogue_deadlybrew",
        b"author": b"BiSPulse",
        b"originalAuthor": b"BiSPulse",
        b"lastModifier": b"BiSPulse",
        b"classID": 4,
        b"defaultVersion": 0,
        b"createdAt": now,
        b"updatedAt": now,
        b"lastModifiedAt": now,
        b"privacyMode": b"public",
        b"provenanceSource": b"native",
        b"contextOverrides": [],
        b"versions": [],
    }


def make_version(steps: list[str], keypress: str) -> dict:
    return {
        b"resetTimer": 0,
        b"resetOnSpec": False,
        b"resetOnTarget": False,
        b"resetOnCombat": False,
        b"resetOnGear": False,
        b"keyRelease": "",
        b"keyPress": keypress,
        b"stepFunction": "Priority",
        b"stepLabels": [],
        b"steps": steps,
    }


def wrap(name: bytes, seq: dict) -> dict:
    return {
        b"locale": b"enUS",
        b"version": 5,
        b"format": b"GRIP-EMS",
        b"sequence": seq,
        b"name": name,
    }


def main() -> None:
    now = int(time.time())

    # Combined 2-version
    seq = base_sequence(now)
    seq[b"versions"] = [
        make_version(STEPS_ST, KEYPRESS_ST),
        make_version(STEPS_AOE, KEYPRESS_AOE),
    ]
    combined = encode_ems(wrap(b"ASSA_S2_Deathstalker_v1", seq))
    (ROOT / "ASSA_S2_Deathstalker_v1_export.txt").write_text(combined + "\n")

    # Separate keybindable ST / AoE
    for name, steps, kp in [
        (b"ASSA_S2_ST_v1", STEPS_ST, KEYPRESS_ST),
        (b"ASSA_S2_AOE_v1", STEPS_AOE, KEYPRESS_AOE),
    ]:
        s = base_sequence(now)
        s[b"versions"] = [make_version(steps, kp)]
        s[b"defaultVersion"] = 0
        export = encode_ems(wrap(name, s))
        (ROOT / f"{name.decode()}_export.txt").write_text(export + "\n")
        print(name.decode(), len(export))

    print("combined", len(combined))


if __name__ == "__main__":
    main()
