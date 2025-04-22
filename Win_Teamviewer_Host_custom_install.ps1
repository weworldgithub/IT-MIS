<#
.SYNOPSIS
    Installs TeamViewer Host and assigns it via ID (new method).

.PARAMETERS
    -urlmsitw: URL to the MSI file
    -customidtw: CUSTOMCONFIGID
    -assignidtw: ID for post-installation assignment

.NOTES
    Compatible with TeamViewer installed in Program Files or Program Files (x86)
#>

param (
   [string] $urlmsitw,
   [string] $customidtw,
   [string] $assignidtw
)

# Check parameters
if ([string]::IsNullOrEmpty($urlmsitw))    { throw "URL MSI not specified. Use -urlmsitw <url>" }
if ([string]::IsNullOrEmpty($customidtw))  { throw "CUSTOMCONFIGID missing. Use -customidtw <id>" }
if ([string]::IsNullOrEmpty($assignidtw))  { throw "Assignment ID missing. Use -assignidtw <id>" }

Write-Host "Checking installed TeamViewer versions..."

# Check both 32-bit and 64-bit installations
$installedSoftware = @( 
    Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue;
    Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue
) | Where-Object { $_.DisplayName -like "*TeamViewer*" }

# Uninstall Full Client if present
if ($installedSoftware) {
    $tvEntry = $installedSoftware | Select-Object -First 1
    if ($tvEntry.DisplayName -notlike "*Host*") {
        Write-Host "Found TeamViewer Full Client. Proceeding with silent uninstall..."
        # Silent uninstall with wmic
        $uninstallCommand = 'wmic product where "name = \'TeamViewer\'" call uninstall /nointeractive'
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstallCommand" -Wait
        Start-Sleep -Seconds 10
    } else {
        Write-Host "TeamViewer Host already installed. Proceeding with assignment."
    }
} else {
    Write-Host "No TeamViewer version found."
}

# Possible paths for TeamViewer.exe
$possiblePaths = @(
    "${env:ProgramFiles(x86)}\TeamViewer\TeamViewer.exe",
    "${env:ProgramFiles}\TeamViewer\TeamViewer.exe"
)

$tvExePath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $tvExePath) {
    Write-Host "Installing TeamViewer Host from: $urlmsitw"
    $msiPath = Join-Path $env:TEMP "TeamViewer_Host.msi"
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $urlmsitw -OutFile $msiPath

    Write-Host "Silent installation in progress..."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msiPath`" /qn CUSTOMCONFIGID=$customidtw" -Wait
    Start-Sleep -Seconds 10

    # Check again for TeamViewer.exe
    $tvExePath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $tvExePath) {
        Write-Host "Error: TeamViewer.exe not found after installation."
        exit 1
    }
}

# Perform assignment
Write-Host "Performing assignment using ID: $assignidtw"
Start-Process -FilePath $tvExePath -ArgumentList "assignment --id $assignidtw" -Wait

Write-Host "✅ Installation and assignment completed successfully."
