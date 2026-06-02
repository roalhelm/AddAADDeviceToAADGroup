function Add-DevicesToAADGroup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupName,
        [Parameter(Mandatory = $false)]
        [string]$CsvPath = ".\Devices.csv"
    )
    function Escape-ODataStringLiteral {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Value
        )

        return $Value.Replace("'", "''")
    }

    $scriptDirectory = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

    if ($CsvPath -eq ".\Devices.csv") {
        $CsvPath = Join-Path -Path $scriptDirectory -ChildPath "Devices.csv"
    }

    Write-Host "Using Microsoft Graph PowerShell SDK." -ForegroundColor Yellow

    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
        try {
            Write-Host "Microsoft.Graph module not found. Installing..." -ForegroundColor Yellow
            Install-Module Microsoft.Graph -Scope CurrentUser -Force -ErrorAction Stop
        } catch {
            Write-Host "FATAL ERROR: Could not install Microsoft.Graph module. Please install manually. Error: $_" -ForegroundColor Red
            throw $_
        }
    }

    try {
        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
        Import-Module Microsoft.Graph.Groups -ErrorAction Stop
        Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop
    } catch {
        Write-Host "FATAL ERROR: Could not import Microsoft.Graph modules. Please check your installation. Error: $_" -ForegroundColor Red
        throw $_
    }

    # Function to write logs
    function Write-Log {
        param($Message, [switch]$IsError)
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] $Message"
        
        if ($IsError) {
            Write-Host $logMessage -ForegroundColor Red
            if ($errorLogFile) {
                Add-Content -Path $errorLogFile -Value $logMessage
            }
        }
        Write-Host $logMessage
        if ($logFile) {
            Add-Content -Path $logFile -Value $logMessage
        }
    }

    try {
        $logFile = $null
        $errorLogFile = $null

        # Check if CSV exists
        if (-not (Test-Path $CsvPath)) {
            throw "The CSV file '$CsvPath' does not exist."
        }

        $deviceList = Import-Csv -Path $CsvPath
        Connect-MgGraph -Scopes @("Group.ReadWrite.All", "Directory.Read.All", "Device.Read.All")
        $escapedGroupName = Escape-ODataStringLiteral -Value $GroupName
        $groupObj = Get-MgGroup -Filter "displayName eq '$escapedGroupName'"
        if ($null -eq $groupObj) {
            throw "The specified Azure AD group '$GroupName' does not exist."
        }
        if ($groupObj.Count -gt 1) {
            throw "Multiple groups found with the name '$GroupName'. Please specify a more precise group name."
        }

        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $logFile = Join-Path -Path $scriptDirectory -ChildPath "Device_Addition_Log_$timestamp.txt"
        $errorLogFile = Join-Path -Path $scriptDirectory -ChildPath "Device_Addition_ErrorLog_$timestamp.txt"
        $logHeader = "=== Device Addition Log - Started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
        Add-Content -Path $logFile -Value $logHeader
        Add-Content -Path $errorLogFile -Value $logHeader

        $groupId = $groupObj.Id
        $groupMembers = Get-MgGroupMember -GroupId $groupId -All | Select-Object -ExpandProperty Id
        $results = @{ Success = 0; AlreadyMember = 0; NotFound = 0; Failed = 0 }

        foreach ($device in $deviceList) {
            $escapedDeviceName = Escape-ODataStringLiteral -Value $device.DeviceName
            $deviceObj = Get-MgDevice -Filter "displayName eq '$escapedDeviceName'"

            if ($null -ne $deviceObj) {
                foreach ($dev in $deviceObj) {
                    if ($groupMembers -contains $dev.Id) {
                        Write-Log "Device $($device.DeviceName) is already a member of group $GroupName"
                        $results.AlreadyMember++
                    } else {
                        try {
                            New-MgGroupMember -GroupId $groupId -DirectoryObjectId $dev.Id
                            Write-Log "SUCCESS: Device $($device.DeviceName) added to group $GroupName"
                            $results.Success++
                        } catch {
                            Write-Log "ERROR: Failed to add $($device.DeviceName) to group. Error: $_" -IsError
                            $results.Failed++
                        }
                    }
                }
            } else {
                Write-Log "WARNING: Device $($device.DeviceName) not found in Azure AD" -IsError
                $results.NotFound++
            }
        }

        return [PSCustomObject]@{
            GroupName = $GroupName
            Success = $results.Success
            AlreadyMember = $results.AlreadyMember
            NotFound = $results.NotFound
            Failed = $results.Failed
            LogFile = $logFile
            ErrorLogFile = $errorLogFile
        }
    }
    catch {
        Write-Log "FATAL ERROR: $_" -IsError
        throw $_
    }
    finally {
        if (Get-MgContext) {
            Disconnect-MgGraph | Out-Null
        }
    }
}

<#
# Example usage:

try {
    $result = Add-DevicesToAADGroup -GroupName "MyAADGroup" -CsvPath ".\Devices.csv"
    Write-Host "`nSummary:"
    Write-Host "Successfully added: $($result.Success)"
    Write-Host "Already members: $($result.AlreadyMember)"
    Write-Host "Not found: $($result.NotFound)"
    Write-Host "Failed: $($result.Failed)"
    Write-Host "`nLog files:"
    Write-Host "Main log: $($result.LogFile)"
    Write-Host "Error log: $($result.ErrorLogFile)"
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

#>