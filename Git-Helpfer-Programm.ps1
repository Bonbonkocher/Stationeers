# ==============================================================================
# GIT-HELFER (PowerShell for Windows)
# Copyright (c) 2026 Jens (Bonbonkocher)
# ==============================================================================

Set-Location $PSScriptRoot

# --- PFADE ---
$ORDNER_SCRIPTS = Join-Path $PSScriptRoot "Scripts"
$DATEI_VERSION  = Join-Path $ORDNER_SCRIPTS "version.txt"
$DATEI_NAME     = Join-Path $ORDNER_SCRIPTS "name.txt"
$VDF_PFAD       = Join-Path $PSScriptRoot "update_mod.vdf"
$STEAMCMD_PFAD  = "C:\MeineProgramme\Jens\GitHub-Projekte\Stationeers\SteamCMD\steamcmd.exe"

# Definition der Pakete
$DATEIEN_NORMAL = @("StationeersDE\rocketstation_Data")
$DATEIEN_MOD    = @("SteamMod\About", "SteamMod\GameData")

# Sicherstellen, dass der Scripts-Ordner existiert
if (!(Test-Path $ORDNER_SCRIPTS)) { New-Item -ItemType Directory -Path $ORDNER_SCRIPTS -Force | Out-Null }

# --- MOD-NAME & VERSION LADEN ---
if (Test-Path $DATEI_NAME) { $MOD_NAME = (Get-Content $DATEI_NAME -Raw).Trim() } else { $MOD_NAME = "Stationeers_Deutsch" }
if (Test-Path $DATEI_VERSION) { $aktuelleVersion = (Get-Content $DATEI_VERSION -Raw).Trim() } else { $aktuelleVersion = "0.0.1" }

$letzteNachricht = ""
$letzteAktion = "Programm gestartet"

while ($true) {
    Clear-Host
    Write-Host "--- GitHub & Steam Workshop Manager ---" -ForegroundColor Cyan
    Write-Host "Projekt: $MOD_NAME | Version: $aktuelleVersion" -ForegroundColor Green
    Write-Host "Letzte Aktion: $letzteAktion" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Was moechtest du tun?" -ForegroundColor White
    Write-Host "------------------------------------------------"
    Write-Host "[0] Status-Datei    [1] Pull"
    Write-Host "[2] Push (Git)      - Merkt Nachricht fuer Steam"
    Write-Host "[3] Status-Zeile    (Diff)"
    Write-Host "[4] ZIP & Sync      - Kopiert Language & XML"
    Write-Host "[5] Release (gh)    - Upload zu GitHub"
    Write-Host "[6] Steam Update    - Upload zu Workshop"
    Write-Host "------------------------------------------------"
    Write-Host "[V] Version aendern [N] Name aendern"
    Write-Host "[Q] Beenden (Fenster schliessen)"
    Write-Host ""

    $eingabe = (Read-Host "-> Auswahl").Trim().ToLower()

    switch ($eingabe) {
      
        "0" { 
            Write-Host "`n--- DATEI STATUS ---" -ForegroundColor Yellow
            git status -s
            $letzteAktion = "Status geprueft"
            $null = [Console]::ReadKey() 
        }
        
        "1" { 
            Write-Host "`n--- GIT PULL ---" -ForegroundColor Yellow
            git pull
            $letzteAktion = "Pull erledigt"
            $null = [Console]::ReadKey() 
        }
        
        "2" {
            Write-Host "`n--- GIT PUSH ---" -ForegroundColor Yellow
            $msg = Read-Host "Commit-Nachricht (leer lassen fuer Zeitstempel)"
            if (-not $msg) { $msg = "Update $(Get-Date -Format 'dd.MM.yyyy HH:mm')" }
            $letzteNachricht = $msg
            git add .
            git commit -m "$msg"
            git push
            $letzteAktion = "Git Push: $msg"
            $null = [Console]::ReadKey()
        }
        "3" { 
            Write-Host "`n--- DETAIL STATUS ---" -ForegroundColor Yellow
            git --no-pager diff
            git --no-pager diff --cached
            $letzteAktion = "Diff geprueft"
            $null = [Console]::ReadKey() 
        }
        
        "4" {
            Write-Host "`n--- SYNCHRONISIEREN & ZIP ERSTELLUNG ---" -ForegroundColor Yellow
            
            # 1. Sprachdateien synchronisieren
            $quelleLang = Join-Path $PSScriptRoot "StationeersDE\rocketstation_Data\StreamingAssets\Language"
            $zielLang   = Join-Path $PSScriptRoot "SteamMod\GameData\Language"
            if (Test-Path $quelleLang) {
                if (Test-Path $zielLang) { Remove-Item $zielLang -Recurse -Force }
                Copy-Item -Path $quelleLang -Destination $zielLang -Recurse -Force
                Write-Host "Sprachdateien synchronisiert." -ForegroundColor Green
            }

            # 2. XML Version aktualisieren
            $xmlPfad = Join-Path $PSScriptRoot "SteamMod\About\SteamAbout.xml"
            if (Test-Path $xmlPfad) {
                $content = Get-Content $xmlPfad -Raw
                $neuerContent = $content -replace '<Version>.*</Version>', "<Version>v$aktuelleVersion</Version>"
                $neuerContent | Out-File -FilePath $xmlPfad -Encoding utf8 -Force
                Write-Host "SteamAbout.xml auf v$aktuelleVersion aktualisiert." -ForegroundColor Green
            }
            
            # 3. ZIPs erstellen
            $zipOrdner = Join-Path $PSScriptRoot "zip"
            if (!(Test-Path $zipOrdner)) { New-Item -ItemType Directory -Path $zipOrdner -Force | Out-Null }
            Remove-Item (Join-Path $zipOrdner "*.zip") -ErrorAction SilentlyContinue
            
            $pfadNormal = Join-Path $zipOrdner "$MOD_NAME-$aktuelleVersion.zip"
            Compress-Archive -Path (Join-Path $PSScriptRoot $DATEIEN_NORMAL) -DestinationPath $pfadNormal -Force
            
            $pfadMod = Join-Path $zipOrdner "${MOD_NAME}_Mod-$aktuelleVersion.zip"
            Compress-Archive -Path ($DATEIEN_MOD | ForEach-Object { Join-Path $PSScriptRoot $_ }) -DestinationPath $pfadMod -Force
            
            $letzteAktion = "ZIPs erstellt ($aktuelleVersion)"
            Write-Host "ZIP-Dateien erfolgreich erstellt!" -ForegroundColor Green
            $null = [Console]::ReadKey()
        }
        
        "5" {
            Write-Host "`n--- GITHUB RELEASE ---" -ForegroundColor Yellow
            $zipNormal = Join-Path $PSScriptRoot "zip\$MOD_NAME-$aktuelleVersion.zip"
            $zipMod    = Join-Path $PSScriptRoot "zip\${MOD_NAME}_Mod-$aktuelleVersion.zip"
            $uploadFiles = @()
            if (Test-Path $zipNormal) { $uploadFiles += "`"$zipNormal`"" }
            if (Test-Path $zipMod)    { $uploadFiles += "`"$zipMod`"" }
            
            if ($uploadFiles.Count -gt 0) {
                $tagName = "v$aktuelleVersion"
                Invoke-Expression "gh release create $tagName $($uploadFiles -join ' ') --title `"Version $aktuelleVersion`" --generate-notes"
                $letzteAktion = "GitHub Release v$aktuelleVersion"
            }
            $null = [Console]::ReadKey()
        }
        
"6" {
            Write-Host "`n--- STEAM WORKSHOP UPDATE ---" -ForegroundColor Yellow
            $steamNotes = Read-Host "Changenotes (Enter fuer: '$letzteNachricht')"
            if (-not $steamNotes) { $steamNotes = $letzteNachricht }
            if (-not $steamNotes) { $steamNotes = "Update v$aktuelleVersion" }

            # Wir bauen die VDF mit expliziten Anführungszeichen
            $vdfContent = @"
"workshopitem"
{
 "appid"             "544550"
 "publishedfileid"   "3694636517"
 "contentfolder"     "$($PSScriptRoot)\SteamMod"
 "changenotes"       "$($steamNotes)"
}
"@# WICHTIG: Encoding auf ASCII setzen für SteamCMD Kompatibilität
            $vdfContent | Out-File -FilePath $VDF_PFAD -Encoding ascii -Force

            if (Test-Path $STEAMCMD_PFAD) {
                Start-Process -FilePath $STEAMCMD_PFAD -ArgumentList "+login Bonbonkocher", "+workshop_build_item `"$VDF_PFAD`"", "+quit" -Wait
                $letzteAktion = "Steam Update erledigt"
            } else { Write-Host "SteamCMD nicht gefunden!" -ForegroundColor Red }
            $null = [Console]::ReadKey()
        }
        
        "v" {
            $aktuelleVersion = (Read-Host "Neue Version").Trim()
            $aktuelleVersion | Out-File -FilePath $DATEI_VERSION -Encoding utf8 -Force
            $letzteAktion = "Version -> $aktuelleVersion"
        }
        
        "n" {
            $MOD_NAME = (Read-Host "Neuer Projekt-Name").Trim()
            $MOD_NAME | Out-File -FilePath $DATEI_NAME -Encoding utf8 -Force
            $letzteAktion = "Name -> $MOD_NAME"
        }
        
        "q" { 
            Write-Host "Beende..." -ForegroundColor Gray
            exit 
        }
        
    }
}