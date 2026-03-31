Set-Location $PSScriptRoot

$letzteAktion = "Keine (Programm gestartet)"

while ($true) {
    Clear-Host
    Write-Host "--- GitHub Projekt Manager ---" -ForegroundColor Cyan
    Write-Host "Verzeichnis: $PSScriptRoot" -ForegroundColor Gray
    Write-Host "Letzte Aktion: " -NoNewline
    Write-Host $letzteAktion -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Was moechtest du tun?" -ForegroundColor White
    Write-Host "------------------------------------------------"
    Write-Host "[1] Pull          - Projektdaten laden"
    Write-Host "[2] Push          - Lokale Aenderungen hochladen"
    Write-Host "[3] Status-Zeile  - Detail-Ansicht der geaenderten Zeilen"
    Write-Host "[4] Status-Datei  - Nur Liste der geaenderten Dateien"
    Write-Host "[5] Release       - Neue Version veroeffentlichen (gh)"
    Write-Host "[Q] Quit          - Programm beenden"
    Write-Host "------------------------------------------------"
    Write-Host ""

    $auswahl = Read-Host "-> Auswahl"

    switch ($auswahl) {
        "1" {
            Write-Host "`nFuehre 'git pull' aus..." -ForegroundColor Yellow
            git pull
            $letzteAktion = "Pull ausgefuehrt ($(Get-Date -Format 'HH:mm:ss'))"
            Write-Host "`nFertig. Druecke eine Taste..."
            $null = [Console]::ReadKey()
        }
        "2" {
            Write-Host "`nBereite Push vor..." -ForegroundColor Yellow
            $msg = Read-Host "Commit-Nachricht (leer lassen fuer Zeitstempel)"
            if (-not $msg) { $msg = "Update $(Get-Date -Format 'dd.MM.yyyy HH:mm')" }
            
            git add .
            git commit -m "$msg"
            git push
            $letzteAktion = "Push mit Nachricht: '$msg'"
            
            Write-Host "`nFertig. Druecke eine Taste..."
            $null = [Console]::ReadKey()
        }
        "3" {
            Write-Host "`n--- DETAIL STATUS (Zeilen-Aenderungen) ---" -ForegroundColor Yellow
            # git diff zeigt die genauen Zeilenunterschiede
            # --stat zeigt erst eine Zusammenfassung, dann kommen die Details
            git diff
            
            # Falls die Dateien bereits mit 'git add' vorgemerkt wurden, braucht man --cached
            Write-Host "`n--- Bereits vorgemerkte (staged) Aenderungen ---" -ForegroundColor DarkYellow
            git diff --cached
            
            $letzteAktion = "Status-Zeile geprueft ($(Get-Date -Format 'HH:mm:ss'))"
            Write-Host "`nDruecke eine Taste fuer das Menue..."
            $null = [Console]::ReadKey()
        }
        "4" {
            Write-Host "`n--- DATEI STATUS ---" -ForegroundColor Yellow
            git status -s  # -s fuer eine kompakte Liste
            $letzteAktion = "Status-Datei geprueft ($(Get-Date -Format 'HH:mm:ss'))"
            Write-Host "`nDruecke eine Taste..."
            $null = [Console]::ReadKey()
        }
        "5" {
            if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
                Write-Host "GitHub CLI nicht gefunden!" -ForegroundColor Red
            } else {
                $version = Read-Host "Version (z.B. v1.0.0)"
                $zip = Read-Host "Pfad zur ZIP"
                if ($version -and (Test-Path $zip)) {
                    gh release create $version $zip --generate-notes
                    $letzteAktion = "Release $version erstellt"
                }
            }
            $null = [Console]::ReadKey()
        }
        "q" { break }
        default {
            Write-Host "Ungueltige Auswahl." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}