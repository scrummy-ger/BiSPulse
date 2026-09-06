# BiSPulse — WoW Retail Addon

**BiSPulse** zeigt dir, wann Loot Best in Slot (oder eine starke Alternative) für deine aktuelle Spezialisierung ist — und optional für eine Offspec deiner Wahl. Datenbasis: **Wowhead** Overall-BiS-Guides für **alle Retail-Specs**.

Wenn ein Item für deinen Build zählt, siehst du es sofort: im **Tooltip**, als **Toast**, mit **Loot-Badges** und in der **Minimap-Checkliste**, damit du fehlende Pieces tracken kannst.

**Midnight** · Patch **12.1** / Season 2 · **40 Specs** (inkl. Devourer) · UI **Deutsch & Englisch**

---

## Features

- **Tooltip-Ranking** — BiS / Strong, Score und Wowhead-Liste (Main + optional Offspec)
- **Custom Loot-Toast** — Icon, Rank, Score-Leiste
- **Loot-Badges** — klare BiS-Marker im Loot-Fenster
- **Offspec-Tracking** — zweite Spec in Optionen wählen; Alerts & Checkliste
- **BiS-Checkliste** (Minimap) — Besitz in Taschen / angelegt / Bank; Filter Rank (Alle · BiS · Strong), Slot, Instanz/Craft; „Nur fehlend“; Sortierung; Drop als `Boss (Instanz)`
- **Guide-Links** — kopierbares Popup (Wowhead), Rechtsklick auf Checklisten-Zeilen
- **Content-Filter** — Overall / Raid / Mythic+ (BiS = Overall; Strong = Raid/M+-Extras)

## Befehle

| Befehl | Wirkung |
|--------|---------|
| `/bispulse` / `/bp` | Optionen |
| `/bp list` | Checkliste |
| `/bp scan` | Taschen scannen |
| `/bp toast` | Toast-Preview |
| `/bp reset` | Settings zurücksetzen |

## Installation

1. Ordner `BiSPulse` nach  
   `World of Warcraft\_retail_\Interface\AddOns\` kopieren  
   (der Ordner muss `BiSPulse.toc` direkt enthalten).
2. WoW **neu starten** (nicht nur `/reload` bei Erstinstallation).
3. Charakterauswahl → AddOns → BiSPulse aktivieren.

## Daten / Updates

WoW-Addons dürfen **nicht** selbst Wowhead aufrufen. Die Listen sind **im Addon gepackt** (Wowhead Overall-BiS + Strong aus Raid/M+-Abschnitten) und kommen über **CurseForge-/Wago-Updates** (Auto-Update empfohlen).

Lokal neu generieren:

```powershell
cd tools
.\update_bis.ps1
python check_data_quality.py
```

GitHub Action `.github/workflows/update-bis.yml` kann Listen per Scrape prüfen und einen PR öffnen. Im Spiel warnt BiSPulse, wenn die gepackten Listen älter als **14 Tage** sind.

## Hinweis

Für Feintuning (Stat Weights, Sims, Edge Cases) weiter Raidbots oder deine üblichen Tools nutzen — BiSPulse ist für **schnelle Loot-Entscheidungen im Spiel**.

---

## English (CurseForge)

**BiSPulse** shows you when loot is Best in Slot — or a strong upgrade — for your current specialization, and optionally an offspec of your choice. Powered by **Wowhead** Overall BiS guides for **all Retail specs**.

When an item matters for your build, BiSPulse surfaces it instantly: on the **tooltip**, as a **custom toast**, with **loot-window badges**, and in a **minimap checklist** so you can track what you still need.

Built for **Midnight** (patch **12.1** / Season 2). **English & German** UI. Full Retail coverage including Devourer.

### Features

- **Tooltip rankings** — BiS / Strong with score and Wowhead list tag (main + optional offspec)
- **Custom loot toast** — item icon, rank, and score bar
- **Loot badges** — clear BiS markers in the loot frame
- **Offspec tracking** — pick a second spec in options; alerts & checklist follow it
- **BiS checklist** (minimap) — owned vs missing (bags, equipped, bank); filters for rank (All · BiS · Strong), slot, instance/craft; “Only missing”; sorting; drop line as `Boss (Instance)`
- **Guide links** — copyable popup (Wowhead); right-click checklist rows
- **Content filter** — Overall / Raid / Mythic+ (BiS = Overall; Strong = Raid/M+ extras)

### Commands

- `/bispulse` or `/bp` — options
- `/bp list` — checklist
- `/bp scan` — scan bags
- `/bp toast` — preview toast
- `/bp reset` — restore defaults

### Notes

Data is packed from Wowhead Overall BiS guides plus Strong picks from Raid/Mythic+ sections (not live-scraped in-game — WoW addons can’t fetch Wowhead). You get refreshed lists via CurseForge/Wago addon updates (keep auto-update on). The addon warns in-game if the packed lists are older than 14 days.

For fine-tuning (stat weights, sims, edge cases), keep using Raidbots or your usual tools — BiSPulse is for fast in-game loot decisions.
