#!/usr/bin/env bash
# Kopiert gepatchte EllesmereUI.lua nach WoW AddOns\EllesmereUI
WOW="${WOW_EUI_PATH:-/mnt/d/Games/World of Warcraft/_retail_/Interface/AddOns/EllesmereUI}"
SRC="$(dirname "$0")/EllesmereUI.lua"

if [[ ! -f "$WOW/EllesmereUI.lua" ]]; then
  echo "FEHLER: $WOW/EllesmereUI.lua nicht gefunden."
  echo "Setze WOW_EUI_PATH auf deinen EllesmereUI-Ordner."
  exit 1
fi

cp "$SRC" "$WOW/EllesmereUI.lua"
echo "OK: Contrail One + Manrope in EllesmereUI.lua eingetragen."
echo "WoW -> /eui -> Fonts -> Global Font -> Contrail One -> /reload"
