<#
.SYNOPSIS
    Installa TeamViewer Host personalizzato e lo assegna tramite nuovo metodo di deployment (Assignment ID).

.PARAMETERS
    -urlmsitw      : URL diretto al file MSI di TeamViewer Host
    -customidtw    : CUSTOMCONFIGID usato per configurazione personalizzata dell'MSI
    -assignidtw    : Assignment ID da usare per l'assegnazione post-installazione

.NOTES
    Supporta disinstallazione del client completo se presente, installazione e assegnazione automatica.
#>

param (
    [string] $urlmsitw,
    [string] $customidtw,
    [string] $assignidtw
)

# Verifica parametri obbligatori
if ([string]::IsNullOrEmpty($urlmsitw))    { throw "URL MSI non specificato. Usa -urlmsitw <url>" }
if ([string]::IsNullOrEmpty($customidtw))  { throw "CUSTOMCONFIGID mancante. Usa -customidtw <id>" }
if ([string]::IsNullOrEmpty($assignidtw))  { throw "Assignment ID mancante. Usa -assignidtw <id>" }

Write-Host "Verifica presenza di versioni TeamViewer installate..."

# Verifica se TeamViewer Host è già installato (usando l'eseguibile specifico del servizio)
$tvHostExePaths = @(
    "${env:ProgramFiles(x86)}\TeamViewer\TeamViewer_Service.exe",
    "${env:ProgramFiles}\TeamViewer\TeamViewer_Service.exe"
)
$tvHostInstalled = $tvHostExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($tvHostInstalled) {
    Write-Host "TeamViewer Host già installato (rilevato dal servizio)."
    exit 0 # Esci dallo script se Host è già installato
}

# Verifica presenza di versioni TeamViewer complete (non Host) tramite registro e disinstalla
Write-Host "Verifica presenza di versioni TeamViewer complete (tramite registro)..."

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

# Percorsi possibili per TeamViewer.exe (dopo la disinstallazione o se non c'era)
$possiblePaths = @(
    "${env:ProgramFiles(x86)}\TeamViewer\TeamViewer.exe",
    "${env:ProgramFiles}\TeamViewer\TeamViewer.exe"
)

# Se TeamViewer Host non è già installato, procedi con il download e l'installazione
if (-not $tvHostInstalled) {
    Write-Host "Scarico TeamViewer Host da: $urlmsitw"

    $msiPath = Join-Path $env:TEMP "TeamViewer_Host.msi"
    $ProgressPreference = 'SilentlyContinue'
    try {
        Write-Host "Tentativo di download del file MSI..."
        Invoke-WebRequest -Uri $urlmsitw -OutFile $msiPath -ErrorAction Stop
        Write-Host "Download completato con successo. File salvato in: $msiPath"
        if (Test-Path $msiPath) {
            Write-Host "File MSI trovato. Tentativo di installazione silenziosa..."
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msiPath`" /qn CUSTOMCONFIGID=$customidtw" -Wait -PassThru
            $exitCodeInstall = $process.ExitCode
            Write-Host "Installazione completata con codice di uscita: $exitCodeInstall"
            if ($exitCodeInstall -ne 0) {
                Write-Error "L'installazione di TeamViewer Host ha restituito un errore. Codice di uscita: $exitCodeInstall"
                exit 1
            }
            Start-Sleep -Seconds 10

            # Controllo se TeamViewer.exe (Host) è stato installato (cerchiamo di nuovo il servizio)
            $tvHostInstalledCheck = $tvHostExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
            if (-not $tvHostInstalledCheck) {
                Write-Host "Errore: TeamViewer Host non trovato dopo installazione."
                exit 1
            }
        } else {
            Write-Error "Errore: File MSI non trovato dopo il download."
            exit 1
        }
    } catch {
        Write-Error "Errore durante il download del file MSI: $($_.Exception.Message)"
        exit 1
    }
}

# Assegnazione dell’host
if ($tvHostInstalled -or $tvHostInstalledCheck) {
    # Determina il percorso dell'eseguibile Host (potrebbe essere necessario se non l'abbiamo tracciato prima)
    $tvHostExe = $tvHostExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($tvHostExe) {
        Write-Host "Procedo con assegnazione usando ID: $assignidtw"
        Start-Process -FilePath $tvHostExe -ArgumentList "assignment --id $assignidtw" -Wait
        Write-Host "Installazione e assegnazione completate con successo!"
    } else {
        Write-Warning "Avviso: Impossibile trovare l'eseguibile di TeamViewer Host per l'assegnazione."
    }
}
