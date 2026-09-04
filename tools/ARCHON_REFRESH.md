# Archon.gg refresh (manual)

Archon gear tables are public but behind Cloudflare. Headless Playwright usually fails.
Use a real Cursor / Chrome tab that already passed the human check.

## Steps

1. Open any Archon Midnight gear page, e.g.  
   https://www.archon.gg/wow/builds/arms/warrior/raid/gear-and-tier-set/mythic/all-bosses  
   and complete the Cloudflare check if shown.
2. In the agent chat, ask to **re-scrape Archon** (CDP bulk fetch of `/_next/data/...` for all 40 specs).
3. Confirm `tools/archon_browser_data.json` has `"ok": 40` and a large `totalItems`.
4. Merge:

```powershell
cd tools
python scrape_method_bis.py --wowhead-json wowhead_browser_data.json --archon-json archon_browser_data.json
python enrich_drops.py
python check_data_quality.py
```

5. Commit the updated `archon_browser_data.json` + `Data/*.lua` so weekly CI keeps Archon alternatives.

## Safety

- `scrape_archon.mjs` refuses to overwrite a good JSON with an empty (`ok: 0`) run.
- `scrape_method_bis.py` skips Archon when `ok: 0`.
- `update_bis.ps1` keeps the last snapshot if Playwright Archon fails.
