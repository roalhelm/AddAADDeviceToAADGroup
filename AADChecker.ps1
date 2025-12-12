<#
.SYNOPSIS
    Checks if devices listed in a CSV file exist in Azure Active Directory (AAD) and generates separate CSV files 
    for devices found and not found in AAD.
    GitHub Repository: https://github.com/roalhelm/

.DESCRIPTION
    This script reads a list of device names from a CSV file and checks each device against Azure AD.
    It creates two output files:
    - Devices_In_AAD.csv: Contains devices that were found in AAD
    - Devices_Not_In_AAD.csv: Contains devices that were not found in AAD
    
    The script uses Microsoft.Graph SDK exclusively for all PowerShell versions.
    Supports PowerShell 5.1+ on Windows and PowerShell Core 7+ on macOS/Linux.

.CHANGES
    Version 1.2 (2025-12-11):
    - BREAKING: Removed AzureAD module support (Azure AD Graph API has been deprecated by Microsoft)
    - Now uses Microsoft.Graph SDK exclusively for all PowerShell versions
    - Requires PowerShell 5.1 or higher

    Version 1.1 (2025-12-11):
    - Added cross-platform support (macOS, Linux, Windows)
    - Automatic detection of PowerShell version (Core 7+ vs Windows PowerShell 5.1)
    - Uses Microsoft.Graph SDK for PowerShell Core 7+
    - Falls back to AzureAD module for Windows PowerShell 5.1
    - Improved module installation and import error handling

.NOTES
    File Name      : AADChecker.ps1
    Author         : Ronny Alhelm
    Prerequisite   : Microsoft.Graph PowerShell Module
    Version        : 1.2
    Creation Date  : 2025-03-13
    Last Modified  : 2025-12-11

.EXAMPLE
    .\AADChecker.ps1
    Reads Devices.csv in the current directory and checks each device against AAD.
    Works on Windows (PowerShell 5.1 or 7+), macOS (PowerShell 7+), and Linux (PowerShell 7+).
#>

# Define the CSV file path
$CsvFilePath = ".\Devices.csv"
$InAADFile = ".\Devices_In_AAD.csv"
$NotInAADFile = ".\Devices_Not_In_AAD.csv"

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
Write-Host "PowerShell Version: $psVersion" -ForegroundColor Cyan

if ($psVersion.Major -lt 5 -or ($psVersion.Major -eq 5 -and $psVersion.Minor -lt 1)) {
    Write-Host "FATAL ERROR: This script requires PowerShell 5.1 or higher." -ForegroundColor Red
    Write-Host "Please upgrade your PowerShell version." -ForegroundColor Red
    exit 1
}

Write-Host "Using Microsoft Graph PowerShell SDK (AzureAD module is deprecated)." -ForegroundColor Cyan

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

# Import Microsoft.Graph modules
try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop
    Write-Host "Microsoft.Graph modules imported successfully." -ForegroundColor Green
} catch {
    Write-Host "FATAL ERROR: Could not import Microsoft.Graph modules." -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}

# Connect to Microsoft Graph
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
try {
    Connect-MgGraph -Scopes "Device.Read.All" -ErrorAction Stop
    Write-Host "Successfully connected to Microsoft Graph." -ForegroundColor Green
} catch {
    Write-Host "FATAL ERROR: Could not connect to Microsoft Graph." -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}

# Read devices from CSV
if (-Not (Test-Path $CsvFilePath)) {
    Write-Host "CSV file not found: $CsvFilePath" -ForegroundColor Red
    exit 1
}

$devices = Import-Csv -Path $CsvFilePath
$devicesInAAD = @()
$devicesNotInAAD = @()

foreach ($device in $devices) {
    $clientName = $device.DeviceName # Assuming the CSV column is named 'DeviceName'
    
    if (-not $clientName) {
        Write-Host "Skipping empty client name entry." -ForegroundColor Yellow
        continue
    }
    
    Write-Host "Checking AAD for device: $clientName"
    
    # Use Microsoft Graph
    try {
        $aadDevice = Get-MgDevice -Filter "displayName eq '$clientName'" -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Error querying device: $_" -ForegroundColor Yellow
        $aadDevice = $null
    }
    
    if ($aadDevice) {
        Write-Host "Device found in AAD: $clientName" -ForegroundColor Green
        $devicesInAAD += $device
    } else {
        Write-Host "Device NOT found in AAD: $clientName" -ForegroundColor Red
        $devicesNotInAAD += $device
    }
}

# Export results to CSV files
$devicesInAAD | Export-Csv -Path $InAADFile -NoTypeInformation
$devicesNotInAAD | Export-Csv -Path $NotInAADFile -NoTypeInformation

# Add summary counts
$totalDevices = $devices.Count
$inAADCount = $devicesInAAD.Count
$notInAADCount = $devicesNotInAAD.Count

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "Total devices checked: $totalDevices" -ForegroundColor White
Write-Host "Devices found in AAD: $inAADCount" -ForegroundColor Green
Write-Host "Devices NOT found in AAD: $notInAADCount" -ForegroundColor Red
Write-Host "`nScript execution completed. Results saved to $InAADFile and $NotInAADFile."