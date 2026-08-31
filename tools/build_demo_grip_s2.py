#!/usr/bin/env python3
"""Rebuild Demonology Warlock GRIP-EMS import from MFDOOM LazyGrip base.

Optimizations for Midnight Season 2 (12.1 Diabolist):
- Priority instead of Sequential
- Grimoire before Tyrant (extend big demons)
- Demonbolt in the rotation (not only Ctrl)
- Trinkets fire with Tyrant
- Keep V1 Imp Lord / V2 Fel Ravager split

GRIP-EMS encode: base64 -> raw Deflate level 6 -> CBOR
"""
from __future__ import annotations

import base64
import time
import zlib
from pathlib import Path

import cbor2

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "DEMO_S2_Diabolist_v2_export.txt"

# LazyGrip MFDOOM Demo Warlock (working reference)
MFDOOM_EMS = (
    "!EMS1!7Zg/b9tGFMDToUMzdnMnAu3QwbFJSqQoZ7FiWn9sUbItxxYQBMLx7lG8irxj745uhcJA0ClLt36FFOi/pVOHAv0C/Q4Fii5dMnno2CMjG7Kc1ikQhCjQSeDxvfd7790T77171k44Rgn4wB6OOmcgJOXs7XbERYpUt3PUO7i3G4y6Ej7OgWH4cW2fgMSCZkrLjcOAEkansTJ8SDnjCZ/OjVMktM2ZESAs+IbR5sKIIcnWjTCnCZHrBmLEEIB5mgIjQIxUbhmxUpnc2tyMeS6BR2mhKze0zIALOqUMJa1cxVy0g7Y/HAY9LAApIC313kcbX//qF4DxB6OYRsq4Z4xiRPgnUS7mxo4SiV4p3TMe8ER1C9GEstl47W+ZR5JOGVK5gFYy1XwVp0Gr35mcWJNRt2U7bi/PyBX++zWfYs4e9gYnk4BKPDnMQRbpCZCYHWSCnwFDOncjngsMbW2YnsGB1lDwqRrqlAuqc/pkPxP0DOF5wAn0Mwk54WyeateClBMaURA7MaLsy2cPUBn0c5+hFBb58GeUkc4iKV1tjymq5uNt10aoHiKCopqHATzLJE69FoHpOCQMwWrYphVZjchyorCGvSYhDah7bmiTemQ2I3dXW0zSTkv/GI59if7zBroNhL4B8rfdysinlZHTyshfVEb+qjLyT5WRf6mM/Htl5D+qIn93pzLyu5WRP6yM7FRGvl8Z+YfKyD9XRv6tKrJuwt40eZAgqYIXvdllJ3i4tCaOlqW7i95afv7NngAJ6pimIO7sSgWZfDp+fxNrTeMR4zhGjIHuUKePjc9kBkmyZTVdu9E4v0XIrNcs9xYh23Us73ZLjtWon48nLxFa307LbllHs1529Uy3q4hc6XpNz/TO768qZQmag1iRGq+/FLAia9kNt+6Yr+iz8U9Cruee75fJH7JRBvgiWDwcIzEFdfW4w9MQqYu9GcyPIAEkYbtf7FM7Z7ho7PdG5TikKEr2ivU+CiGRT3u9NEt4scmBrzedSIWSmd71QTl9UGwczwViatAtBiAeGZ08IYjtj7SLoKelKcVdbcHoc0FuyJQTTTnAXAbQASQuutrFA70gx2wRuB4WtmQxB91IZM20vdr53SU5rIejpdKoWw1Pv1dlMoBBOi/yGCORPn5UbvLdzQwUUgrh2X+miE9vK2Id3moRW03HdFaLeOXtvyhe91V9/b9430zxdrD+TMue/87x8ue699rOiWHExQxIW/C0nNmfHF5eYowuLxbG204DW5Y2Vou8iITYrIHjhlZom2GjaXuaYDug/w6kHnrYClFkm7aL60h7gyzLC53R9YuRa4dNGy1flvSXo1ysnVzXfn2xX4W6s3xD83xAIEJ5ok5enIJvlaf1IPAHxxN/NxgOJuaG9Rc="
)

IMPLOSION = 196277
DREADSTALKERS = 104316
TYRANT = 265187
HOG = 105174
SINGE = 89808
IMP_LORD = 1276452
SHADOW_BOLT = 686
DEVOUR_MAGIC = 19505
FEL_RAVAGER = 1276467
SHADOWFURY = 30283
DEMONBOLT = 264178

STEPS_V1 = [
    f"/cast [nochanneling,@player] {{spell:{IMP_LORD}}}",
    f"/cast [nochanneling] {{spell:{DREADSTALKERS}}}",
    f"/cast [nochanneling] {{spell:{TYRANT}}}\n/use 13\n/use 14",
    f"/cast [nochanneling] {{spell:{IMPLOSION}}}",
    f"/cast [nochanneling] {{spell:{HOG}}}",
    f"/cast [nochanneling] {{spell:{DEMONBOLT}}}",
    f"/cast [nochanneling,@mouseover,help,nodead] {{spell:{SINGE}}}; [nochanneling,@player] {{spell:{SINGE}}}",
    f"/cast [nochanneling] {{spell:{SHADOW_BOLT}}}",
]

STEPS_V2 = [
    f"/cast [nochanneling,@player] {{spell:{FEL_RAVAGER}}}",
    f"/cast [nochanneling] {{spell:{DREADSTALKERS}}}",
    f"/cast [nochanneling] {{spell:{TYRANT}}}\n/use 13\n/use 14",
    f"/cast [nochanneling] {{spell:{IMPLOSION}}}",
    f"/cast [nochanneling] {{spell:{HOG}}}",
    f"/cast [nochanneling] {{spell:{DEMONBOLT}}}",
    f"/cast [nochanneling,@mouseover,harm,nodead] {{spell:{DEVOUR_MAGIC}}}; [nochanneling] {{spell:{DEVOUR_MAGIC}}}",
    f"/cast [nochanneling] {{spell:{SHADOW_BOLT}}}",
]

KEYPRESS = (
    f"/cast [mod:shift,@player] {{spell:{SHADOWFURY}}}\n"
    f"/cast [mod:ctrl] {{spell:{DEMONBOLT}}}\n"
    "/targetenemy [noharm][dead]\n"
    "/petattack"
)


def decode_ems(s: str):
    raw = s.replace("!EMS1!", "").strip()
    data = base64.b64decode(raw + "=" * ((-len(raw)) % 4))
    return cbor2.loads(zlib.decompress(data, -15))


def encode_ems(obj) -> str:
    buf = cbor2.dumps(obj)
    c = zlib.compressobj(6, zlib.DEFLATED, -15)
    return "!EMS1!" + base64.b64encode(c.compress(buf) + c.flush()).decode("ascii")


def main() -> None:
    obj = decode_ems(MFDOOM_EMS)
    seq = obj[b"sequence"]
    now = int(time.time())

    for v in seq[b"versions"]:
        v[b"stepFunction"] = "Priority"
        v[b"keyPress"] = KEYPRESS
        v[b"keyRelease"] = ""

    seq[b"versions"][0][b"steps"] = STEPS_V1
    seq[b"versions"][1][b"steps"] = STEPS_V2
    seq[b"defaultVersion"] = 0

    obj[b"name"] = b"DEMO_S2_Diabolist_v2"
    seq[b"help"] = (
        b"Shift=Shadowfury | Ctrl=Demonbolt (force)\n"
        b"V1=Imp Lord+Singe Magic | V2=Fel Ravager+Devour Magic\n"
        b"Priority: Grimoire>Dreadstalkers>Tyrant+Trinkets>Implosion>HoG>Demonbolt>Utility>Shadow Bolt\n"
        b"100ms + auto-adjust. Skip Tyrant on dying packs by briefly releasing the key."
    )
    seq[b"description"] = (
        b"Diabolist Demo M+/Raid S2. Based on MFDOOM with Tyrant setup fixed "
        b"(Grimoire before Tyrant), Demonbolt in rotation, Priority. Patch 12.1."
    )
    seq[b"updatedAt"] = now
    seq[b"lastModifiedAt"] = now
    for key in (b"originalSignature", b"signatureAlgorithm"):
        seq.pop(key, None)

    export = encode_ems(obj)
    OUT.write_text(export + "\n", encoding="utf-8")
    print(f"Wrote {OUT} ({len(export)} chars)")
    print(export)


if __name__ == "__main__":
    main()
