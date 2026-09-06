# Archon.gg — deprecated for BiSPulse

BiSPulse is **Wowhead-only** as of 1.5.10.

Archon’s gear tables label BiS from Wowhead and add parse popularity, but Cloudflare
makes reliable refreshes painful, and the % display is not worth the ops cost.

- Do **not** merge `archon_browser_data.json` into `Data/*.lua`.
- Refresh pipeline: `tools/update_bis.ps1` (Wowhead scrape → generate → drop fixes).
- Legacy `scrape_archon*.mjs` scripts may remain in `tools/` for experiments; they are unused by CI.
