# This tiny script uploads the CustomPlatform connector script to SPP which is useful for testing.
# It requires the Custom Platform created earlier with a base script.
# It currently supports: Restore|Elevate|Demote|Suspend

# Base parameters
$appliance = "<spp-address>"
$username = "<spp-user-to-upload-the-script-and-run-the-task>"
$provider = "<local|etc>"

# Script Upload parameters
$customPlatformScriptPath = "<path-of-custom-platform-script.json>"
$customPlatformName = "<name-of-platform-as-configured-in-spp>"


# Test parameters
$uploadScript = $true
$accountid = <id-of-test-account>
$restore = $true
$elevate = $false
$demote = $false
$suspend = $true

if (-not($AccessToken)) {
    $AccessToken = Connect-Safeguard -Insecure -Appliance $appliance -Username $username -IdentityProvider $provider -NoSessionVariable
}

if ($uploadScript) {

    $customPlatform = Get-SafeguardPlatform -AccessToken $AccessToken -Appliance $appliance -Fields "id" -Insecure -Platform $customPlatformName
    
    $script = Get-Content $customPlatformScriptPath
    $bytesScript = [System.Text.Encoding]::UTF8.GetBytes($script)
    $base64Script = [Convert]::ToBase64String($bytesScript)
    
    echo "Uploading script to SPP..."

    $scriptupdate = Invoke-SafeguardMethod -Method Put -RelativeUrl $("Platforms/" + $customPlatform.Id + "/Script") -Service Core -AccessToken $AccessToken -Appliance $appliance -Body $base64Script
 }

if ($restore) {
    $tasklog = Invoke-SafeguardMethod -Method Post -RelativeUrl $("AssetAccounts/" + $accountid + "/RestoreAccount?extendedLogging=true") -Service Core -AccessToken $AccessToken -Appliance $appliance
    write-host "Restore task log id: " $tasklog.id
}

if ($elevate) {
    $tasklog = Invoke-SafeguardMethod -Method Post -RelativeUrl $("AssetAccounts/" + $accountid + "/ElevateAccount?extendedLogging=true") -Service Core -AccessToken $AccessToken -Appliance $appliance
    write-host "Elevate task log id: " $tasklog.id
}

if ($demote) {
    $tasklog = Invoke-SafeguardMethod -Method Post -RelativeUrl $("AssetAccounts/" + $accountid + "/DemoteAccount?extendedLogging=true") -Service Core -AccessToken $AccessToken -Appliance $appliance
    write-host "Demote task log id: " $tasklog.id
}

if ($suspend) {
    $tasklog = Invoke-SafeguardMethod -Method Post -RelativeUrl $("AssetAccounts/" + $accountid + "/SuspendAccount?extendedLogging=true") -Service Core -AccessToken $AccessToken -Appliance $appliance
    write-host "Suspend task log id: " $tasklog.id
}
