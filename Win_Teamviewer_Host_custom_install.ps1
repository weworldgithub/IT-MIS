# Verifica presenza di versioni TeamViewer installate...
Write-Host "Verifica presenza di versioni TeamViewer installate (tramite registro)..."

# Chiavi di registro dove cercare le informazioni di disinstallazione
$uninstallKeys = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

# Ricerca delle voci di registro di TeamViewer (non Host)
$tvFullRegistry = Get-ChildItem -Path $uninstallKeys | Get-ItemProperty | Where-Object {
    $_.DisplayName -like "TeamViewer *" -and $_.DisplayName -notlike "*Host*"
}

foreach ($app in $tvFullRegistry) {
    Write-Host "Trovata installazione completa tramite registro: $($app.DisplayName)."

    # Recupera il percorso di disinstallazione
    $uninstallString = if ($app.UninstallString) { $app.UninstallString } elseif ($app.QuietUninstallString) { $app.QuietUninstallString }

    if ($uninstallString) {
        Write-Host "Comando di disinstallazione trovato: $uninstallString"
        if ($uninstallString -like "*uninstall.exe*") {
            Write-Host "Rilevato uninstall.exe. Esecuzione silenziosa..."
            try {
                Start-Process -FilePath $uninstallString -ArgumentList "/S" -Wait -ErrorAction Stop
                $exitCodeUninstall = $LASTEXITCODE
                Write-Host "Disinstallazione completata con codice di uscita: $exitCodeUninstall"
                if ($exitCodeUninstall -ne 0) {
                    Write-Warning "La disinstallazione potrebbe aver riscontrato problemi. Codice di uscita: $exitCodeUninstall"
                }
                Start-Sleep -Seconds 20
            } catch {
                Write-Warning "Errore durante l'esecuzione del comando di disinstallazione: $($_.Exception.Message)"
            }
        } else {
            Write-Warning "Comando di disinstallazione non standard. Impossibile eseguire la disinstallazione automatica in modo sicuro."
        }
    } else {
        Write-Warning "Stringa di disinstallazione non trovata per $($app.DisplayName). Impossibile disinstallare automaticamente."
    }
}
