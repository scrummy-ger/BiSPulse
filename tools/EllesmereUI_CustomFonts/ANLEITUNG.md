# Ellesmere UI — Contrail One + Manrope (NICHT ElvUI)

Deine Dateien liegen schon hier:
`World of Warcraft\_retail_\Interface\AddOns\EllesmereUI\media\fonts\ContrailOne.ttf`
`World of Warcraft\_retail_\Interface\AddOns\EllesmereUI\media\fonts\Manrope.ttf`

**Nur die Datei reicht nicht.** Ellesmere UI liest die Liste aus `EllesmereUI.lua`.

---

## Option A — Direkt in EllesmereUI.lua (sofort, sicher)

1. **WoW komplett schliessen**
2. Datei oeffnen:
   `...\AddOns\EllesmereUI\EllesmereUI.lua`
3. Suchen: `EllesmereUI.FONT_FILES = {`
4. **Vor** der Zeile `["Friz Quadrata"] = nil` einfuegen:

```lua
 ["Contrail One"] = "ContrailOne.ttf",
 ["Manrope"] = "Manrope.ttf",
```

5. Suchen: `EllesmereUI.FONT_ORDER = {`
6. **Vor** `"Friz Quadrata"` einfuegen:

```lua
 "Contrail One", "Manrope",
```

7. Speichern, WoW starten
8. Im Spiel: **`/eui`** → Tab **Fonts** (nicht General!) → **Global Font** → **Contrail One** oder **Manrope**
9. **`/reload`**
10. Pruefen: `/euifonts` (wenn Companion-Addon aktiv) oder nochmal Fonts-Tab oeffnen

Combat Text (Schadenszahlen): Tab **General** → **Combat Text Font** → Contrail One → **Relog** (nicht nur /reload)

---

## Option B — Companion-Addon (ueberlebt EUI-Updates besser)

Ordner `EllesmereUI_CustomFonts` nach `...\Interface\AddOns\` kopieren, Addon aktivieren, `/reload`, dann Schritt 8–9 oben.

---

## Haeufige Fehler

| Problem | Loesung |
|---------|---------|
| Font nicht in Liste | Option A oder Companion-Addon |
| In Liste, UI unveraendert | **Fonts**-Tab → Global Font waehlen → `/reload` |
| Nur Combat Text | General reicht nicht fuer Action Bars / Unit Frames |
| Nach EUI-Update weg | Option A erneut oder Companion-Addon nutzen |
