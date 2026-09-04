#!/usr/bin/env python3
"""Fill empty drop= fields in Data/*.lua via Wowhead tooltip 'Dropped by' / similar."""
from __future__ import annotations

import argparse
import json
import re
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "Data"
WH_JSON = ROOT / "tools" / "wowhead_browser_data.json"

UA = "Mozilla/5.0 (compatible; BiSPulseDropFill/1.5.8)"
SOURCE_RE = re.compile(
    r'whtt-(?:droppedby|soldby|rewardfrom)[^>]*>\s*'
    r'(?:Dropped by|Sold by|Reward from):\s*([^<]+)</div>',
    re.I,
)
ENTRY_RE = re.compile(r"\[(\d+)\] = entry\(\{([\s\S]*?)\}\),")


def fetch_drop(item_id: int) -> str | None:
    url = f"https://nether.wowhead.com/tooltip/item/{item_id}?dataEnv=1&locale=0"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode("utf-8", "replace"))
        tip = data.get("tooltip") or ""
        m = SOURCE_RE.search(tip)
        if m:
            return re.sub(r"\s+", " ", m.group(1)).strip()
    except Exception:
        return None
    return None


def drops_from_wowhead_json() -> dict[int, str]:
    out: dict[int, str] = {}
    if not WH_JSON.is_file():
        return out
    raw = json.loads(WH_JSON.read_text(encoding="utf-8"))
    for pack in (raw.get("out") or {}).values():
        for row in pack.get("items") or []:
            iid = int(row["id"])
            drop = (row.get("drop") or "").strip()
            if drop and (iid not in out or len(drop) > len(out[iid])):
                out[iid] = drop
    return out


def drops_from_guide_cache() -> dict[int, str]:
    cache = ROOT / "tools" / "drop_guide_cache.json"
    if not cache.is_file():
        return {}
    raw = json.loads(cache.read_text(encoding="utf-8"))
    return {int(k): str(v) for k, v in (raw or {}).items() if v}


def lua_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-lookups", type=int, default=800)
    parser.add_argument("--sleep", type=float, default=0.12)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    # After Wowhead scrape + Lua write:
    #   python enrich_drops.py
    #   python fill_missing_drops.py
    cache = drops_from_wowhead_json()
    cache.update(drops_from_guide_cache())
    print(f"Seed drops from Wowhead JSON + guide cache: {len(cache)}")

    missing_ids: list[int] = []
    for path in sorted(DATA_DIR.glob("*.lua")):
        if path.name == "Registry.lua":
            continue
        text = path.read_text(encoding="utf-8")
        for m in ENTRY_RE.finditer(text):
            iid = int(m.group(1))
            body = m.group(2)
            drop_m = re.search(r'drop = "((?:\\.|[^"\\])*)"', body)
            drop = drop_m.group(1).replace('\\"', '"') if drop_m else ""
            if drop.strip():
                continue
            if iid not in cache:
                missing_ids.append(iid)

    # unique preserve order
    seen: set[int] = set()
    uniq = []
    for iid in missing_ids:
        if iid not in seen:
            seen.add(iid)
            uniq.append(iid)

    lookups = 0
    for iid in uniq:
        if lookups >= args.max_lookups:
            break
        d = fetch_drop(iid)
        lookups += 1
        if d:
            cache[iid] = d
        if lookups % 50 == 0:
            print(f"  lookups={lookups} cached={len(cache)}")
        time.sleep(args.sleep)

    print(f"API lookups={lookups}; drop cache size={len(cache)}")

    filled = 0
    for path in sorted(DATA_DIR.glob("*.lua")):
        if path.name == "Registry.lua":
            continue
        text = path.read_text(encoding="utf-8")

        def repl(m: re.Match) -> str:
            nonlocal filled
            iid = int(m.group(1))
            body = m.group(2)
            drop_m = re.search(r'drop = "((?:\\.|[^"\\])*)"', body)
            drop = drop_m.group(1).replace('\\"', '"') if drop_m else ""
            if drop.strip() or iid not in cache:
                return m.group(0)
            new_drop = lua_escape(cache[iid])
            new_body = re.sub(
                r'drop = "(?:\\.|[^"\\])*"',
                f'drop = "{new_drop}"',
                body,
                count=1,
            )
            filled += 1
            return f"[{iid}] = entry({{{new_body}}}),"

        new_text = ENTRY_RE.sub(repl, text)
        if new_text != text and not args.dry_run:
            path.write_text(new_text, encoding="utf-8")

    print(f"Filled {filled} empty drops" + (" (dry-run)" if args.dry_run else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
