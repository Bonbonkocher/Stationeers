# ==============================================================================
# GIT-HELFER (PowerShell for Windows)
# 
# Copyright (c) 2026 Jens (Bonbonkocher)
# Lizenziert unter der MIT-Lizenz.
# ==============================================================================

Set-Location $PSScriptRoot

# --- PFADE ZU DEN KONFIGURATIONS-DATEIEN ---
$ORDNER_SCRIPTS = Join-Path $PSScriptRoot "Scripts"
$DATEI_VERSION  = Join-Path $ORDNER_SCRIPTS "version.txt"
$DATEI_NAME     = Join-Path $ORDNER_SCRIPTS "name.txt"

# Definition der zwei verschiedenen Pakete
# Paket 1: Normal ( rocketstation_Data -> StreamingAssets -> Language )
$DATEIEN_NORMAL = @("StationeersDE\rocketstation_Data")

# Paket 2: Mod ( About + GameData -> Language )
$DATEIEN_MOD    = @("SteamMod\About", "SteamMod\GameData")

# Sicherstellen, dass der Scripts-Ordner existiert
if (!(Test-Path $ORDNER_SCRIPTS)) { New-Item -ItemType Directory -Path $ORDNER_SCRIPTS -Force | Out-Null }

# --- MOD-NAME LADEN ODER FRAGEN ---
if (Test-Path $DATEI_NAME) {
    $MOD_NAME = (Get-Content $DATEI_NAME -Raw).Trim()
} else {
    Write-Host "Kein Mod-Name gefunden!" -ForegroundColor Yellow
    $MOD_NAME = (Read-Host "Wie soll die Mod/ZIP heissen? (z.B. Mein_Mod_Name)").Trim()
    $MOD_NAME | Out-File -FilePath $DATEI_NAME -Encoding utf8 -Force
}

# --- VERSION LADEN ---
if (Test-Path $DATEI_VERSION) {
    $aktuelleVersion = (Get-Content $DATEI_VERSION -Raw).Trim()
} else {
    $aktuelleVersion = ""
}

$letzteAktion = "Programm gestartet"

while ($true) {
    Clear-Host
    Write-Host "--- GitHub Projekt Manager ---" -ForegroundColor Cyan
    Write-Host "Projekt-Name: " -NoNewline
    Write-Host $MOD_NAME -ForegroundColor Green
    Write-Host "Version:      " -NoNewline
    if ($aktuelleVersion) { Write-Host $aktuelleVersion -ForegroundColor Green } else { Write-Host "FEHLT" -ForegroundColor Red }
    Write-Host "Letzte Aktion: " -NoNewline
    Write-Host $letzteAktion -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Was moechtest du tun?" -ForegroundColor White
    Write-Host "------------------------------------------------"
    Write-Host "[0] Status-Datei    - Liste geanderter Dateien"
    Write-Host "[1] Pull            - Daten von GitHub laden"
    Write-Host "[2] Push            - Lokale Aenderungen hochladen"
    Write-Host "[3] Status-Zeile    - Detail-Ansicht (Diff)"
    Write-Host "[4] ZIP erstellen   - Nutzt Name & Version"
    Write-Host "[5] Release (gh)    - ZIP hochladen"
    Write-Host "[V] Version aendern - Versionsnummer anpassen"
    Write-Host "[N] Name aendern    - Mod-Namen anpassen"
    Write-Host "[Q] Quit            - Beenden"
    Write-Host "------------------------------------------------"
    Write-Host ""

    $eingabe = (Read-Host "-> Auswahl").Trim().ToLower()

    switch ($eingabe) {
      
        "0" { 
            Write-Host "`n--- DATEI STATUS ---" -ForegroundColor Yellow
            git status -s; $letzteAktion = "Status geprueft"; $null = [Console]::ReadKey() 
        }

        "1" { 
            Write-Host "`nFuehre 'git pull' aus..." -ForegroundColor Yellow
            git pull; $letzteAktion = "Pull erledigt"; $null = [Console]::ReadKey() 
        }

        "2" {
            Write-Host "`nBereite Push vor..." -ForegroundColor Yellow
            $msg = Read-Host "Commit-Nachricht (leer lassen fuer Zeitstempel)"
            if (-not $msg) { $msg = "Update $(Get-Date -Format 'dd.MM.yyyy HH:mm')" }
            git add .; git commit -m "$msg"; git push
            $letzteAktion = "Push ausgefuehrt"; $null = [Console]::ReadKey()
        }

        "3" { 
            Write-Host "`n--- DETAIL STATUS ---" -ForegroundColor Yellow
            git --no-pager diff; git --no-pager diff --cached; $null = [Console]::ReadKey() 
        }

        "4" {
            Write-Host "`n--- SYNCHRONISIEREN & ZIP ERSTELLUNG ---" -ForegroundColor Yellow
            if (-not $aktuelleVersion) {
                $aktuelleVersion = (Read-Host "Version eingeben (z.B. 0.0.9)").Trim()
                $aktuelleVersion | Out-File -FilePath $DATEI_VERSION -Encoding utf8 -Force
            }

            # --- 1. LANGUAGE ORDNER SYNCHRONISIEREN ---
            $quelleLang = Join-Path $PSScriptRoot "StationeersDE\rocketstation_Data\StreamingAssets\Language"
            $zielLang   = Join-Path $PSScriptRoot "SteamMod\GameData\Language"

            if (Test-Path $quelleLang) {
                Write-Host "Kopiere aktuelle Sprachdateien nach SteamMod..." -ForegroundColor Cyan
                # Falls der Zielordner existiert, loeschen wir ihn kurz, um keine alten Dateien zu behalten
                if (Test-Path $zielLang) { Remove-Item $zielLang -Recurse -Force }
                # Kopiert den kompletten Ordner von A nach B
                Copy-Item -Path $quelleLang -Destination $zielLang -Recurse -Force
            } else {
                Write-Host "FEHLER: Quell-Sprachordner nicht gefunden!" -ForegroundColor Red
            }

            # --- 2. AUTOMATISCHES UPDATE DER XML VERSION ---
            $xmlPfad = Join-Path $PSScriptRoot "SteamMod\About\SteamAbout.xml"
            if (Test-Path $xmlPfad) {
                Write-Host "Aktualisiere Version in SteamAbout.xml..." -ForegroundColor Cyan
                $content = Get-Content $xmlPfad -Raw
                $neuerContent = $content -replace '<Version>.*</Version>', "<Version>v$aktuelleVersion</Version>"
                $neuerContent | Out-File -FilePath $xmlPfad -Encoding utf8 -Force
            }
            
            # --- 3. ZIP ORDNER VORBEREITEN ---
            $zipOrdner = Join-Path $PSScriptRoot "zip"
            if (!(Test-Path $zipOrdner)) { New-Item -ItemType Directory -Path $zipOrdner -Force | Out-Null }
            Remove-Item (Join-Path $zipOrdner "*.zip") -ErrorAction SilentlyContinue
            
            # --- 4. NORMAL ZIP PACKEN ---
            $nameNormal = "$MOD_NAME-$aktuelleVersion.zip"
            $pfadNormal = Join-Path $zipOrdner $nameNormal
            $vorhandenNormal = $DATEIEN_NORMAL | Where-Object { Test-Path (Join-Path $PSScriptRoot $_) }
            if ($vorhandenNormal) {
                Compress-Archive -Path $vorhandenNormal -DestinationPath $pfadNormal -Force
                Write-Host "Erstellt: $nameNormal" -ForegroundColor Green
            }

            # --- 5. MOD ZIP PACKEN ---
            $nameMod = "${MOD_NAME}_Mod-$aktuelleVersion.zip"
            $pfadMod = Join-Path $zipOrdner $nameMod
            $vorhandenMod = $DATEIEN_MOD | Where-Object { Test-Path (Join-Path $PSScriptRoot $_) }
            if ($vorhandenMod) {
                Compress-Archive -Path $vorhandenMod -DestinationPath $pfadMod -Force
                Write-Host "Erstellt: $nameMod" -ForegroundColor Green
            }

            $letzteAktion = "Sync erledigt & ZIPs erstellt ($aktuelleVersion)"
            Write-Host "`nFertig! Alles auf dem neuesten Stand." -ForegroundColor Cyan
            $null = [Console]::ReadKey()
        }

        "5" {
            Write-Host "`n--- GITHUB RELEASE (Upload beider Dateien) ---" -ForegroundColor Yellow
            if (!(Get-Command gh -ErrorAction SilentlyContinue)) { Write-Host "gh CLI fehlt!" -ForegroundColor Red }
            elseif (-not $aktuelleVersion) { Write-Host "Bitte erst Version setzen!" -ForegroundColor Red }
            else {
                $zipNormal = Join-Path $PSScriptRoot "zip\$MOD_NAME-$aktuelleVersion.zip"
                $zipMod    = Join-Path $PSScriptRoot "zip\${MOD_NAME}_Mod-$aktuelleVersion.zip"
                
                $uploadFiles = @()
                if (Test-Path $zipNormal) { $uploadFiles += "`"$zipNormal`"" }
                if (Test-Path $zipMod)    { $uploadFiles += "`"$zipMod`"" }

                if ($uploadFiles.Count -gt 0) {
                    $tagName = "v$aktuelleVersion"
                    # Wir übergeben alle gefundenen ZIPs an den gh Befehl
                    Write-Host "Lade hoch: $($uploadFiles -join ' und ')..." -ForegroundColor Cyan
                    
                    # Der Trick: gh release create akzeptiert mehrere Dateien am Ende
                    Invoke-Expression "gh release create $tagName $($uploadFiles -join ' ') --title `"Version $aktuelleVersion`" --generate-notes"
                    
                    $letzteAktion = "Release $tagName mit $($uploadFiles.Count) Dateien"
                } else {
                    Write-Host "Keine ZIP-Dateien im Ordner gefunden!" -ForegroundColor Red
                }
            }
            $null = [Console]::ReadKey()
        }

        "v" {
            $aktuelleVersion = (Read-Host "Neue Version").Trim()
            $aktuelleVersion | Out-File -FilePath $DATEI_VERSION -Encoding utf8 -Force
            $letzteAktion = "Version geandert auf $aktuelleVersion"
        }

        "n" {
            $MOD_NAME = (Read-Host "Neuer Mod-Name").Trim()
            $MOD_NAME | Out-File -FilePath $DATEI_NAME -Encoding utf8 -Force
            $letzteAktion = "Name geandert auf $MOD_NAME"
        }

        "q" { exit }
    }
}