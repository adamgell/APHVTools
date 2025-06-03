# Windows Autopilot Integration Guide

This guide explains how to configure and use Windows Autopilot with HVTools for automated device provisioning.

## Overview

Windows Autopilot integration allows HVTools to:
- Automatically fetch Autopilot profiles from Intune
- Inject profiles into VMs before first boot
- Enable zero-touch provisioning for test VMs
- Simulate real-world device enrollment scenarios

## Prerequisites

### Required Permissions
- **Global Administrator** or **Intune Administrator** role
- **Device enrollment manager** permissions
- Access to Azure AD and Microsoft Intune

### Required Licenses
- Microsoft Intune license
- Azure AD Premium P1 or P2
- Windows 10/11 Pro or Enterprise

### PowerShell Modules
These are automatically installed with HVTools:
- Microsoft.Graph.Authentication
- Microsoft.Graph.DeviceManagement
- WindowsAutoPilotIntune

## Initial Setup

### Step 1: Configure Autopilot Profile in Intune

1. Sign in to [Microsoft Endpoint Manager](https://endpoint.microsoft.com)
2. Navigate to **Devices** > **Windows** > **Windows enrollment**
3. Select **Deployment Profiles**
4. Create a new Autopilot profile with your desired settings

### Step 2: Note Your Profile Details

You'll need:
- Tenant ID
- Admin UPN (User Principal Name)
- Autopilot profile name (optional)

### Step 3: Add Tenant to HVTools

```powershell
# Add tenant with Autopilot-enabled admin
Add-TenantToConfig -TenantName "Contoso" `
                   -AdminUpn "admin@contoso.onmicrosoft.com" `
                   -ImageName "Win11"
```

## Creating Autopilot-Enabled VMs

### Basic Autopilot VM Creation

```powershell
# Creates VMs with Autopilot profile injected
New-ClientVM -TenantName "Contoso" `
             -NumberOfVMs 5 `
             -CPUsPerVM 2 `
             -VMMemory 4GB
```

### First-Time Authentication

On first run, you'll be prompted to authenticate:

1. A browser window will open
2. Sign in with your admin credentials
3. Grant consent for required permissions
4. Return to PowerShell

The authentication token is cached for future use.

### Verify Autopilot Configuration

```powershell
# Check if Autopilot config was fetched
$config = Get-HVToolsConfig
$tenantPath = ($config.tenantConfig | Where-Object {$_.TenantName -eq "Contoso"}).pathToConfig
Get-ChildItem "$tenantPath\AutoPilotConfigurationFile.json"
```

## Advanced Autopilot Scenarios

### Multiple Autopilot Profiles

If you have multiple Autopilot profiles:

```powershell
# The module will prompt you to select a profile
# Or it will use the default profile automatically
```

### Refresh Autopilot Configuration

To get the latest profile from Intune:

```powershell
# Delete cached configuration
$config = Get-HVToolsConfig
$tenantPath = ($config.tenantConfig | Where-Object {$_.TenantName -eq "Contoso"}).pathToConfig
Remove-Item "$tenantPath\AutoPilotConfigurationFile.json" -Force

# Next VM creation will fetch fresh config
New-ClientVM -TenantName "Contoso" -NumberOfVMs 1 -CPUsPerVM 2
```

### Skip Autopilot for Specific VMs

```powershell
# Create VMs without Autopilot
New-ClientVM -TenantName "Contoso" `
             -NumberOfVMs 2 `
             -CPUsPerVM 2 `
             -SkipAutoPilot
```

## Understanding the Autopilot Process

### What Happens During VM Creation

1. **Profile Fetch**: HVTools connects to Intune and downloads the Autopilot profile
2. **Profile Cache**: The profile is saved locally for reuse
3. **Profile Injection**: During VM creation, the profile is injected into the VHDX
4. **First Boot**: When the VM starts, it reads the profile and begins Autopilot enrollment

### File Locations

```powershell
# Autopilot configuration is stored at:
C:\HVTools\<TenantName>\AutoPilotConfigurationFile.json

# Inside each VM, the file is placed at:
C:\Windows\Provisioning\Autopilot\AutoPilotConfigurationFile.json
```

### Profile Structure

```json
{
  "CloudAssignedTenantId": "00000000-0000-0000-0000-000000000000",
  "CloudAssignedDeviceName": "",
  "CloudAssignedOobeConfig": 1310,
  "CloudAssignedDomainJoinMethod": 0,
  "CloudAssignedTenantDomain": "contoso.onmicrosoft.com",
  "IsDevicePersonalizationAllowed": false,
  "IsLocalUserCreationAllowed": true,
  "ZtdCorrelationId": "00000000-0000-0000-0000-000000000000"
}
```

## Troubleshooting Autopilot Issues

### Authentication Failures

```powershell
# Clear cached credentials
Disconnect-MgGraph

# Re-authenticate
Connect-MgGraph -Scopes "DeviceManagementServiceConfig.Read.All"

# Test connection
Get-MgDeviceManagementWindowAutopilotDeploymentProfile
```

### Profile Not Found

```powershell
# List all Autopilot profiles
Connect-MgGraph -Scopes "DeviceManagementServiceConfig.Read.All"
Get-MgDeviceManagementWindowAutopilotDeploymentProfile | Select-Object DisplayName, Id
```

### Profile Not Applying

1. Check the JSON file was created:
```powershell
# Mount the VHDX
$vhdx = "C:\HVTools\VMs\Contoso\VM001\VM001.vhdx"
Mount-VHD -Path $vhdx -Passthru
# Check in mounted drive under Windows\Provisioning\Autopilot\
# Dismount when done
Dismount-VHD -Path $vhdx
```

2. Verify profile content:
```powershell
# Check cached profile
$config = Get-HVToolsConfig
$tenantPath = ($config.tenantConfig | Where-Object {$_.TenantName -eq "Contoso"}).pathToConfig
Get-Content "$tenantPath\AutoPilotConfigurationFile.json" | ConvertFrom-Json
```

### VM Not Enrolling

Common causes:
- No internet connectivity in VM
- DNS resolution issues
- Firewall blocking required endpoints
- Time sync issues

Required endpoints:
- `*.microsoftonline.com`
- `*.windows.net`
- `*.manage.microsoft.com`
- `*.windowsupdate.com`

## Best Practices

### Security

1. **Use Dedicated Admin Account**: Create a service account for Autopilot operations
2. **Limit Permissions**: Grant only required Graph API permissions
3. **Rotate Credentials**: Regularly update admin passwords
4. **Audit Access**: Monitor who creates Autopilot-enabled VMs

### Performance

1. **Cache Profiles**: Let HVTools cache profiles to reduce API calls
2. **Batch Operations**: Create multiple VMs in one command
3. **Network Optimization**: Ensure VMs have fast internet for enrollment

### Testing

1. **Test Profile First**: Create one VM and verify Autopilot works
2. **Monitor Enrollment**: Watch the OOBE process on first VM
3. **Check Intune**: Verify devices appear in Intune portal
4. **Document Settings**: Keep notes on working configurations

## Integration with Intune Policies

### Pre-configured Policies

VMs created with Autopilot will automatically receive:
- Device configuration profiles
- Compliance policies  
- Application deployments
- Update rings
- Security baselines

### Testing Policy Application

```powershell
# Create test VM
New-ClientVM -TenantName "Contoso" -NumberOfVMs 1 -CPUsPerVM 2

# Start VM and monitor:
# 1. Autopilot enrollment
# 2. Azure AD join
# 3. Policy application
# 4. App installation
```

## Automation Scenarios

### Bulk Testing

```powershell
# Create VMs for different test scenarios
$scenarios = @(
    @{Name="BasicUsers"; Count=5},
    @{Name="PowerUsers"; Count=3},
    @{Name="Developers"; Count=2}
)

foreach ($scenario in $scenarios) {
    New-ClientVM -TenantName "Contoso" `
                 -NumberOfVMs $scenario.Count `
                 -CPUsPerVM 2 `
                 -VMMemory 4GB
    
    # Tag VMs in Intune for different policies
    # (Manual step or use Graph API)
}
```

### Scheduled VM Creation

```powershell
# Create a scheduled task for nightly VM refresh
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument '-Command "Import-Module HVTools; New-ClientVM -TenantName Contoso -NumberOfVMs 10 -CPUsPerVM 2"'

$trigger = New-ScheduledTaskTrigger -Daily -At 2am

Register-ScheduledTask -TaskName "HVTools-Nightly-VMs" `
                       -Action $action `
                       -Trigger $trigger `
                       -RunLevel Highest
```

## Frequently Asked Questions

### Q: Can I use multiple Autopilot profiles?
A: Yes, HVTools will prompt you to select if multiple profiles exist.

### Q: How often should I refresh the cached profile?
A: Whenever you make changes to the Autopilot profile in Intune.

### Q: Can I use Autopilot with Azure AD Hybrid Join?
A: Yes, ensure your Autopilot profile is configured for Hybrid Join and VMs can reach your domain controllers.

### Q: What happens if Autopilot fails?
A: The VM will show the standard Windows OOBE. Check network connectivity and profile configuration.

### Q: Can I pre-assign devices to users?
A: Not with HVTools-generated VMs, as they don't have real hardware hashes. Use dynamic groups instead.

## Additional Resources

- [Windows Autopilot documentation](https://docs.microsoft.com/en-us/mem/autopilot/)
- [Intune enrollment options](https://docs.microsoft.com/en-us/mem/intune/enrollment/)
- [Graph API reference](https://docs.microsoft.com/en-us/graph/api/resources/intune-graph-overview)
- [HVTools GitHub repository](https://github.com/adamgell/HVTools)