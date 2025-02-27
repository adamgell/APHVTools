function Add-TroubleshootingTools {
    [cmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$VMName,

        [parameter(Mandatory = $true)]
        [string]$ClientPath,

        [parameter(Mandatory = $false)]
        [string[]]$Tools
    )
    try {
        Write-Verbose "Adding troubleshooting tools to $VMName"

        # Get tools from config if not specified
        if (-not $Tools) {
            $Tools = Get-ToolsFromConfig
            if (-not $Tools -or $Tools.Count -eq 0) {
                $Tools = @("psexec.exe", "procmon.exe", "cmtrace.exe")
            }
        }

        # Define paths
        $vhdxPath = "$ClientPath\$VMName.vhdx"
        $toolsSourcePath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "Tools"
        # Validate source path exists
        if (!(Test-Path -Path $toolsSourcePath)) {
            Write-Warning "Tools source directory not found at $toolsSourcePath. Creating directory..."
            New-Item -Path $toolsSourcePath -ItemType Directory -Force | Out-Null
            Write-Warning "Please add tool files to $toolsSourcePath before using this feature."
            return
        }

        # Mount the VHDX
        Write-Verbose "Mounting $VMName.vhdx..."
        $disk = Mount-VHD -Path $vhdxPath -Passthru |
                Get-Disk |
                Get-Partition |
                Where-Object { $_.Type -eq 'Basic' } |
                Select-Object -ExpandProperty DriveLetter

        if ($disk) {
            Write-Host "Adding troubleshooting tools to $VMName.vhdx... " -ForegroundColor Cyan -NoNewline

            # Create Tools directory on VHDX
            $vmToolsFolder = "$disk`:\Tools"
            if (!(Test-Path -Path $vmToolsFolder -PathType Container)) {
                New-Item -Path $vmToolsFolder -ItemType Directory -Force | Out-Null
            }

            # Copy each tool that exists
            $toolsAdded = 0
            foreach ($tool in $Tools) {
                $toolPath = Join-Path -Path $toolsSourcePath -ChildPath $tool
                if (Test-Path $toolPath) {
                    Copy-Item -Path $toolPath -Destination "$vmToolsFolder\$tool" -Force
                    $toolsAdded++
                    Write-Verbose "Added $tool to VM"
                }
                else {
                    Write-Verbose "Tool not found: $toolPath"
                }
            }

            # Create shortcuts on the desktop
            $desktopPath = "C:\Users\Public\Desktop"
            if (Test-Path $desktopPath) {
                # Create folder shortcut
                $wshShell = New-Object -ComObject WScript.Shell
                $shortcut = $wshShell.CreateShortcut("$desktopPath\Troubleshooting Tools.lnk")
                $iconSourcePath = Join-Path -Path $toolsSourcePath -ChildPath "troubleshootingtools_IMK_icon.ico"
                $iconDestinationPath = "$vmToolsFolder\troubleshootingtools_IMK_icon.ico"
                if (Test-Path $iconSourcePath) {
                    Copy-Item -Path $iconSourcePath -Destination $iconDestinationPath -Force
                    Write-Verbose "Copied troubleshootingtools_IMK_icon.ico to VM"
                } else {
                    Write-Warning "Icon file troubleshootingtools_IMK_icon.ico not found in $toolsSourcePath"
                }
                $shortcut.IconLocation = $iconDestinationPath
                $shortcut.TargetPath = "$vmToolsFolder"
                $shortcut.Save()
                Write-Verbose "Created desktop shortcut to tools folder"

                # Create individual shortcuts for each tool
                foreach ($tool in $Tools) {
                    $toolPath = Join-Path -Path $vmToolsFolder -ChildPath $tool
                    if (Test-Path $toolPath) {
                        $toolName = [System.IO.Path]::GetFileNameWithoutExtension($tool)
                        $shortcut = $wshShell.CreateShortcut("$desktopPath\$toolName.lnk")
                        $shortcut.TargetPath = $toolPath
                        $shortcut.WorkingDirectory = $vmToolsFolder
                        $shortcut.IconLocation = "$toolPath,0"
                        $shortcut.Save()
                        Write-Verbose "Created desktop shortcut for $toolName"
                    }
                }
            }

            Write-Host "$script:tick ($toolsAdded tools added)" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Error occurred adding troubleshooting tools: $_"
        throw
    }
    finally {
        if ($disk) {
            Write-Verbose "Dismounting $VMName.vhdx"
            Dismount-VHD $vhdxPath
        }
    }
}