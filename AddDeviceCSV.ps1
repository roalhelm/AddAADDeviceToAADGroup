<#
.SYNOPSIS
    Creates a CSV file containing a list of device names entered through a GUI.
    The GUI also displays the current contents of the CSV file.
    GitHub Repository: https://github.com/roalhelm/

.DESCRIPTION
    This script provides a graphical user interface (GUI) to enter a list of device names.
    The names can be separated by spaces, commas, or semicolons.
    The script creates a CSV file named 'Devices.csv' with a single column 'DeviceName' 
    and updates a second text box to display the current content of the CSV file.

.NOTES
    File Name      : CreateDeviceCSV.ps1
    Author         : Ronny Alhelm
    Version        : 1.2
    Creation Date  : 2025-03-12
    Last Modified  : 2025-03-13
    Requirements   : PowerShell 5.1 or higher
    Dependencies   : System.Windows.Forms, System.Drawing

.AUTHOR
    ChatGPT (OpenAI)

.VERSION
    1.2 - Updated layout to display input and output side by side.

.EXAMPLE
    PS C:\> .\CreateDeviceCSV.ps1
    This command will open the GUI. After entering device names and clicking
    "Create CSV", the script will generate a 'Devices.csv' file and show its content.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function to load CSV content into the output text box
function Load-CSVContent {
    if (Test-Path "Devices.csv") {
        $csvContent = Get-Content "Devices.csv" -Raw
        $outputBox.Text = $csvContent
    } else {
        $outputBox.Text = "No CSV file found."
    }
}

# Create the GUI
$form = New-Object System.Windows.Forms.Form
$form.Text = "Device CSV Creator"
$form.Size = New-Object System.Drawing.Size(700, 350)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen

# Label for input box
$inputLabel = New-Object System.Windows.Forms.Label
$inputLabel.Text = "Enter Device Names (comma, semicolon, or space-separated):"
$inputLabel.AutoSize = $true
$inputLabel.Location = New-Object System.Drawing.Point(20, 10)

# TextBox for entering device names (left side)
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Multiline = $true
$textBox.Width = 300
$textBox.Height = 150
$textBox.Location = New-Object System.Drawing.Point(20, 30)

# Label for output box
$outputLabel = New-Object System.Windows.Forms.Label
$outputLabel.Text = "Current CSV Content:"
$outputLabel.AutoSize = $true
$outputLabel.Location = New-Object System.Drawing.Point(350, 10)

# TextBox to display the current CSV file content (right side)
$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Multiline = $true
$outputBox.Width = 300
$outputBox.Height = 150
$outputBox.Location = New-Object System.Drawing.Point(350, 30)
$outputBox.ReadOnly = $true
$outputBox.ScrollBars = "Vertical"

# Button to create the CSV (centered below text boxes)
$button = New-Object System.Windows.Forms.Button
$button.Text = "Create CSV"
$button.Width = 120
$button.Height = 30
$button.Location = New-Object System.Drawing.Point(150, 200)

# Button to close the window (centered below text boxes)
$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "Close"
$closeButton.Width = 120
$closeButton.Height = 30
$closeButton.Location = New-Object System.Drawing.Point(400, 200)
$closeButton.Add_Click({ $form.Close() })

# Button to cleanup the CSV file
$cleanupButton = New-Object System.Windows.Forms.Button
$cleanupButton.Text = "Cleanup CSV"
$cleanupButton.Width = 120
$cleanupButton.Height = 30
$cleanupButton.Location = New-Object System.Drawing.Point(275, 200)

# Event handler for the button
$button.Add_Click({
    # Get input from the TextBox
    $input = $textBox.Text
    
    # Split the device names by spaces, commas, or semicolons
    $deviceNames = $input -split '[,; \r\n]+'

    # Prepare the CSV file (without quotes)
    $csvPath = "Devices.csv"
    
    # Create the CSV file with the header
    "DeviceName" | Out-File -FilePath $csvPath -Encoding UTF8
    
    # Write the device names into the CSV file without quotes
    $deviceNames | ForEach-Object {
        $_ | Out-File -FilePath $csvPath -Encoding UTF8 -Append
    }

    # Reload the CSV content into the output box
    Load-CSVContent

    [System.Windows.Forms.MessageBox]::Show("CSV has been created: $csvPath")
})

# Event handler for the cleanup button
$cleanupButton.Add_Click({
    if (Test-Path "Devices.csv") {
        # Create new CSV with only the header
        "DeviceName" | Out-File -FilePath "Devices.csv" -Encoding UTF8 -Force
        
        # Reload the CSV content
        Load-CSVContent
        
        # Clear the input textbox
        $textBox.Clear()
        
        [System.Windows.Forms.MessageBox]::Show("CSV file has been cleared. All devices have been removed.")
    } else {
        [System.Windows.Forms.MessageBox]::Show("No CSV file found to clean up.")
    }
})

# Update button positions for better spacing
$button.Location = New-Object System.Drawing.Point(150, 200)
$cleanupButton.Location = New-Object System.Drawing.Point(275, 200)
$closeButton.Location = New-Object System.Drawing.Point(400, 200)

# Load CSV content initially
Load-CSVContent

# Add controls to the form
$form.Controls.Add($inputLabel)
$form.Controls.Add($textBox)
$form.Controls.Add($outputLabel)
$form.Controls.Add($outputBox)
$form.Controls.Add($button)
$form.Controls.Add($cleanupButton)  # Add the new cleanup button
$form.Controls.Add($closeButton)

# Show the form
$form.ShowDialog()
