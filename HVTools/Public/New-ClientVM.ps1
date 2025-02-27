function New-ClientVM {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [parameter(Position = 1, Mandatory = $true)]
        [string]$TenantName,

        [parameter(Position = 2, Mandatory = $false)]
        [string]$OSBuild,

        [parameter(Position = 3, Mandatory = $true)]
        [ValidateRange(1, 999)]
        [string]$NumberOfVMs,

        [parameter(Position = 4, Mandatory = $true)]
        [ValidateRange(1, 999)]
        [string]$CPUsPerVM,

        [parameter(Position = 5, Mandatory = $false)]
        [ValidateRange(2gb, 20gb)]
        [int64]$VMMemory,

        [parameter(Position = 6, Mandatory = $false)]
        [switch]$SkipAutoPilot,

        [parameter(Position = 7, Mandatory = $false)]
        [switch]$IncludeTools
    )
    try {
        Write-Verbose "Starting New-ClientVM function..."

        #region Config
        Write-Verbose "Entering Config region..."
        #pre-load HV module..
        Write-Verbose "Loading Hyper-V module..."
        Get-Command -Module 'Hyper-V' | Out-Null
        Write-Verbose "Getting client details for tenant: $TenantName"
        $clientDetails = $script:hvConfig.tenantConfig | Where-Object { $_.TenantName -eq $TenantName }
        Write-Verbose "Client details found: $($null -ne $clientDetails)"

        Write-Verbose "Getting image details..."
        if ($OSBuild) {
            Write-Verbose "Looking for OSBuild: $OSBuild"
            $imageDetails = $script:hvConfig.images | Where-Object { $_.imageName -eq $OSBuild }
        }
        else {
            Write-Verbose "Using client default image: $($clientDetails.imageName)"
            $imageDetails = $script:hvConfig.images | Where-Object { $_.imageName -eq $clientDetails.imageName }
        }
        Write-Verbose "Image details found: $($null -ne $imageDetails)"
        $clientPath = "$($script:hvConfig.vmPath)\$($TenantName)"
        if ($imageDetails.refimagePath -like '*wks$($ImageName)ref.vhdx') {
            if (!(Test-Path $imageDetails.imagePath -ErrorAction SilentlyContinue)) {
                throw "Installation media not found at location: $($imageDetails.imagePath)"
            }
        }
        if (!(Test-Path $clientPath)) {
            if ($PSCmdlet.ShouldProcess($clientPath, "Create directory")) {
                New-Item -ItemType Directory -Force -Path $clientPath | Out-Null
            }
        }

        Write-Verbose "Autopilot Reference VHDX: $($imageDetails.refImagePath)"
        Write-Verbose "Client name: $TenantName"
        Write-Verbose "Win10 ISO is located:  $($imageDetails.imagePath)"
        Write-Verbose "Path to client VMs will be: $clientPath"
        Write-Verbose "Number of VMs to create:  $NumberOfVMs"
        Write-Verbose "Admin user for $TenantName is:  $($clientDetails.adminUpn)`n"
        #endregion

        #region Check for ref image - if it's not there, build it
        if (!(Test-Path -Path $imageDetails.refImagePath -ErrorAction SilentlyContinue)) {
            if ($PSCmdlet.ShouldProcess($imageDetails.refImagePath, "Create reference Autopilot VHDX")) {
                Write-Host "Creating reference Autopilot VHDX - this may take some time.." -ForegroundColor Yellow
                New-ClientVHDX -vhdxPath $imageDetails.refImagePath -winIso $imageDetails.imagePath
                Write-Host "Reference Autopilot VHDX has been created.." -ForegroundColor Yellow
            }
        }
        #endregion

        #region Get Autopilot policy
        Write-Verbose "Entering Autopilot policy region..."
        # Initialize device naming template
        $script:deviceNameTemplate = $null

        if (!($SkipAutoPilot)) {
            Write-Host "Grabbing Autopilot config.." -ForegroundColor Yellow
            Write-Verbose "Constructing full AutopilotConfigurationFile path"
            # Change this line - pass only the directory path
            if ($PSCmdlet.ShouldProcess($clientPath, "Get Autopilot policy")) {
                Get-AutopilotPolicy -FileDestination $clientPath
            }

            # Load Autopilot naming convention if available
            $autopilotConfigPath = "$clientPath\AutopilotConfigurationFile.json"
            if (Test-Path $autopilotConfigPath) {
                Write-Verbose "Loading AutopilotConfigurationFile.json to get naming convention"
                try {
                    $autopilotConfig = Get-Content -Path $autopilotConfigPath | ConvertFrom-Json
                    if ($autopilotConfig.CloudAssignedDeviceName) {
                        Write-Verbose "Found CloudAssignedDeviceName: $($autopilotConfig.CloudAssignedDeviceName)"
                        $script:deviceNameTemplate = $autopilotConfig.CloudAssignedDeviceName
                    }
                }
                catch {
                    Write-Warning "Could not parse AutopilotConfigurationFile.json: $_"
                }
            }
        }
        Write-Verbose "Exiting Autopilot policy region..."
        #endregion

        #region Build the client VMs
        Write-Verbose "Entering VM Build region..."
        if (!(Test-Path -Path $clientPath -ErrorAction SilentlyContinue)) {
            if ($PSCmdlet.ShouldProcess($clientPath, "Create client directory")) {
                New-Item -Path $clientPath -ItemType Directory -Force | Out-Null
            }
        }

        Write-Verbose "Building vmParams hashtable..."
        $vmParams = @{
            ClientPath  = $clientPath
            RefVHDX     = $imageDetails.refImagePath
            VSwitchName = $script:hvConfig.vSwitchName
            CPUCount    = $CPUsPerVM
            VMMemory    = $VMMemory
        }

        if ($SkipAutoPilot) {
            $vmParams.Add('skipAutoPilot', $true)
        }

        Write-Verbose "Created vmParams with values:"
        $vmParams.GetEnumerator() | ForEach-Object {
            Write-Verbose "  $($_.Key): $($_.Value)"
        }

        Write-Verbose "Processing $NumberOfVMs VM(s)..."
        if ($numberOfVMs -eq 1) {
            Write-Verbose "Single VM mode..."

            # Get existing VMs for this tenant with proper pattern matching
            $existingVMs = Get-VM -Name "$TenantName*" -ErrorAction SilentlyContinue

            # Extract only the numeric suffixes using regex pattern
            $pattern = "^$([regex]::Escape($TenantName))_(\d+)$"
            $existingNumbers = @($existingVMs | ForEach-Object {
                    if ($_.Name -match $pattern) {
                        [int]$matches[1]
                    }
                })

            # Find the maximum number or start at 0
            $max = 0
            if ($existingNumbers.Count -gt 0) {
                $max = ($existingNumbers | Measure-Object -Maximum).Maximum
            }

            $max += 1

            # Generate VM name based on CloudAssignedDeviceName if available, otherwise use default naming
            if ($script:deviceNameTemplate) {
                # Create and start the VM first to get the serial number
                $tempVMName = "$($TenantName)_Temp$max"
                Write-Verbose "Creating temporary VM: $tempVMName to get serial number"

                # Copy the VHDX file for the VM
                if ($PSCmdlet.ShouldProcess("$($vmParams.ClientPath)\$tempVMName.vhdx", "Copy reference VHDX")) {
                    Copy-Item -Path $vmParams.RefVHDX -Destination "$($vmParams.ClientPath)\$tempVMName.vhdx"
                }

                # Create the VM without starting it
                if ($PSCmdlet.ShouldProcess($tempVMName, "Create temporary VM")) {
                    New-VM -Name $tempVMName -MemoryStartupBytes $VMMemory -VHDPath "$($vmParams.ClientPath)\$tempVMName.vhdx" -Generation 2 | Out-Null
                }

                # Get the serial number
                if ($PSCmdlet.ShouldProcess($tempVMName, "Get VM serial number")) {
                    $vmSerial = (Get-CimInstance -Namespace root\virtualization\v2 -class Msvm_VirtualSystemSettingData |
                        Where-Object { ($_.VirtualSystemType -eq "Microsoft:Hyper-V:System:Realized") -and
                                         ($_.elementname -eq $tempVMName) }).BIOSSerialNumber
                } else {
                    # In WhatIf mode, use a placeholder serial
                    $vmSerial = "1268-0649-6308-2683-1866-1606-61"
                }

                # Generate the VM name based on the CloudAssignedDeviceName template
                $vmName = $script:deviceNameTemplate -replace '%SERIAL%', $vmSerial

                # Truncate to 15 characters to match Autopilot behavior
                if ($vmName.Length -gt 15) {
                    Write-Verbose "Truncating VM name from '$vmName' to 15 characters"
                    $vmName = $vmName.Substring(0, 15)
                    Write-Verbose "Truncated name: '$vmName'"
                }

                # Rename the VM
                if ($PSCmdlet.ShouldProcess($tempVMName, "Rename VM to $vmName")) {
                    Rename-VM -Name $tempVMName -NewName $vmName
                }

                # Rename the VHDX file
                if ($PSCmdlet.ShouldProcess($vmName, "Stop VM")) {
                    Stop-VM -Name $vmName -Force
                }

                if ($PSCmdlet.ShouldProcess("$($vmParams.ClientPath)\$tempVMName.vhdx", "Rename to $vmName.vhdx")) {
                    Rename-Item -Path "$($vmParams.ClientPath)\$tempVMName.vhdx" -NewName "$vmName.vhdx"
                }

                # Fix the disk reference issue
                if ($PSCmdlet.ShouldProcess($vmName, "Update VM hard disk drive")) {
                    Get-VMHardDiskDrive -VMName $vmName | Remove-VMHardDiskDrive
                    Add-VMHardDiskDrive -VMName $vmName -Path "$($vmParams.ClientPath)\$vmName.vhdx"
                }

                if ($PSCmdlet.ShouldProcess($vmName, "Update VM smart paging file path")) {
                    Set-VM -Name $vmName -SmartPagingFilePath "$($vmParams.ClientPath)\$vmName"
                }

                $vmParams.VMName = $vmName
            }
            else {
                $vmParams.VMName = "$($TenantName)_$max"
            }

            Write-Verbose "Generated VMName: $($vmParams.VMName)"
            Write-Host "Creating VM: $($vmParams.VMName).." -ForegroundColor Yellow

            if ($PSCmdlet.ShouldProcess($vmParams.VMName, "Create new VM")) {
                # If we didn't already create the VM for serial number
                if (!$script:deviceNameTemplate) {
                    # Copy the VHDX file for the VM
                    if ($PSCmdlet.ShouldProcess("$($vmParams.ClientPath)\$($vmParams.VMName).vhdx", "Copy reference VHDX")) {
                        Copy-Item -Path $vmParams.RefVHDX -Destination "$($vmParams.ClientPath)\$($vmParams.VMName).vhdx"
                    }
                }

                # Add Autopilot Config if needed
                if (!($SkipAutoPilot)) {
                    Write-Verbose "Publishing Autopilot config"
                    if ($PSCmdlet.ShouldProcess($vmParams.VMName, "Publish Autopilot config")) {
                        Publish-AutoPilotConfig -vmName $vmParams.VMName -clientPath $vmParams.ClientPath
                    }
                }

                # Add troubleshooting tools if requested
                if ($IncludeTools) {
                    Write-Verbose "Including troubleshooting tools for $($vmParams.VMName)"
                    if ($PSCmdlet.ShouldProcess($vmParams.VMName, "Add troubleshooting tools")) {
                        Add-TroubleshootingTools -VMName $vmParams.VMName -ClientPath $vmParams.ClientPath
                    }
                }

                # Create and start the VM if it wasn't already created for serial number
                if (!$script:deviceNameTemplate) {
                    Write-Verbose "Creating VM with the prepared VHDX"
                    if ($PSCmdlet.ShouldProcess($vmParams.VMName, "Create VM")) {
                        New-VM -Name $vmParams.VMName -MemoryStartupBytes $VMMemory -VHDPath "$($vmParams.ClientPath)\$($vmParams.VMName).vhdx" -Generation 2 | Out-Null
                    }

                    # Get the serial number for VM Notes
                    if ($PSCmdlet.ShouldProcess($vmParams.VMName, "Get VM serial number")) {
                        $vmSerial = (Get-CimInstance -Namespace root\virtualization\v2 -class Msvm_VirtualSystemSettingData |
                            Where-Object { ($_.VirtualSystemType -eq "Microsoft:Hyper-V:System:Realized") -and
                                             ($_.elementname -eq $vmParams.VMName) }).BIOSSerialNumber
                    } else {
                        # In WhatIf mode, use a placeholder serial
                        $vmSerial = "1268-0649-6308-2683-1866-1606-61"
                    }
                }

                # Configure VM settings
                if ($PSCmdlet.ShouldProcess($vmParams.VMName, "Configure VM settings")) {
                    Enable-VMIntegrationService -vmName $vmParams.VMName -Name "Guest Service Interface"
                    Set-VM -name $vmParams.VMName -CheckpointType Disabled
                    Set-VMProcessor -VMName $vmParams.VMName -Count $vmParams.CPUCount
                    Set-VMFirmware -VMName $vmParams.VMName -EnableSecureBoot On
                    Get-VMNetworkAdapter -vmName $vmParams.VMName | Connect-VMNetworkAdapter -SwitchName $vmParams.VSwitchName | Set-VMNetworkAdapter -Name $vmParams.VSwitchName -DeviceNaming On

                    if ($script:hvConfig.vLanId) {
                        Set-VMNetworkAdapterVlan -Access -VMName $vmParams.VMName -VlanId $script:hvConfig.vLanId
                    }

                    $owner = Get-HgsGuardian UntrustedGuardian -ErrorAction SilentlyContinue
                    If (!$owner) {
                        # Creating new UntrustedGuardian since it did not exist
                        $owner = New-HgsGuardian -Name UntrustedGuardian -GenerateCertificates
                    }
                    $kp = New-HgsKeyProtector -Owner $owner -AllowUntrustedRoot
                    Set-VMKeyProtector -VMName $vmParams.VMName -KeyProtector $kp.RawData
                    Enable-VMTPM -VMName $vmParams.VMName

                    # Set VM Info with Serial number
                    Get-VM -Name $vmParams.VMName | Set-VM -Notes "Serial# $vmSerial | Tenant: $TenantName"
                }

                # Start the VM
                if ($PSCmdlet.ShouldProcess($vmParams.VMName, "Start VM")) {
                    Start-VM -Name $vmParams.VMName
                }
            }
        }
        else {
            Write-Verbose "Multiple VM mode..."

            # Get all VMs in a single call for efficiency
            $allExistingVMs = Get-VM -Name "$TenantName*" -ErrorAction SilentlyContinue
            $pattern = "^$([regex]::Escape($TenantName))_(\d+)$"

            # Extract all existing numbers
            $existingNumbers = @($allExistingVMs | ForEach-Object {
                    if ($_.Name -match $pattern) {
                        [int]$matches[1]
                    }
                })

            # Find the maximum number
            $startNumber = 0
            if ($existingNumbers.Count -gt 0) {
                $startNumber = ($existingNumbers | Measure-Object -Maximum).Maximum
            }

            # Create each VM with incremental numbering
            for ($i = 1; $i -le [int]$NumberOfVMs; $i++) {
                $vmNumber = $startNumber + $i

                # Generate VM name based on CloudAssignedDeviceName if available, otherwise use default naming
                if ($script:deviceNameTemplate) {
                    # Create a temporary VM to get serial number
                    $tempVMName = "$($TenantName)_Temp$vmNumber"
                    Write-Verbose "Creating temporary VM: $tempVMName to get serial number"

                    # Copy the VHDX file for the VM
                    if ($PSCmdlet.ShouldProcess("$($vmParams.ClientPath)\$tempVMName.vhdx", "Copy reference VHDX")) {
                        Copy-Item -Path $vmParams.RefVHDX -Destination "$($vmParams.ClientPath)\$tempVMName.vhdx"
                    }

                    # Create the VM without starting it
                    if ($PSCmdlet.ShouldProcess($tempVMName, "Create temporary VM")) {
                        New-VM -Name $tempVMName -MemoryStartupBytes $VMMemory -VHDPath "$($vmParams.ClientPath)\$tempVMName.vhdx" -Generation 2 | Out-Null
                    }

                    # Get the serial number
                    if ($PSCmdlet.ShouldProcess($tempVMName, "Get VM serial number")) {
                        $vmSerial = (Get-CimInstance -Namespace root\virtualization\v2 -class Msvm_VirtualSystemSettingData |
                            Where-Object { ($_.VirtualSystemType -eq "Microsoft:Hyper-V:System:Realized") -and
                                             ($_.elementname -eq $tempVMName) }).BIOSSerialNumber
                    } else {
                        # In WhatIf mode, use a placeholder serial with counter
                        $vmSerial = "1268-0649-6308-2683-1866-1606-$vmNumber"
                    }

                    # Generate the VM name based on the CloudAssignedDeviceName template
                    #strip out hyphens from serial number
                    $vmSerial = $vmSerial -replace '-', ''
                    Write-Verbose "Serial number for VM: $vmSerial"
                    $vmName = $script:deviceNameTemplate -replace '%SERIAL%', $vmSerial

                    # Truncate to 15 characters to match Autopilot behavior
                    if ($vmName.Length -gt 15) {
                        Write-Verbose "Truncating VM name from '$vmName' to 15 characters"
                        $vmName = $vmName.Substring(0, 15)
                        Write-Verbose "Truncated name: '$vmName'"
                    }

                    # Rename the VM
                    if ($PSCmdlet.ShouldProcess($tempVMName, "Rename VM to $vmName")) {
                        Rename-VM -Name $tempVMName -NewName $vmName
                    }

                    # Rename the VHDX file
                    if ($PSCmdlet.ShouldProcess($vmName, "Stop VM")) {
                        Stop-VM -Name $vmName -Force
                    }

                    if ($PSCmdlet.ShouldProcess("$($vmParams.ClientPath)\$tempVMName.vhdx", "Rename to $vmName.vhdx")) {
                        Rename-Item -Path "$($vmParams.ClientPath)\$tempVMName.vhdx" -NewName "$vmName.vhdx"
                    }

                    # Fix the disk reference issue
                    if ($PSCmdlet.ShouldProcess($vmName, "Update VM hard disk drive")) {
                        Get-VMHardDiskDrive -VMName $vmName | Remove-VMHardDiskDrive
                        Add-VMHardDiskDrive -VMName $vmName -Path "$($vmParams.ClientPath)\$vmName.vhdx"
                    }

                    if ($PSCmdlet.ShouldProcess($vmName, "Update VM smart paging file path")) {
                        Set-VM -Name $vmName -SmartPagingFilePath "$($vmParams.ClientPath)\$vmName"
                    }

                    $vmParams.VMName = $vmName
                }
                else {
                    $vmParams.VMName = "$($TenantName)_$vmNumber"
                }

                Write-Verbose "Generated VMName: $($vmParams.VMName)"
                Write-Host "Creating VM: $($vmParams.VMName).." -ForegroundColor Yellow

                if ($PSCmdlet.ShouldProcess($vmParams.VMName, "Create new VM")) {
                    # If we didn't already create the VM for serial number
                    if (!$script:deviceNameTemplate) {
                        # Copy the VHDX file for the VM
                        if ($PSCmdlet.ShouldProcess("$($vmParams.ClientPath)\$($vmParams.VMName).vhdx", "Copy reference VHDX")) {
                            Copy-Item -Path $vmParams.RefVHDX -Destination "$($vmParams.ClientPath)\$($vmParams.VMName).vhdx"
                        }
                    }

                    # Add Autopilot Config if needed
                    if (!($SkipAutoPilot)) {
                        Write-Verbose "Publishing Autopilot config"
                        if ($PSCmdlet.ShouldProcess($vmParams.VMName, "Publish Autopilot config")) {
                            Publish-AutoPilotConfig -vmName $vmParams.VMName -clientPath $vmParams.ClientPath
                        }
                    }

                    # Add troubleshooting tools if requested
                    if ($IncludeTools) {
                        Write-Verbose "Including troubleshooting tools for $($vmParams.VMName)"
                        if ($PSCmdlet.ShouldProcess($vmParams.VMName, "Add troubleshooting tools")) {
                            Add-TroubleshootingTools -VMName $vmParams.VMName -ClientPath $vmParams.ClientPath
                        }
                    }

                    # Create and start the VM if it wasn't already created for serial number
                    if (!$script:deviceNameTemplate) {
                        Write-Verbose "Creating VM with the prepared VHDX"
                        if ($PSCmdlet.ShouldProcess($vmParams.VMName, "Create VM")) {
                            New-VM -Name $vmParams.VMName -MemoryStartupBytes $VMMemory -VHDPath "$($vmParams.ClientPath)\$($vmParams.VMName).vhdx" -Generation 2 | Out-Null
                        }

                        # Get the serial number for VM Notes
                        if ($PSCmdlet.ShouldProcess($vmParams.VMName, "Get VM serial number")) {
                            $vmSerial = (Get-CimInstance -Namespace root\virtualization\v2 -class Msvm_VirtualSystemSettingData |
                                Where-Object { ($_.VirtualSystemType -eq "Microsoft:Hyper-V:System:Realized") -and
                                                 ($_.elementname -eq $vmParams.VMName) }).BIOSSerialNumber
                        } else {
                            # In WhatIf mode, use a placeholder serial with counter
                            $vmSerial = "1268-0649-6308-2683-1866-1606-$vmNumber"
                        }
                    }

                    # Configure VM settings
                    if ($PSCmdlet.ShouldProcess($vmParams.VMName, "Configure VM settings")) {
                        Enable-VMIntegrationService -vmName $vmParams.VMName -Name "Guest Service Interface"
                        Set-VM -name $vmParams.VMName -CheckpointType Disabled
                        Set-VMProcessor -VMName $vmParams.VMName -Count $vmParams.CPUCount
                        Set-VMFirmware -VMName $vmParams.VMName -EnableSecureBoot On
                        Get-VMNetworkAdapter -vmName $vmParams.VMName | Connect-VMNetworkAdapter -SwitchName $vmParams.VSwitchName | Set-VMNetworkAdapter -Name $vmParams.VSwitchName -DeviceNaming On

                        if ($script:hvConfig.vLanId) {
                            Set-VMNetworkAdapterVlan -Access -VMName $vmParams.VMName -VlanId $script:hvConfig.vLanId
                        }

                        $owner = Get-HgsGuardian UntrustedGuardian -ErrorAction SilentlyContinue
                        If (!$owner) {
                            # Creating new UntrustedGuardian since it did not exist
                            $owner = New-HgsGuardian -Name UntrustedGuardian -GenerateCertificates
                        }
                        $kp = New-HgsKeyProtector -Owner $owner -AllowUntrustedRoot
                        Set-VMKeyProtector -VMName $vmParams.VMName -KeyProtector $kp.RawData
                        Enable-VMTPM -VMName $vmParams.VMName

                        # Set VM Info with Serial number
                        Get-VM -Name $vmParams.VMName | Set-VM -Notes "Serial# $vmSerial | Tenant: $TenantName"
                    }

                    # Start the VM
                    if ($PSCmdlet.ShouldProcess($vmParams.VMName, "Start VM")) {
                        Start-VM -Name $vmParams.VMName
                    }
                }
            }
        }
        Write-Verbose "VM creation completed"
        #endregion
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Error "Error in New-ClientVM: $errorMsg"
    }
    finally {
        if ($errorMsg) {
            Write-Warning $errorMsg
        }
    }
}