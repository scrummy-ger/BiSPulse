#!/usr/bin/env python3
"""Refresh tools/wowhead_browser_data.json via live Wowhead HTML (no Node)."""
from __future__ import annotations

import json
import sys
import time
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from scrape_method_bis import (  # noqa: E402
    SPECS,
    STEMS,
    fetch_wowhead,
    parse_wowhead_bis,
)

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tools" / "wowhead_browser_data.json"


def pack_items(parsed: dict[int, dict]) -> list[dict]:
    rows = []
    for iid, info in parsed.items():
        rows.append(
            {
                "id": iid,
                "name": info.get("name") or f"Item {iid}",
                "wowhead": info.get("wowhead") or "overall",
                "rank": info.get("rank") or "bis",
                "slot": info.get("slot") or "",
                "drop": info.get("drop") or "",
                "note": info.get("note"),
            }
        )
    return rows


def enrich_from_previous(new_items: list[dict], old_items: list[dict]) -> list[dict]:
    by_id = {int(r["id"]): r for r in old_items}
    out = []
    for row in new_items:
        prev = by_id.get(int(row["id"]))
        if prev:
            if not (row.get("slot") or "").strip() and (prev.get("slot") or "").strip():
                row["slot"] = prev["slot"]
            if not (row.get("drop") or "").strip() and (prev.get("drop") or "").strip():
                row["drop"] = prev["drop"]
            if (row.get("name") or "").startswith("Item ") and prev.get("name"):
                row["name"] = prev["name"]
        out.append(row)
    return out


def main() -> int:
    previous = {}
    if OUT.is_file():
        try:
            previous = json.loads(OUT.read_text(encoding="utf-8")).get("out") or {}
        except Exception:
            previous = {}

    out: dict = {}
    errors: dict = {}
    ok = 0
    for spec in SPECS:
        class_file, spec_index, _slug, wh_class, wh_spec, class_name, spec_name = spec
        stem = STEMS[(class_file, spec_index)]
        url = f"https://www.wowhead.com/guide/classes/{wh_class}/{wh_spec}/bis-gear"
        print(f"{stem} ...", flush=True)
        try:
            html = fetch_wowhead(url)
            parsed = parse_wowhead_bis(html)
            items = pack_items(parsed)
            items = enrich_from_previous(items, (previous.get(stem) or {}).get("items") or [])
            ranks = Counter(r["rank"] for r in items)
            if len(items) < 8:
                errors[stem] = f"only {len(items)} items"
            out[stem] = {
                "count": len(items),
                "withDrop": sum(1 for r in items if (r.get("drop") or "").strip()),
                "placeholders": sum(1 for r in items if str(r.get("name") or "").startswith("Item ")),
                "byRank": {
                    "bis": ranks.get("bis", 0),
                    "strong": ranks.get("strong", 0),
                    "alt": ranks.get("alt", 0),
                    "ok": ranks.get("ok", 0),
                },
                "items": items,
                "url": url,
            }
            if items:
                ok += 1
            print(f"  {len(items)} items")
        except Exception as e:
            errors[stem] = str(e)
            if previous.get(stem, {}).get("items"):
                out[stem] = {**previous[stem], "reused": True}
                ok += 1
                print(f"  FAIL {e} — reused previous")
            else:
                out[stem] = {"count": 0, "items": [], "error": str(e)}
                print(f"  FAIL {e}")
        time.sleep(0.4)

    total = sum(len((p.get("items") or [])) for p in out.values())
    placeholders = sum(p.get("placeholders") or 0 for p in out.values())
    payload = {
        "scrapedAt": __import__("datetime").date.today().isoformat(),
        "ok": ok,
        "freshOk": ok - sum(1 for p in out.values() if p.get("reused")),
        "totalItems": total,
        "placeholders": placeholders,
        "errors": errors,
        "out": out,
    }
    OUT.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"\nWrote {OUT} ok={ok}/40 items={total} placeholders={placeholders}")
    return 0 if ok >= 36 else 1


if __name__ == "__main__":
    raise SystemExit(main())
