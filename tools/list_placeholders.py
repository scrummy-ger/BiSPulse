"""List Data/*.lua specs with placeholder Item NNNNN names."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "Data"

rows = []
for path in sorted(DATA.glob("*.lua")):
    if path.name == "Registry.lua":
        continue
    text = path.read_text(encoding="utf-8")
    n = len(re.findall(r"\[\d+\] = entry", text))
    ph = len(re.findall(r'name = "Item \d+"', text))
    if ph:
        rows.append((ph, n, path.stem, round(100 * ph / n) if n else 0))

rows.sort(reverse=True)
for ph, n, stem, pct in rows:
    print(f"{stem}: {ph}/{n} ({pct}%)")
print(f"total specs with placeholders: {len(rows)}")
