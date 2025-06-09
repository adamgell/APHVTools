function Get-MountedVMDisk-Alternative {
    <#
    .SYNOPSIS
        Alternative implementation that uses more robust VHD detection
    .DESCRIPTION
        This version tries multiple methods to detect mounted VHDs, particularly
        focusing on cases where differencing disks (.avhdx) might not be detected
        by the standard Location property filtering.
    .PARAMETER ShowMenu
        If specified, displays an interactive menu to dismount selected disks
    .EXAMPLE
        Get-MountedVMDisk-Alternative
        Lists all currently mounted VHDX files using robust detection
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$ShowMenu
    )
    
    try {
        Write-Verbose "Checking for mounted VHD files using alternative method"
        
        $mountedDisks = @()
        
        # Method 1: Try to enumerate all VHDs and filter for attached ones
        # This is the most reliable method when it works
        try {
            Write-Verbose "Method 1: Using Get-VHD to enumerate all VHDs"
            
            # Get all VHDs in the system
            $allVHDs = @()
            
            # Try without parameters first (gets all VHDs)
            try {
                $allVHDs = Get-VHD -ErrorAction Stop
                Write-Verbose "Found $($allVHDs.Count) total VHDs in system"
            }
            catch {
                Write-Verbose "Get-VHD failed: $_"
                # If that fails, we'll try the disk enumeration method
                throw $_
            }
            
            # Filter for attached VHDs
            $attachedVHDs = $allVHDs | Where-Object { $_.Attached -eq $true }
            
            if ($attachedVHDs) {
                Write-Verbose "Found $($attachedVHDs.Count) attached VHDs"
                $mountedDisks = $attachedVHDs
            }
            else {
                Write-Verbose "No attached VHDs found via Get-VHD"
            }
        }
        catch {
            Write-Verbose "Method 1 failed, trying disk enumeration: $_"
            
            # Method 2: Enumerate disks and test each one
            try {
                Write-Verbose "Method 2: Enumerating all disks and testing for VHD properties"
                
                $allDisks = Get-Disk
                Write-Verbose "Found $($allDisks.Count) total disks"
                
                foreach ($disk in $allDisks) {
                    try {
                        # Test if this disk is a VHD by trying to get VHD info
                        $vhdInfo = Get-VHD -DiskNumber $disk.Number -ErrorAction Stop
                        
                        if ($vhdInfo -and $vhdInfo.Attached) {
                            Write-Verbose "Disk $($disk.Number) is an attached VHD: $($vhdInfo.Path)"
                            $mountedDisks += $vhdInfo
                        }
                    }
                    catch {
                        # Not a VHD or can't access it, skip silently
                        continue
                    }
                }
                
                Write-Verbose "Method 2 found $($mountedDisks.Count) attached VHDs"
            }
            catch {
                Write-Error "Both detection methods failed: $_"
                return
            }
        }
        
        if (-not $mountedDisks -or $mountedDisks.Count -eq 0) {
            Write-Host "No mounted VHD files found." -ForegroundColor Green
            return
        }
        
        # Remove duplicates (in case both methods found some of the same disks)
        $uniqueDisks = $mountedDisks | Sort-Object Path -Unique
        Write-Verbose "After deduplication: $($uniqueDisks.Count) unique mounted VHDs"
        
        # Build display information for each mounted disk
        $mountedInfo = @()
        $index = 1
        
        foreach ($disk in $uniqueDisks) {
            try {
                # Get disk information
                $diskInfo = Get-Disk -Number $disk.DiskNumber -ErrorAction SilentlyContinue
                
                # Get drive letters
                $driveLetters = @()
                if ($diskInfo) {
                    $driveLetters = Get-Partition -DiskNumber $disk.DiskNumber -ErrorAction SilentlyContinue |
                        Where-Object { $_.DriveLetter } |
                        Select-Object -ExpandProperty DriveLetter
                }
                
                # Extract VM name from path - handle both .vhdx and .avhdx files
                $vmName = 'Unknown'
                if ($disk.Path -match '\\([^\\]+)\\[^\\]+\.(vhdx?|avhdx?)') {
                    $vmName = $Matches[1]
                }
                
                $info = [PSCustomObject]@{
                    Index        = $index
                    Path         = $disk.Path
                    DiskNumber   = $disk.DiskNumber
                    Size         = [math]::Round($disk.Size / 1GB, 2)
                    VhdType      = $disk.VhdType
                    DriveLetters = ($driveLetters -join ', ')
                    VMName       = $vmName
                    ParentPath   = if ($disk.ParentPath) { $disk.ParentPath } else { 'N/A' }
                }
                
                $mountedInfo += $info
                $index++
            }
            catch {
                Write-Warning "Error processing disk $($disk.DiskNumber): $_"
                continue
            }
        }
        
        # Display mounted disks
        Write-Host "`nMounted VHD Files:" -ForegroundColor Cyan
        Write-Host ("=" * 100) -ForegroundColor Cyan
        
        $mountedInfo | Format-Table -Property @(
            @{Label = "#"; Expression = { $_.Index }; Width = 3},
            @{Label = "VM Name"; Expression = { $_.VMName }; Width = 15},
            @{Label = "Type"; Expression = { $_.VhdType }; Width = 12},
            @{Label = "Drive(s)"; Expression = { if ($_.DriveLetters) { $_.DriveLetters + ":" } else { "N/A" } }; Width = 8},
            @{Label = "Disk #"; Expression = { $_.DiskNumber }; Width = 6},
            @{Label = "Size (GB)"; Expression = { $_.Size }; Width = 9},
            @{Label = "Path"; Expression = { $_.Path }}
        ) -AutoSize
        
        if (-not $ShowMenu) {
            Write-Host "`nTip: Use -ShowMenu parameter to interactively dismount disks" -ForegroundColor Yellow
            return $mountedInfo
        }
        
        # Interactive menu (same as original)
        Write-Host "`nSelect disk(s) to dismount:" -ForegroundColor Yellow
        Write-Host "Enter numbers separated by commas (e.g., 1,3,5) or 'all' to dismount all" -ForegroundColor Yellow
        Write-Host "Enter 'q' to quit without dismounting" -ForegroundColor Yellow
        
        $selection = Read-Host "`nSelection"
        
        if ($selection -eq 'q') {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            return
        }
        
        $toDismount = @()
        
        if ($selection -eq 'all') {
            $toDismount = $mountedInfo
        }
        else {
            # Parse comma-separated numbers
            $selectedIndexes = $selection -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
            
            foreach ($indexStr in $selectedIndexes) {
                $index = [int]$indexStr
                $selected = $mountedInfo | Where-Object { $_.Index -eq $index }
                
                if ($selected) {
                    $toDismount += $selected
                }
                else {
                    Write-Host "Warning: Invalid selection '$index' - skipping" -ForegroundColor Yellow
                }
            }
        }
        
        if ($toDismount.Count -eq 0) {
            Write-Host "No valid selections made." -ForegroundColor Yellow
            return
        }
        
        # Confirm dismount
        Write-Host "`nAbout to dismount the following disk(s):" -ForegroundColor Yellow
        $toDismount | ForEach-Object {
            Write-Host "  - $($_.VMName) (Disk #$($_.DiskNumber)): $($_.Path)" -ForegroundColor Yellow
        }
        
        $confirm = Read-Host "`nAre you sure? (Y/N)"
        
        if ($confirm -ne 'Y' -and $confirm -ne 'y') {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            return
        }
        
        # Dismount selected disks
        foreach ($disk in $toDismount) {
            try {
                if ($PSCmdlet.ShouldProcess($disk.Path, "Dismount VHD")) {
                    Write-Verbose "Dismounting VHD: $($disk.Path)"
                    Dismount-VHD -Path $disk.Path -ErrorAction Stop
                    Write-Host "Successfully dismounted: $($disk.VMName)" -ForegroundColor Green
                }
            }
            catch {
                Write-Error "Error dismounting $($disk.Path): $_"
                Write-Host "Error dismounting $($disk.VMName): $_" -ForegroundColor Red
            }
        }
        
        Write-Host "`nDismount operation completed." -ForegroundColor Green
    }
    catch {
        Write-Error "Error in Get-MountedVMDisk-Alternative: $_"
        throw
    }
}