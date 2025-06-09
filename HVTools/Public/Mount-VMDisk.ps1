function Mount-VMDisk {
    <#
    .SYNOPSIS
        Mounts a VM's disk for access from the host system
    .DESCRIPTION
        Mounts a VM's VHDX disk file and returns the drive letter where it was mounted.
        The VM must be stopped before mounting its disk.
    .PARAMETER VMName
        Name of the VM whose disk should be mounted
    .PARAMETER DiskNumber
        The disk number to mount (default is 0 for the primary disk)
    .EXAMPLE
        Mount-VMDisk -VMName "Client01"
        Mounts the primary disk of VM "Client01" and returns the drive letter
    .EXAMPLE
        Mount-VMDisk -VMName "Client01" -DiskNumber 1
        Mounts the second disk of VM "Client01"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName,
        
        [Parameter(Mandatory = $false)]
        [int]$DiskNumber = 0
    )
    
    try {
        Write-Verbose "Attempting to mount disk for VM: $VMName"
        
        # Get the VM
        $vm = Get-VM -Name $VMName -ErrorAction Stop
        
        # Check if VM is running
        if ($vm.State -ne 'Off') {
            throw "VM '$VMName' must be stopped before mounting its disk. Current state: $($vm.State)"
        }
        
        # Get the VM's hard drives
        $vmHardDrives = Get-VMHardDiskDrive -VM $vm
        
        if (-not $vmHardDrives) {
            throw "No hard drives found for VM '$VMName'"
        }
        
        if ($DiskNumber -ge $vmHardDrives.Count) {
            throw "Disk number $DiskNumber not found. VM has $($vmHardDrives.Count) disk(s)"
        }
        
        $vhdxPath = $vmHardDrives[$DiskNumber].Path
        
        if (-not (Test-Path -Path $vhdxPath)) {
            throw "VHDX file not found at path: $vhdxPath"
        }
        
        Write-Verbose "Mounting VHDX: $vhdxPath"
        
        if ($PSCmdlet.ShouldProcess($vhdxPath, "Mount VHDX")) {
            # Mount the VHDX and get the drive letter
            $mountedDisk = Mount-VHD -Path $vhdxPath -Passthru -ErrorAction Stop
            
            # Get the drive letter of the mounted disk
            $driveLetter = $mountedDisk |
                Get-Disk |
                Get-Partition |
                Where-Object { $_.Type -eq 'Basic' -and $_.DriveLetter } |
                Select-Object -First 1 -ExpandProperty DriveLetter
            
            if (-not $driveLetter) {
                # If no drive letter found, try to get any partition with a drive letter
                $driveLetter = $mountedDisk |
                    Get-Disk |
                    Get-Partition |
                    Where-Object { $_.DriveLetter } |
                    Select-Object -First 1 -ExpandProperty DriveLetter
            }
            
            if ($driveLetter) {
                Write-Host "VHDX mounted successfully at drive $driveLetter`:" -ForegroundColor Green
                
                # Return an object with mount information
                [PSCustomObject]@{
                    VMName      = $VMName
                    VHDXPath    = $vhdxPath
                    DriveLetter = $driveLetter
                    DiskNumber  = $mountedDisk.DiskNumber
                    MountTime   = Get-Date
                }
            }
            else {
                Write-Warning "VHDX mounted but no drive letter assigned"
                
                # Return mount info without drive letter
                [PSCustomObject]@{
                    VMName      = $VMName
                    VHDXPath    = $vhdxPath
                    DriveLetter = $null
                    DiskNumber  = $mountedDisk.DiskNumber
                    MountTime   = Get-Date
                }
            }
        }
    }
    catch {
        Write-Error "Error mounting VM disk: $_"
        throw
    }
}