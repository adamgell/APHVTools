function Convert-WindowsImageInternal {
    <#
    .SYNOPSIS
        Simplified Convert-WindowsImage function integrated into HVTools
    
    .DESCRIPTION
        Creates a VHDX from a Windows ISO/WIM file using DISM and diskpart.
        This is a simplified version of the original Convert-WindowsImage script,
        focused on the specific needs of HVTools.
    
    .PARAMETER SourcePath
        Path to the Windows ISO or WIM file
    
    .PARAMETER Edition
        Edition index number from the WIM file
    
    .PARAMETER VhdPath
        Output path for the VHDX file
    
    .PARAMETER VhdFormat
        VHD format (VHD or VHDX)
    
    .PARAMETER VhdType
        VHD type (Fixed or Dynamic)
    
    .PARAMETER DiskLayout
        Disk layout (BIOS or UEFI)
    
    .PARAMETER SizeBytes
        Size of the VHD in bytes
    
    .PARAMETER UnattendPath
        Optional path to unattend.xml file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$SourcePath,
        
        [Parameter(Mandatory = $true)]
        [int]$Edition,
        
        [Parameter(Mandatory = $true)]
        [string]$VhdPath,
        
        [Parameter()]
        [ValidateSet("VHD", "VHDX")]
        [string]$VhdFormat = "VHDX",
        
        [Parameter()]
        [ValidateSet("Fixed", "Dynamic")]
        [string]$VhdType = "Dynamic",
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("BIOS", "UEFI")]
        [string]$DiskLayout,
        
        [Parameter()]
        [UInt64]$SizeBytes = 127GB,
        
        [Parameter()]
        [string]$UnattendPath
    )
    
    Write-Verbose "Starting Convert-WindowsImageInternal with parameters:"
    Write-Verbose "  SourcePath: $SourcePath"
    Write-Verbose "  Edition: $Edition"
    Write-Verbose "  VhdPath: $VhdPath"
    Write-Verbose "  VhdFormat: $VhdFormat"
    Write-Verbose "  VhdType: $VhdType"
    Write-Verbose "  DiskLayout: $DiskLayout"
    Write-Verbose "  SizeBytes: $SizeBytes"
    Write-Verbose "  UnattendPath: $UnattendPath"
    
    try {
        # Ensure target directory exists
        $targetDir = Split-Path $VhdPath -Parent
        if (-not (Test-Path $targetDir)) {
            New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
        }
        
        # Determine if source is ISO or WIM
        $sourceExt = [System.IO.Path]::GetExtension($SourcePath).ToLower()
        $wimPath = $SourcePath
        $dismountRequired = $false
        
        if ($sourceExt -eq ".iso") {
            Write-Verbose "Source is ISO file, mounting to access WIM"
            $currVol = Get-Volume
            Mount-DiskImage -ImagePath $SourcePath | Out-Null
            $dismountRequired = $true
            
            $dl = (Get-Volume | Where-Object { $_.DriveLetter -notin $currVol.DriveLetter }).DriveLetter
            $wimPath = "$dl`:\sources\install.wim"
            
            if (-not (Test-Path $wimPath)) {
                throw "Could not find install.wim in mounted ISO at $wimPath"
            }
            Write-Verbose "Found WIM file at: $wimPath"
        }
        
        # Create VHDX using diskpart
        Write-Verbose "Creating VHDX file using diskpart"
        
        # Build diskpart script line by line
        $diskpartCommands = @()
        $diskpartCommands += "create vdisk file=`"$VhdPath`" maximum=$([math]::Round($SizeBytes/1MB)) type=$(if($VhdType -eq 'Dynamic'){'expandable'}else{'fixed'})"
        $diskpartCommands += "select vdisk file=`"$VhdPath`""
        $diskpartCommands += "attach vdisk"
        
        if ($DiskLayout -eq "UEFI") {
            $diskpartCommands += "convert gpt"
            $diskpartCommands += "create partition efi size=100"
            $diskpartCommands += "format quick fs=fat32 label=`"System`""
            $diskpartCommands += "assign letter=S"
            $diskpartCommands += "create partition msr size=16"
            $diskpartCommands += "create partition primary"
            $diskpartCommands += "format quick fs=ntfs label=`"Windows`""
            $diskpartCommands += "assign letter=W"
        } else {
            $diskpartCommands += "create partition primary active"
            $diskpartCommands += "format quick fs=ntfs label=`"Windows`""
            $diskpartCommands += "assign letter=W"
        }
        
        $diskpartScript = $diskpartCommands -join "`r`n"
        
        # Execute diskpart
        $scriptPath = Join-Path $env:TEMP "hvtools_diskpart_$([guid]::NewGuid().ToString().Substring(0,8)).txt"
        $diskpartScript | Out-File -FilePath $scriptPath -Encoding ASCII
        
        Write-Verbose "Executing diskpart script: $scriptPath"
        Write-Verbose "Diskpart script content:"
        $diskpartScript -split "`n" | ForEach-Object { Write-Verbose "  $_" }
        
        $result = & diskpart /s $scriptPath
        if ($result) {
            Write-Verbose "Diskpart result: $($result -join "`n")"
        } else {
            Write-Verbose "Diskpart completed with no output"
        }
        
        # Check diskpart results and look for specific success/failure indicators
        $outputString = if ($result) { $result -join "`n" } else { "No output" }
        
        # Check for various success indicators in the output
        $vhdxCreated = $outputString -match "DiskPart successfully created the virtual disk file"
        $vhdxSelected = $outputString -match "DiskPart successfully selected the virtual disk file"
        $vhdxAttached = $outputString -match "DiskPart successfully attached the virtual disk file"
        $partitionCreated = $outputString -match "DiskPart succeeded in creating the specified partition"
        $volumeFormatted = $outputString -match "DiskPart successfully formatted the volume"
        $letterAssigned = $outputString -match "DiskPart successfully assigned the drive letter"
        
        Write-Verbose "Diskpart operation results:"
        Write-Verbose "  VHDX created: $vhdxCreated"
        Write-Verbose "  VHDX selected: $vhdxSelected"
        Write-Verbose "  VHDX attached: $vhdxAttached"
        Write-Verbose "  Partition created: $partitionCreated"
        Write-Verbose "  Volume formatted: $volumeFormatted"
        Write-Verbose "  Drive letter assigned: $letterAssigned"
        
        # If we didn't get past attaching, there's a fundamental problem
        if (-not $vhdxAttached) {
            Write-Warning "VHDX was not successfully attached. Full diskpart output:"
            Write-Warning $outputString
            
            # Try alternative approach - use PowerShell cmdlets to complete the operation
            Write-Verbose "Attempting to complete VHDX setup using PowerShell cmdlets..."
            try {
                # Mount the VHDX
                $vhdx = Mount-VHD -Path $VhdPath -Passthru
                $diskNumber = $vhdx.Number
                
                # Initialize and partition the disk
                Initialize-Disk -Number $diskNumber -PartitionStyle GPT -PassThru | Out-Null
                
                if ($DiskLayout -eq "UEFI") {
                    # Create EFI partition
                    New-Partition -DiskNumber $diskNumber -Size 100MB -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' -DriveLetter S | 
                        Format-Volume -FileSystem FAT32 -NewFileSystemLabel "System" -Confirm:$false | Out-Null
                    
                    # Create MSR partition
                    New-Partition -DiskNumber $diskNumber -Size 16MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}' | Out-Null
                    
                    # Create Windows partition
                    New-Partition -DiskNumber $diskNumber -UseMaximumSize -DriveLetter W | 
                        Format-Volume -FileSystem NTFS -NewFileSystemLabel "Windows" -Confirm:$false | Out-Null
                } else {
                    # BIOS layout
                    New-Partition -DiskNumber $diskNumber -UseMaximumSize -IsActive -DriveLetter W | 
                        Format-Volume -FileSystem NTFS -NewFileSystemLabel "Windows" -Confirm:$false | Out-Null
                }
                
                Write-Verbose "Successfully set up VHDX using PowerShell cmdlets"
            }
            catch {
                Write-Error "Failed to set up VHDX using PowerShell cmdlets: $_"
                throw
            }
        }
        
        # Verify the W: drive is available
        Write-Verbose "Waiting for W: drive to become available..."
        $maxRetries = 10
        $retryCount = 0
        $driveReady = $false
        
        while ($retryCount -lt $maxRetries -and -not $driveReady) {
            Start-Sleep -Seconds 2
            $retryCount++
            
            # Check if W: drive exists
            $wDrive = Get-PSDrive -Name W -ErrorAction SilentlyContinue
            if ($wDrive) {
                Write-Verbose "W: drive found, verifying accessibility..."
                if (Test-Path "W:\") {
                    $driveReady = $true
                    Write-Verbose "Windows partition (W:) is accessible"
                } else {
                    Write-Verbose "W: drive exists but not accessible yet (attempt $retryCount/$maxRetries)"
                }
            } else {
                Write-Verbose "W: drive not found yet (attempt $retryCount/$maxRetries)"
                
                # Try to refresh drive list
                Get-PSDrive | Out-Null
            }
        }
        
        if (-not $driveReady) {
            # List available drives for debugging
            Write-Verbose "Available drives:"
            Get-PSDrive -PSProvider FileSystem | ForEach-Object { Write-Verbose "  $($_.Name): $($_.Root)" }
            
            throw "Windows partition (W:) was not created or is not accessible after $maxRetries attempts"
        }
        
        # Clean up diskpart script
        Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
        
        # Apply Windows image using DISM
        Write-Verbose "Applying Windows image using DISM"
        Write-Verbose "WIM Path: $wimPath"
        Write-Verbose "Edition Index: $Edition"
        Write-Verbose "Target Directory: W:\"
        
        # Verify WIM file exists and is accessible
        if (-not (Test-Path $wimPath)) {
            throw "WIM file not found: $wimPath"
        }
        
        $dismArgs = @(
            "/Apply-Image"
            "/ImageFile:$wimPath"
            "/Index:$Edition"
            "/ApplyDir:W:\"
        )
        
        Write-Verbose "DISM command: dism.exe $($dismArgs -join ' ')"
        $dismResult = & dism.exe @dismArgs
        
        if ($LASTEXITCODE -ne 0) {
            # Get more detailed error information
            $dismLog = "C:\Windows\Logs\DISM\dism.log"
            $logContent = ""
            if (Test-Path $dismLog) {
                try {
                    $logContent = Get-Content $dismLog -Tail 20 -ErrorAction SilentlyContinue | Out-String
                }
                catch {
                    $logContent = "Could not read DISM log: $_"
                }
            }
            $dismOutputString = if ($dismResult) { $dismResult -join "`n" } else { "No DISM output" }
            throw "DISM apply failed with exit code $LASTEXITCODE.`nDISM Output: $dismOutputString`nLast 20 lines of DISM log:`n$logContent"
        }
        
        Write-Verbose "DISM apply completed successfully"
        
        # Apply unattend.xml if provided
        if ($UnattendPath -and (Test-Path $UnattendPath)) {
            Write-Verbose "Applying unattend.xml: $UnattendPath"
            Copy-Item -Path $UnattendPath -Destination "W:\Windows\System32\Sysprep\unattend.xml" -Force
        }
        
        # Configure boot for UEFI
        if ($DiskLayout -eq "UEFI") {
            Write-Verbose "Configuring UEFI boot"
            $bcdbootArgs = @(
                "W:\Windows"
                "/s", "S:"
                "/f", "UEFI"
            )
            
            Write-Verbose "BCDBoot command: bcdboot.exe $($bcdbootArgs -join ' ')"
            $bcdResult = & bcdboot.exe @bcdbootArgs
            
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "BCDBoot returned exit code $LASTEXITCODE. Output: $($bcdResult -join "`n")"
            }
        } else {
            # Configure boot for BIOS
            Write-Verbose "Configuring BIOS boot"
            $bcdbootArgs = @(
                "W:\Windows"
                "/s", "W:"
            )
            
            Write-Verbose "BCDBoot command: bcdboot.exe $($bcdbootArgs -join ' ')"
            $bcdResult = & bcdboot.exe @bcdbootArgs
            
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "BCDBoot returned exit code $LASTEXITCODE. Output: $($bcdResult -join "`n")"
            }
        }
        
        # Detach VHDX
        Write-Verbose "Detaching VHDX"
        $detachScript = @"
select vdisk file="$VhdPath"
detach vdisk
"@
        
        $detachScriptPath = Join-Path $env:TEMP "hvtools_detach_$([guid]::NewGuid().ToString().Substring(0,8)).txt"
        $detachScript | Out-File -FilePath $detachScriptPath -Encoding ASCII
        
        $detachResult = & diskpart /s $detachScriptPath
        Write-Verbose "Detach result: $($detachResult -join "`n")"
        
        # Clean up detach script
        Remove-Item $detachScriptPath -Force -ErrorAction SilentlyContinue
        
        # Verify VHDX was created
        if (Test-Path $VhdPath) {
            $vhdInfo = Get-Item $VhdPath
            Write-Verbose "VHDX created successfully: $($vhdInfo.FullName) ($([math]::Round($vhdInfo.Length/1GB, 2)) GB)"
            return $vhdInfo
        } else {
            throw "VHDX file was not created: $VhdPath"
        }
    }
    catch {
        Write-Error "Convert-WindowsImageInternal failed: $_"
        throw
    }
    finally {
        # Dismount ISO if we mounted it
        if ($dismountRequired -and $sourceExt -eq ".iso") {
            try {
                Write-Verbose "Dismounting ISO: $SourcePath"
                Dismount-DiskImage -ImagePath $SourcePath -ErrorAction SilentlyContinue
            }
            catch {
                Write-Warning "Failed to dismount ISO: $_"
            }
        }
        
        # If we failed and the VHDX is still mounted, try to dismount it
        if (-not $result -and (Test-Path $VhdPath)) {
            try {
                $mountedVhd = Get-VHD -Path $VhdPath -ErrorAction SilentlyContinue
                if ($mountedVhd -and $mountedVhd.Attached) {
                    Write-Verbose "Dismounting VHDX due to error: $VhdPath"
                    Dismount-VHD -Path $VhdPath -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-Warning "Failed to dismount VHDX: $_"
            }
        }
    }
}