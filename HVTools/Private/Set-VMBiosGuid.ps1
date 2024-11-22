function Set-VMBiosGuid {
    param(
        [Parameter(Mandatory=$true)]
        [string]$VMName
    )

    # Generate a clean serial (25 digits)
    $serialLength = 25
    $chars = '0123456789'
    $serial = -join ((1..$serialLength) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })

    # Convert to GUID format
    $guid = [System.Guid]::NewGuid()

    # Set BIOS GUID
    $vm = Get-WmiObject -Namespace 'root\virtualization\v2' -Class 'Msvm_ComputerSystem' | Where-Object { $_.ElementName -eq $VMName }
    $biosSettings = Get-WmiObject -Namespace 'root\virtualization\v2' -Class 'Msvm_VirtualSystemSettingData' | Where-Object { $_.InstanceID -like "*$($vm.Name)*" }
    $biosSettings.BIOSGUID = $guid.ToString()
    $biosSettings.BIOSSerialNumber = $serial
    $biosSettings.Put()

    return $serial
}