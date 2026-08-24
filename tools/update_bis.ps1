# Refresh Wowhead Overall BiS → Data/*.lua
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
python scrape_method_bis.py --wowhead-json wowhead_browser_data.json
Write-Host "Done. Copy Data/*.lua into the WoW AddOns folder and /reload."
