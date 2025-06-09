<#
.SYNOPSIS
    Debug script to help identify why Get-MountedVMDisk is not detecting all mounted VHDs

.DESCRIPTION
    This script provides detailed diagnostics for VHD detection issues, specifically
    for cases where differencing disks (.avhdx) are not being detected properly.

.EXAMPLE
    .\Debug-VHDDetection.ps1
#>

Write-Host "VHD Detection Debug Script" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

# Import HVTools module if available
try {
    Import-Module ./HVTools/HVTools.psd1 -Force -ErrorAction Stop
    Write-Host "HVTools module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "Warning: Could not import HVTools module: $_" -ForegroundColor Yellow
}

Write-Host "`n1. Testing Get-VHD directly..." -ForegroundColor Yellow
try {
    # Method 1: Get all VHDs using Get-VHD
    $allVHDs = Get-VHD -ErrorAction Stop
    Write-Host "Total VHDs found: $($allVHDs.Count)" -ForegroundColor Green
    
    $attachedVHDs = $allVHDs | Where-Object { $_.Attached -eq $true }
    Write-Host "Attached VHDs: $($attachedVHDs.Count)" -ForegroundColor Green
    
    if ($attachedVHDs) {
        Write-Host "`nAttached VHD Details:" -ForegroundColor Cyan
        foreach ($vhd in $attachedVHDs) {
            Write-Host "  Path: $($vhd.Path)" -ForegroundColor White
            Write-Host "  Type: $($vhd.VhdType)" -ForegroundColor White
            Write-Host "  Disk Number: $($vhd.DiskNumber)" -ForegroundColor White
            Write-Host "  Parent Path: $($vhd.ParentPath)" -ForegroundColor White
            Write-Host "  Size: $([math]::Round($vhd.Size / 1GB, 2)) GB" -ForegroundColor White
            Write-Host "  ---" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "Error using Get-VHD: $_" -ForegroundColor Red
}

Write-Host "`n2. Testing disk enumeration..." -ForegroundColor Yellow
try {
    $allDisks = Get-Disk
    Write-Host "Total disks found: $($allDisks.Count)" -ForegroundColor Green
    
    # Look for disks with VHD-like properties
    $potentialVHDs = @()
    
    foreach ($disk in $allDisks) {
        $reasons = @()
        
        # Check various properties that might indicate a VHD
        if ($disk.Location -like "*.vhd*" -or $disk.Location -like "*.avhd*") {
            $reasons += "Location matches VHD pattern"
        }
        
        if ($disk.BusType -eq 'File Backed Virtual') {
            $reasons += "BusType is File Backed Virtual"
        }
        
        if ($disk.FriendlyName -like "*Virtual*" -or $disk.Model -like "*Virtual*") {
            $reasons += "Name/Model contains 'Virtual'"
        }
        
        if ($reasons.Count -gt 0) {
            $potentialVHDs += [PSCustomObject]@{
                DiskNumber = $disk.Number
                Location = $disk.Location
                BusType = $disk.BusType
                FriendlyName = $disk.FriendlyName
                Model = $disk.Model
                Size = [math]::Round($disk.Size / 1GB, 2)
                Reasons = $reasons -join ', '
            }
        }
    }
    
    if ($potentialVHDs) {
        Write-Host "`nPotential VHD Disks found: $($potentialVHDs.Count)" -ForegroundColor Green
        
        $potentialVHDs | Format-Table -AutoSize -Property @(
            @{Label="Disk#"; Expression={$_.DiskNumber}},
            @{Label="Size(GB)"; Expression={$_.Size}},
            @{Label="BusType"; Expression={$_.BusType}},
            @{Label="Location"; Expression={if($_.Location) {$_.Location} else {"<empty>"}}},
            @{Label="Detection Reasons"; Expression={$_.Reasons}}
        )
        
        # Now test Get-VHD on each potential disk
        Write-Host "`nTesting Get-VHD on potential VHD disks:" -ForegroundColor Cyan
        foreach ($disk in $potentialVHDs) {
            try {
                $vhdInfo = Get-VHD -DiskNumber $disk.DiskNumber -ErrorAction Stop
                Write-Host "  Disk $($disk.DiskNumber): SUCCESS - $($vhdInfo.Path)" -ForegroundColor Green
                Write-Host "    Type: $($vhdInfo.VhdType), Attached: $($vhdInfo.Attached)" -ForegroundColor White
            } catch {
                Write-Host "  Disk $($disk.DiskNumber): FAILED - $_" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "No potential VHD disks found through disk enumeration" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "Error during disk enumeration: $_" -ForegroundColor Red
}

Write-Host "`n3. Testing current Get-MountedVMDisk function..." -ForegroundColor Yellow
try {
    if (Get-Command Get-MountedVMDisk -ErrorAction SilentlyContinue) {
        Write-Host "Running Get-MountedVMDisk -Verbose..." -ForegroundColor White
        $result = Get-MountedVMDisk -Verbose
        if ($result) {
            Write-Host "Function returned $($result.Count) mounted disk(s)" -ForegroundColor Green
        } else {
            Write-Host "Function returned no results" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Get-MountedVMDisk function not available" -ForegroundColor Red
    }
} catch {
    Write-Host "Error testing Get-MountedVMDisk: $_" -ForegroundColor Red
}

Write-Host "`n4. Specific checks for the mentioned VMs..." -ForegroundColor Yellow
$expectedPaths = @(
    "F:\CMLAB_Copy\PC0002\PC0002-Disk1.vhdx",
    "F:\CMLAB_Copy\PC0003\PC0003-Disk1_3A32BF93-395B-4B6A-BE17-A54E28F47A7E.avhdx",
    "F:\CMLAB_Copy\PC0004\PC0004-Disk1_4DB90350-7468-4047-99CF-ECBDC9A75B7F.avhdx"
)

foreach ($path in $expectedPaths) {
    Write-Host "`nChecking: $path" -ForegroundColor White
    
    # Check if file exists
    if (Test-Path $path) {
        Write-Host "  File exists: YES" -ForegroundColor Green
        
        # Try to get VHD info directly by path
        try {
            $vhdInfo = Get-VHD -Path $path -ErrorAction Stop
            Write-Host "  Get-VHD by path: SUCCESS" -ForegroundColor Green
            Write-Host "    Attached: $($vhdInfo.Attached)" -ForegroundColor White
            Write-Host "    Disk Number: $($vhdInfo.DiskNumber)" -ForegroundColor White
            Write-Host "    Type: $($vhdInfo.VhdType)" -ForegroundColor White
        } catch {
            Write-Host "  Get-VHD by path: FAILED - $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  File exists: NO" -ForegroundColor Red
    }
}

Write-Host "`nDebug completed." -ForegroundColor Cyan