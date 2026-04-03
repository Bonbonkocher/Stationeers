@echo off
:: Hier den Namen der Datei anpassen, falls du sie umbenennst
set scriptName=Git-Helpfer-Programm.ps1

:: Startet PowerShell mit dem oben definierten Namen im selben Ordner (%~dp0)
powershell -NoExit -ExecutionPolicy Bypass -File "%~dp0%scriptName%"