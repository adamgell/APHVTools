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

                # Verify that required functions are available
                $requiredFunctions = @('Get-APHVToolsConfig')
                $missingFunctions = @()

                foreach ($func in $requiredFunctions) {
                    if (-not (Get-Command -Name $func -ErrorAction SilentlyContinue)) {
                        $missingFunctions += $func
                    }
                }

                if ($missingFunctions.Count -gt 0) {
                    Write-Warning "Missing functions: $($missingFunctions -join ', ')"
                    return $false
                }

                return $true
            }
        }

        # Try to import from installed modules
        $module = Get-Module -Name APHVTools -ListAvailable
        if ($module) {
            Import-Module APHVTools -Force
            Write-Host "APHVTools module loaded from installed modules"

            # Verify that required functions are available
            $requiredFunctions = @('Get-APHVToolsConfig')
            $missingFunctions = @()

            foreach ($func in $requiredFunctions) {
                if (-not (Get-Command -Name $func -ErrorAction SilentlyContinue)) {
                    $missingFunctions += $func
                }
            }

            if ($missingFunctions.Count -gt 0) {
                Write-Warning "Missing functions: $($missingFunctions -join ', ')"
                return $false
            }

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
    # Fallback: Try to dot-source the functions directly
    try {
        Write-Host "Attempting to load functions directly..." -ForegroundColor Yellow

        # Try to dot-source the required functions
        $modulePath = "$PSScriptRoot\..\APHVTools"
        if (Test-Path "$modulePath\Public\Get-HVToolsConfig.ps1") {
            . "$modulePath\Public\Get-HVToolsConfig.ps1"
            Write-Host "Loaded Get-APHVToolsConfig function directly" -ForegroundColor Green
        }

        # Verify functions are now available
        if (-not (Get-Command -Name 'Get-APHVToolsConfig' -ErrorAction SilentlyContinue)) {
            throw "Required function Get-APHVToolsConfig is still not available after direct loading"
        }

        Write-Host "Functions loaded successfully via direct sourcing" -ForegroundColor Green
    }
    catch {
        $errorMsg = "Failed to load APHVTools functions: $($_.Exception.Message)"
        [System.Windows.MessageBox]::Show($errorMsg, "Module Loading Failed", "OK", "Error")
        Write-Error $errorMsg
        exit 1
    }
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
            $value = $Data.$($prop.Name)
            $item = New-Object System.Windows.Controls.TreeViewItem
            if ($value -is [System.Collections.IDictionary] -or $value -is [PSCustomObject]) {
                $item.Header = "$($prop.Name)"
                Populate-TreeView -Data $value -Parent $item
            } elseif ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
                $item.Header = "$($prop.Name) [Array]"
                Populate-TreeView -Data $value -Parent $item
            } else {
                $item.Header = "$($prop.Name): $value"
            }
            if ($Parent) {
                $Parent.Items.Add($item)
            } else {
                $treeView.Items.Add($item)
            }
        }
    }
    elseif ($Data -is [System.Collections.IEnumerable] -and $Data -isnot [string]) {
        $i = 0
        foreach ($element in $Data) {
            $item = New-Object System.Windows.Controls.TreeViewItem
            if ($element -is [System.Collections.IDictionary] -or $element -is [PSCustomObject]) {
                # Prefer TenantName over imageName
                $propertyNames = $element | Get-Member -MemberType NoteProperty | ForEach-Object { $_.Name }
                if ($propertyNames -contains "TenantName") {
                    $displayName = $element.TenantName
                } elseif ($propertyNames -contains "imageName") {
                    $displayName = $element.imageName
                } elseif ($propertyNames -contains "Name") {
                    $displayName = $element.Name
                }

                $item.Header = $displayName
                Populate-TreeView -Data $element -Parent $item
            } else {
                $item.Header = "[$i]: $element"
            }
            if ($Parent) {
                $Parent.Items.Add($item)
            } else {
                $treeView.Items.Add($item)
            }
            $i++
        }
    }
    else {
        $item = New-Object System.Windows.Controls.TreeViewItem
        $item.Header = "$Data"
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

        # Check if required functions are available
        if (-not (Get-Command -Name 'Get-APHVToolsConfig' -ErrorAction SilentlyContinue)) {
            throw "Get-APHVToolsConfig function is not available. Please ensure the APHVTools module is properly loaded."
        }

        # Get the raw configuration data
        $config = Get-APHVToolsConfig -Raw

        if (-not $config) {
            throw "No configuration data returned. Please ensure APHVTools is properly initialized."
        }

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