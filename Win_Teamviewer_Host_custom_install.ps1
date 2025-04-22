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

# Percorsi possibili per le directory di installazione di TeamViewer
$possibleInstallPathsFull = @(
    "${env:ProgramFiles(x86)}\TeamViewer",
    "${env:ProgramFiles}\TeamViewer"
)

# Cerca installazioni TeamViewer complete (non Host) e disinstalla silenziosamente tramite uninstall.exe
$tvFull = Get-CimInstance -ClassName Win32_Product | Where-Object {
    $_.Name -like "TeamViewer*" -and $_.Name -notlike "*Host*"
}

foreach ($app in $tvFull) {
    Write-Host "Trovato client completo: $($app.Name)."

    # Cerca la directory di installazione corrispondente
    $installDir = $possibleInstallPathsFull | Where-Object { Test-Path (Join-Path $_ "TeamViewer.exe") } | Select-Object -First 1

    if ($installDir) {
        $uninstallExe = Join-Path $installDir "uninstall.exe"
        if (Test-Path $uninstallExe) {
            Write-Host "Trovato uninstall.exe in: $uninstallExe. Procedo con disinstallazione silenziosa..."
            Start-Process -FilePath $uninstallExe -ArgumentList "/S" -Wait
            Start-Sleep -Seconds 15 # Aumento la pausa per dare tempo alla disinstallazione
        } else {
            Write-Warning "File uninstall.exe non trovato nella directory di installazione di TeamViewer. Impossibile disinstallare automaticamente."
        }
    } else {
        Write-Warning "Directory di installazione di TeamViewer non trovata. Impossibile disinstallare automaticamente."
    }
}

# Percorsi possibili per TeamViewer.exe (dopo la disinstallazione o se non c'era)
$possiblePaths = @(
    "${env:ProgramFiles(x86)}\TeamViewer\TeamViewer.exe",
    "${env:ProgramFiles}\TeamViewer\TeamViewer.exe"
)

# Verifica se TeamViewer Host è già installato
$tvExePathHost = $possiblePaths | Where-Object { $_ -like "*Host*" -and (Test-Path $_) } | Select-Object -First 1

if (-not $tvExePathHost) {
    Write-Host "Scarico e installo TeamViewer Host da: $urlmsitw"

    $msiPath = Join-Path $env:TEMP "TeamViewer_Host.msi"
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $urlmsitw -OutFile $msiPath

    Write-Host "Installazione silenziosa in corso..."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msiPath`" /qn CUSTOMCONFIGID=$customidtw" -Wait
    Start-Sleep -Seconds 10

    # Controllo se TeamViewer.exe (Host) è stato installato
    $tvExePathHost = $possiblePaths | Where-Object { $_ -like "*Host*" -and (Test-Path $_) } | Select-Object -First 1
    if (-not $tvExePathHost) {
        Write-Host "Errore: TeamViewer Host non trovato dopo installazione."
        exit 1
    }
} else {
    Write-Host "TeamViewer Host già installato."
}

# Assegnazione dell’host
Write-Host "Procedo con assegnazione usando ID: $assignidtw"
Start-Process -FilePath $tvExePathHost -ArgumentList "assignment --id $assignidtw" -Wait

Write-Host "Installazione e assegnazione completate con successo!"


