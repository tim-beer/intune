
<#

.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.

#>

####################################################

function Get-AuthToken {

<#
.SYNOPSIS
This function is used to authenticate with the Graph API REST interface
.DESCRIPTION
The function authenticate with the Graph API Interface with the tenant name
.EXAMPLE
Get-AuthToken
Authenticates you with the Graph API interface
.NOTES
NAME: Get-AuthToken
#>

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)]
    $User
)

$userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User

$tenant = $userUpn.Host

Write-Host "Checking for AzureAD module..."

    $AadModule = Get-Module -Name "AzureAD" -ListAvailable

    if ($AadModule -eq $null) {

        Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
        $AadModule = Get-Module -Name "AzureADPreview" -ListAvailable

    }

    if ($AadModule -eq $null) {
        write-host
        write-host "AzureAD Powershell module not installed..." -f Red
        write-host "Install by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt" -f Yellow
        write-host "Script can't continue..." -f Red
        write-host
        exit
    }

# Getting path to ActiveDirectory Assemblies
# If the module count is greater than 1 find the latest version

    if($AadModule.count -gt 1){

        $Latest_Version = ($AadModule | select version | Sort-Object)[-1]

        $aadModule = $AadModule | ? { $_.version -eq $Latest_Version.version }

            # Checking if there are multiple versions of the same module found

            if($AadModule.count -gt 1){

            $aadModule = $AadModule | select -Unique

            }

        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"

    }

    else {

        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"

    }

[System.Reflection.Assembly]::LoadFrom($adal) | Out-Null

[System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null

$clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"

$redirectUri = "urn:ietf:wg:oauth:2.0:oob"

$resourceAppIdURI = "https://graph.microsoft.com"

$authority = "https://login.microsoftonline.com/$Tenant"

    try {

    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority

    # https://msdn.microsoft.com/en-us/library/azure/microsoft.identitymodel.clients.activedirectory.promptbehavior.aspx
    # Change the prompt behaviour to force credentials each time: Auto, Always, Never, RefreshSession

    $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"

    $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")

    $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI,$clientId,$redirectUri,$platformParameters,$userId).Result

        # If the accesstoken is valid then create the authentication header

        if($authResult.AccessToken){

        # Creating header for Authorization token

        $authHeader = @{
            'Content-Type'='application/json'
            'Authorization'="Bearer " + $authResult.AccessToken
            'ExpiresOn'=$authResult.ExpiresOn
            }

        return $authHeader

        }

        else {

        Write-Host
        Write-Host "Authorization Access Token is null, please re-run authentication..." -ForegroundColor Red
        Write-Host
        break

        }

    }

    catch {

    write-host $_.Exception.Message -f Red
    write-host $_.Exception.ItemName -f Red
    write-host
    break

    }

}

####################################################



####################################################

#Time Section
# Filter for the minimum number of minutes where the device hasn't synced

#change the minutes value for your own requirements
$Minutes = 30
$Minutesago = "{0:s}" -f (get-date).AddMinutes(-$minutes) + "Z"

$CurrentTime = [System.DateTimeOffset]::Now

Write-Host
Write-Host "Checking for any devices to be synced" -f Yellow
Write-Host

    try {

    $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=lastSyncDateTime ge $Minutesago"

    $Devices = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | sort deviceName 
        # If there are devices not synced in the past 0 days script continues
        
        if($Devices){

        Write-Host "There are" $Devices.count "devices that have not synced in the last $minutes minutes..." -ForegroundColor Red

        $Devices | foreach { $_.deviceName + " - " + ($_.managementAgent).toupper() + " - " + $_.userPrincipalName + " - " + $_.lastSyncDateTime } 

        Write-Host

            # Looping through all the devices returned
           #foreach($Device in $Devices | Where {$_.managementAgent -match "eas"})
            foreach($Device in $Devices | Where {$_.managementAgent -match "mdm"})
{

            write-host "------------------------------------------------------------------"
            Write-Host

            $DeviceID = $Device.id
            $LSD = $Device.lastSyncDateTime

            write-host "Device Name:"$Device.deviceName -f Green
            write-host "Management State:"$Device.managementState
            write-host "Operating System:"$Device.operatingSystem
            write-host "Device Type:"$Device.deviceType
            write-host "Last Sync Date Time:"$Device.lastSyncDateTime
            write-host "Jail Broken:"$Device.jailBroken
            write-host "Compliance State:"$Device.complianceState
            write-host "Enrollment Type:"$Device.enrollmentType
            write-host "AAD Registered:"$Device.aadRegistered
            write-host "Management Agent:"$Device.managementAgent
            Write-Host "User Principal Name:"$Device.userPrincipalName

            $LastSyncTime = [datetimeoffset]::Parse($LSD)

            $TimeDifference = $CurrentTime - $LastSyncTime

            write-host
            write-host "Device last synced"$TimeDifference.minutes "minutes ago, sent new sync request" -ForegroundColor Red
            Write-Host

            $Resource = "deviceManagement/managedDevices/$DeviceID/syncDevice"
            $uri = "https://graph.microsoft.com/beta/$($resource)"
            write-verbose $uri
            Write-Verbose "Sending deviceSync command to $DeviceID"
            Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post

            }

        }

        else {

        write-host "No Devices not synced in the last $minutes minutes found..." -f green
        Write-Host


        }

    }

    catch {

    Write-Host
    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    Write-Host

    break

    }
####################################################

#region Authentication

write-host

# Checking if authToken exists before running authentication
if($global:authToken){

    # Setting DateTime to Universal time to work in all timezones
    $DateTime = (Get-Date).ToUniversalTime()

    # If the authToken exists checking when it expires
    $TokenExpires = ($authToken.ExpiresOn.datetime - $DateTime).Minutes

        if($TokenExpires -le 0){

        write-host "Authentication Token expired" $TokenExpires "minutes ago" -ForegroundColor Yellow
        write-host

            # Defining User Principal Name if not present

            if($User -eq $null -or $User -eq ""){

            $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
            Write-Host

            }

        $global:authToken = Get-AuthToken -User $User

        }
}

# Authentication doesn't exist, calling Get-AuthToken function

else {

    if($User -eq $null -or $User -eq ""){

    $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
    Write-Host

    }

# Getting the authorization token
$global:authToken = Get-AuthToken -User $User

}

#endregion

####################################################

