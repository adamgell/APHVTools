# APHVTools Quick Start Guide

This guide will help you get up and running with APHVTools in under 10 minutes.

## Prerequisites

Before starting, ensure you have:
- ✅ Windows 10/11 Pro or Enterprise (with Hyper-V enabled)
- ✅ PowerShell 5.1 or higher
- ✅ Administrator privileges
- ✅ At least 50GB free disk space
- ✅ A Windows ISO file
- ✅ Microsoft Intune admin access (optional, for Autopilot)

## Step 1: Install APHVTools

Open PowerShell as Administrator and run:

```powershell
# Install from PowerShell Gallery
Install-Module -Name HVTools -Scope CurrentUser -Force

# Import the module
Import-Module HVTools
```

## Step 2: Initialize Your Workspace

Create a workspace where VMs and configurations will be stored:

```powershell
# Create and initialize workspace
Initialize-HVTools -Path "C:\HVTools"
```

This creates:
- `C:\APHVTools\VMs` - Where your VMs will be stored
- `C:\APHVTools\ReferenceVHDX` - Where base images are kept
- Configuration file at `$env:USERPROFILE\.hvtoolscfgpath`

## Step 3: Add a Windows Image

Add your Windows ISO to create a reference image:

```powershell
# Add Windows 11 image
Add-ImageToConfig -ImageName "Win11" -IsoPath "C:\ISOs\Win11_23H2.iso"
```

**Note**: You'll be prompted to select the Windows edition (Pro, Enterprise, etc.)

## Step 4: Configure Network

Set up the virtual network for your VMs:

```powershell
# Use the default Hyper-V switch
Add-NetworkToConfig -VSwitchName "Default Switch"
```

## Step 5: Add a Tenant (Organization)

Configure at least one tenant:

```powershell
# Add a tenant configuration
Add-TenantToConfig -TenantName "MyCompany" `
                   -AdminUpn "admin@mycompany.com" `
                   -ImageName "Win11"
```

## Step 6: Create Your First VM

Now create a VM:

```powershell
# Create a single VM with 2 CPUs and 4GB RAM
New-ClientVM -TenantName "MyCompany" `
             -NumberOfVMs 1 `
             -CPUsPerVM 2 `
             -VMMemory 4GB
```

## Complete Example Script

Here's everything in one script:

```powershell
# 1. Install and import module
Install-Module -Name APHVTools -Scope CurrentUser -Force
Import-Module APHVTools

# 2. Initialize workspace
Initialize-APHVTools -Path "C:\APHVTools"

# 3. Add Windows image
Add-ImageToConfig -ImageName "Win11" -IsoPath "C:\ISOs\Win11_23H2.iso"

# 4. Configure network
Add-NetworkToConfig -VSwitchName "Default Switch"

# 5. Add tenant
Add-TenantToConfig -TenantName "MyCompany" `
                   -AdminUpn "admin@mycompany.com" `
                   -ImageName "Win11"

# 6. Create VMs
New-ClientVM -TenantName "MyCompany" `
             -NumberOfVMs 3 `
             -CPUsPerVM 2 `
             -VMMemory 4GB
```

## What's Next?

### Connect to Your VMs
1. Open Hyper-V Manager
2. Find VMs named like `HVTOOLS-MYCOMPANY-001`
3. Double-click to connect
4. Start the VM

### Create More VMs
```powershell
# Create 5 more VMs
New-ClientVM -TenantName "MyCompany" -NumberOfVMs 5 -CPUsPerVM 2

# Create VMs without Autopilot
New-ClientVM -TenantName "MyCompany" -NumberOfVMs 2 -CPUsPerVM 2 -SkipAutoPilot
```

### Add More Images
```powershell
# Add Windows 10
Add-ImageToConfig -ImageName "Win10" -IsoPath "C:\ISOs\Win10_22H2.iso"

# Use specific image for VMs
New-ClientVM -TenantName "MyCompany" -OSBuild "Win10" -NumberOfVMs 1 -CPUsPerVM 2
```

### Add More Tenants
```powershell
# Add another company
Add-TenantToConfig -TenantName "Contoso" `
                   -AdminUpn "admin@contoso.com" `
                   -ImageName "Win11"

# Create VMs for new tenant
New-ClientVM -TenantName "Contoso" -NumberOfVMs 3 -CPUsPerVM 2
```

## Tips for Success

1. **Start Small**: Create 1-2 VMs first to test your setup
2. **Check Resources**: Monitor disk space and RAM usage
3. **Use Verbose**: Add `-Verbose` to commands for detailed output
4. **Plan Names**: Use meaningful tenant names for organization
5. **Document Settings**: Keep track of your image names and configurations

## Common Issues

### "Hyper-V not found"
Enable Hyper-V feature:
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
```

### "Access Denied"
Run PowerShell as Administrator

### "Module not found"
```powershell
# Check if module is installed
Get-Module -ListAvailable HVTools

# If not found, reinstall
Install-Module HVTools -Force
```

## Getting Help

```powershell
# Get help for any command
Get-Help New-ClientVM -Full
Get-Help Initialize-HVTools -Examples

# View your configuration
Get-HVToolsConfig

# Check module version
Get-Module HVTools | Select-Object Version
```

## Next Steps

- Read the [full documentation](../README.md)
- Learn about [advanced features](./ADVANCED-USAGE.md)
- Set up [Autopilot integration](./AUTOPILOT-SETUP.md)
- Explore [troubleshooting tips](./TROUBLESHOOTING.md)

Happy VM creating! 🚀