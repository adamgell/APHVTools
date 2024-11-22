function Register-AutopilotDevice {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName,

        [Parameter(Mandatory = $true)]
        [string]$SerialNumber,

        [Parameter(Mandatory = $false)]
        [string]$Description = "Virtual Machine",

        [Parameter(Mandatory = $true)]
        [switch]$UseAutopilotV2,

        [Parameter(Mandatory = $true)]
        [string]$ClientPath
    )

    try {
        if ($UseAutopilotV2) {
            Write-Host "Registering device with Autopilot V2..." -ForegroundColor Cyan

            $params = @{
                ImportedDeviceIdentifier = $SerialNumber
                ImportedDeviceIdentityType = "serialNumber"
                Description = $Description
                EnrollmentState = "enrolled"
                Platform = "windows"
            }

            Add-CorporateIdentifier @params
        }
        else {
            Write-Host "Registering device with traditional Autopilot..." -ForegroundColor Cyan
            Publish-AutoPilotConfig -vmName $VMName -clientPath $ClientPath
        }

        return $true
    }
    catch {
        Write-Error "Failed to register Autopilot device: $_"
        return $false
    }
}