@echo off
REM Kopiert die gepatchte EllesmereUI.lua in deine WoW-Installation.
REM Pfad aus deinem Screenshot: D:\Games\World of Warcraft\_retail_\Interface\AddOns\EllesmereUI\

set "WOW=D:\Games\World of Warcraft\_retail_\Interface\AddOns\EllesmereUI"
set "SRC=%~dp0EllesmereUI.lua"

if not exist "%WOW%\EllesmereUI.lua" (
  echo FEHLER: EllesmereUI.lua nicht gefunden unter:
  echo   %WOW%
  echo Bitte WOW-Pfad in install.bat anpassen.
  pause
  exit /b 1
)

copy /Y "%SRC%" "%WOW%\EllesmereUI.lua"
echo OK: Contrail One + Manrope eingetragen.
echo WoW starten -^> /eui -^> Fonts -^> Global Font -^> Contrail One -^> /reload
pause
