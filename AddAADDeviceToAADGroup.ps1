<#
.SYNOPSIS
    This script adds devices to an Azure AD group based on a list provided in a CSV file.
    It also checks if the device is already in the group before attempting to add it.
    GitHub Repository: https://github.com/roalhelm/

.CHANGES
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
    
    The script automatically detects the PowerShell version:
    - PowerShell Core 7+ (macOS, Linux, Windows): Uses Microsoft.Graph SDK
    - Windows PowerShell 5.1: Uses AzureAD module

.NOTES
    - For PowerShell Core 7+: Requires Microsoft.Graph module (cross-platform)
    - For Windows PowerShell 5.1: Requires AzureAD module (Windows only)
    - The script will automatically install the required module if not present
    - Appropriate Azure AD permissions are required
    - The CSV file must be placed in the same directory as this script.

.AUTHOR

    Original script by Ronny Alhelm
    Version        : 1.5
    Creation Date  : 2025-03-10
    Last Modified  : 2025-11-24

.EXAMPLE
    PS C:\> .\AddAADDeviceToAADGroup.ps1
    Enter the Azure AD group name: MyDeviceGroup
    The script will process the devices listed in 'Devices.csv' and attempt to add them to 'MyDeviceGroup'.
    
    Works on Windows (PowerShell 5.1 or 7+), macOS (PowerShell 7+), and Linux (PowerShell 7+).
#>

# Detect PowerShell version and set module preference
$isPwsh7 = $PSVersionTable.PSEdition -eq 'Core'
$useGraph = $false

if ($isPwsh7) {
    $useGraph = $true
    Write-Host "PowerShell Core detected. Will use Microsoft Graph PowerShell SDK." -ForegroundColor Cyan
    
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
    
    # Import Microsoft.Graph module
    try {
        Import-Module Microsoft.Graph -ErrorAction Stop
        Write-Host "Microsoft.Graph module imported successfully." -ForegroundColor Green
    } catch {
        Write-Host "FATAL ERROR: Could not import Microsoft.Graph module." -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Windows PowerShell detected. Will use AzureAD module." -ForegroundColor Cyan
    
    # Check and install AzureAD module
    if (-not (Get-Module -ListAvailable -Name AzureAD)) {
        try {
            Write-Host "AzureAD module not found. Installing..." -ForegroundColor Yellow
            Install-Module AzureAD -Scope CurrentUser -Force -ErrorAction Stop
            Write-Host "AzureAD module has been installed successfully." -ForegroundColor Green
        } catch {
            Write-Host "FATAL ERROR: Could not install AzureAD module. Please install manually." -ForegroundColor Red
            Write-Host "Error: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "AzureAD module is already installed." -ForegroundColor Green
    }
    
    # Import AzureAD module
    try {
        Import-Module AzureAD -ErrorAction Stop
        Write-Host "AzureAD module imported successfully." -ForegroundColor Green
    } catch {
        Write-Host "FATAL ERROR: Could not import AzureAD module." -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        exit 1
    }
}

# Prompt the user for the group name
$groupName = Read-Host "Enter the Azure AD group name"

# Prompt the user for CSV file choice
$csvChoice = Read-Host "Which CSV file do you want to use? Enter 1 for Devices.csv or 2 for Devices_In_AAD.csv"

# Set the CSV file path based on user choice
$csvPath = switch ($csvChoice) {
    "1" { ".\Devices.csv" }
    "2" { ".\Devices_In_AAD.csv" }
    default {
        Write-Host "Invalid choice. Defaulting to Devices.csv" -ForegroundColor Yellow
        ".\Devices.csv"
    }
}

# Check if the selected CSV file exists
if (-not (Test-Path $csvPath)) {
    Write-Host "Error: The selected CSV file '$csvPath' does not exist." -ForegroundColor Red
    exit 1
}

# Validate CSV header
$csvHeader = Get-Content -Path $csvPath -TotalCount 1
$validHeaders = @("DeviceName", "AzureADDeviceId", "DeviceId")
$headerValid = $false
$useDeviceId = $false

foreach ($header in $validHeaders) {
    if ($csvHeader -eq $header) {
        $headerValid = $true
        if ($header -in @("AzureADDeviceId", "DeviceId")) {
            $useDeviceId = $true
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
Write-Host "Option 1 (Device Name):"
Write-Host "DeviceName"
Write-Host "Device1"
Write-Host "Device2"
Write-Host ""
Write-Host "Option 2 (Azure AD Device ID):"
Write-Host "AzureADDeviceId"
Write-Host "12345678-1234-1234-1234-123456789abc"
Write-Host "87654321-4321-4321-4321-cba987654321"
Write-Host ""
Write-Host "Ensure the file is placed in the same directory as this script."
Write-Host ""

if ($useDeviceId) {
    Write-Host "Detected: CSV contains Azure AD Device IDs" -ForegroundColor Green
} else {
    Write-Host "Detected: CSV contains Device Names" -ForegroundColor Green
}
Write-Host ""

try {
    $deviceList = Import-Csv -Path $csvPath
    
    if ($useGraph) {
        # Microsoft Graph logic (PowerShell Core 7+)
        Write-Host "`nConnecting to Microsoft Graph..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes "Group.ReadWrite.All", "Directory.Read.All", "Device.Read.All"
        
        # Get the Azure AD group object and test if it exists
        $groupObj = Get-MgGroup -Filter "displayName eq '$groupName'"
        
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
        $groupMembers = Get-MgGroupMember -GroupId $groupId | Select-Object -ExpandProperty Id
        
        # Define log files with timestamps
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $logFile = "./Device_Addition_Log_$timestamp.txt"
        $errorLogFile = "./Device_Addition_ErrorLog_$timestamp.txt"
        
        # Create header for log files
        $logHeader = "=== Device Addition Log - Started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
        Add-Content -Path $logFile -Value $logHeader
        Add-Content -Path $errorLogFile -Value $logHeader
        
        foreach ($device in $deviceList) {
            $currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            
            # Get device based on input type (DeviceName or DeviceId)
            if ($useDeviceId) {
                # Using Azure AD Device ID directly
                $deviceId = $device.AzureADDeviceId
                if ([string]::IsNullOrWhiteSpace($deviceId)) {
                    $deviceId = $device.DeviceId
                }
                
                if ([string]::IsNullOrWhiteSpace($deviceId)) {
                    $notFoundMessage = "[$currentTime] WARNING: Empty Device ID in CSV row."
                    Write-Host $notFoundMessage -ForegroundColor Yellow
                    Add-Content -Path $logFile -Value $notFoundMessage
                    Add-Content -Path $errorLogFile -Value $notFoundMessage
                    continue
                }
                
                try {
                    $deviceObj = Get-MgDevice -DeviceId $deviceId -ErrorAction Stop
                } catch {
                    $notFoundMessage = "[$currentTime] WARNING: No device found in AAD with ID: $deviceId"
                    Write-Host $notFoundMessage -ForegroundColor Yellow
                    Add-Content -Path $logFile -Value $notFoundMessage
                    Add-Content -Path $errorLogFile -Value $notFoundMessage
                    continue
                }
            } else {
                # Using Device Name (original logic)
                $deviceObj = Get-MgDevice -Filter "displayName eq '$($device.DeviceName)'"
            }
            
            if ($null -ne $deviceObj) {
                foreach ($dev in $deviceObj) {
                    $deviceIdentifier = if ($useDeviceId) { $deviceId } else { $device.DeviceName }
                    
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
                $deviceIdentifier = if ($useDeviceId) { $deviceId } else { $device.DeviceName }
                $notFoundMessage = "[$currentTime] WARNING: No device found in AAD for $deviceIdentifier."
                Write-Host $notFoundMessage -ForegroundColor Yellow
                Add-Content -Path $logFile -Value $notFoundMessage
                Add-Content -Path $errorLogFile -Value $notFoundMessage
            }
        }
        
        Disconnect-MgGraph
        
    } else {
        # AzureAD logic (Windows PowerShell 5.1)
        Write-Host "`nConnecting to Azure AD..." -ForegroundColor Cyan
        Connect-AzureAD
        
        # AzureAD logic (Windows PowerShell 5.1)
        Write-Host "`nConnecting to Azure AD..." -ForegroundColor Cyan
        Connect-AzureAD
    
        # Get the Azure AD group object and test if it exists
        $groupObj = Get-AzureADGroup -SearchString $groupName
        
        if ($null -eq $groupObj) {
            Write-Host "Error: The specified Azure AD group '$groupName' does not exist." -ForegroundColor Red
            exit 1
        }
        
        if ($groupObj.Count -gt 1) {
            Write-Host "Warning: Multiple groups found with the name '$groupName'. Please specify a more precise group name." -ForegroundColor Yellow
            Write-Host "Found groups:"
            $groupObj | Format-Table DisplayName, ObjectId
            exit 1
        }
        
        # Get the current members of the group
        $groupMembers = Get-AzureADGroupMember -ObjectId $groupObj.ObjectId | Select-Object -ExpandProperty ObjectId
        
        # Define log files with timestamps
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $logFile = "./Device_Addition_Log_$timestamp.txt"
        $errorLogFile = "./Device_Addition_ErrorLog_$timestamp.txt"
        
        # Create header for log files
        $logHeader = "=== Device Addition Log - Started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
        Add-Content -Path $logFile -Value $logHeader
        Add-Content -Path $errorLogFile -Value $logHeader
        
        foreach ($device in $deviceList) {
            $currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            
            # Get device based on input type (DeviceName or DeviceId)
            if ($useDeviceId) {
                # Using Azure AD Device ID directly
                $deviceId = $device.AzureADDeviceId
                if ([string]::IsNullOrWhiteSpace($deviceId)) {
                    $deviceId = $device.DeviceId
                }
                
                if ([string]::IsNullOrWhiteSpace($deviceId)) {
                    $notFoundMessage = "[$currentTime] WARNING: Empty Device ID in CSV row."
                    Write-Host $notFoundMessage -ForegroundColor Yellow
                    Add-Content -Path $logFile -Value $notFoundMessage
                    Add-Content -Path $errorLogFile -Value $notFoundMessage
                    continue
                }
                
                try {
                    $deviceObj = Get-AzureADDevice -ObjectId $deviceId -ErrorAction Stop
                } catch {
                    $notFoundMessage = "[$currentTime] WARNING: No device found in AAD with ID: $deviceId"
                    Write-Host $notFoundMessage -ForegroundColor Yellow
                    Add-Content -Path $logFile -Value $notFoundMessage
                    Add-Content -Path $errorLogFile -Value $notFoundMessage
                    continue
                }
            } else {
                # Using Device Name (original logic)
                $deviceObj = Get-AzureADDevice -SearchString $device.DeviceName
            }
            
            if ($deviceObj -ne $null) {
                foreach ($dev in $deviceObj) {
                    $deviceIdentifier = if ($useDeviceId) { $deviceId } else { $device.DeviceName }
                    
                    if ($groupMembers -contains $dev.ObjectId) {
                        $alreadyInGroupMessage = "[$currentTime] INFO: Device $deviceIdentifier is already a member of group $groupName."
                        Write-Host $alreadyInGroupMessage
                        Add-Content -Path $logFile -Value $alreadyInGroupMessage
                    } else {
                        try {
                            Add-AzureADGroupMember -ObjectId $groupObj.ObjectId -RefObjectId $dev.ObjectId       
                            $successMessage = "[$currentTime] SUCCESS: Device $deviceIdentifier added to group $groupName."
                            Write-Host $successMessage -ForegroundColor Green
                            Add-Content -Path $logFile -Value $successMessage
                        }
                        catch {
                            $errMsg = $_.Exception.Message
                            if ($errMsg -like '*One or more added object references already exist for the following modified properties*') {
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
                $deviceIdentifier = if ($useDeviceId) { $deviceId } else { $device.DeviceName }
                $notFoundMessage = "[$currentTime] WARNING: No device found in AAD for $deviceIdentifier."
                Write-Host $notFoundMessage -ForegroundColor Yellow
                Add-Content -Path $logFile -Value $notFoundMessage
                Add-Content -Path $errorLogFile -Value $notFoundMessage
            }
        }
    }
}
catch {
    $currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $exceptionMessage = "[$currentTime] FATAL ERROR: $($_.Exception.Message)"
    Write-Host $exceptionMessage -ForegroundColor Red
    Add-Content -Path $logFile -Value $exceptionMessage
    Add-Content -Path $errorLogFile -Value $exceptionMessage
}

# Add footer to log files
$logFooter = "`n=== Script completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
Add-Content -Path $logFile -Value $logFooter
Add-Content -Path $errorLogFile -Value $logFooter

Write-Host "`nScript completed. Check the following files for details:"
Write-Host "Main Log: $logFile"
Write-Host "Error Log: $errorLogFile"
