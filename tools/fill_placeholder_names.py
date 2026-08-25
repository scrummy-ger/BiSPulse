#!/usr/bin/env python3
"""Fill placeholder Item NNNNN names via Wowhead tooltip API."""
from __future__ import annotations

import json
import re
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JSON_PATH = ROOT / "tools" / "wowhead_browser_data.json"

UA = "Mozilla/5.0 (compatible; BiSPulseNameFill/1.0)"


def fetch_name(item_id: int) -> str | None:
    url = f"https://nether.wowhead.com/tooltip/item/{item_id}?dataEnv=1&locale=0"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read().decode("utf-8", "replace")
        data = json.loads(raw)
        name = data.get("name") or data.get("name_enus")
        if name and not re.match(r"^Item \d+$", name):
            return name
    except Exception:
        return None
    return None


def main() -> None:
    payload = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    out = payload.get("out") or {}
    cache: dict[int, str] = {}
    filled = 0
    for stem, pack in out.items():
        for row in pack.get("items") or []:
            name = row.get("name") or ""
            iid = int(row["id"])
            if not re.match(r"^Item \d+$", name):
                continue
            if iid not in cache:
                n = fetch_name(iid)
                cache[iid] = n or name
                time.sleep(0.15)
            if cache[iid] and not re.match(r"^Item \d+$", cache[iid]):
                row["name"] = cache[iid]
                filled += 1
        pack["placeholders"] = sum(
            1
            for r in (pack.get("items") or [])
            if re.match(r"^Item \d+$", r.get("name") or "")
        )
    payload["placeholders"] = sum(
        p.get("placeholders") or 0 for p in out.values()
    )
    JSON_PATH.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"Filled {filled} names (unique lookups={len(cache)})")
    print(f"Remaining placeholders={payload['placeholders']}")


if __name__ == "__main__":
    main()
