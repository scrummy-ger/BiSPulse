# BiSPulse — WoW Retail Addon

Zeigt dir anhand der **Wowhead**-BiS-Guides, wie gut ein Item für deine Spec ist — im Tooltip, als Toast und in der Checkliste.

**Alle Retail-Specs** (40) für Midnight Patch **12.1** / Season 2.

Daten: Wowhead Overall-BiS, generiert mit `tools/scrape_method_bis.py` aus `tools/wowhead_browser_data.json`.

## Specs

Death Knight · Demon Hunter (inkl. Devourer) · Druid · Evoker · Hunter · Mage · Monk · Paladin · Priest · Rogue · Shaman · Warlock · Warrior — jeweils alle Spezialisierungen.

## Installation

1. Ordner `BiSPulse` nach  
   `World of Warcraft\_retail_\Interface\AddOns\` kopieren  
   (der Ordner muss `BiSPulse.toc` direkt enthalten).
2. WoW **neu starten** (nicht nur `/reload` bei Erstinstallation).
3. Charakterauswahl → AddOns → BiSPulse aktivieren.

## Features

- **Tooltip-Ranking** — Rank, Score, Wowhead-Liste (Main + optional Offspec)
- **Custom Toast** — Icon + Rank + Score + ilvl-Vergleich
- **Loot-Badges** — Badge + Glow im Loot-Fenster
- **Offspec-Tracking** — Alerts/Checkliste für eine zweite Spec
- **Minimap-Button** + **BiS-Checkliste**
- Deutsch + Englisch

## Befehle

| Befehl | Wirkung |
|--------|---------|
| `/bispulse` / `/bp` | Optionen |
| `/bp list` | Checkliste |
| `/bp scan` | Taschen scannen |
| `/bp toast` | Toast-Preview |
| `/bp reset` | Settings reset |

## Daten aktualisieren

WoW-Addons dürfen **nicht** selbst Wowhead aufrufen. Frische Listen kommen nur über ein Addon-Update (CurseForge/Wago Auto-Update).

Lokal / CI (Playwright holt die Guides, Python schreibt `Data/*.lua`):

```powershell
cd tools
.\update_bis.ps1
python check_data_quality.py
```

GitHub Action `.github/workflows/update-bis.yml` läuft montags und öffnet einen PR, wenn sich Listen geändert haben. Die Action bricht ab, wenn zu wenige Specs kommen oder zu viele `Item 12345`-Platzhalter-Namen übrig bleiben. Nach Merge: Release auf CurseForge/Wago.

Im Spiel warnt BiSPulse, wenn die Wowhead-Listen älter als 14 Tage sind.

## Hinweis

Für Feintuning weiterhin simmen (Raidbots). BiSPulse mappt Wowhead-Overall-Listen, es ersetzt keine Sims.
