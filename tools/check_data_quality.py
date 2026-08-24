#!/usr/bin/env python3
"""Quality gates for BiSPulse Data/*.lua after a Wowhead scrape."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "Data"

PLACEHOLDER_RE = re.compile(r'^\s*name = "Item \d+"', re.M)
ENTRY_RE = re.compile(r"\[\d+\] = entry")
DROP_EMPTY_RE = re.compile(r'drop = ""')
DROP_NONEMPTY_RE = re.compile(r'drop = "[^"]+"')


def audit() -> dict:
    specs = []
    total = placeholders = empty_drop = 0
    weak = []
    for path in sorted(DATA_DIR.glob("*.lua")):
        if path.name == "Registry.lua":
            continue
        text = path.read_text(encoding="utf-8")
        n = len(ENTRY_RE.findall(text))
        ph = len(PLACEHOLDER_RE.findall(text))
        nd = len(DROP_EMPTY_RE.findall(text))
        # Prefer counting empty via total - nonempty when drop="" is omitted style
        nonempty = len(DROP_NONEMPTY_RE.findall(text))
        if n and nonempty <= n:
            nd = max(nd, n - nonempty)
        total += n
        placeholders += ph
        empty_drop += nd
        specs.append(path.stem)
        if n < 8:
            weak.append(f"{path.stem}: only {n} items")
        if n > 0 and ph / n > 0.55:
            weak.append(f"{path.stem}: placeholder rate {ph}/{n}")
    return {
        "specs": len(specs),
        "total": total,
        "placeholders": placeholders,
        "empty_drop": empty_drop,
        "weak": weak,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-placeholder-rate", type=float, default=0.40)
    parser.add_argument("--min-specs", type=int, default=36)
    parser.add_argument("--min-items", type=int, default=500)
    args = parser.parse_args()

    report = audit()
    ph_rate = (report["placeholders"] / report["total"]) if report["total"] else 1.0
    print(
        f"specs={report['specs']} items={report['total']} "
        f"placeholders={report['placeholders']} ({ph_rate:.1%}) "
        f"empty_drop={report['empty_drop']}"
    )
    for line in report["weak"]:
        print(f"WARN {line}")

    failed = False
    if report["specs"] < args.min_specs:
        print(f"FAIL: only {report['specs']} specs (need >= {args.min_specs})")
        failed = True
    if report["total"] < args.min_items:
        print(f"FAIL: only {report['total']} items (need >= {args.min_items})")
        failed = True
    if ph_rate > args.max_placeholder_rate:
        print(
            f"FAIL: placeholder rate {ph_rate:.1%} "
            f"> {args.max_placeholder_rate:.0%}"
        )
        failed = True
    empty_rate = (report["empty_drop"] / report["total"]) if report["total"] else 1.0
    if empty_rate > 0.55:
        print(f"WARN: empty drop rate {empty_rate:.1%} (informational)")
    if failed:
        return 1
    print("OK data quality gates passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
