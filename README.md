# Azure AD Device Group Management

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207%2B-blue?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)](https://github.com/roalhelm/PowershellScripts)
[![Version](https://img.shields.io/badge/Version-1.6-brightgreen)](https://github.com/roalhelm/PowershellScripts)
[![Module](https://img.shields.io/badge/Module-Microsoft.Graph-orange)](https://www.powershellgallery.com/packages/Microsoft.Graph)

PowerShell-Skripte zur Verwaltung von Azure AD-Geräten und Gruppenzugehörigkeiten mit **Cross-Platform-Support** für Windows, macOS und Linux.

> **⚠️ Wichtiger Hinweis**: Ab Version 1.6 wird ausschließlich **Microsoft.Graph** verwendet. Das AzureAD-Modul wird nicht mehr unterstützt, da Microsoft die Azure AD Graph API deaktiviert hat.

## ✨ Features

- 🖥️ **Cross-Platform**: Windows, macOS, Linux (PowerShell 5.1+ oder 7+)
- 🔄 **Modern**: Verwendet ausschließlich Microsoft.Graph SDK (Azure AD Graph API ist deprecated)
- 📊 **Batch-Verarbeitung**: Mehrere Geräte gleichzeitig hinzufügen
- ✅ **Duplikatsprüfung**: Überspringt bereits vorhandene Geräte
- 📝 **Logging**: Detaillierte Log-Dateien mit Zeitstempel
- 🔧 **Auto-Install**: Installiert Microsoft.Graph automatisch, falls nicht vorhanden

## 📦 Skripte

| Skript | Plattform | Beschreibung |
|--------|-----------|--------------|
| **AddAADDeviceToAADGroup.ps1** | 🪟🍎🐧 | Hauptskript: Geräte aus CSV zu Azure AD-Gruppe hinzufügen |
| **AADChecker.ps1** | 🪟🍎🐧 | Prüft, welche Geräte in Azure AD existieren |
| **Add-DevicesToAADGroupFunction.ps1** | 🪟🍎🐧 | PowerShell-Funktion für Automatisierung |
| **AddDeviceCSV.ps1** | 🪟 | GUI-Tool zur CSV-Erstellung (nur Windows) |

🪟 Windows | 🍎 macOS | 🐧 Linux

## 🚀 Schnellstart

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

Das Skript fragt nach:
1. CSV-Datei (1 = Devices.csv, 2 = Devices_In_AAD.csv)
2. Name der Azure AD-Gruppe
3. Anmeldung bei Azure AD / Microsoft Graph

## 📋 CSV-Datei Format

Die CSV-Datei kann einen der folgenden Header verwenden:

```csv
DeviceName
DESKTOP-ABC123
LAPTOP-XYZ456
WORKSTATION-789
```

Oder alternativ per Azure AD Device ID:

```csv
AzureADDeviceId
12345678-1234-1234-1234-123456789abc
87654321-4321-4321-4321-cba987654321
```

**Wichtig**: Erste Zeile muss exakt `DeviceName`, `AzureADDeviceId` oder `DeviceId` sein.

## 📖 Verwendung

### 1. AddAADDeviceToAADGroup.ps1 (Hauptskript)

Fügt Geräte aus CSV zu einer Azure AD-Gruppe hinzu.

**Ablauf**:
1. Prüft PowerShell-Version (mind. 5.1 erforderlich)
2. Installiert Microsoft.Graph automatisch, falls nicht vorhanden
3. Liest CSV-Datei
4. Prüft jedes Gerät (Existiert? Bereits Mitglied?)
5. Fügt neue Geräte zur Gruppe hinzu
6. Erstellt Log-Dateien

**Ausgabe**:
```
PowerShell Version: 7.4.1
Using Microsoft Graph PowerShell SDK (AzureAD module is deprecated).
[2025-12-12 10:30:15] SUCCESS: Device LAPTOP-XYZ456 added to group Intune-Devices.
[2025-12-12 10:30:17] INFO: Device DESKTOP-ABC123 is already a member.

Script completed. Check log files for details.
```

### 2. AADChecker.ps1

Prüft, welche Geräte aus der CSV in Azure AD existieren.

**Verwendung**:
```powershell
.\AADChecker.ps1
```

**Erstellt**:
- `Devices_In_AAD.csv` - Gefundene Geräte
- `Devices_Not_In_AAD.csv` - Nicht gefundene Geräte

**Anwendung**: Vorab-Prüfung vor dem Hinzufügen zu Gruppen

### 3. Add-DevicesToAADGroupFunction.ps1

PowerShell-Funktion für Automatisierung.

**Verwendung**:
```powershell
# Funktion laden
. .\Add-DevicesToAADGroupFunction.ps1

# Ausführen
$result = Add-DevicesToAADGroup -GroupName "Intune-Devices" -CsvPath ".\Devices.csv"

# Ergebnis
Write-Host "Erfolgreich: $($result.Success)"
Write-Host "Bereits Mitglied: $($result.AlreadyMember)"
```

### 4. AddDeviceCSV.ps1 (nur Windows)

GUI-Tool zur einfachen CSV-Erstellung.

```powershell
.\AddDeviceCSV.ps1
```

Gerätenamen eingeben (komma-, semikolon- oder leerzeichen-getrennt) und speichern.

## ⚙️ Installation

### Windows
```powershell
# Execution Policy setzen
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Microsoft.Graph Modul (wird automatisch installiert, oder manuell):
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

**Wichtig**: Das AzureAD-Modul wird **nicht mehr unterstützt**, da Microsoft die Azure AD Graph API deaktiviert hat. Verwenden Sie ausschließlich Microsoft.Graph.

### macOS / Linux
```bash
# PowerShell 7+ installieren
# macOS:
brew install --cask powershell

# Linux (Ubuntu/Debian):
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update && sudo apt-get install -y powershell

# PowerShell starten und Modul installieren
pwsh
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

### Azure AD Berechtigungen

Benötigt werden:
- `Group.ReadWrite.All` - Gruppen lesen und schreiben
- `Device.Read.All` - Geräte lesen
- `Directory.Read.All` - Verzeichnis lesen

*Diese werden beim ersten `Connect-MgGraph` angefordert.*

## 📝 Beispiele

### Standard-Verwendung
```powershell
.\AddAADDeviceToAADGroup.ps1
# CSV wählen → Gruppe eingeben → Anmelden → Fertig
```

### Mit Vorab-Prüfung
```powershell
# 1. Prüfen, welche Geräte existieren
.\AADChecker.ps1

# 2. Nur existierende Geräte hinzufügen
.\AddAADDeviceToAADGroup.ps1  # Option "2" wählen für Devices_In_AAD.csv
```

### Automatisierung mit Funktion
```powershell
. .\Add-DevicesToAADGroupFunction.ps1

$result = Add-DevicesToAADGroup -GroupName "Intune-Devices" -CsvPath ".\Devices.csv"
Write-Host "Erfolgreich: $($result.Success) | Fehler: $($result.Failed)"
```

### Mehrere Gruppen befüllen
```powershell
. .\Add-DevicesToAADGroupFunction.ps1

$groups = @("Gruppe1", "Gruppe2", "Gruppe3")
foreach ($group in $groups) {
    Add-DevicesToAADGroup -GroupName $group -CsvPath ".\Devices_$group.csv"
}
```

## 🐛 Häufige Probleme

### "Access blocked to AAD Graph API"
**Problem**: Fehlermeldung "Access blocked to AAD Graph API for this application"

**Ursache**: Microsoft hat die Azure AD Graph API deaktiviert. Das alte AzureAD-Modul funktioniert nicht mehr.

**Lösung**: Verwenden Sie Version 1.6+ der Scripts, die Microsoft.Graph nutzen:
```powershell
# Alte AzureAD-Module entfernen (optional)
Uninstall-Module AzureAD -Force

# Microsoft.Graph installieren
Install-Module Microsoft.Graph -Scope CurrentUser -Force

# Scripts aktualisieren und erneut ausführen
./AddAADDeviceToAADGroup.ps1
```

### CSV-Format-Fehler
**Problem**: `Error: The CSV file must have one of the following headers: DeviceName, AzureADDeviceId, DeviceId`

**Lösung**: Erste Zeile muss exakt `DeviceName`, `AzureADDeviceId` oder `DeviceId` sein
```powershell
Get-Content Devices.csv -TotalCount 1  # Prüfen
```

### Gruppe nicht gefunden
**Problem**: `Error: The specified Azure AD group 'MyGroup' does not exist`

**Lösung**: Exakten Gruppennamen verwenden
```powershell
Connect-MgGraph -Scopes "Group.Read.All"
Get-MgGroup -Filter "startswith(displayName,'Intune')" | Select DisplayName
```

### Berechtigungsfehler
**Problem**: `Insufficient privileges to complete the operation`

**Lösung**: Mit korrekten Berechtigungen verbinden
```powershell
Disconnect-MgGraph
Connect-MgGraph -Scopes "Group.ReadWrite.All","Device.Read.All","Directory.Read.All"
```

## ❓ FAQ

**F: Warum funktioniert das AzureAD-Modul nicht mehr?**  
A: Microsoft hat die Azure AD Graph API am 30. Juni 2023 deaktiviert. Alle Scripts wurden auf Microsoft.Graph migriert.

**F: Funktioniert das ohne Admin-Rechte?**  
A: Ja, lokale Admin-Rechte sind nicht nötig. Nur Azure AD-Berechtigungen werden benötigt.

**F: Welche PowerShell-Version brauche ich?**  
A: PowerShell 5.1 oder höher (Windows) bzw. PowerShell Core 7+ (macOS/Linux).

**F: Wie viele Geräte kann ich verarbeiten?**  
A: Getestet mit bis zu 500 Geräten. Bei >1000 Geräten in mehrere CSV-Dateien aufteilen.

**F: Was passiert bei bereits vorhandenen Geräten?**  
A: Diese werden übersprungen mit der Meldung "already a member" - kein Fehler.

**F: Kann ich Security Groups verwenden?**  
A: Ja, funktioniert mit Security Groups und Microsoft 365 Groups.

**F: Unterstützt das Skript MFA?**  
A: Ja, die interaktive Anmeldung unterstützt MFA, Conditional Access, etc.

---

## 📄 License & Autor

**License**: GNU General Public License v3.0

**Autor**: Ronny Alhelm  
**GitHub**: [@roalhelm](https://github.com/roalhelm)  
**Version**: 1.6 (2025-12-11)  
**Module**: Microsoft.Graph (AzureAD deprecated)

---

<div align="center">

**Viel Erfolg bei der Verwaltung Ihrer Azure AD-Geräte! 🚀**

[![GitHub](https://img.shields.io/badge/GitHub-roalhelm-blue?logo=github)](https://github.com/roalhelm/PowershellScripts)

</div>
