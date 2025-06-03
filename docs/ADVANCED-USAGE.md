# Advanced Usage Guide

This guide covers advanced scenarios and techniques for power users of HVTools.

## Advanced VM Configurations

### Dynamic VM Sizing

Create VMs with different specifications based on use cases:

```powershell
# Development VMs - High CPU, moderate RAM
$devVMs = @{
    TenantName = "DevTeam"
    NumberOfVMs = 5
    CPUsPerVM = 4
    VMMemory = 8GB
}
New-ClientVM @devVMs

# Testing VMs - Minimal resources
$testVMs = @{
    TenantName = "QATeam"
    NumberOfVMs = 10
    CPUsPerVM = 1
    VMMemory = 2GB
}
New-ClientVM @testVMs

# Power User VMs - Maximum resources
$powerVMs = @{
    TenantName = "PowerUsers"
    NumberOfVMs = 2
    CPUsPerVM = 8
    VMMemory = 16GB
}
New-ClientVM @powerVMs
```

### Custom VM Naming Patterns

Modify VM names using PowerShell after creation:

```powershell
# Get created VMs
$vms = Get-VM -Name "HVTOOLS-DEVTEAM-*"

# Rename with custom pattern
$counter = 1
foreach ($vm in $vms) {
    $newName = "DEV-WIN11-{0:D3}" -f $counter
    Rename-VM -VM $vm -NewName $newName
    $counter++
}
```

### Advanced Disk Configurations

```powershell
# Create VMs with additional data disks
$vmName = "HVTOOLS-STORAGE-001"
New-ClientVM -TenantName "Storage" -NumberOfVMs 1 -CPUsPerVM 2

# Add data disk
$vm = Get-VM -Name $vmName
$dataVHDX = "C:\HVTools\VMs\Storage\$vmName-Data.vhdx"
New-VHD -Path $dataVHDX -SizeBytes 100GB -Dynamic
Add-VMHardDiskDrive -VMName $vmName -Path $dataVHDX
```

## Bulk Operations and Automation

### Parallel VM Creation

Create multiple batches of VMs in parallel:

```powershell
# Define batches
$batches = @(
    @{Tenant="Sales"; Count=10},
    @{Tenant="Marketing"; Count=5},
    @{Tenant="IT"; Count=15}
)

# Create jobs for parallel execution
$jobs = foreach ($batch in $batches) {
    Start-Job -ScriptBlock {
        param($tenant, $count)
        Import-Module HVTools
        New-ClientVM -TenantName $tenant -NumberOfVMs $count -CPUsPerVM 2
    } -ArgumentList $batch.Tenant, $batch.Count
}

# Wait for completion
$jobs | Wait-Job | Receive-Job
$jobs | Remove-Job
```

### Scheduled VM Lifecycle Management

```powershell
# Script to refresh test VMs weekly
$refreshScript = @'
Import-Module HVTools

# Remove old VMs
$oldVMs = Get-VM -Name "HVTOOLS-TEST-*" | Where-Object {$_.CreationTime -lt (Get-Date).AddDays(-7)}
$oldVMs | Stop-VM -Force -Passthru | Remove-VM -Force

# Remove old VHDXs
$config = Get-HVToolsConfig
Get-ChildItem -Path "$($config.vmPath)\Test" -Filter "*.vhdx" | 
    Where-Object {$_.CreationTime -lt (Get-Date).AddDays(-7)} | 
    Remove-Item -Force

# Create fresh VMs
New-ClientVM -TenantName "Test" -NumberOfVMs 10 -CPUsPerVM 2
'@

# Save and schedule
$refreshScript | Out-File "C:\Scripts\RefreshTestVMs.ps1"

# Create scheduled task
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File C:\Scripts\RefreshTestVMs.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2am
Register-ScheduledTask -TaskName "HVTools-Weekly-Refresh" -Action $action -Trigger $trigger
```

## Custom Image Management

### Creating Specialized Images

Build custom reference images with pre-installed software:

```powershell
# 1. Create base VM
New-ClientVM -TenantName "ImagePrep" -NumberOfVMs 1 -CPUsPerVM 4 -SkipAutoPilot

# 2. Start and customize VM
$vm = Get-VM -Name "HVTOOLS-IMAGEPREP-001"
Start-VM -VM $vm

# 3. Install software, configure settings, etc.
# ... (manual process) ...

# 4. Sysprep the VM
# Inside VM: C:\Windows\System32\Sysprep\sysprep.exe /oobe /generalize /shutdown

# 5. Wait for shutdown
while ($vm.State -ne 'Off') { Start-Sleep -Seconds 5 }

# 6. Convert to reference image
$source = $vm.HardDrives[0].Path
$destination = "C:\HVTools\ReferenceVHDX\Win11-Custom.vhdx"
Convert-VHD -Path $source -DestinationPath $destination -VHDType Dynamic

# 7. Add to configuration
Add-ImageToConfig -ImageName "Win11-Custom" -ReferenceVHDX $destination
```

### Image Versioning Strategy

```powershell
# Maintain multiple versions
$imageVersions = @(
    @{Name="Win11-23H2-v1"; Path="C:\Images\Win11-23H2-v1.vhdx"},
    @{Name="Win11-23H2-v2"; Path="C:\Images\Win11-23H2-v2.vhdx"},
    @{Name="Win11-23H2-Latest"; Path="C:\Images\Win11-23H2-v2.vhdx"}
)

foreach ($image in $imageVersions) {
    Add-ImageToConfig -ImageName $image.Name -ReferenceVHDX $image.Path
}
```

## Network Isolation and Security

### VLAN-based Isolation

```powershell
# Create isolated networks for different tenants
$networks = @(
    @{Tenant="ProdTest"; VLAN=100},
    @{Tenant="DevTest"; VLAN=200},
    @{Tenant="Security"; VLAN=300}
)

foreach ($net in $networks) {
    # Update network config
    Add-NetworkToConfig -VSwitchName "External Switch" -VlanId $net.VLAN
    
    # Create VMs in isolated network
    New-ClientVM -TenantName $net.Tenant -NumberOfVMs 5 -CPUsPerVM 2
}
```

### Private Virtual Switches

```powershell
# Create private switch for isolated testing
New-VMSwitch -Name "IsolatedTest" -SwitchType Private

# Configure HVTools to use it
Add-NetworkToConfig -VSwitchName "IsolatedTest"

# Create isolated VMs
New-ClientVM -TenantName "SecurityTest" -NumberOfVMs 3 -CPUsPerVM 2
```

## Performance Optimization

### Storage Optimization

```powershell
# Pre-expand reference VHDX for better performance
$ref = "C:\HVTools\ReferenceVHDX\Win11.vhdx"
Optimize-VHD -Path $ref -Mode Full

# Use fixed-size VHDXs for production-like testing
$fixedRef = "C:\HVTools\ReferenceVHDX\Win11-Fixed.vhdx"
Convert-VHD -Path $ref -DestinationPath $fixedRef -VHDType Fixed
```

### Memory Optimization

```powershell
# Configure dynamic memory for VMs
$vms = Get-VM -Name "HVTOOLS-*"
foreach ($vm in $vms) {
    Set-VM -VM $vm `
           -DynamicMemory `
           -MemoryStartupBytes 2GB `
           -MemoryMinimumBytes 1GB `
           -MemoryMaximumBytes 8GB
}
```

### CPU Optimization

```powershell
# Set CPU resource controls
$vms = Get-VM -Name "HVTOOLS-*"
foreach ($vm in $vms) {
    Set-VMProcessor -VM $vm `
                    -Maximum 100 `
                    -Reserve 10 `
                    -RelativeWeight 100
}
```

## Integration with External Systems

### Export VM Information

```powershell
# Export VM inventory to CSV
$inventory = Get-VM -Name "HVTOOLS-*" | Select-Object `
    Name,
    State,
    CPUUsage,
    MemoryAssigned,
    Uptime,
    CreationTime,
    @{N='Tenant';E={$_.Name -replace 'HVTOOLS-(\w+)-\d+','$1'}}

$inventory | Export-Csv -Path "C:\Reports\HVTools-Inventory.csv" -NoTypeInformation
```

### Integration with Monitoring

```powershell
# Send VM metrics to monitoring system
function Send-VMMetrics {
    $vms = Get-VM -Name "HVTOOLS-*"
    foreach ($vm in $vms) {
        $metrics = @{
            VMName = $vm.Name
            State = $vm.State
            CPUUsage = $vm.CPUUsage
            MemoryMB = $vm.MemoryAssigned / 1MB
            UptimeHours = $vm.Uptime.TotalHours
        }
        
        # Send to monitoring API
        Invoke-RestMethod -Uri "https://monitoring.company.com/api/metrics" `
                          -Method Post `
                          -Body ($metrics | ConvertTo-Json) `
                          -ContentType "application/json"
    }
}
```

### PowerShell Remoting to VMs

```powershell
# Enable PSRemoting on VMs
$vms = Get-VM -Name "HVTOOLS-*" | Where-Object {$_.State -eq 'Running'}
foreach ($vm in $vms) {
    # Get VM IP address
    $ip = (Get-VMNetworkAdapter -VM $vm).IPAddresses | 
          Where-Object {$_ -match '\d+\.\d+\.\d+\.\d+'} | 
          Select-Object -First 1
    
    if ($ip) {
        # Configure VM for remoting
        Invoke-Command -ComputerName $ip -Credential (Get-Credential) -ScriptBlock {
            Enable-PSRemoting -Force
            Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
        }
    }
}
```

## Custom Module Extensions

### Creating Helper Functions

```powershell
# Save as C:\HVTools\Extensions\HVToolsHelpers.psm1
function Get-HVToolsVMInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TenantName
    )
    
    $vms = Get-VM -Name "HVTOOLS-$TenantName-*"
    foreach ($vm in $vms) {
        [PSCustomObject]@{
            Name = $vm.Name
            Tenant = $TenantName
            State = $vm.State
            CPUs = $vm.ProcessorCount
            MemoryGB = [math]::Round($vm.MemoryAssigned / 1GB, 2)
            CreatedDate = $vm.CreationTime
            Uptime = $vm.Uptime
            IPAddress = (Get-VMNetworkAdapter -VM $vm).IPAddresses -join ", "
        }
    }
}

function Remove-HVToolsTenant {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TenantName,
        [switch]$Force
    )
    
    if (-not $Force) {
        $confirm = Read-Host "Remove all VMs and data for tenant '$TenantName'? (yes/no)"
        if ($confirm -ne 'yes') { return }
    }
    
    # Remove VMs
    Get-VM -Name "HVTOOLS-$TenantName-*" | 
        Stop-VM -Force -Passthru | 
        Remove-VM -Force
    
    # Remove files
    $config = Get-HVToolsConfig
    $tenantPath = "$($config.vmPath)\$TenantName"
    if (Test-Path $tenantPath) {
        Remove-Item $tenantPath -Recurse -Force
    }
    
    Write-Host "Tenant '$TenantName' removed successfully" -ForegroundColor Green
}

Export-ModuleMember -Function Get-HVToolsVMInfo, Remove-HVToolsTenant
```

### Loading Extensions

```powershell
# In your PowerShell profile
Import-Module HVTools
Import-Module C:\HVTools\Extensions\HVToolsHelpers.psm1

# Now use extended functions
Get-HVToolsVMInfo -TenantName "Contoso" | Format-Table
Remove-HVToolsTenant -TenantName "OldClient" -Force
```

## Troubleshooting Tools Integration

### Advanced Diagnostics Package

```powershell
# Create comprehensive diagnostics package
$diagPath = "C:\HVTools\DiagnosticTools"
New-Item -Path $diagPath -ItemType Directory -Force

# Download Sysinternals Suite
Invoke-WebRequest -Uri "https://download.sysinternals.com/files/SysinternalsSuite.zip" `
                  -OutFile "$diagPath\SysinternalsSuite.zip"
Expand-Archive -Path "$diagPath\SysinternalsSuite.zip" -DestinationPath $diagPath

# Add custom scripts
@'
# Diagnostic script
Write-Host "System Diagnostics" -ForegroundColor Green
Get-ComputerInfo | Select-Object CsName, WindowsVersion, OsBuildNumber
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10
Get-EventLog -LogName System -Newest 10 -EntryType Error
'@ | Out-File "$diagPath\RunDiagnostics.ps1"

# Configure in HVTools
Add-ToolsToConfig -ToolsPath $diagPath

# Create VMs with full diagnostic suite
New-ClientVM -TenantName "Support" -NumberOfVMs 2 -CPUsPerVM 2 -IncludeTools
```

## Best Practices for Advanced Usage

1. **Resource Planning**: Calculate total resource requirements before bulk operations
2. **Naming Conventions**: Establish clear naming patterns for different VM types
3. **Documentation**: Document custom configurations and scripts
4. **Backup Strategy**: Regular backup of configuration and reference images
5. **Security**: Implement network isolation for sensitive testing
6. **Monitoring**: Set up alerts for resource exhaustion
7. **Automation**: Use scheduled tasks for routine maintenance
8. **Version Control**: Track custom scripts and configurations in Git

## Next Steps

- Explore [PowerShell DSC](https://docs.microsoft.com/en-us/powershell/dsc/overview) for VM configuration
- Integrate with [Azure DevOps](https://azure.microsoft.com/en-us/services/devops/) for CI/CD
- Consider [Windows Admin Center](https://www.microsoft.com/en-us/windows-server/windows-admin-center) for management
- Learn about [Hyper-V Replica](https://docs.microsoft.com/en-us/windows-server/virtualization/hyper-v/manage/set-up-hyper-v-replica) for DR scenarios