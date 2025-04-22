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
    "${env:ProgramFiles}\TeamViewer\TeamViewer_Service.exe",
    "${env:ProgramFiles(x86)}\TeamViewer\TeamViewer.exe", # Fallback
    "${env:ProgramFiles}\TeamViewer\TeamViewer.exe"      # Fallback
)
$tvHostInstalled = $tvHostExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($tvHostInstalled) {
    Write-Host "TeamViewer Host già installato (rilevato dal servizio)."
} else {
    # Verifica presenza di versioni TeamViewer complete (non Host) tramite registro e disinstalla
    Write-Host "Verifica presenza di versioni TeamViewer complete (tramite registro - filtro preciso)..."

    # Chiavi di registro dove cercare le informazioni di disinstallazione
    $uninstallKeys = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    # Ricerca delle voci di registro di TeamViewer che NON contengono "Host" nel DisplayName
    $tvFullRegistry = Get-ChildItem -Path $uninstallKeys | Get-ItemProperty | Where-Object {
        $_.DisplayName -like "TeamViewer" -and $_.DisplayName -notlike "*Host*" -and $_.UninstallString -like "*TeamViewer*"
    }

    foreach ($app in $tvFullRegistry) {
        Write-Host "Trovata installazione completa tramite registro (filtrata): $($app.DisplayName)."

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

    # Se TeamViewer Host non è già installato, procedi con il download e l'installazione
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
# Percorsi possibili per la directory di installazione di TeamViewer
$programFilesX86 = "${env:ProgramFiles(x86)}\TeamViewer"
$programFiles = "${env:ProgramFiles}\TeamViewer"
$tvExeName = "TeamViewer.exe"

if (Test-Path $programFilesX86) {
    Write-Host "Cambio directory a: $programFilesX86"
    Set-Location -Path $programFilesX86
    $tvExeFullPath = Join-Path $programFilesX86 $tvExeName
    try {
        & "$tvExeFullPath" assignment --id "$assignidtw"
        Write-Host "Comando di assegnazione (x86) inviato."
    } catch {
        Write-Warning "Errore durante l'assegnazione (x86): $($_.Exception.Message)"
    } finally {
        # Ritorna alla directory originale (opzionale, ma buona pratica)
        Pop-Location
    }
} elseif (Test-Path $programFiles) {
    Write-Host "Cambio directory a: $programFiles"
    Set-Location -Path $programFiles
    $tvExeFullPath = Join-Path $programFiles $tvExeName
    try {
        & "$tvExeFullPath" assignment --id "$assignidtw"
        Write-Host "Comando di assegnazione (x64) inviato."
    } catch {
        Write-Warning "Errore durante l'assegnazione (x64): $($_.Exception.Message)"
    } finally {
        # Ritorna alla directory originale (opzionale, ma buona pratica)
        Pop-Location
    }
} else {
    Write-Warning "Avviso: Impossibile trovare la directory di installazione di TeamViewer per l'assegnazione."
}
