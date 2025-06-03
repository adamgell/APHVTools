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
        $diskpartScript = @"
create vdisk file="$VhdPath" maximum=$([math]::Round($SizeBytes/1MB)) type=$(if($VhdType -eq 'Dynamic'){'expandable'}else{'fixed'})
select vdisk file="$VhdPath"
attach vdisk
"@
        
        if ($DiskLayout -eq "UEFI") {
            $diskpartScript += @"
convert gpt
create partition efi size=100
format quick fs=fat32 label="System"
assign letter=S
create partition msr size=16
create partition primary
format quick fs=ntfs label="Windows"
assign letter=W
"@
        } else {
            $diskpartScript += @"
create partition primary active
format quick fs=ntfs label="Windows"
assign letter=W
"@
        }
        
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
        
        # Check if diskpart succeeded
        if ($LASTEXITCODE -ne 0) {
            $outputString = if ($result) { $result -join "`n" } else { "No output" }
            throw "Diskpart failed with exit code $LASTEXITCODE. Output: $outputString"
        }
        
        # Verify the W: drive is available
        Start-Sleep -Seconds 2  # Give time for drive to be available
        if (-not (Test-Path "W:\")) {
            throw "Windows partition (W:) was not created or is not accessible"
        }
        Write-Verbose "Windows partition (W:) is accessible"
        
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
    }
}