<#
 .SYNOPSIS
    Set a new Alias Name for MDv2 Device without new Assignment.


 .DESCRIPTION
    The script allows you to set a new Alias Name
	for your Devices in Device Groups (MDv2).
	Per Default the Script is set for 64bit OS and 64bit TeamViewer Clients.
	You can uncomment the line
	$rid = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\TeamViewer"
	and comment the the line like this
	# $rid = Get-ItemProperty "HKLM:\SOFTWARE\TeamViewer"
	so the script can be used for 64bit OS and 32bit TeamViewer Client.


 .REQUIREMENT Device Manager
	The API Token Owner must be also a Device Manager
	for the MDv2 Device.

 .PARAMETER ApiToken
    The TeamViewer API token to use.
    Must be a user access token.
    The token requires the following access permissions:
        - Device Groups -> "read operations", "modifying operations"
	
	Enter the API Token in Line 45 and replace
	YOUR_USER_API_TOKEN with the correct API Token.


 .PARAMETER Alias
	You can change the System Variables to have a different
	Alias Name. Per default the Script use 
	$cname = $env:COMPUTERNAME
	$uname = $env:username


 .NOTES
    Copyright (c) 2024 TeamViewer GmbH
    Version 1.0.1
#>

# Define headers
$headers = @{
    "authorization" = "Bearer 23078073-GCj6dztznanj6kzuePwR"
}


# Get TeamViewer Client ID from the local registry
# Uncomment to use it for 32bit Client on 64bit OS
$rid = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\TeamViewer"
# $rid = Get-ItemProperty "HKLM:\SOFTWARE\TeamViewer"
$cid = $rid.ClientID

# Invoke REST method to retrieve devices from the specified URL
$devicesResponse = Invoke-RestMethod -Uri "https://webapi.teamviewer.com/api/v1/managed/devices" -Method Get -Headers $headers

# Get devices from the response
$devices = $devicesResponse.resources

# Find the device with a matching TeamViewer ID
$matchingDevice = $devices | Where-Object { $_.teamviewerId -eq $cid }

# Define Alias Variables
$cname = $env:COMPUTERNAME
$uname = $env:username

# If a matching device is found, update the alias
if ($matchingDevice) {
    # Construct a new alias using Define Alias Variables
    $newAlias = "$cname - $uname"
    
    # Update the device alias using the PUT method
    $body = @{
        name = $newAlias
    } | ConvertTo-Json
    
    # Invoke REST method to update device information
    Invoke-RestMethod -Uri "https://webapi.teamviewer.com/api/v1/managed/devices/$($matchingDevice.id)" -Method PUT -Headers $headers -ContentType application/json -Body $body

    Write-Host "Alias updated successfully for Device ID: $($matchingDevice.id) with new alias: $newAlias"
} else {
    Write-Host "No matching device found for TeamViewer ID: $cid"
}