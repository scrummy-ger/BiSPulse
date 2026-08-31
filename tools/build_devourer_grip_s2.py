#!/usr/bin/env python3
"""Rebuild Devourer DH GRIP-EMS import from MFDOOM base (LazyGrip #1207).

GRIP-EMS uses: base64 -> raw Deflate (level 6) -> CBOR.
"""
from __future__ import annotations

import base64
import zlib
from pathlib import Path

try:
    import cbor2
except ImportError:
    raise SystemExit("pip install cbor2")

ROOT = Path(__file__).resolve().parent
MFDOOM_URL = "https://lazygrip.net/sequences/1207-mfdoom-devourer-demon-hunter-mql7isti"
OUT = ROOT / "DEVOURER_S2_Simple_v2_export.txt"

# LazyGrip MFDOOM Annihilator M+ (working reference import)
MFDOOM_EMS = (
    "!EMS1!3Zm/byNFFMehOIqIkuIOmpUACbjcxfvTdqr44vhHkrUdO7EMp8ianX0bD5nd2ZuZtbC4SBFCR8uvQ4dEew2CHgoahERDQYH4AxASEhQ01wANs459OFJykdCJkahWM37z/bwfuyPrvfs1yjCiUIVkr1cfAxeEJZdqEeMxko16t9m5tuH3GgJuZZBg+OLKVggCc5JKZTfYqjFuiCxNGZcQGiIFLJaNICM0VE+UhIbfM1IKSIAxJoLIVWMkZSpWV1ZGLBPAohhhzsR1zOIW4+SAJIhWMjlivObXqu2238QckNKuyGdff+bddnUENB3c6o1IJI1rRo9l1GjGMaMo98eo0Hy3z4gCg0Qx4+mICSKMdcnp/JcWGyPjpf5JqIZlsIROlo352jSUecpByokRcESSEFD4ciPnUpIcDq6cG0BXkIMEyYxDhR6oYOQo9ivb9WHfHPYaFcv1mlkazmNxb39ZJZgle81Wf+gTgYc7GYg8CB/xw07K2RgSpDKuQuQYakqYjKGjTkh4Q7ZVoThRlTjeSjkZIzzxWQi1NAsowX7MQhIR4Osj5f69q/dvoGnygmqCYpjltXqoIqvPkttQUokkcjJY8yyEnACFKLJLGKBkFkLXsSMouG4YBGAWrYIZmcXIdKPAxqVyGBbBKXmBFTpRoRx5G0qRxjuqEMARNnyWJVJ5IWZOvPf51IkbHTx1oAYh+U/57z+lmf+KZv6revkfvKaX/2FXM/8vvfy7A818oZf/0SXN/LpmfqqZf6yZ/45m/l3N/D/08u/d0cv/ONHMv62Z/41e/idfaeZ/rZn/rWb+d5r532vm/6CZ/5Nm/i+a+b9p5v+ulX95+0fN/J8183/VzP9TL99/UjNfb//jsr+kmf+iZn5DM9/XzNfbf8m7rnr4LYqE9E8as/MG8M7CHu+efa4xa8mLtz7d5CBA7pIY+BMbQkIq7gycFaw0jJsJwyOUJEBJcrBvvClSoHTVtBzXMa2jpZVMgGHas6czeOGCU2bZLh4Nrp5htbyWUjQB/o91qViylPHzj5J0inbRKh1dxLW8glm+WMrzrKOtaS7aSS8F/MCfLXYRPwD5cLnO4gDJB5uHMOnCdAaxtp2nrZYlOG+0Nzqc5G36yWa+u40CoOJ4LlwHxB801NGO2hCD51bkVBwSiCe5ayPE4/2b+Wxg/4zCvP0vC/M/z+JnM59iFq6KfISz/Mg3cGnBHNHTxue9iItnsOT0PIKtEK6yPr+sdaw+T9GsPr27+Jk2H9tN0Y4YP4Swxlk8HdQc78wHYL35HGmwVnJsy3WDsml6UcGxnUK5jG2ECmYAtmki7DpW4Nqh53lOVC474EUBeGHkBdhxCpYT9E4P1c65ZGpoceS2vRivuin7pzUeXwYeBry+OOMLWiFEKKNyNpE7+ce041dbu8PqRr+9193oDgvXzb8B"
)

STEPS_V2 = [
    "/cast [nochanneling] {spell:1221162}",  # Collapsing Star
    "/cast [nochanneling] {spell:473728}",  # Void Ray
    "/cast [nochanneling] Devour",
    "/cast [nochanneling] {spell:1226019}",  # Reap / Eradicate proc
    "/cast [nochanneling] {spell:1245412}",  # Voidblade
    "/cast [nochanneling] {spell:473662}",  # Consume
]

KEYPRESS_V2 = (
    "/cast [mod:alt,nochanneling,@player] {spell:473671}\n"
    "/use [mod:alt] 13\n"
    "/use [mod:alt] 14\n"
    "/cast [mod:shift,nochanneling] {spell:1241937}\n"
    "/cast [mod:ctrl,nochanneling] {spell:1234195}\n"
    "/targetenemy [noharm][dead]"
)


def decode_ems(s: str) -> bytes:
    raw = s.replace("!EMS1!", "").strip()
    data = base64.b64decode(raw + "=" * ((-len(raw)) % 4))
    return zlib.decompress(data, -15)


def encode_ems(buf: bytes) -> str:
    # GRIP-EMS matches zlib level 6 raw deflate on unchanged payloads.
    c = zlib.compressobj(6, zlib.DEFLATED, -15)
    compressed = c.compress(buf) + c.flush()
    return "!EMS1!" + base64.b64encode(compressed).decode("ascii")


def main() -> None:
    obj = cbor2.loads(decode_ems(MFDOOM_EMS))
    seq = obj[b"sequence"]

    seq[b"versions"][1][b"steps"] = STEPS_V2
    seq[b"versions"][1][b"keyPress"] = KEYPRESS_V2
    seq[b"defaultVersion"] = 1  # Version 2 (manual burst)
    obj[b"name"] = b"DEVOURER_S2_Simple_v2"
    seq[b"help"] = (
        b"Alt=Void Meta+Trinkets | Shift=Soul Immolation | Ctrl=Void Nova (interrupt)\n"
        b"Hold rotation key. Alt at ~50 Souls. 100ms + auto-adjust click rate."
    )
    seq[b"description"] = (
        b"Simplified Annihilator M+ priority based on MFDOOM. "
        b"Manual Meta, Collapsing Star first. Patch 12.1."
    )
    # Edited payload: drop auth signature from source export.
    for key in (b"originalSignature", b"signatureAlgorithm"):
        seq.pop(key, None)

    export = encode_ems(cbor2.dumps(obj))
    OUT.write_text(export + "\n", encoding="utf-8")
    print(f"Wrote {OUT} ({len(export)} chars)")
    print(export)


if __name__ == "__main__":
    main()
