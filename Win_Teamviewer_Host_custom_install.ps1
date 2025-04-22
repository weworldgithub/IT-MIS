<#
.SYNOPSIS
    Installa TeamViewer Host e lo assegna tramite ID (nuovo metodo).

.PARAMETERS
    -urlmsitw: URL al file MSI
    -customidtw: CUSTOMCONFIGID
    -assignidtw: ID per assegnazione post-installazione

.NOTES
    Compatibile con TeamViewer installato in Program Files o Program Files (x86)
#>

param (
   [string] $urlmsitw,
   [string] $customidtw,
   [string] $assignidtw
)

# Controllo parametri
if ([string]::IsNullOrEmpty($urlmsitw))    { throw "URL MSI non specificato. Usa -urlmsitw <url>" }
if ([string]::IsNullOrEmpty($customidtw))  { throw "CUSTOMCONFIGID mancante. Usa -customidtw <id>" }
if ([string]::IsNullOrEmpty($assignidtw))  { throw "Assignment ID mancante. Usa -assignidtw <id>" }

Write-Host "Controllo versioni TeamViewer installate..."

# Controlla sia a 32 che 64 bit
$installedSoftware = @( 
    Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue;
    Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue
) | Where-Object { $_.DisplayName -like "*TeamViewer*" }

# Disinstalla Full Client se presente
if ($installedSoftware) {
    $tvEntry = $installedSoftware | Select-Object -First 1
    if ($tvEntry.DisplayName -notlike "*Host*") {
        Write-Host "Trovato TeamViewer Full Client. Procedo con disinstallazione..."
        if ($tvEntry.UninstallString) {
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$($tvEntry.UninstallString) /quiet`"" -Wait
            Start-Sleep -Seconds 10
        } else {
            Write-Host "Impossibile trovare stringa di disinstallazione. Interruzione."
            exit 1
        }
    } else {
        Write-Host "TeamViewer Host già presente. Procedo direttamente con assegnazione."
    }
} else {
    Write-Host "Nessuna versione TeamViewer rilevata."
}

# Percorso possibile per TeamViewer.exe
$possiblePaths = @(
    "${env:ProgramFiles(x86)}\TeamViewer\TeamViewer.exe",
    "${env:ProgramFiles}\TeamViewer\TeamViewer.exe"
)

$tvExePath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $tvExePath) {
    Write-Host "Installazione TeamViewer Host da: $urlmsitw"
    $msiPath = Join-Path $env:TEMP "TeamViewer_Host.msi"
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $urlmsitw -OutFile $msiPath

    Write-Host "Installazione silenziosa in corso..."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msiPath`" /qn CUSTOMCONFIGID=$customidtw" -Wait
    Start-Sleep -Seconds 10

    # Ricerca nuovamente l'eseguibile
    $tvExePath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $tvExePath) {
        Write-Host "Errore: TeamViewer.exe non trovato dopo installazione."
        exit 1
    }
}

# Assegnazione
Write-Host "Eseguo assegnazione tramite: assignment --id $assignidtw"
Start-Process -FilePath $tvExePath -ArgumentList "assignment --id $assignidtw" -Wait

Write-Host "✅ Installazione e assegnazione completate con successo."
