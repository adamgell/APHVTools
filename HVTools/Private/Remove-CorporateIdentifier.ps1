function Remove-CorporateIdentifier {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Manufacturer,

        [Parameter(Mandatory = $true)]
        [string]$Model,

        [Parameter(Mandatory = $true)]
        [string]$SerialNumber
    )

    try {
        # Ensure MS Graph connection
        if (-not (Get-MgContext)) {
            Connect-MgGraph -Scopes @(
                "DeviceManagementServiceConfig.ReadWrite.All"
            )
        }

        # Clean serial number
        $SerialNumber = $SerialNumber.Replace(".", "")

        # Get current identifiers
        $uri = "https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities"
        $response = Invoke-MgGraphRequest -Uri $uri -Method GET

        # Find matching identifier
        $identifier = $response.value | Where-Object {
            $_.manufacturer -eq $Manufacturer -and
            $_.model -eq $Model -and
            $_.serialNumber -eq $SerialNumber
        }

        if ($identifier) {
            # Delete the identifier
            $deleteUri = "$uri/$($identifier.id)"
            $null = Invoke-MgGraphRequest -Uri $deleteUri -Method DELETE
            Write-Host "Successfully removed corporate identifier for $Model (Serial: $SerialNumber)" -ForegroundColor Green
        }
        else {
            Write-Warning "No matching corporate identifier found"
        }
    }
    catch {
        Write-Error "Failed to remove corporate identifier: $_"
        throw
    }
}