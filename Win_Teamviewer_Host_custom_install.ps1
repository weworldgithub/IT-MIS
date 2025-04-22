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

# Percorsi possibili per l'eseguibile di TeamViewer (versione completa)
$tvFullExePaths = @(
    "${env:ProgramFiles(x86)}\TeamViewer\TeamViewer.exe",
    "${env:ProgramFiles}\TeamViewer\TeamViewer.exe"
)

# Cerca l'eseguibile della versione completa e disinstalla
$tvFullExeFound = $tvFullExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($tvFullExeFound) {
    Write-Host "Trovata installazione completa di TeamViewer in: $tvFullExeFound"

    # Ricava la directory di installazione
    $installDirFull = Split-Path -Parent $tvFullExeFound
    $uninstallExePath = Join-Path $installDirFull "uninstall.exe"

    if (Test-Path $uninstallExePath) {
        Write-Host "Trovato uninstall.exe in: $uninstallExePath. Procedo con disinstallazione silenziosa..."
        try {
            Start-Process -FilePath $uninstallExePath -ArgumentList "/S" -Wait -ErrorAction Stop
            $exitCodeUninstall = $LASTEXITCODE
            Write-Host "Disinstallazione completata con codice di uscita: $exitCodeUninstall"
            if ($exitCodeUninstall -ne 0) {
                Write-Warning "La disinstallazione potrebbe aver riscontrato problemi. Codice di uscita: $exitCodeUninstall"
            }
            Start-Sleep -Seconds 20
        } catch {
            Write-Warning "Errore durante l'esecuzione di uninstall.exe: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "File uninstall.exe non trovato nella directory di installazione. Impossibile disinstallare automaticamente."
    }
} else {
    Write-Host "Nessuna installazione completa di TeamViewer rilevata."
}

# Percorsi possibili per TeamViewer.exe (dopo la disinstallazione o se non c'era)
$possiblePaths = @(
    "${env:ProgramFiles(x86)}\TeamViewer\TeamViewer.exe",
    "${env:ProgramFiles}\TeamViewer\TeamViewer.exe"
)

# Verifica se TeamViewer Host è già installato
$tvExePathHost = $possiblePaths | Where-Object { $_ -like "*Host*" -and (Test-Path $_) } | Select-Object -First 1

if (-not $tvExePathHost) {
    Write-Host "Scarico TeamViewer Host da: $urlmsitw"

    $msiPath = Join-Path $env:TEMP "TeamViewer_Host.msi"
    $ProgressPreference = 'SilentlyContinue'
    try {
        Write-Host "Tentativo di download del file MSI..."
        Invoke-WebRequest -Uri $urlmsitw -OutFile $msiPath -ErrorAction Stop
        Write-Host "Download completato con successo. File salvato in: $msiPath"
        if (Test-Path $msiPath) {
            Write-Host "File MSI trovato. Tentativo di installazione silenziosa..."
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msiPath`" /qn CUSTOMCONFIGID=$customidtw" -Wait -PassThru | Out-Null
            $exitCodeInstall = $LASTEXITCODE
            Write-Host "Installazione completata con codice di uscita: $exitCodeInstall"
            if ($exitCodeInstall -ne 0) {
                Write-Error "L'installazione di TeamViewer Host ha restituito un errore. Codice di uscita: $exitCodeInstall"
                exit 1
            }
            Start-Sleep -Seconds 10

            # Controllo se TeamViewer.exe (Host) è stato installato
            $tvExePathHost = $possiblePaths | Where-Object { $_ -like "*Host*" -and (Test-Path $_) } | Select-Object -First 1
            if (-not $tvExePathHost) {
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
} else {
    Write-Host "TeamViewer Host già installato."
}

# Assegnazione dell’host
if ($tvExePathHost) {
    Write-Host "Procedo con assegnazione usando ID: $assignidtw"
    Start-Process -FilePath $tvExePathHost -ArgumentList "assignment --id $assignidtw" -Wait
    Write-Host "Installazione e assegnazione completate con successo!"
}
