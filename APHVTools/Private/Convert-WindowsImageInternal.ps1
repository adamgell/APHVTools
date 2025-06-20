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

    # Variables that need to be accessible in finally block
    $diskNumber = $null

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

        # Create VHDX using PowerShell cmdlets only (no diskpart)
        Write-Verbose "Creating VHDX using PowerShell cmdlets"
        Write-Verbose "VHDX Path: $VhdPath"
        Write-Verbose "Size: $([math]::Round($SizeBytes/1GB, 2)) GB"
        Write-Verbose "Type: $VhdType"
        Write-Verbose "Format: $VhdFormat"

        try {
            # Check if VHDX already exists and is mounted
            if (Test-Path $VhdPath) {
                Write-Verbose "VHDX file already exists at: $VhdPath"
                $existingVhd = Get-VHD -Path $VhdPath -ErrorAction SilentlyContinue
                if ($existingVhd -and $existingVhd.Attached) {
                    Write-Warning "VHDX is already mounted. Attempting to dismount..."
                    try {
                        Dismount-VHD -Path $VhdPath -ErrorAction Stop
                        Write-Verbose "Existing VHDX dismounted successfully"
                    }
                    catch {
                        throw "Cannot dismount existing VHDX: $_"
                    }
                }
                # Remove existing file
                Write-Verbose "Removing existing VHDX file..."
                Remove-Item -Path $VhdPath -Force -ErrorAction Stop
            }

                        # Always find available drive letters dynamically to prevent conflicts
            Write-Verbose "Finding available drive letters..."
            $requiredDrives = if ($DiskLayout -eq "UEFI") { 2 } else { 1 }
            $availableLetters = Get-AvailableDriveLetters -Count $requiredDrives

            # Assign drive letters
            $script:altWindowsDrive = $availableLetters[0]
            if ($DiskLayout -eq "UEFI") {
                $script:altSystemDrive = $availableLetters[1]
                Write-Verbose "Using drive letters: Windows=$($script:altWindowsDrive), System=$($script:altSystemDrive)"
            } else {
                $script:altSystemDrive = $null
                Write-Verbose "Using drive letter: Windows=$($script:altWindowsDrive)"
            }

            # Create the VHDX file
            Write-Verbose "Creating new VHDX file..."
            $vhdParams = @{
                Path = $VhdPath
                SizeBytes = $SizeBytes
                Dynamic = ($VhdType -eq 'Dynamic')
            }

            New-VHD @vhdParams -ErrorAction Stop | Out-Null
            Write-Verbose "VHDX file created successfully"

            # Mount the VHDX
            Write-Verbose "Mounting VHDX..."
            $vhdx = Mount-VHD -Path $VhdPath -Passthru -ErrorAction Stop
            $diskNumber = $vhdx.Number
            Write-Verbose "VHDX mounted as disk number: $diskNumber"

            # Initialize the disk
            Write-Verbose "Initializing disk..."
            $partitionStyle = if ($DiskLayout -eq "UEFI") { "GPT" } else { "MBR" }
            Initialize-Disk -Number $diskNumber -PartitionStyle $partitionStyle -PassThru -ErrorAction Stop | Out-Null
            Write-Verbose "Disk initialized with $partitionStyle partition style"

            if ($DiskLayout -eq "UEFI") {
                # UEFI layout
                Write-Verbose "Creating UEFI partition layout..."

                # Create EFI System Partition (ESP)
                Write-Verbose "Creating EFI System Partition (100MB) with drive letter $($script:altSystemDrive)..."
                $efiPartition = New-Partition -DiskNumber $diskNumber -Size 100MB -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' -DriveLetter $script:altSystemDrive -ErrorAction Stop
                Format-Volume -Partition $efiPartition -FileSystem FAT32 -NewFileSystemLabel "System" -Confirm:$false -ErrorAction Stop | Out-Null
                Write-Verbose "EFI partition created and formatted"

                # Create Microsoft Reserved Partition (MSR)
                Write-Verbose "Creating Microsoft Reserved Partition (16MB)..."
                New-Partition -DiskNumber $diskNumber -Size 16MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}' -ErrorAction Stop | Out-Null
                Write-Verbose "MSR partition created"

                # Create Windows partition
                Write-Verbose "Creating Windows partition (remaining space) with drive letter $($script:altWindowsDrive)..."
                $windowsPartition = New-Partition -DiskNumber $diskNumber -UseMaximumSize -DriveLetter $script:altWindowsDrive -ErrorAction Stop
                Format-Volume -Partition $windowsPartition -FileSystem NTFS -NewFileSystemLabel "Windows" -Confirm:$false -ErrorAction Stop | Out-Null
                Write-Verbose "Windows partition created and formatted"
            } else {
                # BIOS/MBR layout
                Write-Verbose "Creating BIOS/MBR partition layout..."

                # Create single active Windows partition
                Write-Verbose "Creating Windows partition (full disk) with drive letter $($script:altWindowsDrive)..."
                $windowsPartition = New-Partition -DiskNumber $diskNumber -UseMaximumSize -IsActive -DriveLetter $script:altWindowsDrive -ErrorAction Stop
                Format-Volume -Partition $windowsPartition -FileSystem NTFS -NewFileSystemLabel "Windows" -Confirm:$false -ErrorAction Stop | Out-Null
                Write-Verbose "Windows partition created and formatted"
            }

            Write-Verbose "VHDX setup completed successfully using PowerShell cmdlets"
        }
        catch {
            Write-Error "Failed to create/setup VHDX: $_"
            # Clean up on failure
            if ($diskNumber) {
                try {
                    Dismount-VHD -DiskNumber $diskNumber -ErrorAction SilentlyContinue
                } catch { }
            }
            if (Test-Path $VhdPath) {
                try {
                    Remove-Item $VhdPath -Force -ErrorAction SilentlyContinue
                } catch { }
            }
            throw
        }

        # Verify the Windows drive is available
        Write-Verbose "Waiting for Windows drive ($($script:altWindowsDrive):) to become available..."
        $maxRetries = 10
        $retryCount = 0
        $driveReady = $false

        while ($retryCount -lt $maxRetries -and -not $driveReady) {
            Start-Sleep -Seconds 2
            $retryCount++

            # Check if Windows drive exists
            $windowsDrive = Get-PSDrive -Name $script:altWindowsDrive -ErrorAction SilentlyContinue
            if ($windowsDrive) {
                Write-Verbose "$($script:altWindowsDrive): drive found, verifying accessibility..."
                if (Test-Path "$($script:altWindowsDrive):\") {
                    $driveReady = $true
                    Write-Verbose "Windows partition ($($script:altWindowsDrive):) is accessible"
                } else {
                    Write-Verbose "$($script:altWindowsDrive): drive exists but not accessible yet (attempt $retryCount/$maxRetries)"
                }
            } else {
                Write-Verbose "$($script:altWindowsDrive): drive not found yet (attempt $retryCount/$maxRetries)"

                # Try to refresh drive list
                Get-PSDrive | Out-Null
            }
        }

        if (-not $driveReady) {
            # List available drives for debugging
            Write-Verbose "Available drives:"
            Get-PSDrive -PSProvider FileSystem | ForEach-Object { Write-Verbose "  $($_.Name): $($_.Root)" }

            throw "Windows partition ($($script:altWindowsDrive):) was not created or is not accessible after $maxRetries attempts"
        }

        # Apply Windows image using DISM
        Write-Verbose "Applying Windows image using DISM"
        Write-Verbose "WIM Path: $wimPath"
        Write-Verbose "Edition Index: $Edition"
        Write-Verbose "Target Directory: $($script:altWindowsDrive):\"

        # Verify WIM file exists and is accessible
        if (-not (Test-Path $wimPath)) {
            throw "WIM file not found: $wimPath"
        }

        $dismArgs = @(
            "/Apply-Image"
            "/ImageFile:$wimPath"
            "/Index:$Edition"
            "/ApplyDir:$($script:altWindowsDrive):\"
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
            Copy-Item -Path $UnattendPath -Destination "$($script:altWindowsDrive):\Windows\System32\Sysprep\unattend.xml" -Force
        }

        # Configure boot for UEFI
        if ($DiskLayout -eq "UEFI") {
            Write-Verbose "Configuring UEFI boot"
            $bcdbootArgs = @(
                "$($script:altWindowsDrive):\Windows"
                "/s", "$($script:altSystemDrive):"
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
                "$($script:altWindowsDrive):\Windows"
                "/s", "$($script:altWindowsDrive):"
            )

            Write-Verbose "BCDBoot command: bcdboot.exe $($bcdbootArgs -join ' ')"
            $bcdResult = & bcdboot.exe @bcdbootArgs

            if ($LASTEXITCODE -ne 0) {
                Write-Warning "BCDBoot returned exit code $LASTEXITCODE. Output: $($bcdResult -join "`n")"
            }
        }

        # Detach VHDX using PowerShell cmdlet
        Write-Verbose "Detaching VHDX"
        try {
            Dismount-VHD -Path $VhdPath -ErrorAction Stop
            Write-Verbose "VHDX detached successfully"
        }
        catch {
            Write-Warning "Failed to detach VHDX: $_"
            # Try alternative method using disk number if available
            if ($diskNumber) {
                try {
                    Dismount-VHD -DiskNumber $diskNumber -ErrorAction Stop
                    Write-Verbose "VHDX detached successfully using disk number"
                }
                catch {
                    Write-Warning "Failed to detach VHDX using disk number: $_"
                }
            }
        }

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

# Function to find available drive letters
function Get-AvailableDriveLetters {
    param([int]$Count = 2)

    # Get all currently used drive letters
    $usedLetters = @()

    # Check PSDrives (includes temporary drives)
    Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name.Length -eq 1) {
            $usedLetters += $_.Name.ToUpper()
        }
    }

    # Check volumes (includes mounted volumes without drive letters assigned via PSDrive)
    Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -ne $null } | ForEach-Object {
        $usedLetters += $_.DriveLetter.ToString().ToUpper()
    }

    # Check for any mounted VHDs
    try {
        Get-Disk -ErrorAction SilentlyContinue | Where-Object { $_.BusType -eq 'File Backed Virtual' } | ForEach-Object {
            Get-Partition -DiskNumber $_.Number -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter } | ForEach-Object {
                $usedLetters += $_.DriveLetter.ToString().ToUpper()
            }
        }
    }
    catch {
        # Ignore errors from VHD checking
    }

    # Remove duplicates and sort
    $usedLetters = $usedLetters | Sort-Object -Unique

    Write-Verbose "Currently used drive letters: $($usedLetters -join ', ')"

    # Find available letters (skip A, B, C, D as they're commonly reserved)
    $availableLetters = @()
    foreach ($letter in 69..90) {  # E through Z
        $letterChar = [char]$letter
        if ($letterChar -notin $usedLetters) {
            $availableLetters += $letterChar
            if ($availableLetters.Count -ge $Count) {
                break
            }
        }
    }

    Write-Verbose "Available drive letters found: $($availableLetters -join ', ')"

    if ($availableLetters.Count -lt $Count) {
        throw "Not enough available drive letters. Need $Count, found $($availableLetters.Count). Please free up some drive letters and try again."
    }

    return $availableLetters
}