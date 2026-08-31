#!/usr/bin/env python3
"""Build Assassination Rogue GRIP-EMS imports for Midnight Season 2 (Deathstalker).

Native !EMS1! format, Deflate level 6 (GRIP-compatible).
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
FEINT = 1966

KEYPRESS = (
    f"/cast [mod:shift] {{spell:{KICK}}}\n"
    f"/cast [mod:alt] {{spell:{VANISH}}}\n"
    f"/cast [mod:ctrl] {{spell:{FEINT}}}\n"
    "/startattack\n"
    "/targetenemy [noharm][dead]"
)

# Bleeds before Envenom so one-button keeps DoTs up (tradeoff vs perfect Envenom chaining)
STEPS_ST = [
    f"/cast [nochanneling] {{spell:{GARROTE}}}",
    f"/cast [nochanneling] {{spell:{DEATHMARK}}}\n/use 13\n/use 14",
    f"/cast [nochanneling] {{spell:{KINGSBANE}}}\n/cast {{spell:{THISTLE}}}",
    f"/cast [nochanneling] {{spell:{RUPTURE}}}",
    f"/cast [nochanneling] {{spell:{ENVENOM}}}",
    f"/cast [nochanneling] {{spell:{SHIV}}}",
    f"/cast [nochanneling] {{spell:{AMBUSH}}}",
    f"/cast [nochanneling] {{spell:{MUTILATE}}}",
]

STEPS_AOE = [
    f"/cast [nochanneling] {{spell:{GARROTE}}}",
    f"/cast [nochanneling] {{spell:{DEATHMARK}}}\n/use 13\n/use 14",
    f"/cast [nochanneling] {{spell:{KINGSBANE}}}\n/cast {{spell:{THISTLE}}}",
    f"/cast [nochanneling] {{spell:{CRIMSON}}}",
    f"/cast [nochanneling] {{spell:{RUPTURE}}}",
    f"/cast [nochanneling] {{spell:{ENVENOM}}}",
    f"/cast [nochanneling] {{spell:{FOK}}}",
    f"/cast [nochanneling] {{spell:{MUTILATE}}}",
]

HELP = (
    b"Shift=Kick | Alt=Vanish (Improved Garrote before Deathmark) | Ctrl=Feint\n"
    b"V1=ST | V2=AoE | Open from Stealth with Garrote\n"
    b"Burst: Alt Vanish -> Garrote -> hold key for Deathmark/Kingsbane\n"
    b"100ms + auto-adjust. Deathstalker recommended S2."
)

DESC = (
    b"Deathstalker Assassination Rogue Midnight S2. Priority ST/AoE. "
    b"Based on Icy Veins / Method 12.1 for GRIP-EMS."
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


def make_version(steps: list[str]) -> dict:
    return {
        b"resetTimer": 0,
        b"resetOnSpec": False,
        b"resetOnTarget": False,
        b"resetOnCombat": False,
        b"resetOnGear": False,
        b"keyRelease": "",
        b"keyPress": KEYPRESS,
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
    seq[b"versions"] = [make_version(STEPS_ST), make_version(STEPS_AOE)]
    combined = encode_ems(wrap(b"ASSA_S2_Deathstalker_v1", seq))
    (ROOT / "ASSA_S2_Deathstalker_v1_export.txt").write_text(combined + "\n")

    # Separate keybindable ST / AoE
    for name, steps in [
        (b"ASSA_S2_ST_v1", STEPS_ST),
        (b"ASSA_S2_AOE_v1", STEPS_AOE),
    ]:
        s = base_sequence(now)
        s[b"versions"] = [make_version(steps)]
        s[b"defaultVersion"] = 0
        export = encode_ems(wrap(name, s))
        (ROOT / f"{name.decode()}_export.txt").write_text(export + "\n")
        print(name.decode(), len(export))

    print("combined", len(combined))
    print(combined)


if __name__ == "__main__":
    main()
