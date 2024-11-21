function New-ClientDevice {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [parameter(Position = 1, Mandatory = $true)]
        [string]$VMName,

        [parameter(Position = 2, Mandatory = $true)]
        [string]$ClientPath,

        [parameter(Position = 3, Mandatory = $true)]
        [string]$RefVHDX,

        [parameter(Position = 4, Mandatory = $true)]
        [string]$VSwitchName,

        [parameter(Position = 5, Mandatory = $false)]
        [string]$VLanId,

        [parameter(Position = 6, Mandatory = $true)]
        [string]$CPUCount,

        [parameter(Position = 7, Mandatory = $true)]
        [string]$VMMMemory,

        [parameter(Position = 8, Mandatory = $false)]
        [switch]$skipAutoPilot,

        [parameter(Position = 9, Mandatory = $false)]
        [switch]$UseAutopilotV2,

        [parameter(Position = 10, Mandatory = $false)]
        [string]$Manufacturer = "Microsoft",

        [parameter(Position = 11, Mandatory = $false)]
        [string]$Model = "Hyper-V Virtual Machine"
    )

    try {
        # Create the VM with base VHDX
        Copy-Item -path $RefVHDX -Destination "$ClientPath\$VMName.vhdx"

        if (!($skipAutoPilot)) {
            Publish-AutoPilotConfig -vmName $VMName -clientPath $ClientPath
        }

        # Create and configure the VM
        New-VM -Name $VMName -MemoryStartupBytes $VMMMemory -VHDPath "$ClientPath\$VMName.vhdx" -Generation 2 | Out-Null
        Enable-VMIntegrationService -vmName $VMName -Name "Guest Service Interface"
        Set-VM -name $VMName -CheckpointType Disabled
        Set-VMProcessor -VMName $VMName -Count $CPUCount
        Set-VMFirmware -VMName $VMName -EnableSecureBoot On

        # Configure networking
        Get-VMNetworkAdapter -vmName $VMName |
            Connect-VMNetworkAdapter -SwitchName $VSwitchName |
            Set-VMNetworkAdapter -Name $VSwitchName -DeviceNaming On

        if ($VLanId) {
            Set-VMNetworkAdapterVlan -Access -VMName $VMName -VlanId $VLanId
        }

        # Configure TPM
        $owner = Get-HgsGuardian UntrustedGuardian -ErrorAction SilentlyContinue
        If (!$owner) {
            $owner = New-HgsGuardian -Name UntrustedGuardian -GenerateCertificates
        }
        $kp = New-HgsKeyProtector -Owner $owner -AllowUntrustedRoot
        Set-VMKeyProtector -VMName $VMName -KeyProtector $kp.RawData
        Enable-VMTPM -VMName $VMName

        # Get VM Serial Number
        $vmSerial = (Get-CimInstance -Namespace root\virtualization\v2 -class Msvm_VirtualSystemSettingData |
            Where-Object { ($_.VirtualSystemType -eq "Microsoft:Hyper-V:System:Realized") -and
                         ($_.elementname -eq $VMName) }).BIOSSerialNumber

        # Set VM Info with Serial number
        Get-VM -Name $VMname | Set-VM -Notes "Serial# $vmSerial"

        # If using Autopilot V2, register the corporate identifier
        if ($UseAutopilotV2) {
            Write-Host "Registering corporate identifier for Autopilot V2..." -ForegroundColor Cyan

            # Get existing identifiers to avoid duplicates
            $existingIdentifiers = Get-CorporateIdentifiers

            # Add the new identifier
            Add-CorporateIdentifier -Manufacturer $Manufacturer -Model $Model -SerialNumber $vmSerial -ImportedIdentifiers $existingIdentifiers
        }

        # Start the VM
        Start-VM -Name $VMName

        # Return VM information
        return @{
            VMName = $VMName
            SerialNumber = $vmSerial
            Path = "$ClientPath\$VMName.vhdx"
        }
    }
    catch {
        Write-Error "Failed to create VM: $_"
        throw
    }
}