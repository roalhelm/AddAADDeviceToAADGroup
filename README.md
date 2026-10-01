# Azure AD / Entra ID Group Management

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207%2B-blue?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)](https://github.com/roalhelm/PowershellScripts)
[![Version](https://img.shields.io/badge/Version-1.7-brightgreen)](https://github.com/roalhelm/PowershellScripts)
[![Module](https://img.shields.io/badge/Module-Microsoft.Graph-orange)](https://www.powershellgallery.com/packages/Microsoft.Graph)

PowerShell scripts for managing Azure AD / Microsoft Entra ID group memberships for both devices and users. The scripts work across Windows, macOS, and Linux.

> **⚠️ Important note**: Starting with version 1.6, the scripts use only **Microsoft.Graph**. The AzureAD module is no longer supported because Microsoft has retired the Azure AD Graph API.

## ✨ Features

- 🖥️ **Cross-platform**: Windows, macOS, Linux (PowerShell 5.1+ or 7+)
- 🔄 **Modern**: Uses Microsoft.Graph SDK only
- 📊 **Batch processing**: Add multiple devices or users at once
- ✅ **Duplicate check**: Skips members that are already in the group
- 🧠 **Runtime selection**: Decide at startup whether to add devices/clients or users
- 📝 **Logging**: Detailed log files with timestamps
- 🔧 **Auto-install**: Installs Microsoft.Graph automatically if needed

## 📦 Scripts

| Script | Platform | Description |
|--------|-----------|--------------|
| **AddAADDeviceToAADGroup.ps1** | 🪟🍎🐧 | Main script: add devices or users from CSV to an Entra ID group |
| **AADChecker.ps1** | 🪟🍎🐧 | Checks which devices exist in Entra ID |
| **Add-DevicesToAADGroupFunction.ps1** | 🪟🍎🐧 | PowerShell function for automation |
| **Users.csv** | 🪟🍎🐧 | Sample CSV for user imports |
| **Devices.csv** | 🪟🍎🐧 | Sample CSV for device imports |

🪟 Windows | 🍎 macOS | 🐧 Linux

## 🚀 Quick start

### Windows
```powershell
cd AddAADDeviceToAADGroup
.\AddAADDeviceToAADGroup.ps1
```

### macOS / Linux
```bash
cd AddAADDeviceToAADGroup
pwsh
./AddAADDeviceToAADGroup.ps1
```

When the script starts, it asks:
1. Whether to add devices/clients or users
2. The Entra ID group name
3. Which CSV file to use
4. To sign in to Microsoft Graph

## 📋 CSV formats

### Devices / clients

#### Option 1: Device name
```csv
DeviceName
DESKTOP-ABC123
LAPTOP-XYZ456
WORKSTATION-789
```

#### Option 2: Azure AD / Entra device ID
```csv
AzureADDeviceId
12345678-1234-1234-1234-123456789abc
87654321-4321-4321-4321-cba987654321
```

### Users

#### Option 1: User Principal Name
```csv
UserPrincipalName
user1@contoso.com
user2@contoso.com
```

#### Option 2: Email / Mail
```csv
Mail
user1@contoso.com
user2@contoso.com
```

**Important**: The first row must match one of the valid headers exactly, such as `DeviceName`, `AzureADDeviceId`, `UserPrincipalName`, `Mail`, or `Email`.

## 📖 Usage

### 1. AddAADDeviceToAADGroup.ps1 (main script)

Adds either devices or users from a CSV file to an Entra ID group, depending on the selection made at startup.

**Flow**:
1. Checks the PowerShell version (minimum 5.1 required)
2. Installs Microsoft.Graph automatically if needed
3. Prompts for the object type (`1 = Devices`, `2 = Users`)
4. Reads the selected CSV file
5. Checks each item (exists? already a member?)
6. Adds new objects to the group
7. Creates log files

**Example output**:
```
Which objects do you want to add to an AAD group? Enter 1 for Clients/Devices or 2 for Users
Enter the Azure AD group name: MyGroup
[2025-12-12 10:30:15] SUCCESS: Device LAPTOP-XYZ456 added to group MyGroup.
[2025-12-12 10:30:17] INFO: User user1@contoso.com is already a member.

Script completed. Check log files for details.
```

### 2. AADChecker.ps1

Checks which devices from the CSV exist in Entra ID.

**Usage**:
```powershell
.\AADChecker.ps1
```

**Creates**:
- `Devices_In_AAD.csv` - devices found
- `Devices_Not_In_AAD.csv` - devices not found

**Use case**: Pre-check before adding members to a group

### 3. Add-DevicesToAADGroupFunction.ps1

PowerShell function for automation. This function is still optimized for device workflows, but it can be extended for user scenarios as needed.

**Usage**:
```powershell
# Load the function
. .\Add-DevicesToAADGroupFunction.ps1

# Run it
$result = Add-DevicesToAADGroup -GroupName "Intune-Devices" -CsvPath ".\Devices.csv"

# Display the result
Write-Host "Successful: $($result.Success)"
Write-Host "Already a member: $($result.AlreadyMember)"
```

## ⚙️ Installation

### Windows
```powershell
# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Microsoft.Graph module (installed automatically or manually)
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

**Important**: The AzureAD module is no longer supported because Microsoft has retired the Azure AD Graph API. Use only Microsoft.Graph.

### macOS / Linux
```bash
# Install PowerShell 7+
# macOS:
brew install --cask powershell

# Linux (Ubuntu/Debian):
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update && sudo apt-get install -y powershell

# Start PowerShell and install the module
pwsh
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

### Azure AD / Entra ID permissions

The following permissions are required:
- `Group.ReadWrite.All` - read and write group memberships
- `Device.Read.All` - read devices
- `User.Read.All` - read users
- `Directory.Read.All` - read directory data

*These are requested at the first `Connect-MgGraph` call.*

## 📝 Examples

### Add devices (default)
```powershell
.\AddAADDeviceToAADGroup.ps1
# Selection: 1 = Devices/Clients
# Enter group name → choose CSV → sign in → done
```

### Add users
```powershell
.\AddAADDeviceToAADGroup.ps1
# Selection: 2 = Users
# Enter group name → choose Users.csv → sign in → done
```

### Pre-check devices before adding them
```powershell
# 1. Check which devices exist
.\AADChecker.ps1

# 2. Add only the found devices
.\AddAADDeviceToAADGroup.ps1  # choose option "1" for Devices_In_AAD.csv
```

### Automation with function
```powershell
. .\Add-DevicesToAADGroupFunction.ps1

$result = Add-DevicesToAADGroup -GroupName "Intune-Devices" -CsvPath ".\Devices.csv"
Write-Host "Successful: $($result.Success) | Failed: $($result.Failed)"
```

## 🐛 Common issues

### "Access blocked to AAD Graph API"
**Problem**: Error message: "Access blocked to AAD Graph API for this application"

**Cause**: Microsoft retired the Azure AD Graph API. The legacy AzureAD module no longer works.

**Solution**: Use version 1.6+ of the scripts, which use Microsoft.Graph:
```powershell
# Optional: remove the old AzureAD module
Uninstall-Module AzureAD -Force

# Install Microsoft.Graph
Install-Module Microsoft.Graph -Scope CurrentUser -Force

# Run the script again
./AddAADDeviceToAADGroup.ps1
```

### CSV format error
**Problem**: `Error: The CSV file must have one of the following headers: DeviceName, AzureADDeviceId, UserPrincipalName, Mail, Email`

**Solution**: Make sure the first line matches a valid header exactly.
```powershell
Get-Content Devices.csv -TotalCount 1  # check
Get-Content Users.csv -TotalCount 1    # check
```

### Group not found
**Problem**: `Error: The specified Azure AD group 'MyGroup' does not exist`

**Solution**: Use the exact group name.
```powershell
Connect-MgGraph -Scopes "Group.Read.All"
Get-MgGroup -Filter "startswith(displayName,'Intune')" | Select DisplayName
```

### Permission errors
**Problem**: `Insufficient privileges to complete the operation`

**Solution**: Connect with the correct permissions.
```powershell
Disconnect-MgGraph
Connect-MgGraph -Scopes "Group.ReadWrite.All","Device.Read.All","User.Read.All","Directory.Read.All"
```

## ❓ FAQ

**Q: Can I also add users to an Entra ID group?**  
A: Yes. The main script asks at startup whether to process devices or users. For users, a CSV with `UserPrincipalName`, `Mail`, or `Email` is expected.

**Q: Why does the AzureAD module no longer work?**  
A: Microsoft retired the Azure AD Graph API on June 30, 2023. All scripts were migrated to Microsoft.Graph.

**Q: Does this work without admin rights?**  
A: Yes, local admin rights are not required. Only the required Azure AD / Entra permissions are needed.

**Q: Which PowerShell version do I need?**  
A: PowerShell 5.1 or later on Windows, or PowerShell Core 7+ on macOS/Linux.

**Q: How many devices can I process?**  
A: It has been tested with up to 500 devices. For more than 1000 entries, split them into multiple CSV files.

**Q: What happens with devices that are already in the group?**  
A: They are skipped with the message "already a member" and do not cause an error.

**Q: Can I use security groups?**  
A: Yes. This works with both Security Groups and Microsoft 365 Groups.

**Q: Does the script support MFA?**  
A: Yes. Interactive sign-in supports MFA, Conditional Access, and similar policies.

---

## 📄 License & Author

**License**: GNU General Public License v3.0

**Author**: Ronny Alhelm  
**GitHub**: [@roalhelm](https://github.com/roalhelm)  
**Version**: 1.7  
**Module**: Microsoft.Graph (AzureAD deprecated)

---

<div align="center">

**Good luck managing your Azure AD / Entra ID devices and users! 🚀**

[![GitHub](https://img.shields.io/badge/GitHub-roalhelm-blue?logo=github)](https://github.com/roalhelm/PowershellScripts)

</div>
