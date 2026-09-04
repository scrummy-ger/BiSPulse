# Refresh Wowhead Overall BiS + Archon popularity → Data/*.lua
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  Write-Error "npm is required (Node.js)."
}
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
  Write-Error "python is required."
}

npm install
npx playwright install chromium
node scrape_wowhead.mjs

# Archon is Cloudflare-blocked in CI/headless; keep the last good snapshot on failure.
$archonOk = $false
try {
  node scrape_archon.mjs
  if ($LASTEXITCODE -eq 0) { $archonOk = $true }
} catch {
  Write-Host "Archon scrape failed — using existing archon_browser_data.json if present."
}

python fill_placeholder_names.py
if ($archonOk -or (Test-Path "archon_browser_data.json")) {
  python scrape_method_bis.py --wowhead-json wowhead_browser_data.json --archon-json archon_browser_data.json
} else {
  python scrape_method_bis.py --wowhead-json wowhead_browser_data.json
}
python enrich_drops.py
python fill_missing_drops.py
python fix_dungeon_drops.py
python check_data_quality.py
Write-Host "Done. Copy Data/*.lua into the WoW AddOns folder and /reload."
