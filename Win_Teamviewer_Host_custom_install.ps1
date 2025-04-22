<#
.SYNOPSIS
    Installa TeamViewer Host e lo assegna tramite ID, con la nuova sintassi (CUSTOMCONFIGID + assignment --id).

.REQUIREMENTS
    - MSI caricato su URL.
    - CUSTOMCONFIGID (da Management Console).
    - ASSIGNMENT_ID (per assegnazione automatica).

.INSTRUCTIONS
    Crea in Tactical RMM:
        a) LinkMSITW -> Text
        b) CUSTOMIDTW -> Text
        c) ASSIGNIDTW -> Text

.NOTES
    V2.4 - Gestisce installazione e assegnazione separate.
#>

param (
   [string] $urlmsitw,
   [string] $customidtw,
   [string] $assignidtw
)

if ([string]::IsNullOrEmpty($urlmsitw)) {
    throw "URL must be defined. Use -urlmsitw <value> to pass it."
}
if ([string]::IsNullOrEmpty($customidtw)) {
    throw "CUSTOMCONFIGID must be defined. Use -customidtw <value> to pass it."
}
if ([string]::IsNullOrEmpty($assignidtw)) {
    throw "Assignment ID must be defined. Use -assignidtw <value> to pass it."
}

Write-Host "Controllo TeamViewer installato..."
$installedSoftware = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Where-Object { $_.DisplayName -like "*TeamViewer*" }

$tvPath = "${env:ProgramFiles(x86)}\TeamViewer\TeamViewer.exe"

if ($installedSoftware) {
    if ($installedSoftware.DisplayName -like "*Host*") {
        Write-Host "TeamViewer Host è già installato. Procedo con l'assegnazione..."
    } else {
        Write-Host "Trovato TeamViewer Full Client. Procedo alla disinstallazione..."
        $uninstallString = $installedSoftware.UninstallString
        if ($uninstallString) {
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$uninstallString /quiet`"" -Wait
            Start-Sleep -Seconds 10
        } else {
            Write-Host "Impossibile trovare la stringa di disinstallazione. Interruzione script."
            exit 1
        }
    }
}

if (-not (Test-Path $tvPath)) {
    # Scarica e installa
    $tempPath = Join-Path $env:TEMP "TeamViewer_Host.msi"
    Write-Host "Scarico MSI da $urlmsitw..."
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $urlmsitw -OutFile $tempPath

    Write-Host "Installazione TeamViewer Host con CUSTOMCONFIGID=$customidtw"
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$tempPath`" /qn CUSTOMCONFIGID=$customidtw" -Wait
    Start-Sleep -Seconds 10
}

# Assegnazione
if (Test-Path $tvPath) {
    Write-Host "Eseguo l'assegnazione con ID: $assignidtw"
    Start-Process -FilePath $tvPath -ArgumentList "assignment --id $assignidtw" -Wait
    Write-Host "Assegnazione completata."
} else {
    Write-Host "Errore: TeamViewer.exe non trovato dopo installazione."
    exit 1
}
