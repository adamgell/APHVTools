# HVTools Troubleshooting Guide

## Common Issues and Solutions

### Installation Issues

#### Module Won't Install
```powershell
# Error: "Unable to install module HVTools"
```

**Solutions:**
1. Check PowerShell version:
   ```powershell
   $PSVersionTable.PSVersion
   # Must be 5.1 or higher
   ```

2. Set execution policy:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. Install from local source:
   ```powershell
   git clone https://github.com/adamgell/HVTools.git
   cd HVTools
   ./build.ps1 -modulePath ./HVTools -buildLocal
   Import-Module ./HVTools/HVTools.psd1 -Force
   ```

#### Missing Dependencies
```powershell
# Error: "The specified module 'Microsoft.Graph.Authentication' was not loaded"
```

**Solution:**
```powershell
# Install all dependencies
Install-Module Microsoft.Graph.Authentication -Force
Install-Module Microsoft.Graph.DeviceManagement -Force
Install-Module Microsoft.Graph.DeviceManagement.Enrollment -Force
Install-Module Hyper-ConvertImage -Force
Install-Module WindowsAutoPilotIntune -Force
Install-Module Microsoft.Graph.Intune -Force
```

### Configuration Issues

#### Initialize-HVTools Fails
```powershell
# Error: "Access to the path is denied"
```

**Solutions:**
1. Run PowerShell as Administrator
2. Check folder permissions:
   ```powershell
   # Test write access
   $testPath = "C:\HVTools-Workspace"
   New-Item -Path $testPath -Name "test.txt" -ItemType File -Force
   Remove-Item "$testPath\test.txt"
   ```

3. Use a different path:
   ```powershell
   Initialize-HVTools -Path "$env:USERPROFILE\HVTools"
   ```

#### Configuration File Not Found
```powershell
# Error: "Please run Initialize-HVTools to configure the environment"
```

**Solutions:**
1. Check if configuration exists:
   ```powershell
   Test-Path "$env:USERPROFILE\.hvtoolscfgpath"
   ```

2. Re-initialize:
   ```powershell
   Initialize-HVTools -Path "C:\HVTools-Workspace"
   ```

3. Manually check configuration:
   ```powershell
   Get-Content "$env:USERPROFILE\.hvtoolscfgpath" | ConvertFrom-Json
   ```

### VM Creation Issues

#### Reference VHDX Not Found
```powershell
# Error: "Reference VHDX not found at path"
```

**Solutions:**
1. Check if reference VHDX exists:
   ```powershell
   $config = Get-HVToolsConfig
   $config.images | ForEach-Object {
       Test-Path $_.refVHDX
   }
   ```

2. Recreate reference VHDX:
   ```powershell
   # Remove and re-add image
   $config = Get-HVToolsConfig
   $badImage = $config.images | Where-Object { -not (Test-Path $_.refVHDX) }
   # Manually edit config file to remove bad image
   # Then re-add:
   Add-ImageToConfig -ImageName $badImage.imageName -IsoPath $badImage.imagePath
   ```

#### VM Creation Hangs
```powershell
# Symptom: New-ClientVM runs but never completes
```

**Solutions:**
1. Check Hyper-V service:
   ```powershell
   Get-Service vmms | Select-Object Name, Status, StartType
   # Should show "Running"
   
   # Restart if needed
   Restart-Service vmms
   ```

2. Check available resources:
   ```powershell
   # Check disk space
   Get-PSDrive C | Select-Object @{n='FreeGB';e={[math]::Round($_.Free/1GB,2)}}
   
   # Check memory
   Get-CimInstance Win32_OperatingSystem | 
       Select-Object @{n='AvailableGB';e={[math]::Round($_.FreePhysicalMemory/1MB,2)}}
   ```

3. Create with verbose output:
   ```powershell
   New-ClientVM -TenantName "Test" -NumberOfVMs 1 -CPUsPerVM 2 -Verbose
   ```

#### Autopilot Configuration Fails
```powershell
# Error: "Failed to get Autopilot policy"
```

**Solutions:**
1. Test Graph connectivity:
   ```powershell
   # Connect manually
   Connect-MgGraph -Scopes "DeviceManagementServiceConfig.Read.All"
   
   # Test API access
   Get-MgDeviceManagementWindowAutopilotDeploymentProfile
   ```

2. Clear cached credentials:
   ```powershell
   # Remove cached auth
   Disconnect-MgGraph
   
   # Clear token cache
   Remove-Item "$env:USERPROFILE\.graph" -Recurse -Force -ErrorAction SilentlyContinue
   ```

3. Skip Autopilot temporarily:
   ```powershell
   New-ClientVM -TenantName "Test" -NumberOfVMs 1 -CPUsPerVM 2 -SkipAutoPilot
   ```

### Network Issues

#### Virtual Switch Not Found
```powershell
# Error: "Virtual switch 'Default Switch' not found"
```

**Solutions:**
1. List available switches:
   ```powershell
   Get-VMSwitch | Select-Object Name, SwitchType
   ```

2. Create default switch:
   ```powershell
   New-VMSwitch -Name "Default Switch" -SwitchType Internal
   ```

3. Use existing switch:
   ```powershell
   $switch = Get-VMSwitch | Select-Object -First 1
   Add-NetworkToConfig -VSwitchName $switch.Name
   ```

#### VLAN Configuration Issues
```powershell
# Error: "Failed to set VLAN configuration"
```

**Solution:**
```powershell
# Verify VLAN ID is valid (1-4094)
# Check if switch supports VLANs
Get-VMSwitch "YourSwitch" | Get-VMNetworkAdapterVlan
```

### Performance Issues

#### Slow VM Creation
**Diagnostics:**
```powershell
# Measure VM creation time
Measure-Command {
    New-ClientVM -TenantName "Test" -NumberOfVMs 1 -CPUsPerVM 2
}
```

**Solutions:**
1. Check disk performance:
   ```powershell
   # Simple disk speed test
   $testFile = "C:\test.tmp"
   Measure-Command {
       $bytes = New-Object byte[] 1GB
       [System.IO.File]::WriteAllBytes($testFile, $bytes)
   }
   Remove-Item $testFile
   ```

2. Reduce VM specs:
   ```powershell
   # Use minimum resources
   New-ClientVM -TenantName "Test" -NumberOfVMs 1 -CPUsPerVM 1 -VMMemory 2GB
   ```

3. Check antivirus exclusions:
   - Exclude VM storage paths
   - Exclude VHDX files
   - Exclude Hyper-V processes

### Logging and Debugging

#### Enable Verbose Logging
```powershell
# For single command
New-ClientVM -TenantName "Test" -NumberOfVMs 1 -CPUsPerVM 2 -Verbose

# For session
$VerbosePreference = "Continue"
```

#### Enable Debug Output
```powershell
# For detailed debugging
$DebugPreference = "Continue"
```

#### Check Log Files
```powershell
# Find log files
$config = Get-HVToolsConfig
Get-ChildItem -Path $config.vmPath -Filter "*.log" -Recurse |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 10
```

#### Transcript Logging
```powershell
# Start transcript
Start-Transcript -Path "C:\Temp\HVTools-Debug.log"

# Run your commands
New-ClientVM -TenantName "Test" -NumberOfVMs 1 -CPUsPerVM 2 -Verbose

# Stop transcript
Stop-Transcript
```

### Advanced Diagnostics

#### Module Diagnostics
```powershell
# Check module is loaded
Get-Module HVTools

# Check exported commands
Get-Command -Module HVTools

# Check module path
(Get-Module HVTools).Path

# Verify all functions loaded
$modulePath = (Get-Module HVTools).ModuleBase
Get-ChildItem "$modulePath\Public\*.ps1"
Get-ChildItem "$modulePath\Private\*.ps1"
```

#### Hyper-V Diagnostics
```powershell
# Check Hyper-V installation
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All

# Check Hyper-V services
Get-Service vm* | Select-Object Name, Status, StartType

# Check Hyper-V event log
Get-WinEvent -LogName "Microsoft-Windows-Hyper-V-Worker-Admin" -MaxEvents 20
```

#### Permission Diagnostics
```powershell
# Check if running as admin
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

# Check Hyper-V administrators group
Get-LocalGroupMember -Group "Hyper-V Administrators"

# Check effective permissions
$path = (Get-HVToolsConfig).vmPath
(Get-Acl $path).Access | Where-Object {$_.IdentityReference -like "*$env:USERNAME*"}
```

### Recovery Procedures

#### Reset Configuration
```powershell
# Backup current config
Copy-Item "$env:USERPROFILE\.hvtoolscfgpath" "$env:USERPROFILE\.hvtoolscfgpath.backup"

# Remove configuration
Remove-Item "$env:USERPROFILE\.hvtoolscfgpath"

# Re-initialize
Initialize-HVTools -Path "C:\HVTools-Workspace"
```

#### Clean Orphaned VMs
```powershell
# Find VMs without config
$config = Get-HVToolsConfig
$configuredVMs = Get-ChildItem -Path $config.vmPath -Directory | Select-Object -ExpandProperty Name
$hyperVMs = Get-VM | Where-Object {$_.Name -like "HVTools-*"} | Select-Object -ExpandProperty Name

# Find orphans
$orphans = $hyperVMs | Where-Object {$_ -notin $configuredVMs}

# Remove orphans (careful!)
$orphans | ForEach-Object {
    Remove-VM -Name $_ -Force
}
```

#### Repair Differencing Disks
```powershell
# Check differencing disk chain
$vhdx = "Path\to\differencing.vhdx"
Get-VHD -Path $vhdx | Select-Object Path, ParentPath, FragmentationPercentage

# Reconnect parent
Set-VHD -Path $vhdx -ParentPath "Path\to\parent.vhdx"

# Merge if needed (destructive!)
Merge-VHD -Path $vhdx -DestinationPath "Path\to\merged.vhdx"
```

### Getting Help

#### Built-in Help
```powershell
# Module help
Get-Help about_HVTools

# Function help
Get-Help New-ClientVM -Full
Get-Help Initialize-HVTools -Examples

# Online help
Get-Help New-ClientVM -Online
```

#### Diagnostic Information for Support
```powershell
# Gather system info
$diagnostics = @{
    PowerShellVersion = $PSVersionTable.PSVersion
    OSVersion = [System.Environment]::OSVersion.VersionString
    HVToolsVersion = (Get-Module HVTools).Version
    HyperVEnabled = (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All).State
    IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    Config = Get-HVToolsConfig
}

# Save to file
$diagnostics | ConvertTo-Json -Depth 10 | Out-File "HVTools-Diagnostics.json"
```

### Reporting Issues

When reporting issues, include:
1. Full error message
2. PowerShell version (`$PSVersionTable`)
3. HVTools version (`(Get-Module HVTools).Version`)
4. Steps to reproduce
5. Diagnostic output from above
6. Relevant log files

Report issues at: https://github.com/adamgell/HVTools/issues