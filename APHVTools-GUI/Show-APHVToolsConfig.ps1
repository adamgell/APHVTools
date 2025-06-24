#Requires -Version 5.1

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Function to load APHVTools module
function Import-APHVToolsModule {
    try {
        # Try to import from various locations
        $modulePaths = @(
            "$PSScriptRoot\..\APHVTools",
            "$PWD\APHVTools",
            "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\APHVTools",
            "$env:PROGRAMFILES\WindowsPowerShell\Modules\APHVTools"
        )

        foreach ($path in $modulePaths) {
            if (Test-Path "$path\APHVTools.psm1") {
                Import-Module $path -Force
                Write-Host "APHVTools module loaded from: $path"
                return $true
            }
        }

        # Try to import from installed modules
        $module = Get-Module -Name APHVTools -ListAvailable
        if ($module) {
            Import-Module APHVTools -Force
            Write-Host "APHVTools module loaded from installed modules"
            return $true
        }

        throw "APHVTools module not found in any expected location"
    }
    catch {
        Write-Error "Failed to load APHVTools module: $($_.Exception.Message)"
        return $false
    }
}

# Load the module
if (-not (Import-APHVToolsModule)) {
    [System.Windows.MessageBox]::Show("APHVTools module not found. Please ensure it is installed.", "Module Not Found", "OK", "Error")
    exit 1
}

# Create the main window
$window = New-Object System.Windows.Window
$window.Title = "APHVTools Configuration Viewer"
$window.Width = 1200
$window.Height = 800
$window.WindowStartupLocation = "CenterScreen"

# Create the main grid
$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = New-Object System.Windows.Thickness(10)

# Define rows
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))

# Create toolbar
$toolbar = New-Object System.Windows.Controls.StackPanel
$toolbar.Orientation = "Horizontal"
$toolbar.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)

# Refresh button
$refreshButton = New-Object System.Windows.Controls.Button
$refreshButton.Content = "Refresh Configuration"
$refreshButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$refreshButton.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)

# Export button
$exportButton = New-Object System.Windows.Controls.Button
$exportButton.Content = "Export JSON"
$exportButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$exportButton.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)

# Status label
$statusLabel = New-Object System.Windows.Controls.Label
$statusLabel.Content = "Ready"
$statusLabel.Foreground = [System.Windows.Media.Brushes]::Green

# Add controls to toolbar
$toolbar.Children.Add($refreshButton)
$toolbar.Children.Add($exportButton)
$toolbar.Children.Add($statusLabel)

# Create the main content area with tabs
$tabControl = New-Object System.Windows.Controls.TabControl

# JSON View Tab
$jsonTab = New-Object System.Windows.Controls.TabItem
$jsonTab.Header = "JSON View"

$jsonTextBox = New-Object System.Windows.Controls.TextBox
$jsonTextBox.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas")
$jsonTextBox.FontSize = 12
$jsonTextBox.IsReadOnly = $true
$jsonTextBox.VerticalScrollBarVisibility = "Auto"
$jsonTextBox.HorizontalScrollBarVisibility = "Auto"
$jsonTextBox.AcceptsReturn = $true
$jsonTextBox.TextWrapping = "NoWrap"

$jsonTab.Content = $jsonTextBox

# Tree View Tab
$treeTab = New-Object System.Windows.Controls.TabItem
$treeTab.Header = "Tree View"

$treeView = New-Object System.Windows.Controls.TreeView
$treeView.FontSize = 12

$treeTab.Content = $treeView

# Add tabs to tab control
$tabControl.Items.Add($jsonTab)
$tabControl.Items.Add($treeTab)

# Set grid positions
[System.Windows.Controls.Grid]::SetRow($toolbar, 0)
[System.Windows.Controls.Grid]::SetRow($tabControl, 1)

# Add controls to grid
$grid.Children.Add($toolbar)
$grid.Children.Add($tabControl)

# Set grid as window content
$window.Content = $grid

# Function to format JSON
function Format-Json {
    param([string]$Json)
    try {
        $obj = $Json | ConvertFrom-Json
        return ($obj | ConvertTo-Json -Depth 10)
    }
    catch {
        return "Error formatting JSON: $($_.Exception.Message)"
    }
}

# Function to populate tree view
function Populate-TreeView {
    param([object]$Data, [System.Windows.Controls.TreeViewItem]$Parent = $null)

    if ($Data -is [System.Collections.IDictionary] -or $Data -is [PSCustomObject]) {
        $properties = $Data | Get-Member -MemberType NoteProperty
        foreach ($prop in $properties) {
            $item = New-Object System.Windows.Controls.TreeViewItem
            $item.Header = "$($prop.Name): $($prop.PropertyType.Name)"

            if ($Parent) {
                $Parent.Items.Add($item)
            } else {
                $treeView.Items.Add($item)
            }

            # Recursively add child items
            Populate-TreeView -Data $Data.$($prop.Name) -Parent $item
        }
    }
    elseif ($Data -is [System.Collections.IEnumerable] -and $Data -isnot [string]) {
        for ($i = 0; $i -lt $Data.Count; $i++) {
            $item = New-Object System.Windows.Controls.TreeViewItem
            $item.Header = "[$i]: $($Data[$i].GetType().Name)"

            if ($Parent) {
                $Parent.Items.Add($item)
            } else {
                $treeView.Items.Add($item)
            }

            Populate-TreeView -Data $Data[$i] -Parent $item
        }
    }
    else {
        $item = New-Object System.Windows.Controls.TreeViewItem
        $item.Header = "Value: $Data"

        if ($Parent) {
            $Parent.Items.Add($item)
        } else {
            $treeView.Items.Add($item)
        }
    }
}

# Function to load configuration
function Load-Configuration {
    try {
        $statusLabel.Content = "Loading configuration..."
        $statusLabel.Foreground = [System.Windows.Media.Brushes]::Orange

        # Get the configuration
        $config = Get-APHVToolsConfig -Raw

        # Format and display JSON
        $formattedJson = Format-Json -Json ($config | ConvertTo-Json -Depth 10)
        $jsonTextBox.Text = $formattedJson

        # Clear and populate tree view
        $treeView.Items.Clear()
        Populate-TreeView -Data $config

        $statusLabel.Content = "Configuration loaded successfully"
        $statusLabel.Foreground = [System.Windows.Media.Brushes]::Green

        return $config
    }
    catch {
        $errorMsg = "Error loading configuration: $($_.Exception.Message)"
        $jsonTextBox.Text = $errorMsg
        $statusLabel.Content = "Error loading configuration"
        $statusLabel.Foreground = [System.Windows.Media.Brushes]::Red
        Write-Error $errorMsg
        return $null
    }
}

# Function to export JSON
function Export-Json {
    try {
        $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveFileDialog.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
        $saveFileDialog.DefaultExt = "json"
        $saveFileDialog.FileName = "APHVTools-Config-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

        if ($saveFileDialog.ShowDialog()) {
            $jsonTextBox.Text | Out-File -FilePath $saveFileDialog.FileName -Encoding UTF8
            $statusLabel.Content = "Configuration exported successfully"
            $statusLabel.Foreground = [System.Windows.Media.Brushes]::Green
        }
    }
    catch {
        $statusLabel.Content = "Error exporting configuration"
        $statusLabel.Foreground = [System.Windows.Media.Brushes]::Red
        Write-Error "Error exporting configuration: $($_.Exception.Message)"
    }
}

# Event handlers
$refreshButton.Add_Click({
    Load-Configuration
})

$exportButton.Add_Click({
    Export-Json
})

# Load configuration on startup
$config = Load-Configuration

# Show the window
$window.ShowDialog()