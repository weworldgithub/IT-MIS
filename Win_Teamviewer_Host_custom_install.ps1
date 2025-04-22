<#
.SYNOPSIS
    Installa TeamViewer Host personalizzato e lo assegna tramite nuovo metodo di deployment (Assignment ID).

.PARAMETERS
    -urlmsitw     : URL diretto al file MSI di TeamViewer Host
    -customidtw   : CUSTOMCONFIGID usato per configurazione personalizzata dell'MSI
    -assignidtw   : Assignment ID da usare per l'assegnazione post-installazione

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

Write-Host "🔍 Verifica presenza di versioni TeamViewer installate..."

# Cerca installazioni TeamViewer complete (non Host) e disinstalla silenziosamente
$tvFull = Get-CimInstance -ClassName Win32_Product | Where-Object {
    $_.Name -like "TeamViewer*" -and $_.Name -notlike "*Host*"
}

foreach ($app in $tvFull) {
    Write-Host "🧹 Trovato client completo: $($app.Name). Procedo con disinstallazione silenziosa..."
    $app | Invoke-CimMethod -MethodName Uninstall
    Start-Sleep -Seconds 10
}

# Possibili percorsi di TeamViewer.exe (sia 64-bit che 32-bit)
$possiblePaths = @(
    "${env:ProgramFiles(x86)}\TeamViewer\TeamViewer.exe",
    "${env:ProgramFiles}\TeamViewer\TeamViewer.exe"
)

# Controlla se TeamViewer Host è già installato
$tvExePath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

# Se non trovato, installa TeamViewer Host da URL MSI
if (-not $tvExePath) {
    Write-Host "📥 Scarico e installo TeamViewer Host da: $urlmsitw"

    $msiPath = Join-Path $env:TEMP "TeamViewer_Host.msi"
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $urlmsitw -OutFile $msiPath

    Write-Host "⚙️ Installazione silenziosa in corso..."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msiPath`" /qn CUSTOMCONFIGID=$customidtw" -Wait
    Start-Sleep -Seconds 10

    # Controllo nuovamente se TeamViewer.exe è stato installato
    $tvExePath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $tvExePath) {
        Write-Host "❌ Errore: TeamViewer.exe non trovato dopo installazione."
        exit 1
    }
} else {
    Write-Host "✅ TeamViewer Host già installato."
}

# Assegnazione dell’host tramite ID
Write-Host "🔐 Procedo con assegnazione usando ID: $assignidtw"
Start-Process -FilePath $tvExePath -ArgumentList "assignment --id $assignidtw" -Wait

Write-Host "🎉 Installazione e assegnazione completate con successo!"
