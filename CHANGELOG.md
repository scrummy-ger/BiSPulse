# Changelog

## 1.5.8

### DE
- Checkliste: modernes Flat-Dark-Design (grüne Akzente), Suche volle Breite ohne Overflow
- Checkliste: eigene Flat-Dropdowns (Caret statt fehlender Unicode-Zeichen; Auswahl mit grünem Seitenstreifen)
- Checkliste: Filter „Nur fehlend“ und Sortierung (Rank / Name / Slot / Fehlend zuerst)
- Tooltip: Archon-Popularität als eigene Zeile; Checkliste zeigt % in der Unterzeile
- Guide-Links (Wowhead / Archon) in Optionen und Checkliste
- Drop-Texte für viele Archon-Items nachgezogen (leere Drops ~87% → ~30%)
- CI behält Archon-Snapshot beim wöchentlichen Wowhead-Refresh
- Daten: Popularitätsfeld in den Listen; tools/_debug aufgeräumt
- Wowhead-Listen frisch gescraped (04.09.2026); schwache Specs behalten bessere Snapshots

### EN
- Checklist: modern flat dark design (green accents), full-width search without overflow
- Checklist: custom flat dropdowns (drawn caret instead of missing Unicode glyphs; green side accent for the active option)
- Checklist: “Only missing” filter and sort (Rank / Name / Slot / Missing first)
- Tooltip: Archon popularity as its own line; checklist shows % on the subtitle
- Guide links (Wowhead / Archon) in options and checklist
- Drop text filled for many Archon items (empty drops ~87% → ~30%)
- CI keeps the Archon snapshot during the weekly Wowhead refresh
- Data: popularity field on list entries; cleaned up tools/_debug helpers
- Fresh Wowhead scrape (2026-09-04); weak specs keep stronger prior snapshots

## 1.5.7

### DE
- BiS-Listen um Archon.gg Popularitätsdaten ergänzt (Raid + Mythic+, Snapshot 31.08.2026)
- Wowhead Overall-BiS bleibt die Basis (letzter voller Scrape 25.08.2026)
- Rank-Filter Alt / Nische und Content-Filter Raid sind mit echten Daten gefüllt
- Quellen-Mix: Wowhead-BiS + Archon-Alternativen; Archon-Refresh ist manuell (Cloudflare)

### EN
- BiS lists supplemented with Archon.gg popularity data (Raid + Mythic+, snapshot 2026-08-31)
- Wowhead Overall BiS stays the baseline (last full scrape 2026-08-25)
- Rank filters Alt / Niche and content filter Raid now have real data
- Source mix: Wowhead BiS + Archon alternatives; Archon refresh is manual (Cloudflare)

## 1.5.6

### DE
- Content-Filter: Overall / Raid / Mythic+ / Alle (Alerts + Checkliste)
- Neue Option: Bank (und Warband-Bank) als Besitz zählen
- Checkliste: Filter nach Rank und Slot plus Suche in Name/Drop
- Checkliste: Rank- und Slot-Filter als Dropdown statt Klick-Zyklus
- Datenqualität: keine Item-Platzhalter-Namen mehr; Drop-Texte aktualisiert
- UI-Fix: Options mit Scroll (kein Überlaufen), fehlende Labels, leere Checklisten-Filter mit Hinweis + Slot-Reset

### EN
- Content filter: Overall / Raid / Mythic+ / All (alerts + checklist)
- New option: count bank (and warband bank) as owned
- Checklist: filter by rank and slot plus name/drop search
- Checklist: rank and slot filters use dropdowns instead of click-to-cycle
- Data quality: no more Item placeholder names; refreshed drop text
- UI fix: scrollable options (no overflow), missing labels, empty checklist filters with hint + slot reset

## 1.5.5

### DE
- Neu: Offspec-Tracking (Option + Spec-Auswahl)
- Toast/Badges/Tooltip können Offspec-BiS anzeigen
- Checkliste: Umschalter Main / Offspec (ohne Layout-Überlappung)
- Strong/Alt-Ranks aus Wowhead (Trinket-Tiers & Nebenlisten) — Mindest-Rank-Filter greift
- Bessere Drop-Angaben und aktualisierte BiS-Listen
- Hinweis am Mindest-Rank: gilt für Toast/Badges; Tooltips zeigen weiterhin alle Ranks
- Warnung bei veralteten Wowhead-Listen (bereits ab 1.5.4)

### EN
- New: Offspec tracking (option + spec picker)
- Toast/badges/tooltip can show offspec BiS
- Checklist: Main / Offspec toggle (no header overlap)
- Strong/Alt ranks from Wowhead (trinket tiers & secondary lists) — min-rank filter actually works
- Better drop text and refreshed BiS lists
- Min-rank hint: applies to toast/badges; tooltips still show every rank
- Stale Wowhead list warning (from 1.5.4)

## 1.5.4

### DE
- ilvl-Vergleich im Toast/Tooltip
- Downgrade-Filter (Option)
- Zuverlässigerer Vergleich ohne Fake-Deltas

### EN
- Item level compare on toast/tooltip
- Downgrade filter (option)
- More reliable compare (no fake catalog deltas)
