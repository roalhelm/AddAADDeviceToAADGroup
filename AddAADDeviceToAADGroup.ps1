<#
.SYNOPSIS
    This script adds devices to an Azure AD group based on a list provided in a CSV file.
    It also checks if the device is already in the group before attempting to add it.
    GitHub Repository: https://github.com/roalhelm/

.CHANGES
    Version 1.6 (2025-12-11):
    - BREAKING: Removed AzureAD module support (Azure AD Graph API has been deprecated by Microsoft)
    - Now uses Microsoft.Graph SDK exclusively for all PowerShell versions
    - Requires PowerShell 5.1 or higher (Windows PowerShell 5.1 or PowerShell Core 7+)
    - Microsoft.Graph module is now compatible with all supported PowerShell versions

    Version 1.5 (2025-11-24):
    - Added cross-platform support (macOS, Linux, Windows)
    - Automatic detection of PowerShell version (Core 7+ vs Windows PowerShell 5.1)
    - Uses Microsoft.Graph SDK for PowerShell Core 7+
    - Falls back to AzureAD module for Windows PowerShell 5.1
    - Improved module installation and import error handling

    Version 1.4 (2025-09-17):
    - Improved error handling: If the error 'One or more added object references already exist for the following modified properties' occurs, the script now outputs that the client is already in the group and logs this as a warning instead of an error.

    Version 1.3 (2025-04-28):
    - Added CSV header validation to ensure "DeviceName" column exists
    - Added detailed error messaging for CSV format issues

    Version 1.2 (2025-03-13):
    - Added group existence validation
    - Added multiple group detection
    - Improved error handling for group operations
    - Added separate error log file

    Version 1.1 (2025-03-11):
    - Added support for multiple CSV file selection
    - Enhanced logging with timestamps
    - Added try-catch blocks for better error handling

    Version 1.0 (2025-03-10):
    - Initial release
    - Basic functionality to add devices to AAD group
    - CSV file support
    - Basic logging

.DESCRIPTION
    The script prompts the user for an Azure AD group name, then reads a CSV file named 'Devices.csv' containing device names.
    It verifies if each device is already a member of the specified Azure AD group before adding it.
    A log file is created to track successes, failures, and already existing devices.
    
    The script uses Microsoft.Graph SDK exclusively for all PowerShell versions.
    Supports PowerShell 5.1+ on Windows and PowerShell Core 7+ on macOS/Linux.

.NOTES
    - Requires Microsoft.Graph module (works on all platforms)
    - Compatible with PowerShell 5.1+ (Windows) and PowerShell Core 7+ (macOS, Linux, Windows)
    - The script will automatically install Microsoft.Graph module if not present
    - Appropriate Azure AD permissions are required (Group.ReadWrite.All, Directory.Read.All, Device.Read.All)
    - The CSV file must be placed in the same directory as this script.
    - Note: AzureAD module is no longer supported due to Azure AD Graph API deprecation

.AUTHOR

    Original script by Ronny Alhelm
    Version        : 1.6
    Creation Date  : 2025-03-10
    Last Modified  : 2025-12-11

.EXAMPLE
    PS C:\> .\AddAADDeviceToAADGroup.ps1
    Enter the Azure AD group name: MyDeviceGroup
    The script will process the devices listed in 'Devices.csv' and attempt to add them to 'MyDeviceGroup'.
    
    Works on Windows (PowerShell 5.1 or 7+), macOS (PowerShell 7+), and Linux (PowerShell 7+).
#>

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
Write-Host "PowerShell Version: $psVersion" -ForegroundColor Cyan

if ($psVersion.Major -lt 5 -or ($psVersion.Major -eq 5 -and $psVersion.Minor -lt 1)) {
    Write-Host "FATAL ERROR: This script requires PowerShell 5.1 or higher." -ForegroundColor Red
    Write-Host "Please upgrade your PowerShell version." -ForegroundColor Red
    exit 1
}

Write-Host "Using Microsoft Graph PowerShell SDK (AzureAD module is deprecated)." -ForegroundColor Cyan

function Escape-ODataStringLiteral {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return $Value.Replace("'", "''")
}

$scriptDirectory = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

# Check and install Microsoft.Graph module
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    try {
        Write-Host "Microsoft.Graph module not found. Installing..." -ForegroundColor Yellow
        Install-Module Microsoft.Graph -Scope CurrentUser -Force -ErrorAction Stop
        Write-Host "Microsoft.Graph module has been installed successfully." -ForegroundColor Green
    } catch {
        Write-Host "FATAL ERROR: Could not install Microsoft.Graph module. Please install manually." -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Microsoft.Graph module is already installed." -ForegroundColor Green
}

# Import required Microsoft.Graph modules
try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Groups -ErrorAction Stop
    Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop
    Write-Host "Microsoft.Graph modules imported successfully." -ForegroundColor Green
} catch {
    Write-Host "FATAL ERROR: Could not import Microsoft.Graph modules." -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}

function Connect-MgGraphWithFallback {
    param(
        [string[]]$Scopes
    )

    try {
        Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
    }
    catch {
        Write-Host "Interactive browser sign-in could not be completed or was hidden behind another window. Trying device-code sign-in instead..." -ForegroundColor Yellow
        try {
            Connect-MgGraph -Scopes $Scopes -UseDeviceAuthentication -NoWelcome -ErrorAction Stop
            Write-Host "Device-code authentication started in the console. Open the URL shown and enter the code." -ForegroundColor Green
        }
        catch {
            Write-Host "Authentication failed with both interactive and device-code sign-in. Please run the script in a normal PowerShell window and sign in again." -ForegroundColor Red
            throw
        }
    }
}

# Prompt the user for target type
$targetTypeChoice = Read-Host "Welche Objekte möchten Sie einer AAD-Gruppe hinzufügen? Enter 1 for Clients/Devices or 2 for Users"

$targetType = switch ($targetTypeChoice) {
    "1" { "Device" }
    "2" { "User" }
    default {
        Write-Host "Invalid choice. Defaulting to Devices/Clients." -ForegroundColor Yellow
        "Device"
    }
}

# Prompt the user for the group name
$groupName = Read-Host "Enter the Azure AD group name"

# Prompt the user for CSV file choice
if ($targetType -eq "Device") {
    $defaultCsvName = "Devices.csv"
    $secondaryCsvName = "Devices_In_AAD.csv"
    $validHeaders = @("DeviceName", "AzureADDeviceId", "DeviceId")
} else {
    $defaultCsvName = "Users.csv"
    $secondaryCsvName = "Users_In_AAD.csv"
    $validHeaders = @("UserPrincipalName", "UPN", "Mail", "Email", "DisplayName", "UserName", "ObjectId", "Id")
}

$csvChoice = Read-Host "Which CSV file do you want to use? Enter 1 for $defaultCsvName or 2 for $secondaryCsvName"

# Set the CSV file path based on user choice
$csvPath = switch ($csvChoice) {
    "1" { Join-Path -Path $scriptDirectory -ChildPath $defaultCsvName }
    "2" { Join-Path -Path $scriptDirectory -ChildPath $secondaryCsvName }
    default {
        Write-Host "Invalid choice. Defaulting to $defaultCsvName" -ForegroundColor Yellow
        Join-Path -Path $scriptDirectory -ChildPath $defaultCsvName
    }
}

# Check if the selected CSV file exists
if (-not (Test-Path $csvPath)) {
    Write-Host "Error: The selected CSV file '$csvPath' does not exist." -ForegroundColor Red
    exit 1
}

# Validate CSV header
$csvHeader = Get-Content -Path $csvPath -TotalCount 1
$headerValid = $false
$useObjectId = $false

foreach ($header in $validHeaders) {
    if ($csvHeader -eq $header) {
        $headerValid = $true
        if ($targetType -eq "Device" -and $header -in @("AzureADDeviceId", "DeviceId")) {
            $useObjectId = $true
        }
        break
    }
}

if (-not $headerValid) {
    Write-Host "Error: The CSV file must have one of the following headers: $($validHeaders -join ', ')" -ForegroundColor Red
    Write-Host "Current header is: $csvHeader" -ForegroundColor Yellow
    exit 1
}

# Inform the user about the required CSV format
Write-Host "The CSV file should have one of the following formats:" -ForegroundColor Cyan
Write-Host ""

if ($targetType -eq "Device") {
    Write-Host "Option 1 (Device Name):"
    Write-Host "DeviceName"
    Write-Host "Laptop-01"
    Write-Host "Laptop-02"
    Write-Host ""
    Write-Host "Option 2 (Azure AD Device ID):"
    Write-Host "AzureADDeviceId"
    Write-Host "12345678-1234-1234-1234-123456789abc"
    Write-Host "87654321-4321-4321-4321-cba987654321"
    Write-Host ""
    Write-Host "Detected: CSV contains Device Names or Azure AD Device IDs" -ForegroundColor Green
} else {
    Write-Host "Option 1 (User Principal Name):"
    Write-Host "UserPrincipalName"
    Write-Host "user1@contoso.com"
    Write-Host "user2@contoso.com"
    Write-Host ""
    Write-Host "Option 2 (Mail / Email):"
    Write-Host "Mail"
    Write-Host "user1@contoso.com"
    Write-Host "user2@contoso.com"
    Write-Host ""
    Write-Host "Detected: CSV contains user identifiers" -ForegroundColor Green
}

Write-Host "Ensure the file is placed in the same directory as this script."
Write-Host ""

try {
    $logFile = $null
    $errorLogFile = $null
    $objectList = Import-Csv -Path $csvPath
    
    # Microsoft Graph logic
    Write-Host "`nConnecting to Microsoft Graph..." -ForegroundColor Cyan
    Connect-MgGraphWithFallback -Scopes @("Group.ReadWrite.All", "Directory.Read.All", "Device.Read.All", "User.Read.All")
        
        # Get the Azure AD group object and test if it exists
        $escapedGroupName = Escape-ODataStringLiteral -Value $groupName
        $groupObj = Get-MgGroup -Filter "displayName eq '$escapedGroupName'"
        
        if ($null -eq $groupObj) {
            Write-Host "Error: The specified Azure AD group '$groupName' does not exist." -ForegroundColor Red
            Disconnect-MgGraph
            exit 1
        }
        
        if ($groupObj.Count -gt 1) {
            Write-Host "Warning: Multiple groups found with the name '$groupName'. Please specify a more precise group name." -ForegroundColor Yellow
            Write-Host "Found groups:"
            $groupObj | Format-Table DisplayName, Id
            Disconnect-MgGraph
            exit 1
        }
        
        $groupId = $groupObj.Id
        
        # Get the current members of the group
        $groupMembers = Get-MgGroupMember -GroupId $groupId -All | Select-Object -ExpandProperty Id
        
        # Define log files with timestamps
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $objectTypeLabel = if ($targetType -eq "User") { "User" } else { "Device" }
        $logFile = Join-Path -Path $scriptDirectory -ChildPath "${objectTypeLabel}_Addition_Log_$timestamp.txt"
        $errorLogFile = Join-Path -Path $scriptDirectory -ChildPath "${objectTypeLabel}_Addition_ErrorLog_$timestamp.txt"
        
        # Create header for log files
        $logHeader = "=== ${objectTypeLabel} Addition Log - Started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
        Add-Content -Path $logFile -Value $logHeader
        Add-Content -Path $errorLogFile -Value $logHeader
        
        foreach ($row in $objectList) {
            $currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

            if ($targetType -eq "User") {
                $userValue = $null
                foreach ($identifierKey in @("UserPrincipalName", "UPN", "Mail", "Email", "DisplayName", "UserName", "ObjectId", "Id")) {
                    if ($row.PSObject.Properties.Name -contains $identifierKey) {
                        $candidateValue = $row.$identifierKey
                        if (-not [string]::IsNullOrWhiteSpace($candidateValue)) {
                            $userValue = $candidateValue
                            break
                        }
                    }
                }

                if ([string]::IsNullOrWhiteSpace($userValue)) {
                    $notFoundMessage = "[$currentTime] WARNING: Empty user identifier in CSV row."
                    Write-Host $notFoundMessage -ForegroundColor Yellow
                    Add-Content -Path $logFile -Value $notFoundMessage
                    Add-Content -Path $errorLogFile -Value $notFoundMessage
                    continue
                }

                try {
                    $userObj = $null
                    if ($row.PSObject.Properties.Name -contains "UserPrincipalName" -or $row.PSObject.Properties.Name -contains "UPN") {
                        $escapedUserValue = Escape-ODataStringLiteral -Value $userValue
                        $userObj = @(Get-MgUser -Filter "userPrincipalName eq '$escapedUserValue'" -ErrorAction Stop)
                    } elseif ($row.PSObject.Properties.Name -contains "Mail" -or $row.PSObject.Properties.Name -contains "Email") {
                        $escapedUserValue = Escape-ODataStringLiteral -Value $userValue
                        $userObj = @(Get-MgUser -Filter "mail eq '$escapedUserValue'" -ErrorAction Stop)
                    } elseif ($row.PSObject.Properties.Name -contains "ObjectId" -or $row.PSObject.Properties.Name -contains "Id") {
                        $userObj = @(Get-MgUser -UserId $userValue -ErrorAction Stop)
                    } else {
                        $escapedUserValue = Escape-ODataStringLiteral -Value $userValue
                        $userObj = @(Get-MgUser -Filter "displayName eq '$escapedUserValue'" -ErrorAction Stop)
                    }

                    if ($null -eq $userObj -or $userObj.Count -eq 0) {
                        throw "No user found in AAD for $userValue"
                    }
                } catch {
                    $notFoundMessage = "[$currentTime] WARNING: No user found in AAD for $userValue"
                    Write-Host $notFoundMessage -ForegroundColor Yellow
                    Add-Content -Path $logFile -Value $notFoundMessage
                    Add-Content -Path $errorLogFile -Value $notFoundMessage
                    continue
                }

                foreach ($user in $userObj) {
                    if ($groupMembers -contains $user.Id) {
                        $alreadyInGroupMessage = "[$currentTime] INFO: User $($user.UserPrincipalName) is already a member of group $groupName."
                        Write-Host $alreadyInGroupMessage
                        Add-Content -Path $logFile -Value $alreadyInGroupMessage
                    } else {
                        try {
                            New-MgGroupMember -GroupId $groupId -DirectoryObjectId $user.Id
                            $successMessage = "[$currentTime] SUCCESS: User $($user.UserPrincipalName) added to group $groupName."
                            Write-Host $successMessage -ForegroundColor Green
                            Add-Content -Path $logFile -Value $successMessage
                        } catch {
                            $errMsg = $_.Exception.Message
                            if ($errMsg -like '*already exist*' -or $errMsg -like '*already a member*') {
                                $alreadyMsg = "[$currentTime] WARNING: User $($user.UserPrincipalName) is already a member of group $groupName (detected by error)."
                                Write-Host "User $($user.UserPrincipalName) is already in the group $groupName (detected by error)." -ForegroundColor Yellow
                                Add-Content -Path $logFile -Value $alreadyMsg
                                Add-Content -Path $errorLogFile -Value $alreadyMsg
                            } else {
                                $errorMessage = "[$currentTime] ERROR: User $($user.UserPrincipalName) could not be added to the group. Error: $errMsg"
                                Write-Host $errorMessage -ForegroundColor Red
                                Add-Content -Path $logFile -Value $errorMessage
                                Add-Content -Path $errorLogFile -Value $errorMessage
                            }
                        }
                    }
                }
                continue
            }

            # Device logic
            if ($useObjectId) {
                $objectId = $row.AzureADDeviceId
                if ([string]::IsNullOrWhiteSpace($objectId)) {
                    $objectId = $row.DeviceId
                }

                if ([string]::IsNullOrWhiteSpace($objectId)) {
                    $notFoundMessage = "[$currentTime] WARNING: Empty Device ID in CSV row."
                    Write-Host $notFoundMessage -ForegroundColor Yellow
                    Add-Content -Path $logFile -Value $notFoundMessage
                    Add-Content -Path $errorLogFile -Value $notFoundMessage
                    continue
                }

                try {
                    $deviceObj = @(Get-MgDevice -DeviceId $objectId -ErrorAction Stop)
                } catch {
                    $notFoundMessage = "[$currentTime] WARNING: No device found in AAD with ID: $objectId"
                    Write-Host $notFoundMessage -ForegroundColor Yellow
                    Add-Content -Path $logFile -Value $notFoundMessage
                    Add-Content -Path $errorLogFile -Value $notFoundMessage
                    continue
                }
            } else {
                $escapedDeviceName = Escape-ODataStringLiteral -Value $row.DeviceName
                $deviceObj = @(Get-MgDevice -Filter "displayName eq '$escapedDeviceName'" -ErrorAction Stop)
            }
            
            if ($deviceObj.Count -gt 0) {
                foreach ($dev in $deviceObj) {
                    $deviceIdentifier = if ($useObjectId) { $objectId } else { $row.DeviceName }
                    
                    if ($groupMembers -contains $dev.Id) {
                        $alreadyInGroupMessage = "[$currentTime] INFO: Device $deviceIdentifier is already a member of group $groupName."
                        Write-Host $alreadyInGroupMessage
                        Add-Content -Path $logFile -Value $alreadyInGroupMessage
                    } else {
                        try {
                            New-MgGroupMember -GroupId $groupId -DirectoryObjectId $dev.Id
                            $successMessage = "[$currentTime] SUCCESS: Device $deviceIdentifier added to group $groupName."
                            Write-Host $successMessage -ForegroundColor Green
                            Add-Content -Path $logFile -Value $successMessage
                        }
                        catch {
                            $errMsg = $_.Exception.Message
                            if ($errMsg -like '*already exist*' -or $errMsg -like '*already a member*') {
                                $alreadyMsg = "[$currentTime] WARNING: Device $deviceIdentifier is already a member of group $groupName (detected by error)."
                                Write-Host "Device $deviceIdentifier is already in the group $groupName (detected by error)." -ForegroundColor Yellow
                                Add-Content -Path $logFile -Value $alreadyMsg
                                Add-Content -Path $errorLogFile -Value $alreadyMsg
                            } else {
                                $errorMessage = "[$currentTime] ERROR: Device $deviceIdentifier could not be added to the group. Error: $errMsg"
                                Write-Host $errorMessage -ForegroundColor Red
                                Add-Content -Path $logFile -Value $errorMessage
                                Add-Content -Path $errorLogFile -Value $errorMessage
                            }
                        }
                    }
                }
            } else {
                $deviceIdentifier = if ($useObjectId) { $objectId } else { $row.DeviceName }
                $notFoundMessage = "[$currentTime] WARNING: No device found in AAD for $deviceIdentifier."
                Write-Host $notFoundMessage -ForegroundColor Yellow
                Add-Content -Path $logFile -Value $notFoundMessage
                Add-Content -Path $errorLogFile -Value $notFoundMessage
            }
        }
        
}
catch {
    $currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $exceptionMessage = "[$currentTime] FATAL ERROR: $($_.Exception.Message)"
    Write-Host $exceptionMessage -ForegroundColor Red
    if ($logFile) {
        Add-Content -Path $logFile -Value $exceptionMessage
    }
    if ($errorLogFile) {
        Add-Content -Path $errorLogFile -Value $exceptionMessage
    }
}
finally {
    if (Get-MgContext) {
        Disconnect-MgGraph | Out-Null
    }
}

# Add footer to log files
$logFooter = "`n=== Script completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
if ($logFile) {
    Add-Content -Path $logFile -Value $logFooter
}
if ($errorLogFile) {
    Add-Content -Path $errorLogFile -Value $logFooter
}

Write-Host "`nScript completed. Check the following files for details:"
Write-Host "Main Log: $logFile"
Write-Host "Error Log: $errorLogFile"
