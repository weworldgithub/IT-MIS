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
   [string] $urlmsitw,   # URL of the TeamViewer Host MSI file
   [string] $customidtw,  # Custom configuration ID for TeamViewer Host
   [string] $assignidtw   # TeamViewer assignment ID
)

# Check if all required parameters are provided
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
    # Loop through each instance of TeamViewer found
    foreach ($software in $installedSoftware) {
        # If it's the full client, uninstall it
        if ($software.DisplayName -notlike "*Host*") {
            Write-Host "Found TeamViewer Full Client. Proceeding with silent uninstall..."
            # Use PowerShell's Get-WmiObject to perform the uninstallation
            $uninstallCommand = $software.PSBase.GetMethodParameters("Uninstall")
            $software.InvokeMethod("Uninstall", $uninstallCommand)
            Start-Sleep -Seconds 10
        } else {
            Write-Host "TeamViewer Host already installed. Proceeding with assignment."
        }
    }
} else {
    Write-Host "No TeamViewer installation found."
}

# Possible paths for TeamViewer.exe (for both 32-bit and 64-bit installations)
$possiblePaths = @(
    "${env:ProgramFiles(x86)}\TeamViewer\TeamViewer.exe",  # 32-bit path
    "${env:ProgramFiles}\TeamViewer\TeamViewer.exe"       # 64-bit path
)

# Check if TeamViewer.exe is installed in either of the paths
$tvExePath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

# If TeamViewer.exe is not found, install the Host
if (-not $tvExePath) {
    Write-Host "Installing TeamViewer Host from: $urlmsitw"
    # Download the MSI to the temp directory
    $msiPath = Join-Path $env:TEMP "TeamViewer_Host.msi"
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $urlmsitw -OutFile $msiPath

    Write-Host "Silent installation in progress..."
    # Perform the MSI installation with the provided CUSTOMCONFIGID
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msiPath`" /qn CUSTOMCONFIGID=$customidtw" -Wait
    Start-Sleep -Seconds 10

    # Check again for TeamViewer.exe after installation
    $tvExePath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $tvExePath) {
        Write-Host "Error: TeamViewer.exe not found after installation."
        exit 1
    }
}

# Perform assignment using the provided assignment ID
Write-Host "Performing assignment using ID: $assignidtw"
Start-Process -FilePath $tvExePath -ArgumentList "assignment --id $assignidtw" -Wait

Write-Host "✅ Installation and assignment completed successfully."
