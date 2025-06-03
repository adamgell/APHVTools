# HVTools API Reference

## Public Functions

### Initialize-HVTools

Initializes the HVTools environment and creates necessary folder structures.

```powershell
Initialize-HVTools [-Path] <string> [-WhatIf] [-Confirm]
```

#### Parameters
- **Path** (Mandatory): The root path where HVTools will store VMs and configurations
- **WhatIf**: Shows what would happen if the cmdlet runs
- **Confirm**: Prompts for confirmation before running

#### Example
```powershell
Initialize-HVTools -Path "C:\HVTools-Workspace"
```

---

### Add-ImageToConfig

Adds a Windows image to the HVTools configuration.

```powershell
Add-ImageToConfig -ImageName <string> [-IsoPath <string>] [-ReferenceVHDX <string>] [-WhatIf] [-Confirm]
```

#### Parameters
- **ImageName** (Mandatory): Friendly name for the image
- **IsoPath**: Path to Windows ISO file
- **ReferenceVHDX**: Path to existing reference VHDX
- **WhatIf**: Shows what would happen if the cmdlet runs
- **Confirm**: Prompts for confirmation before running

#### Examples
```powershell
# Add ISO image
Add-ImageToConfig -ImageName "Win11-23H2" -IsoPath "C:\ISOs\Win11.iso"

# Add existing VHDX
Add-ImageToConfig -ImageName "Win11-Custom" -ReferenceVHDX "C:\VHDXs\Win11.vhdx"
```

---

### Add-TenantToConfig

Adds a tenant configuration to HVTools.

```powershell
Add-TenantToConfig -TenantName <string> -AdminUpn <string> -ImageName <string> [-WhatIf] [-Confirm]
```

#### Parameters
- **TenantName** (Mandatory): Name of the tenant
- **AdminUpn** (Mandatory): Admin user principal name
- **ImageName** (Mandatory): Default image for this tenant
- **WhatIf**: Shows what would happen if the cmdlet runs
- **Confirm**: Prompts for confirmation before running

#### Example
```powershell
Add-TenantToConfig -TenantName "Contoso" -AdminUpn "admin@contoso.com" -ImageName "Win11-23H2"
```

---

### Add-NetworkToConfig

Configures network settings for VMs.

```powershell
Add-NetworkToConfig -VSwitchName <string> [-VlanId <int>] [-WhatIf] [-Confirm]
```

#### Parameters
- **VSwitchName** (Mandatory): Name of the Hyper-V virtual switch
- **VlanId**: VLAN ID for network isolation
- **WhatIf**: Shows what would happen if the cmdlet runs
- **Confirm**: Prompts for confirmation before running

#### Examples
```powershell
# Basic network configuration
Add-NetworkToConfig -VSwitchName "Default Switch"

# With VLAN
Add-NetworkToConfig -VSwitchName "External Switch" -VlanId 100
```

---

### Add-ToolsToConfig

Adds troubleshooting tools to the configuration.

```powershell
Add-ToolsToConfig -ToolsPath <string> [-WhatIf] [-Confirm]
```

#### Parameters
- **ToolsPath** (Mandatory): Path to folder containing tools
- **WhatIf**: Shows what would happen if the cmdlet runs
- **Confirm**: Prompts for confirmation before running

#### Example
```powershell
Add-ToolsToConfig -ToolsPath "C:\DiagnosticTools"
```

---

### New-ClientVM

Creates new Hyper-V virtual machines with optional Autopilot configuration.

```powershell
New-ClientVM -TenantName <string> [-OSBuild <string>] -NumberOfVMs <int> 
             -CPUsPerVM <int> [-VMMemory <int64>] [-SkipAutoPilot] 
             [-IncludeTools] [-WhatIf] [-Confirm]
```

#### Parameters
- **TenantName** (Mandatory): Name of the tenant
- **OSBuild**: Specific OS image to use (overrides tenant default)
- **NumberOfVMs** (Mandatory): Number of VMs to create (1-999)
- **CPUsPerVM** (Mandatory): Number of CPU cores per VM (1-999)
- **VMMemory**: Memory per VM in bytes (default: 4GB, range: 2GB-20GB)
- **SkipAutoPilot**: Skip Autopilot configuration injection
- **IncludeTools**: Include troubleshooting tools in VMs
- **WhatIf**: Shows what would happen if the cmdlet runs
- **Confirm**: Prompts for confirmation before running

#### Examples
```powershell
# Basic VM creation
New-ClientVM -TenantName "Contoso" -NumberOfVMs 5 -CPUsPerVM 2

# With specific memory and OS
New-ClientVM -TenantName "Contoso" -OSBuild "Win11-23H2" -NumberOfVMs 3 -CPUsPerVM 4 -VMMemory 8GB

# Without Autopilot
New-ClientVM -TenantName "Fabrikam" -NumberOfVMs 2 -CPUsPerVM 2 -SkipAutoPilot

# With diagnostic tools
New-ClientVM -TenantName "Contoso" -NumberOfVMs 1 -CPUsPerVM 2 -IncludeTools
```

---

### Get-HVToolsConfig

Retrieves the current HVTools configuration.

```powershell
Get-HVToolsConfig
```

#### Returns
PSCustomObject containing:
- **vmPath**: Path where VMs are stored
- **referenceVHDXPath**: Path where reference VHDXs are stored
- **tenantConfig**: Array of tenant configurations
- **networkConfig**: Network configuration settings
- **images**: Array of configured images
- **toolsConfig**: Tools configuration settings

#### Example
```powershell
# Get full configuration
$config = Get-HVToolsConfig

# Get specific sections
$tenants = Get-HVToolsConfig | Select-Object -ExpandProperty tenantConfig
$images = Get-HVToolsConfig | Select-Object -ExpandProperty images
```

---

### Get-ToolsFromConfig

Retrieves the configured troubleshooting tools.

```powershell
Get-ToolsFromConfig
```

#### Returns
Array of tool paths configured in the environment

#### Example
```powershell
$tools = Get-ToolsFromConfig
$tools | ForEach-Object { Write-Host "Tool: $_" }
```

## Private Functions

These functions are not exported but are documented for development purposes.

### Write-LogEntry

Writes standardized log entries.

```powershell
Write-LogEntry -Message <string> -Severity <int>
```

#### Parameters
- **Message**: Log message
- **Severity**: 1 = Information, 2 = Warning, 3 = Error

---

### New-ClientDevice

Generates device details and fetches Autopilot configuration.

```powershell
New-ClientDevice -TenantName <string> -ClientName <string> -SerialNumber <string> 
                 -AdminUPN <string> [-PathToConfig <string>]
```

---

### New-ClientVHDX

Creates a differencing disk from reference VHDX.

```powershell
New-ClientVHDX -VHDXPath <string> -ReferenceVHDX <string> 
               -ComputerName <string> [-IncludeTools] [-ToolsPath <string>]
```

---

### Get-AutopilotPolicy

Retrieves Autopilot policy from Intune.

```powershell
Get-AutopilotPolicy -ID <string>
```

---

### Publish-AutoPilotConfig

Publishes Autopilot configuration to VHDX.

```powershell
Publish-AutoPilotConfig -VHDXPath <string> -ConfigPath <string>
```

---

### Get-ImageIndexFromWim

Gets available image indexes from Windows ISO.

```powershell
Get-ImageIndexFromWim -IsoPath <string>
```

---

### Add-TroubleshootingTools

Adds troubleshooting tools to a mounted VHDX.

```powershell
Add-TroubleshootingTools -MountPath <string> -ToolsPath <string>
```

## Return Objects

### Tenant Configuration Object
```powershell
@{
    tenantName = [string]
    adminUpn = [string]
    imageName = [string]
    pathToConfig = [string]
}
```

### Image Configuration Object
```powershell
@{
    imageName = [string]
    imagePath = [string]
    imageIndex = [int]
    refVHDX = [string]
}
```

### Network Configuration Object
```powershell
@{
    vSwitchName = [string]
    vlanId = [int] # Optional
}
```

### VM Creation Result
```powershell
@{
    VMName = [string]
    ComputerName = [string]
    SerialNumber = [string]
    VHDXPath = [string]
    Success = [bool]
    Error = [string] # If applicable
}
```

## Error Codes

| Code | Description | Resolution |
|------|-------------|------------|
| 1001 | Configuration not found | Run Initialize-HVTools |
| 1002 | Tenant not found | Add tenant with Add-TenantToConfig |
| 1003 | Image not found | Add image with Add-ImageToConfig |
| 1004 | Network not configured | Run Add-NetworkToConfig |
| 1005 | Hyper-V not available | Enable Hyper-V feature |
| 1006 | Insufficient permissions | Run as administrator |
| 1007 | Autopilot fetch failed | Check credentials and connectivity |
| 1008 | VHDX creation failed | Check disk space and permissions |
| 1009 | VM creation failed | Check Hyper-V service status |
| 1010 | Module dependency missing | Install required modules |

## Performance Considerations

### Bulk Operations
- VMs are created sequentially
- Each VM takes 30-60 seconds
- Plan for ~5 minutes per 10 VMs

### Storage Requirements
- Reference VHDX: ~15-20GB per image
- Differencing disk: ~1-2GB initial per VM
- Growth depends on VM usage

### Memory Usage
- Module overhead: ~50MB
- Per VM creation: ~100MB
- Graph API calls: ~200MB peak

## Compatibility

### PowerShell Versions
- Minimum: 5.1
- Recommended: 7.3+
- Windows PowerShell and PowerShell Core supported

### Operating Systems
- Windows 10 Pro/Enterprise/Education (1809+)
- Windows 11 Pro/Enterprise/Education
- Windows Server 2016/2019/2022

### Hyper-V Versions
- Windows 10 Hyper-V
- Windows 11 Hyper-V
- Windows Server Hyper-V

## Best Practices

1. **Initialize Once**: Run Initialize-HVTools once per environment
2. **Configure Before Creating**: Set up all configurations before creating VMs
3. **Use WhatIf**: Test commands with -WhatIf first
4. **Monitor Resources**: Check disk space and memory before bulk operations
5. **Regular Cleanup**: Remove old VMs and differencing disks
6. **Credential Security**: Use service accounts for automation
7. **Logging**: Enable verbose logging for troubleshooting
8. **Backup Configuration**: Backup the .hvtoolscfgpath file regularly