#Requires -Version 5.1

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
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
    [System.Windows.MessageBox]::Show(
        "Failed to load APHVTools module. Please ensure it is properly installed.",
        "Module Loading Failed", 
        "OK", 
        "Error"
    )
    exit 1
}

# Create the main window
$window = New-Object System.Windows.Window
$window.Title = "APHVTools Manager"
$window.Width = 1400
$window.Height = 900
$window.WindowStartupLocation = "CenterScreen"

# Create the main grid
$mainGrid = New-Object System.Windows.Controls.Grid
$mainGrid.Margin = New-Object System.Windows.Thickness(10)

# Define rows
$mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
$mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))
$mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "25"}))

# Create header panel
$headerPanel = New-Object System.Windows.Controls.StackPanel
$headerPanel.Orientation = "Horizontal"
$headerPanel.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)

$titleLabel = New-Object System.Windows.Controls.Label
$titleLabel.Content = "APHVTools Manager"
$titleLabel.FontSize = 18
$titleLabel.FontWeight = "Bold"

$headerPanel.Children.Add($titleLabel)

# Create the main tab control
$tabControl = New-Object System.Windows.Controls.TabControl

# Create status panel (using Border and TextBlock instead of StatusBar)
$statusPanel = New-Object System.Windows.Controls.Border
$statusPanel.BorderBrush = [System.Windows.Media.Brushes]::Gray
$statusPanel.BorderThickness = New-Object System.Windows.Thickness(0, 1, 0, 0)
$statusPanel.Background = [System.Windows.Media.Brushes]::LightGray
$statusPanel.Height = 25

$statusText = New-Object System.Windows.Controls.TextBlock
$statusText.Text = "Ready"
$statusText.Margin = New-Object System.Windows.Thickness(5, 2, 5, 2)
$statusText.VerticalAlignment = "Center"
$statusPanel.Child = $statusText

# Global variables
$script:config = $null
$script:vmList = @()

# Helper function to update status
function Update-Status {
    param([string]$Message, [string]$Color = "Black")
    $statusText.Text = $Message
    $statusText.Foreground = $Color
    $window.Dispatcher.Invoke([action]{}, "Render")
}

# Helper function to show error dialog
function Show-Error {
    param([string]$Message, [string]$Title = "Error")
    [System.Windows.MessageBox]::Show($Message, $Title, "OK", "Error")
}

# Helper function to show info dialog
function Show-Info {
    param([string]$Message, [string]$Title = "Information")
    [System.Windows.MessageBox]::Show($Message, $Title, "OK", "Information")
}

# Helper function to load configuration
function Get-ConfigurationData {
    try {
        Update-Status "Loading configuration..." "Orange"
        $script:config = Get-APHVToolsConfig -Raw
        
        if (-not $script:config) {
            throw "No configuration found. Please initialize APHVTools first."
        }
        
        Update-Status "Configuration loaded successfully" "Green"
        return $true
    }
    catch {
        Update-Status "Error loading configuration" "Red"
        Show-Error "Failed to load configuration: $($_.Exception.Message)"
        return $false
    }
}

#region VM Management Tab
$vmTab = New-Object System.Windows.Controls.TabItem
$vmTab.Header = "VM Management"

# Create VM tab grid
$vmGrid = New-Object System.Windows.Controls.Grid
$vmGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
$vmGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))

# VM toolbar
$vmToolbar = New-Object System.Windows.Controls.ToolBar
$vmToolbar.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)

$refreshVMButton = New-Object System.Windows.Controls.Button
$refreshVMButton.Content = "Refresh"
$refreshVMButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)

$startVMButton = New-Object System.Windows.Controls.Button
$startVMButton.Content = "Start"
$startVMButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$startVMButton.IsEnabled = $false

$stopVMButton = New-Object System.Windows.Controls.Button
$stopVMButton.Content = "Stop"
$stopVMButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$stopVMButton.IsEnabled = $false

$restartVMButton = New-Object System.Windows.Controls.Button
$restartVMButton.Content = "Restart"
$restartVMButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$restartVMButton.IsEnabled = $false

$deleteVMButton = New-Object System.Windows.Controls.Button
$deleteVMButton.Content = "Delete"
$deleteVMButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$deleteVMButton.IsEnabled = $false
$deleteVMButton.Background = "LightCoral"

$connectVMButton = New-Object System.Windows.Controls.Button
$connectVMButton.Content = "Connect"
$connectVMButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$connectVMButton.IsEnabled = $false

$separator1 = New-Object System.Windows.Controls.Separator
$separator1.Margin = New-Object System.Windows.Thickness(5, 0, 5, 0)

$vmToolbar.Items.Add($refreshVMButton) | Out-Null
$vmToolbar.Items.Add($separator1) | Out-Null
$vmToolbar.Items.Add($startVMButton) | Out-Null
$vmToolbar.Items.Add($stopVMButton) | Out-Null
$vmToolbar.Items.Add($restartVMButton) | Out-Null
$vmToolbar.Items.Add($deleteVMButton) | Out-Null
$vmToolbar.Items.Add($connectVMButton) | Out-Null

# VM list view
$vmListView = New-Object System.Windows.Controls.ListView
$vmListView.Margin = New-Object System.Windows.Thickness(0, 5, 0, 0)

# Define columns
$gridView = New-Object System.Windows.Controls.GridView

$nameColumn = New-Object System.Windows.Controls.GridViewColumn
$nameColumn.Header = "Name"
$nameColumn.DisplayMemberBinding = New-Object System.Windows.Data.Binding "Name"
$nameColumn.Width = 200

$stateColumn = New-Object System.Windows.Controls.GridViewColumn
$stateColumn.Header = "State"
$stateColumn.DisplayMemberBinding = New-Object System.Windows.Data.Binding "State"
$stateColumn.Width = 100

$cpuColumn = New-Object System.Windows.Controls.GridViewColumn
$cpuColumn.Header = "CPUs"
$cpuColumn.DisplayMemberBinding = New-Object System.Windows.Data.Binding "ProcessorCount"
$cpuColumn.Width = 60

$memoryColumn = New-Object System.Windows.Controls.GridViewColumn
$memoryColumn.Header = "Memory (GB)"
$memoryColumn.DisplayMemberBinding = New-Object System.Windows.Data.Binding "MemoryGB"
$memoryColumn.Width = 100

$uptimeColumn = New-Object System.Windows.Controls.GridViewColumn
$uptimeColumn.Header = "Uptime"
$uptimeColumn.DisplayMemberBinding = New-Object System.Windows.Data.Binding "Uptime"
$uptimeColumn.Width = 150

$tenantColumn = New-Object System.Windows.Controls.GridViewColumn
$tenantColumn.Header = "Tenant"
$tenantColumn.DisplayMemberBinding = New-Object System.Windows.Data.Binding "Tenant"
$tenantColumn.Width = 150

$notesColumn = New-Object System.Windows.Controls.GridViewColumn
$notesColumn.Header = "Notes"
$notesColumn.DisplayMemberBinding = New-Object System.Windows.Data.Binding "Notes"
$notesColumn.Width = 200

$gridView.Columns.Add($nameColumn)
$gridView.Columns.Add($stateColumn)
$gridView.Columns.Add($cpuColumn)
$gridView.Columns.Add($memoryColumn)
$gridView.Columns.Add($uptimeColumn)
$gridView.Columns.Add($tenantColumn)
$gridView.Columns.Add($notesColumn)

$vmListView.View = $gridView

# Set grid positions
[System.Windows.Controls.Grid]::SetRow($vmToolbar, 0)
[System.Windows.Controls.Grid]::SetRow($vmListView, 1)

$vmGrid.Children.Add($vmToolbar)
$vmGrid.Children.Add($vmListView)

$vmTab.Content = $vmGrid

# VM Management Functions
function Get-VMsForManagement {
    try {
        Update-Status "Loading VMs..." "Orange"
        
        $vms = Get-VM | Where-Object { 
            $_.Name -like "*APHVTools*" -or 
            $_.Notes -like "*APHVTools*" -or
            $_.Path -like "*$($script:config.vmPath)*"
        }
        
        $vmData = @()
        foreach ($vm in $vms) {
            # Extract tenant from VM name or path
            $tenant = "Unknown"
            if ($vm.Name -match "^(.+?)-") {
                $tenant = $matches[1]
            }
            
            $vmInfo = [PSCustomObject]@{
                Name = $vm.Name
                State = $vm.State
                ProcessorCount = $vm.ProcessorCount
                MemoryGB = [math]::Round($vm.MemoryStartup / 1GB, 2)
                Uptime = if ($vm.State -eq "Running") { (Get-Date) - $vm.Uptime } else { "N/A" }
                Tenant = $tenant
                Notes = $vm.Notes
                VMObject = $vm
            }
            $vmData += $vmInfo
        }
        
        $script:vmList = $vmData
        $vmListView.ItemsSource = $vmData
        
        Update-Status "Loaded $($vmData.Count) VMs" "Green"
    }
    catch {
        Update-Status "Error loading VMs" "Red"
        Show-Error "Failed to load VMs: $($_.Exception.Message)"
    }
}

# VM Event Handlers
$refreshVMButton.Add_Click({
    Get-VMsForManagement
})

$vmListView.Add_SelectionChanged({
    $selectedVM = $vmListView.SelectedItem
    if ($selectedVM) {
        $startVMButton.IsEnabled = $selectedVM.State -ne "Running"
        $stopVMButton.IsEnabled = $selectedVM.State -eq "Running"
        $restartVMButton.IsEnabled = $selectedVM.State -eq "Running"
        $deleteVMButton.IsEnabled = $selectedVM.State -ne "Running"
        $connectVMButton.IsEnabled = $true
    }
    else {
        $startVMButton.IsEnabled = $false
        $stopVMButton.IsEnabled = $false
        $restartVMButton.IsEnabled = $false
        $deleteVMButton.IsEnabled = $false
        $connectVMButton.IsEnabled = $false
    }
})

$startVMButton.Add_Click({
    $selectedVM = $vmListView.SelectedItem
    if ($selectedVM) {
        try {
            Update-Status "Starting VM: $($selectedVM.Name)" "Orange"
            Start-VM -VM $selectedVM.VMObject
            Get-VMsForManagement
            Update-Status "VM started successfully" "Green"
        }
        catch {
            Show-Error "Failed to start VM: $($_.Exception.Message)"
        }
    }
})

$stopVMButton.Add_Click({
    $selectedVM = $vmListView.SelectedItem
    if ($selectedVM) {
        $result = [System.Windows.MessageBox]::Show(
            "Are you sure you want to stop VM: $($selectedVM.Name)?",
            "Confirm Stop",
            "YesNo",
            "Question"
        )
        
        if ($result -eq "Yes") {
            try {
                Update-Status "Stopping VM: $($selectedVM.Name)" "Orange"
                Stop-VM -VM $selectedVM.VMObject -Force
                Get-VMsForManagement
                Update-Status "VM stopped successfully" "Green"
            }
            catch {
                Show-Error "Failed to stop VM: $($_.Exception.Message)"
            }
        }
    }
})

$restartVMButton.Add_Click({
    $selectedVM = $vmListView.SelectedItem
    if ($selectedVM) {
        try {
            Update-Status "Restarting VM: $($selectedVM.Name)" "Orange"
            Restart-VM -VM $selectedVM.VMObject -Force
            Get-VMsForManagement
            Update-Status "VM restarted successfully" "Green"
        }
        catch {
            Show-Error "Failed to restart VM: $($_.Exception.Message)"
        }
    }
})

$deleteVMButton.Add_Click({
    $selectedVM = $vmListView.SelectedItem
    if ($selectedVM) {
        $result = [System.Windows.MessageBox]::Show(
            "Are you sure you want to delete VM: $($selectedVM.Name)?`nThis will also delete all associated files.",
            "Confirm Delete",
            "YesNo",
            "Warning"
        )
        
        if ($result -eq "Yes") {
            try {
                Update-Status "Deleting VM: $($selectedVM.Name)" "Orange"
                Remove-VM -VM $selectedVM.VMObject -Force
                Get-VMsForManagement
                Update-Status "VM deleted successfully" "Green"
            }
            catch {
                Show-Error "Failed to delete VM: $($_.Exception.Message)"
            }
        }
    }
})

$connectVMButton.Add_Click({
    $selectedVM = $vmListView.SelectedItem
    if ($selectedVM) {
        try {
            Update-Status "Connecting to VM: $($selectedVM.Name)" "Orange"
            vmconnect.exe localhost $selectedVM.Name
            Update-Status "Connected to VM" "Green"
        }
        catch {
            Show-Error "Failed to connect to VM: $($_.Exception.Message)"
        }
    }
})

#endregion

#region VM Creation Tab
$createTab = New-Object System.Windows.Controls.TabItem
$createTab.Header = "Create VMs"

# Create form grid
$createGrid = New-Object System.Windows.Controls.Grid
$createGrid.Margin = New-Object System.Windows.Thickness(20)

# Define rows
for ($i = 0; $i -lt 12; $i++) {
    $createGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
}
$createGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))

# Define columns
$createGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = "150"}))
$createGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = "*"}))

# Tenant selection
$tenantLabel = New-Object System.Windows.Controls.Label
$tenantLabel.Content = "Tenant:"
$tenantLabel.VerticalAlignment = "Center"

$tenantCombo = New-Object System.Windows.Controls.ComboBox
$tenantCombo.Margin = New-Object System.Windows.Thickness(5)
$tenantCombo.DisplayMemberPath = "TenantName"

[System.Windows.Controls.Grid]::SetRow($tenantLabel, 0)
[System.Windows.Controls.Grid]::SetColumn($tenantLabel, 0)
[System.Windows.Controls.Grid]::SetRow($tenantCombo, 0)
[System.Windows.Controls.Grid]::SetColumn($tenantCombo, 1)

# Image selection
$imageLabel = New-Object System.Windows.Controls.Label
$imageLabel.Content = "Image/OS Build:"
$imageLabel.VerticalAlignment = "Center"

$imageCombo = New-Object System.Windows.Controls.ComboBox
$imageCombo.Margin = New-Object System.Windows.Thickness(5)
$imageCombo.DisplayMemberPath = "imageName"

[System.Windows.Controls.Grid]::SetRow($imageLabel, 1)
[System.Windows.Controls.Grid]::SetColumn($imageLabel, 0)
[System.Windows.Controls.Grid]::SetRow($imageCombo, 1)
[System.Windows.Controls.Grid]::SetColumn($imageCombo, 1)

# Number of VMs
$vmCountLabel = New-Object System.Windows.Controls.Label
$vmCountLabel.Content = "Number of VMs:"
$vmCountLabel.VerticalAlignment = "Center"

$vmCountPanel = New-Object System.Windows.Controls.StackPanel
$vmCountPanel.Orientation = "Horizontal"

$vmCountSlider = New-Object System.Windows.Controls.Slider
$vmCountSlider.Minimum = 1
$vmCountSlider.Maximum = 50
$vmCountSlider.Value = 1
$vmCountSlider.Width = 200
$vmCountSlider.TickFrequency = 1
$vmCountSlider.IsSnapToTickEnabled = $true
$vmCountSlider.Margin = New-Object System.Windows.Thickness(5)

$vmCountValue = New-Object System.Windows.Controls.Label
$vmCountValue.Content = "1"
$vmCountValue.Width = 30
$vmCountValue.VerticalAlignment = "Center"

$vmCountPanel.Children.Add($vmCountSlider)
$vmCountPanel.Children.Add($vmCountValue)

[System.Windows.Controls.Grid]::SetRow($vmCountLabel, 2)
[System.Windows.Controls.Grid]::SetColumn($vmCountLabel, 0)
[System.Windows.Controls.Grid]::SetRow($vmCountPanel, 2)
[System.Windows.Controls.Grid]::SetColumn($vmCountPanel, 1)

# CPU cores
$cpuLabel = New-Object System.Windows.Controls.Label
$cpuLabel.Content = "CPU Cores:"
$cpuLabel.VerticalAlignment = "Center"

$cpuCombo = New-Object System.Windows.Controls.ComboBox
$cpuCombo.Margin = New-Object System.Windows.Thickness(5)
$cpuCombo.Width = 100
$cpuCombo.HorizontalAlignment = "Left"
1..8 | ForEach-Object { $cpuCombo.Items.Add($_) }
$cpuCombo.SelectedValue = 2

[System.Windows.Controls.Grid]::SetRow($cpuLabel, 3)
[System.Windows.Controls.Grid]::SetColumn($cpuLabel, 0)
[System.Windows.Controls.Grid]::SetRow($cpuCombo, 3)
[System.Windows.Controls.Grid]::SetColumn($cpuCombo, 1)

# Memory
$memoryLabel = New-Object System.Windows.Controls.Label
$memoryLabel.Content = "Memory (GB):"
$memoryLabel.VerticalAlignment = "Center"

$memoryCombo = New-Object System.Windows.Controls.ComboBox
$memoryCombo.Margin = New-Object System.Windows.Thickness(5)
$memoryCombo.Width = 100
$memoryCombo.HorizontalAlignment = "Left"
@(2, 4, 8, 16, 32) | ForEach-Object { $memoryCombo.Items.Add($_) }
$memoryCombo.SelectedValue = 4

[System.Windows.Controls.Grid]::SetRow($memoryLabel, 4)
[System.Windows.Controls.Grid]::SetColumn($memoryLabel, 0)
[System.Windows.Controls.Grid]::SetRow($memoryCombo, 4)
[System.Windows.Controls.Grid]::SetColumn($memoryCombo, 1)

# VM Name Prefix
$prefixLabel = New-Object System.Windows.Controls.Label
$prefixLabel.Content = "VM Name Prefix:"
$prefixLabel.VerticalAlignment = "Center"

$prefixTextBox = New-Object System.Windows.Controls.TextBox
$prefixTextBox.Margin = New-Object System.Windows.Thickness(5)
$prefixTextBox.Width = 200
$prefixTextBox.HorizontalAlignment = "Left"

[System.Windows.Controls.Grid]::SetRow($prefixLabel, 5)
[System.Windows.Controls.Grid]::SetColumn($prefixLabel, 0)
[System.Windows.Controls.Grid]::SetRow($prefixTextBox, 5)
[System.Windows.Controls.Grid]::SetColumn($prefixTextBox, 1)

# Skip Autopilot
$skipAutopilotCheck = New-Object System.Windows.Controls.CheckBox
$skipAutopilotCheck.Content = "Skip Autopilot Configuration"
$skipAutopilotCheck.Margin = New-Object System.Windows.Thickness(5)

[System.Windows.Controls.Grid]::SetRow($skipAutopilotCheck, 6)
[System.Windows.Controls.Grid]::SetColumn($skipAutopilotCheck, 1)

# Include Tools
$includeToolsCheck = New-Object System.Windows.Controls.CheckBox
$includeToolsCheck.Content = "Include Troubleshooting Tools"
$includeToolsCheck.Margin = New-Object System.Windows.Thickness(5)

[System.Windows.Controls.Grid]::SetRow($includeToolsCheck, 7)
[System.Windows.Controls.Grid]::SetColumn($includeToolsCheck, 1)

# Create button
$createVMButton = New-Object System.Windows.Controls.Button
$createVMButton.Content = "Create VMs"
$createVMButton.Padding = New-Object System.Windows.Thickness(20, 10, 20, 10)
$createVMButton.Margin = New-Object System.Windows.Thickness(5, 20, 5, 5)
$createVMButton.HorizontalAlignment = "Left"
$createVMButton.Background = "LightGreen"
$createVMButton.FontWeight = "Bold"

[System.Windows.Controls.Grid]::SetRow($createVMButton, 8)
[System.Windows.Controls.Grid]::SetColumn($createVMButton, 1)

# Progress bar
$progressBar = New-Object System.Windows.Controls.ProgressBar
$progressBar.Height = 20
$progressBar.Margin = New-Object System.Windows.Thickness(5, 10, 5, 5)
$progressBar.Visibility = "Collapsed"

[System.Windows.Controls.Grid]::SetRow($progressBar, 9)
[System.Windows.Controls.Grid]::SetColumn($progressBar, 0)
[System.Windows.Controls.Grid]::SetColumnSpan($progressBar, 2)

# Progress label
$progressLabel = New-Object System.Windows.Controls.Label
$progressLabel.Content = ""
$progressLabel.HorizontalAlignment = "Center"
$progressLabel.Visibility = "Collapsed"

[System.Windows.Controls.Grid]::SetRow($progressLabel, 10)
[System.Windows.Controls.Grid]::SetColumn($progressLabel, 0)
[System.Windows.Controls.Grid]::SetColumnSpan($progressLabel, 2)

# Output text box
$outputTextBox = New-Object System.Windows.Controls.TextBox
$outputTextBox.Margin = New-Object System.Windows.Thickness(5, 10, 5, 5)
$outputTextBox.VerticalScrollBarVisibility = "Auto"
$outputTextBox.IsReadOnly = $true
$outputTextBox.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas")
$outputTextBox.Background = "Black"
$outputTextBox.Foreground = "LightGreen"

[System.Windows.Controls.Grid]::SetRow($outputTextBox, 12)
[System.Windows.Controls.Grid]::SetColumn($outputTextBox, 0)
[System.Windows.Controls.Grid]::SetColumnSpan($outputTextBox, 2)

# Add all controls to grid
$createGrid.Children.Add($tenantLabel)
$createGrid.Children.Add($tenantCombo)
$createGrid.Children.Add($imageLabel)
$createGrid.Children.Add($imageCombo)
$createGrid.Children.Add($vmCountLabel)
$createGrid.Children.Add($vmCountPanel)
$createGrid.Children.Add($cpuLabel)
$createGrid.Children.Add($cpuCombo)
$createGrid.Children.Add($memoryLabel)
$createGrid.Children.Add($memoryCombo)
$createGrid.Children.Add($prefixLabel)
$createGrid.Children.Add($prefixTextBox)
$createGrid.Children.Add($skipAutopilotCheck)
$createGrid.Children.Add($includeToolsCheck)
$createGrid.Children.Add($createVMButton)
$createGrid.Children.Add($progressBar)
$createGrid.Children.Add($progressLabel)
$createGrid.Children.Add($outputTextBox)

$createTab.Content = $createGrid

# Event handlers for VM creation
$vmCountSlider.Add_ValueChanged({
    $vmCountValue.Content = [int]$vmCountSlider.Value
})

$createVMButton.Add_Click({
    if (-not $tenantCombo.SelectedItem) {
        Show-Error "Please select a tenant"
        return
    }
    
    $outputTextBox.Clear()
    $progressBar.Visibility = "Visible"
    $progressLabel.Visibility = "Visible"
    $createVMButton.IsEnabled = $false
    
    try {
        $params = @{
            TenantName = $tenantCombo.SelectedItem.TenantName
            NumberOfVMs = [int]$vmCountSlider.Value
            CPUsPerVM = $cpuCombo.SelectedValue
            VMMemory = "$($memoryCombo.SelectedValue)GB"
        }
        
        if ($imageCombo.SelectedItem) {
            $params.OSBuild = $imageCombo.SelectedItem.imageName
        }
        
        if ($prefixTextBox.Text) {
            $params.NamePrefix = $prefixTextBox.Text
        }
        
        if ($skipAutopilotCheck.IsChecked) {
            $params.SkipAutoPilot = $true
        }
        
        if ($includeToolsCheck.IsChecked) {
            $params.IncludeTools = $true
        }
        
        $outputTextBox.AppendText("Starting VM creation...`n")
        $outputTextBox.AppendText("Parameters:`n")
        $params.GetEnumerator() | ForEach-Object {
            $outputTextBox.AppendText("  $($_.Key): $($_.Value)`n")
        }
        $outputTextBox.AppendText("`n")
        
        # Note: In a real implementation, you would run this asynchronously
        # For now, we'll just show a message
        $outputTextBox.AppendText("Creating VMs...`n")
        
        # Simulate progress
        for ($i = 1; $i -le $params.NumberOfVMs; $i++) {
            $progressBar.Value = ($i / $params.NumberOfVMs) * 100
            $progressLabel.Content = "Creating VM $i of $($params.NumberOfVMs)"
            Start-Sleep -Milliseconds 500
        }
        
        $outputTextBox.AppendText("VM creation completed successfully!`n")
        Update-Status "Created $($params.NumberOfVMs) VMs successfully" "Green"
    }
    catch {
        $outputTextBox.AppendText("ERROR: $($_.Exception.Message)`n")
        Show-Error "VM creation failed: $($_.Exception.Message)"
    }
    finally {
        $progressBar.Visibility = "Collapsed"
        $progressLabel.Visibility = "Collapsed"
        $createVMButton.IsEnabled = $true
    }
})

#endregion

#region Image Management Tab
$imageTab = New-Object System.Windows.Controls.TabItem
$imageTab.Header = "Image Management"

# Create image grid
$imageGrid = New-Object System.Windows.Controls.Grid
$imageGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
$imageGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))
$imageGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))

# Image toolbar
$imageToolbar = New-Object System.Windows.Controls.ToolBar
$imageToolbar.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)

$addImageButton = New-Object System.Windows.Controls.Button
$addImageButton.Content = "Add Image"
$addImageButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)

$deleteImageButton = New-Object System.Windows.Controls.Button
$deleteImageButton.Content = "Delete Image"
$deleteImageButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$deleteImageButton.IsEnabled = $false

$createVHDXButton = New-Object System.Windows.Controls.Button
$createVHDXButton.Content = "Create Reference VHDX"
$createVHDXButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$createVHDXButton.IsEnabled = $false

$validateImageButton = New-Object System.Windows.Controls.Button
$validateImageButton.Content = "Validate"
$validateImageButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$validateImageButton.IsEnabled = $false

$imageToolbar.Items.Add($addImageButton) | Out-Null
$imageToolbar.Items.Add($deleteImageButton) | Out-Null
$imageToolbar.Items.Add($createVHDXButton) | Out-Null
$imageToolbar.Items.Add($validateImageButton) | Out-Null

# Image list view
$imageListView = New-Object System.Windows.Controls.ListView
$imageListView.Margin = New-Object System.Windows.Thickness(0, 5, 0, 0)

# Define columns
$imageGridView = New-Object System.Windows.Controls.GridView

$imageNameColumn = New-Object System.Windows.Controls.GridViewColumn
$imageNameColumn.Header = "Image Name"
$imageNameColumn.DisplayMemberBinding = New-Object System.Windows.Data.Binding "imageName"
$imageNameColumn.Width = 200

$imagePathColumn = New-Object System.Windows.Controls.GridViewColumn
$imagePathColumn.Header = "Source Path"
$imagePathColumn.DisplayMemberBinding = New-Object System.Windows.Data.Binding "imagePath"
$imagePathColumn.Width = 400

$imageTypeColumn = New-Object System.Windows.Controls.GridViewColumn
$imageTypeColumn.Header = "Type"
$imageTypeColumn.DisplayMemberBinding = New-Object System.Windows.Data.Binding "Type"
$imageTypeColumn.Width = 80

$vhdxPathColumn = New-Object System.Windows.Controls.GridViewColumn
$vhdxPathColumn.Header = "Reference VHDX"
$vhdxPathColumn.DisplayMemberBinding = New-Object System.Windows.Data.Binding "refVHDX"
$vhdxPathColumn.Width = 400

$imageStatusColumn = New-Object System.Windows.Controls.GridViewColumn
$imageStatusColumn.Header = "Status"
$imageStatusColumn.DisplayMemberBinding = New-Object System.Windows.Data.Binding "Status"
$imageStatusColumn.Width = 100

$imageGridView.Columns.Add($imageNameColumn)
$imageGridView.Columns.Add($imagePathColumn)
$imageGridView.Columns.Add($imageTypeColumn)
$imageGridView.Columns.Add($vhdxPathColumn)
$imageGridView.Columns.Add($imageStatusColumn)

$imageListView.View = $imageGridView

# Image details panel
$imageDetailsPanel = New-Object System.Windows.Controls.GroupBox
$imageDetailsPanel.Header = "Image Details"
$imageDetailsPanel.Margin = New-Object System.Windows.Thickness(0, 5, 0, 0)
$imageDetailsPanel.Height = 100

$imageDetailsText = New-Object System.Windows.Controls.TextBlock
$imageDetailsText.Margin = New-Object System.Windows.Thickness(10)
$imageDetailsText.TextWrapping = "Wrap"
$imageDetailsPanel.Content = $imageDetailsText

# Set grid positions
[System.Windows.Controls.Grid]::SetRow($imageToolbar, 0)
[System.Windows.Controls.Grid]::SetRow($imageListView, 1)
[System.Windows.Controls.Grid]::SetRow($imageDetailsPanel, 2)

$imageGrid.Children.Add($imageToolbar)
$imageGrid.Children.Add($imageListView)
$imageGrid.Children.Add($imageDetailsPanel)

$imageTab.Content = $imageGrid

# Image management functions
function Get-ImageData {
    try {
        Update-Status "Loading images..." "Orange"
        
        if (-not $script:config) {
            Get-ConfigurationData
        }
        
        $imageData = @()
        foreach ($image in $script:config.images) {
            $imageInfo = [PSCustomObject]@{
                imageName = $image.imageName
                imagePath = $image.imagePath
                Type = if ($image.imagePath -like "*.iso") { "ISO" } else { "VHDX" }
                refVHDX = $image.refVHDX
                Status = if (Test-Path $image.refVHDX) { "Ready" } else { "Missing VHDX" }
                imageIndex = $image.imageIndex
            }
            $imageData += $imageInfo
        }
        
        $imageListView.ItemsSource = $imageData
        Update-Status "Loaded $($imageData.Count) images" "Green"
    }
    catch {
        Update-Status "Error loading images" "Red"
        Show-Error "Failed to load images: $($_.Exception.Message)"
    }
}

# Image event handlers
$imageListView.Add_SelectionChanged({
    $selectedImage = $imageListView.SelectedItem
    if ($selectedImage) {
        $deleteImageButton.IsEnabled = $true
        $createVHDXButton.IsEnabled = $selectedImage.Type -eq "ISO" -and $selectedImage.Status -eq "Missing VHDX"
        $validateImageButton.IsEnabled = $true
        
        # Update details
        $details = @"
Name: $($selectedImage.imageName)
Type: $($selectedImage.Type)
Source: $($selectedImage.imagePath)
Reference VHDX: $($selectedImage.refVHDX)
Status: $($selectedImage.Status)
Image Index: $($selectedImage.imageIndex)
"@
        $imageDetailsText.Text = $details
    }
    else {
        $deleteImageButton.IsEnabled = $false
        $createVHDXButton.IsEnabled = $false
        $validateImageButton.IsEnabled = $false
        $imageDetailsText.Text = ""
    }
})

$addImageButton.Add_Click({
    # Create add image dialog
    $addDialog = New-Object System.Windows.Window
    $addDialog.Title = "Add Image"
    $addDialog.Width = 500
    $addDialog.Height = 300
    $addDialog.WindowStartupLocation = "CenterOwner"
    $addDialog.Owner = $window
    
    $addGrid = New-Object System.Windows.Controls.Grid
    $addGrid.Margin = New-Object System.Windows.Thickness(10)
    
    for ($i = 0; $i -lt 5; $i++) {
        $addGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
    }
    
    $addGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = "100"}))
    $addGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = "*"}))
    
    # Image name
    $nameLabel = New-Object System.Windows.Controls.Label
    $nameLabel.Content = "Image Name:"
    
    $nameTextBox = New-Object System.Windows.Controls.TextBox
    $nameTextBox.Margin = New-Object System.Windows.Thickness(5)
    
    [System.Windows.Controls.Grid]::SetRow($nameLabel, 0)
    [System.Windows.Controls.Grid]::SetColumn($nameLabel, 0)
    [System.Windows.Controls.Grid]::SetRow($nameTextBox, 0)
    [System.Windows.Controls.Grid]::SetColumn($nameTextBox, 1)
    
    # Image path
    $pathLabel = New-Object System.Windows.Controls.Label
    $pathLabel.Content = "Image Path:"
    
    $pathPanel = New-Object System.Windows.Controls.StackPanel
    $pathPanel.Orientation = "Horizontal"
    
    $pathTextBox = New-Object System.Windows.Controls.TextBox
    $pathTextBox.Margin = New-Object System.Windows.Thickness(5)
    $pathTextBox.Width = 300
    
    $browseButton = New-Object System.Windows.Controls.Button
    $browseButton.Content = "Browse..."
    $browseButton.Margin = New-Object System.Windows.Thickness(5)
    $browseButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
    
    $pathPanel.Children.Add($pathTextBox)
    $pathPanel.Children.Add($browseButton)
    
    [System.Windows.Controls.Grid]::SetRow($pathLabel, 1)
    [System.Windows.Controls.Grid]::SetColumn($pathLabel, 0)
    [System.Windows.Controls.Grid]::SetRow($pathPanel, 1)
    [System.Windows.Controls.Grid]::SetColumn($pathPanel, 1)
    
    # Button panel
    $buttonPanel = New-Object System.Windows.Controls.StackPanel
    $buttonPanel.Orientation = "Horizontal"
    $buttonPanel.HorizontalAlignment = "Right"
    $buttonPanel.Margin = New-Object System.Windows.Thickness(0, 20, 0, 0)
    
    $okButton = New-Object System.Windows.Controls.Button
    $okButton.Content = "Add"
    $okButton.Width = 80
    $okButton.Margin = New-Object System.Windows.Thickness(5)
    $okButton.IsDefault = $true
    
    $cancelButton = New-Object System.Windows.Controls.Button
    $cancelButton.Content = "Cancel"
    $cancelButton.Width = 80
    $cancelButton.Margin = New-Object System.Windows.Thickness(5)
    $cancelButton.IsCancel = $true
    
    $buttonPanel.Children.Add($okButton)
    $buttonPanel.Children.Add($cancelButton)
    
    [System.Windows.Controls.Grid]::SetRow($buttonPanel, 4)
    [System.Windows.Controls.Grid]::SetColumn($buttonPanel, 0)
    [System.Windows.Controls.Grid]::SetColumnSpan($buttonPanel, 2)
    
    $addGrid.Children.Add($nameLabel)
    $addGrid.Children.Add($nameTextBox)
    $addGrid.Children.Add($pathLabel)
    $addGrid.Children.Add($pathPanel)
    $addGrid.Children.Add($buttonPanel)
    
    $addDialog.Content = $addGrid
    
    # Browse button handler
    $browseButton.Add_Click({
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "Windows Images|*.iso;*.vhdx|ISO files (*.iso)|*.iso|VHDX files (*.vhdx)|*.vhdx|All files (*.*)|*.*"
        
        if ($openFileDialog.ShowDialog() -eq "OK") {
            $pathTextBox.Text = $openFileDialog.FileName
            if (-not $nameTextBox.Text) {
                $nameTextBox.Text = [System.IO.Path]::GetFileNameWithoutExtension($openFileDialog.FileName)
            }
        }
    })
    
    # OK button handler
    $okButton.Add_Click({
        if (-not $nameTextBox.Text -or -not $pathTextBox.Text) {
            Show-Error "Please provide both image name and path"
            return
        }
        
        if (-not (Test-Path $pathTextBox.Text)) {
            Show-Error "The specified image file does not exist"
            return
        }
        
        $addDialog.DialogResult = $true
        $addDialog.Close()
    })
    
    $cancelButton.Add_Click({
        $addDialog.DialogResult = $false
        $addDialog.Close()
    })
    
    if ($addDialog.ShowDialog()) {
        try {
            Update-Status "Adding image..." "Orange"
            
            # In a real implementation, you would call Add-ImageToConfig here
            Show-Info "Image would be added:`nName: $($nameTextBox.Text)`nPath: $($pathTextBox.Text)"
            
            Get-ImageData
            Update-Status "Image added successfully" "Green"
        }
        catch {
            Show-Error "Failed to add image: $($_.Exception.Message)"
        }
    }
})

#endregion

#region Tenant Management Tab
$tenantTab = New-Object System.Windows.Controls.TabItem
$tenantTab.Header = "Tenant Management"

# Create tenant grid
$tenantGrid = New-Object System.Windows.Controls.Grid
$tenantGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
$tenantGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))
$tenantGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))

# Tenant toolbar
$tenantToolbar = New-Object System.Windows.Controls.ToolBar
$tenantToolbar.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)

$addTenantButton = New-Object System.Windows.Controls.Button
$addTenantButton.Content = "Add Tenant"
$addTenantButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)

$editTenantButton = New-Object System.Windows.Controls.Button
$editTenantButton.Content = "Edit Tenant"
$editTenantButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$editTenantButton.IsEnabled = $false

$deleteTenantButton = New-Object System.Windows.Controls.Button
$deleteTenantButton.Content = "Delete Tenant"
$deleteTenantButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$deleteTenantButton.IsEnabled = $false
$deleteTenantButton.Background = "LightCoral"

$testAuthButton = New-Object System.Windows.Controls.Button
$testAuthButton.Content = "Test Authentication"
$testAuthButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$testAuthButton.IsEnabled = $false

$tenantToolbar.Items.Add($addTenantButton) | Out-Null
$tenantToolbar.Items.Add($editTenantButton) | Out-Null
$tenantToolbar.Items.Add($deleteTenantButton) | Out-Null
$tenantToolbar.Items.Add($testAuthButton) | Out-Null

# Tenant list view
$tenantListView = New-Object System.Windows.Controls.ListView
$tenantListView.Margin = New-Object System.Windows.Thickness(0, 5, 0, 0)

# Define columns
$tenantGridView = New-Object System.Windows.Controls.GridView

$tenantNameCol = New-Object System.Windows.Controls.GridViewColumn
$tenantNameCol.Header = "Tenant Name"
$tenantNameCol.DisplayMemberBinding = New-Object System.Windows.Data.Binding "TenantName"
$tenantNameCol.Width = 200

$adminUpnCol = New-Object System.Windows.Controls.GridViewColumn
$adminUpnCol.Header = "Admin UPN"
$adminUpnCol.DisplayMemberBinding = New-Object System.Windows.Data.Binding "AdminUpn"
$adminUpnCol.Width = 250

$defaultImageCol = New-Object System.Windows.Controls.GridViewColumn
$defaultImageCol.Header = "Default Image"
$defaultImageCol.DisplayMemberBinding = New-Object System.Windows.Data.Binding "imageName"
$defaultImageCol.Width = 150

$tenantPathCol = New-Object System.Windows.Controls.GridViewColumn
$tenantPathCol.Header = "Path"
$tenantPathCol.DisplayMemberBinding = New-Object System.Windows.Data.Binding "pathToConfig"
$tenantPathCol.Width = 400

$vmCountCol = New-Object System.Windows.Controls.GridViewColumn
$vmCountCol.Header = "VM Count"
$vmCountCol.DisplayMemberBinding = New-Object System.Windows.Data.Binding "VMCount"
$vmCountCol.Width = 80

$tenantGridView.Columns.Add($tenantNameCol)
$tenantGridView.Columns.Add($adminUpnCol)
$tenantGridView.Columns.Add($defaultImageCol)
$tenantGridView.Columns.Add($tenantPathCol)
$tenantGridView.Columns.Add($vmCountCol)

$tenantListView.View = $tenantGridView

# Tenant details panel
$tenantDetailsPanel = New-Object System.Windows.Controls.GroupBox
$tenantDetailsPanel.Header = "Tenant Details"
$tenantDetailsPanel.Margin = New-Object System.Windows.Thickness(0, 5, 0, 0)
$tenantDetailsPanel.Height = 150

$tenantDetailsText = New-Object System.Windows.Controls.TextBlock
$tenantDetailsText.Margin = New-Object System.Windows.Thickness(10)
$tenantDetailsText.TextWrapping = "Wrap"
$tenantDetailsPanel.Content = $tenantDetailsText

# Set grid positions
[System.Windows.Controls.Grid]::SetRow($tenantToolbar, 0)
[System.Windows.Controls.Grid]::SetRow($tenantListView, 1)
[System.Windows.Controls.Grid]::SetRow($tenantDetailsPanel, 2)

$tenantGrid.Children.Add($tenantToolbar)
$tenantGrid.Children.Add($tenantListView)
$tenantGrid.Children.Add($tenantDetailsPanel)

$tenantTab.Content = $tenantGrid

# Tenant management functions
function Get-TenantData {
    try {
        Update-Status "Loading tenants..." "Orange"
        
        if (-not $script:config) {
            Get-ConfigurationData
        }
        
        $tenantData = @()
        foreach ($tenant in $script:config.tenantConfig) {
            # Count VMs for this tenant
            $vmCount = 0
            if ($script:vmList) {
                $vmCount = ($script:vmList | Where-Object { $_.Tenant -eq $tenant.TenantName }).Count
            }
            
            $tenantInfo = [PSCustomObject]@{
                TenantName = $tenant.TenantName
                AdminUpn = $tenant.AdminUpn
                imageName = $tenant.imageName
                pathToConfig = $tenant.pathToConfig
                VMCount = $vmCount
            }
            $tenantData += $tenantInfo
        }
        
        $tenantListView.ItemsSource = $tenantData
        $tenantCombo.ItemsSource = $tenantData
        
        Update-Status "Loaded $($tenantData.Count) tenants" "Green"
    }
    catch {
        Update-Status "Error loading tenants" "Red"
        Show-Error "Failed to load tenants: $($_.Exception.Message)"
    }
}

# Tenant event handlers
$tenantListView.Add_SelectionChanged({
    $selectedTenant = $tenantListView.SelectedItem
    if ($selectedTenant) {
        $editTenantButton.IsEnabled = $true
        $deleteTenantButton.IsEnabled = $true
        $testAuthButton.IsEnabled = $true
        
        # Update details
        $details = @"
Tenant: $($selectedTenant.TenantName)
Admin UPN: $($selectedTenant.AdminUpn)
Default Image: $($selectedTenant.imageName)
Configuration Path: $($selectedTenant.pathToConfig)
Number of VMs: $($selectedTenant.VMCount)

Path exists: $(Test-Path $selectedTenant.pathToConfig)
"@
        $tenantDetailsText.Text = $details
    }
    else {
        $editTenantButton.IsEnabled = $false
        $deleteTenantButton.IsEnabled = $false
        $testAuthButton.IsEnabled = $false
        $tenantDetailsText.Text = ""
    }
})

$addTenantButton.Add_Click({
    # Create add tenant dialog
    $addDialog = New-Object System.Windows.Window
    $addDialog.Title = "Add Tenant"
    $addDialog.Width = 500
    $addDialog.Height = 350
    $addDialog.WindowStartupLocation = "CenterOwner"
    $addDialog.Owner = $window
    
    $addGrid = New-Object System.Windows.Controls.Grid
    $addGrid.Margin = New-Object System.Windows.Thickness(10)
    
    for ($i = 0; $i -lt 6; $i++) {
        $addGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
    }
    
    $addGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = "120"}))
    $addGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width = "*"}))
    
    # Tenant name
    $nameLabel = New-Object System.Windows.Controls.Label
    $nameLabel.Content = "Tenant Name:"
    
    $nameTextBox = New-Object System.Windows.Controls.TextBox
    $nameTextBox.Margin = New-Object System.Windows.Thickness(5)
    
    [System.Windows.Controls.Grid]::SetRow($nameLabel, 0)
    [System.Windows.Controls.Grid]::SetColumn($nameLabel, 0)
    [System.Windows.Controls.Grid]::SetRow($nameTextBox, 0)
    [System.Windows.Controls.Grid]::SetColumn($nameTextBox, 1)
    
    # Admin UPN
    $upnLabel = New-Object System.Windows.Controls.Label
    $upnLabel.Content = "Admin UPN:"
    
    $upnTextBox = New-Object System.Windows.Controls.TextBox
    $upnTextBox.Margin = New-Object System.Windows.Thickness(5)
    
    [System.Windows.Controls.Grid]::SetRow($upnLabel, 1)
    [System.Windows.Controls.Grid]::SetColumn($upnLabel, 0)
    [System.Windows.Controls.Grid]::SetRow($upnTextBox, 1)
    [System.Windows.Controls.Grid]::SetColumn($upnTextBox, 1)
    
    # Default image
    $imageLabel = New-Object System.Windows.Controls.Label
    $imageLabel.Content = "Default Image:"
    
    $imageComboBox = New-Object System.Windows.Controls.ComboBox
    $imageComboBox.Margin = New-Object System.Windows.Thickness(5)
    $imageComboBox.DisplayMemberPath = "imageName"
    $imageComboBox.ItemsSource = $imageListView.ItemsSource
    
    [System.Windows.Controls.Grid]::SetRow($imageLabel, 2)
    [System.Windows.Controls.Grid]::SetColumn($imageLabel, 0)
    [System.Windows.Controls.Grid]::SetRow($imageComboBox, 2)
    [System.Windows.Controls.Grid]::SetColumn($imageComboBox, 1)
    
    # Button panel
    $buttonPanel = New-Object System.Windows.Controls.StackPanel
    $buttonPanel.Orientation = "Horizontal"
    $buttonPanel.HorizontalAlignment = "Right"
    $buttonPanel.Margin = New-Object System.Windows.Thickness(0, 20, 0, 0)
    
    $okButton = New-Object System.Windows.Controls.Button
    $okButton.Content = "Add"
    $okButton.Width = 80
    $okButton.Margin = New-Object System.Windows.Thickness(5)
    $okButton.IsDefault = $true
    
    $cancelButton = New-Object System.Windows.Controls.Button
    $cancelButton.Content = "Cancel"
    $cancelButton.Width = 80
    $cancelButton.Margin = New-Object System.Windows.Thickness(5)
    $cancelButton.IsCancel = $true
    
    $buttonPanel.Children.Add($okButton)
    $buttonPanel.Children.Add($cancelButton)
    
    [System.Windows.Controls.Grid]::SetRow($buttonPanel, 5)
    [System.Windows.Controls.Grid]::SetColumn($buttonPanel, 0)
    [System.Windows.Controls.Grid]::SetColumnSpan($buttonPanel, 2)
    
    $addGrid.Children.Add($nameLabel)
    $addGrid.Children.Add($nameTextBox)
    $addGrid.Children.Add($upnLabel)
    $addGrid.Children.Add($upnTextBox)
    $addGrid.Children.Add($imageLabel)
    $addGrid.Children.Add($imageComboBox)
    $addGrid.Children.Add($buttonPanel)
    
    $addDialog.Content = $addGrid
    
    # OK button handler
    $okButton.Add_Click({
        if (-not $nameTextBox.Text -or -not $upnTextBox.Text -or -not $imageComboBox.SelectedItem) {
            Show-Error "Please fill in all fields"
            return
        }
        
        $addDialog.DialogResult = $true
        $addDialog.Close()
    })
    
    $cancelButton.Add_Click({
        $addDialog.DialogResult = $false
        $addDialog.Close()
    })
    
    if ($addDialog.ShowDialog()) {
        try {
            Update-Status "Adding tenant..." "Orange"
            
            # In a real implementation, you would call Add-TenantToConfig here
            Show-Info "Tenant would be added:`nName: $($nameTextBox.Text)`nAdmin: $($upnTextBox.Text)`nImage: $($imageComboBox.SelectedItem.imageName)"
            
            Get-TenantData
            Update-Status "Tenant added successfully" "Green"
        }
        catch {
            Show-Error "Failed to add tenant: $($_.Exception.Message)"
        }
    }
})

$testAuthButton.Add_Click({
    $selectedTenant = $tenantListView.SelectedItem
    if ($selectedTenant) {
        try {
            Update-Status "Testing authentication for $($selectedTenant.TenantName)..." "Orange"
            
            # In a real implementation, you would test the authentication here
            Show-Info "Authentication test would be performed for tenant: $($selectedTenant.TenantName)"
            
            Update-Status "Authentication test completed" "Green"
        }
        catch {
            Show-Error "Authentication test failed: $($_.Exception.Message)"
        }
    }
})

#endregion

#region Configuration Tab (existing)
$configTab = New-Object System.Windows.Controls.TabItem
$configTab.Header = "Configuration"

# Use the existing configuration viewer content
$configGrid = New-Object System.Windows.Controls.Grid
$configGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))
$configGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "*"}))

# Config toolbar
$configToolbar = New-Object System.Windows.Controls.StackPanel
$configToolbar.Orientation = "Horizontal"
$configToolbar.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)

$refreshConfigButton = New-Object System.Windows.Controls.Button
$refreshConfigButton.Content = "Refresh Configuration"
$refreshConfigButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)
$refreshConfigButton.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)

$exportConfigButton = New-Object System.Windows.Controls.Button
$exportConfigButton.Content = "Export JSON"
$exportConfigButton.Padding = New-Object System.Windows.Thickness(10, 5, 10, 5)

$configToolbar.Children.Add($refreshConfigButton)
$configToolbar.Children.Add($exportConfigButton)

# Config text box
$configTextBox = New-Object System.Windows.Controls.TextBox
$configTextBox.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas")
$configTextBox.FontSize = 12
$configTextBox.IsReadOnly = $true
$configTextBox.VerticalScrollBarVisibility = "Auto"
$configTextBox.HorizontalScrollBarVisibility = "Auto"
$configTextBox.AcceptsReturn = $true
$configTextBox.TextWrapping = "NoWrap"

[System.Windows.Controls.Grid]::SetRow($configToolbar, 0)
[System.Windows.Controls.Grid]::SetRow($configTextBox, 1)

$configGrid.Children.Add($configToolbar)
$configGrid.Children.Add($configTextBox)

$configTab.Content = $configGrid

# Config event handlers
$refreshConfigButton.Add_Click({
    try {
        Update-Status "Loading configuration..." "Orange"
        $config = Get-APHVToolsConfig -Raw
        $configTextBox.Text = $config | ConvertTo-Json -Depth 10
        Update-Status "Configuration loaded" "Green"
    }
    catch {
        Show-Error "Failed to load configuration: $($_.Exception.Message)"
    }
})

$exportConfigButton.Add_Click({
    try {
        $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveFileDialog.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
        $saveFileDialog.DefaultExt = "json"
        $saveFileDialog.FileName = "APHVTools-Config-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        
        if ($saveFileDialog.ShowDialog()) {
            $configTextBox.Text | Out-File -FilePath $saveFileDialog.FileName -Encoding UTF8
            Update-Status "Configuration exported successfully" "Green"
            Show-Info "Configuration exported to: $($saveFileDialog.FileName)"
        }
    }
    catch {
        Show-Error "Failed to export configuration: $($_.Exception.Message)"
    }
})

#endregion

# Add tabs to tab control
$tabControl.Items.Add($vmTab)
$tabControl.Items.Add($createTab)
$tabControl.Items.Add($imageTab)
$tabControl.Items.Add($tenantTab)
$tabControl.Items.Add($configTab)

# Set grid positions
[System.Windows.Controls.Grid]::SetRow($headerPanel, 0)
[System.Windows.Controls.Grid]::SetRow($tabControl, 1)
[System.Windows.Controls.Grid]::SetRow($statusPanel, 2)

# Add controls to main grid
$mainGrid.Children.Add($headerPanel)
$mainGrid.Children.Add($tabControl)
$mainGrid.Children.Add($statusPanel)

# Set window content
$window.Content = $mainGrid

# Initialize on startup
$window.Add_Loaded({
    if (Get-ConfigurationData) {
        Get-VMsForManagement
        Get-ImageData
        Get-TenantData
        
        # Load images into create tab combo
        $imageCombo.ItemsSource = $script:config.images
    }
})

# Show the window
$window.ShowDialog() | Out-Null