function Get-MountedVMDisk {
    <#
    .SYNOPSIS
        Shows mounted VM disks and provides options to dismount them
    .DESCRIPTION
        Displays all currently mounted VHDX files with a numbered menu to dismount them.
        This function helps manage mounted VM disks that may have been left mounted.
    .PARAMETER ShowMenu
        If specified, displays an interactive menu to dismount selected disks
    .EXAMPLE
        Get-MountedVMDisk
        Lists all currently mounted VHDX files
    .EXAMPLE
        Get-MountedVMDisk -ShowMenu
        Shows mounted VHDX files with an interactive menu to dismount them
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$ShowMenu
    )
    
    try {
        Write-LogEntry -Message "Checking for mounted VHDX files" -Severity 1
        
        # Get all mounted VHDX files
        $mountedDisks = Get-VHD | Where-Object { $_.Attached -eq $true }
        
        if (-not $mountedDisks) {
            Write-Host "No mounted VHDX files found." -ForegroundColor Green
            return
        }
        
        # Build display information for each mounted disk
        $mountedInfo = @()
        $index = 1
        
        foreach ($disk in $mountedDisks) {
            # Get disk information
            $diskInfo = Get-Disk -Number $disk.DiskNumber -ErrorAction SilentlyContinue
            
            # Get drive letters
            $driveLetters = @()
            if ($diskInfo) {
                $driveLetters = Get-Partition -DiskNumber $disk.DiskNumber -ErrorAction SilentlyContinue |
                    Where-Object { $_.DriveLetter } |
                    Select-Object -ExpandProperty DriveLetter
            }
            
            $info = [PSCustomObject]@{
                Index        = $index
                Path         = $disk.Path
                DiskNumber   = $disk.DiskNumber
                Size         = [math]::Round($disk.Size / 1GB, 2)
                DriveLetters = ($driveLetters -join ', ')
                VMName       = if ($disk.Path -match '\\([^\\]+)\\[^\\]+\.vhdx$') { $Matches[1] } else { 'Unknown' }
            }
            
            $mountedInfo += $info
            $index++
        }
        
        # Display mounted disks
        Write-Host "`nMounted VHDX Files:" -ForegroundColor Cyan
        Write-Host ("=" * 80) -ForegroundColor Cyan
        
        $mountedInfo | Format-Table -Property @(
            @{Label = "#"; Expression = { $_.Index }; Width = 3},
            @{Label = "VM Name"; Expression = { $_.VMName }; Width = 20},
            @{Label = "Drive(s)"; Expression = { if ($_.DriveLetters) { $_.DriveLetters + ":" } else { "N/A" } }; Width = 10},
            @{Label = "Disk #"; Expression = { $_.DiskNumber }; Width = 7},
            @{Label = "Size (GB)"; Expression = { $_.Size }; Width = 10},
            @{Label = "Path"; Expression = { $_.Path }}
        ) -AutoSize
        
        if (-not $ShowMenu) {
            Write-Host "`nTip: Use -ShowMenu parameter to interactively dismount disks" -ForegroundColor Yellow
            return $mountedInfo
        }
        
        # Interactive menu
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
                if ($PSCmdlet.ShouldProcess($disk.Path, "Dismount VHDX")) {
                    Write-LogEntry -Message "Dismounting VHDX: $($disk.Path)" -Severity 1
                    Dismount-VHD -Path $disk.Path -ErrorAction Stop
                    Write-Host "Successfully dismounted: $($disk.VMName)" -ForegroundColor Green
                }
            }
            catch {
                Write-LogEntry -Message "Error dismounting $($disk.Path): $_" -Severity 3
                Write-Host "Error dismounting $($disk.VMName): $_" -ForegroundColor Red
            }
        }
        
        Write-Host "`nDismount operation completed." -ForegroundColor Green
    }
    catch {
        Write-LogEntry -Message "Error in Get-MountedVMDisk: $_" -Severity 3
        throw
    }
}