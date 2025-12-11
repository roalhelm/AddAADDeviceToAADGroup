# Azure AD Device Group Management

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207%2B-blue?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)](https://github.com/roalhelm/PowershellScripts)
[![Version](https://img.shields.io/badge/Version-1.5-brightgreen)](https://github.com/roalhelm/PowershellScripts)

PowerShell-Skripte zur Verwaltung von Azure AD-Geräten und Gruppenzugehörigkeiten mit **Cross-Platform-Support** für Windows, macOS und Linux.

## ✨ Features

- 🖥️ **Cross-Platform**: Windows, macOS, Linux (PowerShell Core 7+)
- 🔄 **Automatisch**: Erkennt Plattform und wählt passendes Modul (Microsoft.Graph oder AzureAD)
- 📊 **Batch-Verarbeitung**: Mehrere Geräte gleichzeitig hinzufügen
- ✅ **Duplikatsprüfung**: Überspringt bereits vorhandene Geräte
- 📝 **Logging**: Detaillierte Log-Dateien mit Zeitstempel

## 📦 Skripte

| Skript | Plattform | Beschreibung |
|--------|-----------|--------------|
| **AddAADDeviceToAADGroup.ps1** | 🪟🍎🐧 | Hauptskript: Geräte aus CSV zu Azure AD-Gruppe hinzufügen |
| **AADChecker.ps1** | 🪟 | Prüft, welche Geräte in Azure AD existieren |
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

Die CSV-Datei muss so aufgebaut sein:

```csv
DeviceName
DESKTOP-ABC123
LAPTOP-XYZ456
WORKSTATION-789
```

**Wichtig**: Erste Zeile muss exakt `DeviceName` sein.

## 📖 Verwendung

### 1. AddAADDeviceToAADGroup.ps1 (Hauptskript)

Fügt Geräte aus CSV zu einer Azure AD-Gruppe hinzu.

**Ablauf**:
1. Erkennt Plattform (PowerShell Core → Microsoft.Graph, Windows PS 5.1 → AzureAD)
2. Installiert fehlende Module automatisch
3. Liest CSV-Datei
4. Prüft jedes Gerät (Existiert? Bereits Mitglied?)
5. Fügt neue Geräte zur Gruppe hinzu
6. Erstellt Log-Dateien

**Ausgabe**:
```
PowerShell Core detected. Will use Microsoft Graph PowerShell SDK.
[2025-11-25 10:30:15] SUCCESS: Device LAPTOP-XYZ456 added to group Intune-Devices.
[2025-11-25 10:30:17] INFO: Device DESKTOP-ABC123 is already a member.

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

# Module (werden automatisch installiert, oder manuell):
Install-Module Microsoft.Graph -Scope CurrentUser -Force  # Für PowerShell 7+
Install-Module AzureAD -Scope CurrentUser -Force          # Für PowerShell 5.1
```

### macOS / Linux
```bash
# PowerShell 7+ installieren
# macOS:
brew install --cask powershell

# Linux (Ubuntu/Debian):
wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
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

### "AzureAD module requires Amd64" (macOS ARM64)
**Problem**: AzureAD-Modul funktioniert nicht auf Apple Silicon (M1/M2/M3)

**Lösung**: PowerShell Core 7+ verwenden (nicht Windows PowerShell)
```bash
pwsh --version  # Sollte 7.x anzeigen
pwsh -File ./AddAADDeviceToAADGroup.ps1
```

### CSV-Format-Fehler
**Problem**: `Error: The CSV file must have 'DeviceName' as the header`

**Lösung**: Erste Zeile muss exakt `DeviceName` sein
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

**F: Funktioniert das ohne Admin-Rechte?**  
A: Ja, lokale Admin-Rechte sind nicht nötig. Nur Azure AD-Berechtigungen werden benötigt.

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
**Version**: 1.5 (2025-11-24)

---

<div align="center">

**Viel Erfolg bei der Verwaltung Ihrer Azure AD-Geräte! 🚀**

[![GitHub](https://img.shields.io/badge/GitHub-roalhelm-blue?logo=github)](https://github.com/roalhelm/PowershellScripts)

</div>
