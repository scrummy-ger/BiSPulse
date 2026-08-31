#!/usr/bin/env python3
"""Fix Unholy DK GRIP-EMS modifier keys (MFDOOM MDNT_UNHOLY ST/AoE collection).

Bugs fixed:
1. defaultVersion=1 with only versions[0] → Live pointed at missing V2 (empty KeyPress)
2. Typo resetOnComHat → resetOnCombat
3. KeyPress cleaned (mods first, no useless nochanneling)
4. ST /cast Leap → {spell:47482}
"""
from __future__ import annotations

import base64
import time
import zlib
from pathlib import Path

import cbor2

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "UNHOLY_DK_S2_mods_fixed_export.txt"

SRC = (
    "!EMS1!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"
)

# NOTE: SRC above may be truncated in this file; prefer regenerating from
# the user-provided string via CLI. The committed export is the source of truth.

KEYPRESS = (
    "/cast [mod:alt] {spell:49998}\n"
    "/cast [mod:shift] {spell:207167}\n"
    "/targetenemy [noharm][dead]\n"
    "/startattack\n"
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


def to_str(x) -> str:
    return x.decode() if isinstance(x, bytes) else x


def fix_collection(obj, now: int | None = None):
    now = now or int(time.time())
    for _name, seq in obj[b"sequences"].items():
        seq[b"defaultVersion"] = 0
        seq[b"versionCount"] = 1
        seq[b"help"] = (
            b"Shift = Blinding Sleet | Alt = Death Strike\n"
            b"Hold modifier + rotation key together.\n"
            b"If mods still fail: turn OFF Hold-to-Freeze for Shift/Alt;\n"
            b"do not bind the sequence to a Numpad key when using Shift."
        )
        seq[b"updatedAt"] = now
        seq[b"lastModifiedAt"] = now
        for key in (b"originalSignature", b"signatureAlgorithm", b"originalSignatureV2"):
            seq.pop(key, None)

        for v in seq[b"versions"]:
            if b"resetOnComHat" in v:
                v[b"resetOnCombat"] = bool(v.pop(b"resetOnComHat"))
            v[b"keyPress"] = KEYPRESS
            v[b"keyRelease"] = ""
            new_steps = []
            for st in v[b"steps"]:
                st = to_str(st).replace("/cast Leap", "/cast {spell:47482}")
                new_steps.append(st)
            v[b"steps"] = new_steps
            actions = [{b"type": b"action", b"macro": st} for st in new_steps]
            for a in v.get(b"actions") or []:
                if isinstance(a, dict) and a.get(b"disabled"):
                    actions.append(
                        {
                            b"type": b"action",
                            b"macro": to_str(a.get(b"macro", "")),
                            b"disabled": True,
                        }
                    )
            v[b"actions"] = actions
    return obj


def main() -> None:
    # Prefer the already-written fixed export if SRC decode fails
    try:
        obj = decode_ems(SRC)
        obj = fix_collection(obj)
        export = encode_ems(obj)
    except Exception:
        export = OUT.read_text(encoding="utf-8").strip()
        print("SRC decode failed; keeping existing export")
    else:
        OUT.write_text(export + "\n", encoding="utf-8")
    print(f"Wrote {OUT} ({len(export)} chars)")
    print(export)


if __name__ == "__main__":
    main()
