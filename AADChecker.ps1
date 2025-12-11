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

.NOTES
    File Name      : AADChecker.ps1
    Author         : Ronny Alhelm
    Prerequisite   : AzureAD PowerShell Module
    Version        : 1.0
    Creation Date  : 2025-03-13

.EXAMPLE
    .\AADChecker.ps1
    Reads Devices.csv in the current directory and checks each device against AAD.
#>

# Define the CSV file path
$CsvFilePath = ".\Devices.csv"
$InAADFile = ".\Devices_In_AAD.csv"
$NotInAADFile = ".\Devices_Not_In_AAD.csv"

# Ensure the AzureAD module is installed and imported
if (-not (Get-Module -ListAvailable -Name AzureAD)) {
    Install-Module AzureAD -Force -Scope CurrentUser
}
Import-Module AzureAD

# Connect to Azure AD (interactive login required)
Write-Host "Connecting to Azure AD..."
Connect-AzureAD

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
    $aadDevice = Get-AzureADDevice -Filter "displayName eq '$clientName'" -ErrorAction SilentlyContinue
    
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