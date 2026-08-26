"""Update Artaemis ART_LowMover Havoc GSE from Season 1 (12.0b) to Midnight Season 2 (12.1).

Key S2 changes vs Artaemis 03/24/2026 Low Mover:
- Essence Break is mandatory again (Season 2 tier set) — S1 dropped it for Glaive Tempest
- Glaive Tempest is now a passive Blade Dance proc (no active button)
- Throw Glaive demoted (Screaming Brutality spends charges)
- Talent string → Icy Veins Fel-Scarred M+ 12.1
- Fix typo Void Metamorphosis → Metamorphosis
"""
from __future__ import annotations

import base64
import zlib
from pathlib import Path

OUT = Path("/workspace/tools")
SRC = OUT / "_havoc_payload.txt"
SOURCE_GSE = r"""!GSE3!zVbLbttGFK3SR1o1P5Cii9mlheVIpGRXMhAgEqmXTdqtxfoVCMWQvBYZz4PlDG0rQAsX6G904Vibbtpv6D/0M7qs9x3qyTryrlEqQQ/cuffOueee4dzX7QgPCcf+qHuA4xC7BMRVy8ZezMWV1SRAgUmDJ0zmuj34PgHmgbjer+8731n8wubnEK9r+tOSO+oeAj6rJzEWV50DiEXImfjp5usuc5OQyHny65bBqYvlbbvuybHP77lRk6YbHv1SlDgegAQGdIheMB7gmBYY98YR/XzRw0KiF5T7WyIIT2UfNYeAGoBpdsmTMemjFhCXYB+yK5jIAnoeETyEuI8OeOgjGySmPI4CLkIx81U7BpgxICEb9JETAOooAkxnGEFrHyLAstNlEuJzTOobplTmSQEPRgu7PnGfFJnxmZZK3qxFq1VLWvnNSvSyXq2V769Dq2kV/avl2LVqtVKrvT/K4s2UMQXz639L7BJOxVQ6d/HFIEA+m3S9uIFQl1JOcEoZSqVUuGvIEPnBaLVUliuV6qaeAbDgdDPb6w8zZJcz7kt4X6kIPrp5x3xlSXo4A/PjW5feXVyNNAMysVJjPn8PvI//T1x9smIwE7lk5ZoBlp+B+WHljXOCmF+gNsHhOdzzcP303TwTMmA6ZijSe87/OwPr0Yo7qG9Ua3rpHo7GZtPiPJp2N2f1JESthI09tye3vAwxaVrYBdKw13Ystcm3kY8l+Lt6Sd8slfWKtrlR00qdtHEmlvi3TgdIpPY/O/o8kDISW8WiHwqPx/7TwaA4EJCwUMW3HUxUenG9a6+hdaSGCDSeIl53Jws9kEe+0TyrL30d05P0rdvq+/KYqp/pwqvw8vjCfnVsmzo9abfNlwq3Sxu0FV0qa9tNfUz1GZy07fR/Pr9jgvDiMEqLPio2sAAfqVvmkB8GgP0nIhXtes/DcQx+ARGFk6Y4UTrO+Is2t+qJDHj8TT2WGGgYiucnCXnyMmTb7V5zOgc9fvTXvo1ZgsnkZkjp5ey2YwTgnYmE7pxrW+6pVi5r5ZKZ0nj0swNUdVoC0rbydctRTP37hBhKJMo4P1i9VE3KMD+D+UWGNHgNfTFBgIxUMGmywjy6gDDz56EzjX3ZNuEUJ0TmzF1MYcnMZ5lKQMxXF3sI4mY2NWYGycXIeNXqReB1zccP6oazZ3z2Xu7PP5wmO+WxB2ogjJSC3JCEcng7luq2sWdZTcPp7u3+Aw=="""

# Spell IDs
EYE_BEAM = 198013
FELBLADE = 232893
META = 191427
BLADE_DANCE = 188499
CHAOS_STRIKE = 344862  # Midnight Chaos Strike (confirmed Wowhead)
IMMOLATION = 258920
ESSENCE_BREAK = 258860
THE_HUNT_NAME = "The Hunt"

TALENT_S2_MPLUS = (
    "CEkAAAAAAAAAAAAAAAAAAAAAAYmZGzMz2MmZmxYmMmZAAAAAAAzixsNDzMwMWmZmZYmBzyAbzmZMMbMNmZGzYDAAAYAAAAMzgBAAAgB"
)


def decode_gse3(s: str) -> bytes:
    raw = s.replace("!GSE3!", "").strip()
    data = base64.b64decode(raw + "=" * ((-len(raw)) % 4))
    return zlib.decompress(data, -15)


def encode_gse3(buf: bytes) -> str:
    c = zlib.compressobj(9, zlib.DEFLATED, -15)
    compressed = c.compress(buf) + c.flush()
    return "!GSE3!" + base64.b64encode(compressed).decode("ascii")


def mod_prefix_ids() -> str:
    return (
        f"/cast [mod:shift] {EYE_BEAM}\n"
        f"/cast [mod:ctrl] {FELBLADE}\n"
        f"/cast [mod:alt, @player] {META}\n"
    )


def mod_prefix_names(meta_name: str = "Metamorphosis") -> str:
    return (
        "/cast [mod:shift] Eye Beam\n"
        f"/cast [mod:ctrl] Felblade\n"
        f"/cast [mod:alt, @player] {meta_name}\n"
    )


def fit(text: str, length: int) -> bytes:
    text = text.replace("\r\n", "\n").rstrip("\n")
    candidates = [text]
    # drop target line if present
    if text.startswith("/targetenemy"):
        candidates.append("\n".join(text.split("\n")[1:]))
    lines = [
        ln
        for ln in text.split("\n")
        if ln.startswith("/cast") or ln.startswith("/castsequence") or ln.startswith("/use")
    ]
    if lines:
        candidates.append("\n".join(lines))
    for cand in candidates:
        raw = cand.encode("utf-8")
        if len(raw) <= length:
            return raw + b"\n" * (length - len(raw))
    return candidates[-1].encode("utf-8")[:length].ljust(length, b"\n")


def replace_macros(buf: bytes) -> bytes:
    parts: list = []
    i = 0
    macros = []
    while True:
        j = buf.find(b"EmacroX", i)
        if j < 0:
            parts.append(("raw", buf[i:]))
            break
        parts.append(("raw", buf[i:j]))
        pos = j + 7
        ln = buf[pos]
        text = buf[pos + 1 : pos + 1 + ln]
        macros.append((ln, text))
        parts.append(("macro", ln, text))
        i = pos + 1 + ln

    assert len(macros) == 12, len(macros)

    new: dict[int, bytes] = {}

    # 0: Hunt opener — fix Void Metamorphosis typo
    new[0] = fit(
        "/targetenemy [noharm,nocombat]\n"
        + mod_prefix_names("Metamorphosis")
        + f"/cast [nochanneling] {THE_HUNT_NAME}",
        macros[0][0],
    )

    # 1: Essence Break HIGH priority (S2 tier set) — was Blade Dance
    new[1] = fit(mod_prefix_ids() + f"/cast [nochanneling] {ESSENCE_BREAK}", macros[1][0])

    # 2: Immolation Aura dump (2 charges) — keep
    new[2] = fit(
        mod_prefix_names()
        + "/castsequence [nochanneling] reset=target/5  Immolation Aura, Immolation Aura",
        macros[2][0],
    )

    # 3: Chaos Strike
    new[3] = fit(mod_prefix_ids() + f"/cast [nochanneling] {CHAOS_STRIKE}", macros[3][0])

    # 4: Blade Dance
    new[4] = fit(mod_prefix_ids() + f"/cast [nochanneling] {BLADE_DANCE}", macros[4][0])

    # 5: Chaos Strike
    new[5] = fit(mod_prefix_ids() + f"/cast [nochanneling] {CHAOS_STRIKE}", macros[5][0])

    # 6: Blade Dance (named)
    new[6] = fit(mod_prefix_names() + "/cast [nochanneling] Blade Dance", macros[6][0])

    # 7: Chaos Strike
    new[7] = fit(mod_prefix_ids() + f"/cast [nochanneling] {CHAOS_STRIKE}", macros[7][0])

    # 8: Blade Dance
    new[8] = fit(mod_prefix_ids() + f"/cast [nochanneling] {BLADE_DANCE}", macros[8][0])

    # 9: was Throw Glaive → second Essence Break attempt / Blade Dance filler
    # Prefer Blade Dance (TG not actively pressed in S2)
    new[9] = fit(mod_prefix_names() + "/cast [nochanneling] Blade Dance", macros[9][0])

    # 10: was disabled CS — keep as Chaos Strike (re-enable via text; HDisabled flag left as-is in structure)
    new[10] = fit(mod_prefix_ids() + f"/cast [nochanneling] {CHAOS_STRIKE}", macros[10][0])

    # 11: Immolation Aura filler
    new[11] = fit(mod_prefix_ids() + f"/cast [nochanneling] {IMMOLATION}", macros[11][0])

    out = bytearray()
    mi = 0
    for p in parts:
        if p[0] == "raw":
            out += p[1]
        else:
            ln = p[1]
            body = new[mi]
            assert len(body) == ln, (mi, len(body), ln)
            out += b"EmacroX" + bytes([ln]) + body
            mi += 1
    return bytes(out)


def replace_talent_string(buf: bytes, new_talent: str) -> bytes:
    """Replace ITalentSet X-length-prefixed talent string (may change length)."""
    marker = b"ITalentSetX"
    j = buf.find(marker)
    if j < 0:
        raise RuntimeError("TalentSet not found")
    pos = j + len(marker)
    old_ln = buf[pos]
    old_talent = buf[pos + 1 : pos + 1 + old_ln]
    print(f"old talent len={old_ln}: {old_talent[:40]!r}...")
    new_raw = new_talent.encode("ascii")
    assert len(new_raw) <= 255
    return buf[:pos] + bytes([len(new_raw)]) + new_raw + buf[pos + 1 + old_ln :]


def replace_description(buf: bytes) -> bytes:
    # KDescriptionX/Based on WoWhead's Fel-Scarred, low mover build
    # length byte after X is '/' = 0x2f = 47
    old = b"Based on WoWhead's Fel-Scarred, low mover build"
    new = b"Based on Icy Veins Fel-Scarred M+ S2 low-mover"
    # pad to same length
    if len(new) < len(old):
        new = new + b" " * (len(old) - len(new))
    assert len(new) == len(old)
    if old not in buf:
        print("WARN: description not found")
        return buf
    return buf.replace(old, new)


def main():
    src = SRC.read_text(encoding="utf-8").strip() if SRC.exists() else SOURCE_GSE.strip()
    buf = decode_gse3(src)
    print("decoded", len(buf))

    buf = replace_macros(buf)
    buf = replace_talent_string(buf, TALENT_S2_MPLUS)
    buf = replace_description(buf)

    # Rename 12.0b → 12.1b (same length)
    assert len(b"12.0b") == len(b"12.1b")
    buf = buf.replace(b"ART_LowMover-12.0b", b"ART_LowMover-12.1b")

    # Label / talent set name (keep same length — typed string value)
    assert len(b"M+ - Low Mover") == len(b"M+ S2 LowMover")
    buf = buf.replace(b"M+ - Low Mover", b"M+ S2 LowMover")

    # Timestamp
    buf = buf.replace(b"N20260324165910", b"N20260826080000")

    # Neutralize checksum
    buf = buf.replace(b"Kv1:bf133130", b"Kv1:s2update")

    # Help text still accurate for mods
    export = encode_gse3(buf)
    out_path = OUT / "ART_LowMover_Havoc_S2_export.txt"
    out_path.write_text(export + "\n", encoding="utf-8")

    # Verify roundtrip macros
    buf2 = decode_gse3(export)
    print("\n=== UPDATED MACROS ===")
    i = 0
    idx = 0
    while True:
        j = buf2.find(b"EmacroX", i)
        if j < 0:
            break
        pos = j + 7
        ln = buf2[pos]
        text = buf2[pos + 1 : pos + 1 + ln].decode("utf-8").rstrip("\n")
        print(f"\n--- {idx} ({ln}) ---\n{text}")
        idx += 1
        i = pos + 1 + ln

    # show talent
    tpos = buf2.find(b"ITalentSetX") + len(b"ITalentSetX")
    tln = buf2[tpos]
    print("\nTALENT:", buf2[tpos + 1 : tpos + 1 + tln].decode())
    print("\nExport written:", out_path, "len", len(export))
    print(export)


if __name__ == "__main__":
    main()
