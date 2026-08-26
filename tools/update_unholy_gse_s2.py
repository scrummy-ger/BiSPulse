"""Update Orbalisk Wight King Unholy DK GSE (v3.7) for Midnight Season 2 / 12.1.

S2 changes vs 3.7:
- Putrefy raised in priority (spend during Dark Transformation)
- Soul Reaper raised (Reaping procs from DT)
- AoE: more Epidemic; Death and Decay for Cycle of Death builds
- Version 3.7 -> 4.0; help text updated for S2 talents
- Mods unchanged

Source: https://wowlazymacros.com/t/orbalisks-wight-king-pvp-mythic-v-3-7-updated-03-06-26/59777
"""
from __future__ import annotations

import base64
import zlib
from pathlib import Path

OUT = Path("/workspace/tools")
SRC = OUT / "_unholy_payload.txt"

MIND_FREEZE = 47528
DEATH_STRIKE = 49998
ARMY = 42650
DARK_TRANS = 1233448
PUTREFY = 1247378
OUTBREAK = 77575
FESTERING = 316239
SCOURGE = 55090
DEATH_COIL = 47541
EPIDEMIC = 207317
SOUL_REAPER = 343294
RAISE_DEAD = 46585
DEATH_GRIP = 49576
CHAINS = 45524
BLINDING_SLEET = 207167
DEATH_AND_DECAY = 43265

TALENT_S2_ST = (
    "CwPAAAAAAAAAAAAAAAAAAAAAAAwMjZMzYY2mZmZa2MzMjZAAAAAAAAg5BGGDAWmhZ2MzYmZMwAzYRjlFAbD2AwMAmZmZGzgZGMjxA"
)
TALENT_S2_MPLUS = (
    "CwPAAAAAAAAAAAAAAAAAAAAAAAwMjZMzYY2mZmZa2MzMjZAAAAAAAAg5BGDDAWmhZ2MzYMjBGYGLassAYbwGGwMAmZmZGzgZGMjxA"
)


def decode_gse3(s: str) -> bytes:
    raw = s.replace("!GSE3!", "").strip()
    data = base64.b64decode(raw + "=" * ((-len(raw)) % 4))
    return zlib.decompress(data, -15)


def encode_gse3(buf: bytes) -> str:
    c = zlib.compressobj(9, zlib.DEFLATED, -15)
    return "!GSE3!" + base64.b64encode(c.compress(buf) + c.flush()).decode("ascii")


def fit(text: str, length: int) -> bytes:
    text = text.replace("\r\n", "\n").rstrip("\n")
    candidates = [text]
    lines = text.split("\n")
    for drop in (
        "/targetenemy [noharm][dead]",
        "/startattack",
        "/petattack",
        "/use Horde's Might Firework",
        "/use Lion's Pride Firework",
        "/use The Flag of Ownership",
        "/use [combat]  14",
    ):
        lines = [ln for ln in lines if ln != drop]
        candidates.append("\n".join(lines))
    casts = [
        ln
        for ln in text.split("\n")
        if ln.startswith("/cast") or ln.startswith("/castsequence") or ln.startswith("/use")
    ]
    if casts:
        candidates.append("\n".join(casts))
        candidates.append("\n".join(casts[-2:]))
        candidates.append(casts[-1])
    for cand in candidates:
        raw = cand.encode("utf-8")
        if len(raw) <= length:
            return raw + b"\n" * (length - len(raw))
    return candidates[-1].encode("utf-8")[:length].ljust(length, b"\n")


def mods_pve_army() -> str:
    return (
        f"/cast [mod:shift] {MIND_FREEZE}\n"
        f"/cast [mod:lalt] {DEATH_STRIKE}\n"
        f"/cast [mod:ctrl] {ARMY}\n"
    )


def mods_pvp() -> str:
    return (
        f"/cast [mod:shift] {MIND_FREEZE}\n"
        f"/cast [mod:ctrl,@mouseover,exists] {DEATH_GRIP}\n"
        f"/cast [mod:lalt] {CHAINS}\n"
    )


def hdr() -> str:
    return "/targetenemy [noharm][dead]\n/startattack\n/petattack\n"


def extract_macros(buf: bytes):
    parts = []
    macros = []
    i = 0
    while True:
        j = buf.find(b"EmacroX", i)
        if j < 0:
            parts.append(("raw", buf[i:]))
            break
        parts.append(("raw", buf[i:j]))
        pos = j + 7
        ln = buf[pos]
        body = buf[pos + 1 : pos + 1 + ln]
        macros.append((ln, body))
        parts.append(("macro", ln, body))
        i = pos + 1 + ln
    return parts, macros


def rebuild(parts, new_bodies: dict[int, bytes]) -> bytes:
    out = bytearray()
    mi = 0
    for p in parts:
        if p[0] == "raw":
            out += p[1]
        else:
            ln = p[1]
            body = new_bodies[mi]
            assert len(body) == ln, (mi, len(body), ln)
            out += b"EmacroX" + bytes([ln]) + body
            mi += 1
    return bytes(out)


def patch_macros(buf: bytes) -> bytes:
    parts, macros = extract_macros(buf)
    assert len(macros) == 37, len(macros)
    new: dict[int, bytes] = {}

    def setm(idx: int, text: str):
        new[idx] = fit(text, macros[idx][0])

    # ST Mythic+ semi (CTRL=Army) -- Putrefy/Soul Reaper raised
    setm(0, hdr() + mods_pve_army() + f"/castsequence  reset=combat  {DARK_TRANS}, {OUTBREAK}")
    setm(1, hdr() + mods_pve_army() + f"/cast {PUTREFY}\n/cast [nopet] {RAISE_DEAD}")
    setm(2, mods_pve_army() + f"/cast [combat] {SOUL_REAPER}\n/use [combat]  14")
    setm(
        3,
        hdr()
        + mods_pve_army()
        + f"/castsequence  reset=target  {OUTBREAK}, null\n/cast {DEATH_COIL}\n/use Horde's Might Firework",
    )
    setm(4, hdr() + mods_pve_army() + f"/cast [known: Festering Scythe] {FESTERING}")
    setm(
        5,
        mods_pve_army()
        + f"/castsequence  reset=combat/5  {FESTERING}, {SCOURGE}, {SCOURGE}, {SCOURGE}, {SCOURGE}, {SCOURGE}",
    )
    setm(6, hdr() + f"/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:lalt] {DEATH_STRIKE}\n/cast {ARMY}\n/use The Flag of Ownership")

    # ST Mythic+ auto (CTRL=Sleet)
    setm(
        7,
        hdr()
        + f"/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:lalt] {DEATH_STRIKE}\n"
        + f"/castsequence  reset=15  {DARK_TRANS}, {OUTBREAK}\n/use The Flag of Ownership",
    )
    setm(
        8,
        f"/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:lalt] {DEATH_STRIKE}\n"
        f"/cast [mod:ctrl] {BLINDING_SLEET}\n/cast {PUTREFY}",
    )
    setm(
        9,
        f"/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:lalt] {DEATH_STRIKE}\n"
        f"/castsequence  reset=combat/5  {FESTERING}, {SCOURGE}, {SCOURGE}, {SCOURGE}, {SCOURGE}, {SCOURGE}",
    )
    setm(
        10,
        hdr()
        + f"/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:lalt] {DEATH_STRIKE}\n/cast [mod:ctrl] {BLINDING_SLEET}\n"
        + f"/castsequence  reset=target  {OUTBREAK}, null\n/cast {DEATH_COIL}\n/use Horde's Might Firework",
    )
    setm(
        11,
        hdr()
        + f"/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:lalt] {DEATH_STRIKE}\n"
        + f"/cast [mod:ctrl] {BLINDING_SLEET}\n/cast {SOUL_REAPER}",
    )
    setm(
        12,
        hdr()
        + f"/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:lalt] {DEATH_STRIKE}\n"
        + f"/cast [mod:ctrl] {BLINDING_SLEET}\n/cast [combat] {ARMY}\n/cast [combat] {DARK_TRANS}",
    )

    # ST PvP
    setm(13, hdr() + mods_pvp() + f"/cast {ARMY}\n/use The Flag of Ownership")
    setm(14, hdr() + mods_pvp() + f"/castsequence  reset=15  {DARK_TRANS}, {OUTBREAK}\n/use The Flag of Ownership")
    setm(15, mods_pvp() + f"/cast {PUTREFY}")
    setm(
        16,
        mods_pvp()
        + f"/castsequence  reset=combat/5  {FESTERING}, {SCOURGE}, {SCOURGE}, {SCOURGE}, {SCOURGE}, {SCOURGE}",
    )
    setm(
        17,
        hdr()
        + mods_pvp()
        + f"/castsequence  reset=target  {OUTBREAK}, null\n/cast {DEATH_COIL}\n/use Horde's Might Firework",
    )
    setm(18, hdr() + mods_pvp() + f"/cast {SOUL_REAPER}\n/cast [nopet] {RAISE_DEAD}")
    setm(19, hdr() + mods_pvp() + f"/cast [known: Festering Scythe] {FESTERING}")

    # AoE Mythic+ semi
    setm(20, hdr() + mods_pve_army() + f"/cast [known: Festering Scythe] {FESTERING}")
    setm(
        21,
        hdr()
        + f"/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:lalt] {DEATH_STRIKE}\n"
        + f"/cast [mod:ctrl] {BLINDING_SLEET}\n/cast {EPIDEMIC}",
    )
    setm(
        22,
        f"/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:ctrl] {ARMY}\n"
        f"/castsequence  reset=combat/5  {FESTERING}, {SCOURGE}, {EPIDEMIC}, {SCOURGE}, {EPIDEMIC}, {SCOURGE}, {EPIDEMIC}, {SCOURGE}, {EPIDEMIC}, {SCOURGE}",
    )
    setm(23, hdr() + mods_pve_army() + f"/castsequence  reset=combat  {DARK_TRANS}, {OUTBREAK}")
    setm(
        24,
        hdr()
        + mods_pve_army()
        + f"/castsequence  reset=target  {OUTBREAK}, null\n/cast {PUTREFY}\n/cast [nopet] {RAISE_DEAD}",
    )
    setm(
        25,
        hdr()
        + f"/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:lalt] {DEATH_STRIKE}\n"
        + f"/cast [mod:ctrl] {BLINDING_SLEET}\n/cast [known: Festering Scythe] Festering Scythe",
    )
    setm(
        26,
        hdr()
        + f"/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:lalt] {DEATH_STRIKE}\n"
        + f"/cast [mod:ctrl] {BLINDING_SLEET}\n/cast [@player] {DEATH_AND_DECAY}",
    )

    # AoE Mythic+ auto / shared
    setm(
        27,
        hdr()
        + f"/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:lalt] {DEATH_STRIKE}\n"
        + f"/cast [mod:ctrl] {BLINDING_SLEET}\n/cast [combat] {ARMY}\n/cast [combat] {DARK_TRANS}",
    )
    setm(
        28,
        hdr()
        + f"/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:lalt] {DEATH_STRIKE}\n"
        + f"/cast [mod:ctrl] {BLINDING_SLEET}\n"
        + f"/castsequence  reset=target  {OUTBREAK}, null\n/cast {PUTREFY}\n/cast [nopet] {RAISE_DEAD}",
    )
    setm(
        29,
        f"/targetenemy [noharm][dead]\n/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:lalt] {DEATH_STRIKE}\n"
        f"/cast [mod:ctrl] {BLINDING_SLEET}\n"
        f"/castsequence  reset=combat  {FESTERING}, {SCOURGE}, {SCOURGE}, {SCOURGE}, {SCOURGE}, {SCOURGE}",
    )
    setm(
        30,
        hdr()
        + f"/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:lalt] {DEATH_STRIKE}\n"
        + f"/cast [mod:ctrl] {BLINDING_SLEET}\n/cast {EPIDEMIC}",
    )
    setm(31, hdr() + mods_pvp() + f"/cast [known: Festering Scythe] {FESTERING}")
    setm(
        32,
        hdr()
        + f"/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:lalt] {DEATH_STRIKE}\n"
        + f"/cast [mod:ctrl] {BLINDING_SLEET}\n/cast [@player] {DEATH_AND_DECAY}",
    )

    # AoE PvP
    setm(
        33,
        hdr()
        + mods_pvp()
        + f"/cast [combat] {ARMY}\n/cast [combat] {DARK_TRANS}\n/use The Flag of Ownership",
    )
    setm(
        34,
        hdr()
        + mods_pvp()
        + f"/castsequence  reset=target  {OUTBREAK}, null\n/cast {PUTREFY}\n/cast [nopet] {RAISE_DEAD}",
    )
    setm(
        35,
        f"/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:ctrl,@mouseover,exists] {DEATH_GRIP}\n"
        f"/castsequence  reset=combat/5  {FESTERING}, {SCOURGE}, {EPIDEMIC}, {SCOURGE}, {EPIDEMIC}, {SCOURGE}\n"
        f"/use Horde's Might Firework\n/use Lion's Pride Firework",
    )
    setm(
        36,
        hdr()
        + f"/cast [mod:shift] {MIND_FREEZE}\n/cast [mod:lalt] {DEATH_STRIKE}\n"
        + f"/cast [mod:ctrl] {BLINDING_SLEET}\n/cast {EPIDEMIC}",
    )

    return rebuild(parts, new)


def patch_meta(buf: bytes) -> bytes:
    renames = [
        (b"Orb_UDK_ST-3.7", b"Orb_UDK_ST-4.0"),
        (b"Orb_UDK_AoE-3.7", b"Orb_UDK_AoE-4.0"),
    ]
    for old, new in renames:
        assert len(old) == len(new)
        buf = buf.replace(old, new)

    buf = buf.replace(b"N20260306043406", b"N20260826190000")
    buf = buf.replace(b"N20260306043319", b"N20260826190000")

    old_help = (
        b"Mythic+: Shift: Mind Freeze, LALT: Death Strike, CTRL: Army of the Dead\n"
        b"PvP: Shift: Mind Freeze, LALT Chains of Ice, CTRL (@mouseover) Death Grip"
    )
    new_help = (
        b"S2: Shift Mind Freeze | LALT Death Strike | CTRL Army/Sleet/Grip\n"
        b"Talents: San'layn Blightfall (IV) or Rider - Putrefy in DT windows   "
    )
    if len(new_help) < len(old_help):
        new_help = new_help + b" " * (len(old_help) - len(new_help))
    else:
        new_help = new_help[: len(old_help)]
    assert len(new_help) == len(old_help)
    count = buf.count(old_help)
    print("help replacements", count)
    buf = buf.replace(old_help, new_help)
    return buf


def main():
    src = SRC.read_text(encoding="utf-8").strip()
    print("src len", len(src))
    buf = decode_gse3(src)
    print("decoded", len(buf))
    buf = patch_macros(buf)
    print("macros patched", len(buf))
    buf = patch_meta(buf)
    export = encode_gse3(buf)
    out = OUT / "Orb_UDK_WightKing_S2_export.txt"
    out.write_text(export + "\n", encoding="utf-8")

    buf2 = decode_gse3(export)
    print("roundtrip", len(buf2))
    i = 0
    idx = 0
    while True:
        j = buf2.find(b"EmacroX", i)
        if j < 0:
            break
        pos = j + 7
        ln = buf2[pos]
        text = buf2[pos + 1 : pos + 1 + ln].decode("utf-8").rstrip("\n")
        tags = []
        if str(PUTREFY) in text:
            tags.append("PUTREFY")
        if str(EPIDEMIC) in text:
            tags.append("EPIDEMIC")
        if str(DEATH_AND_DECAY) in text:
            tags.append("DnD")
        if str(SOUL_REAPER) in text:
            tags.append("SR")
        tag = (" [" + ",".join(tags) + "]") if tags else ""
        print(f"--- {idx} ({ln}){tag} ---\n{text}\n")
        idx += 1
        i = pos + 1 + ln

    assert b"Orb_UDK_ST-4.0" in buf2
    assert b"Orb_UDK_AoE-4.0" in buf2
    print("TALENT ST:", TALENT_S2_ST)
    print("TALENT M+:", TALENT_S2_MPLUS)
    print("Wrote", out, "len", len(export))
    print(export)


if __name__ == "__main__":
    main()
