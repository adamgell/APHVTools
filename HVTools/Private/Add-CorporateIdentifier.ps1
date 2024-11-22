function Add-CorporateIdentifier {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ImportedDeviceIdentifier,

        [Parameter(Mandatory = $false)]
        [string]$ImportedDeviceIdentityType = "serialNumber",

        [Parameter(Mandatory = $false)]
        [string]$Description = "Corporate Device",

        [Parameter(Mandatory = $false)]
        [string]$EnrollmentState = "enrolled",

        [Parameter(Mandatory = $false)]
        [string]$Platform = "windows"
    )

    try {
        # Validate input parameters
        if (-not $ImportedDeviceIdentifier) {
            throw "Device identifier is required."
        }

        # Clean identifier (remove dashes)
        $ImportedDeviceIdentifier = $ImportedDeviceIdentifier.Replace("-", "")

        Write-Host "Adding device with identifier: $ImportedDeviceIdentifier" -ForegroundColor Yellow

        $params = @{
            overwriteImportedDeviceIdentities = $false
            importedDeviceIdentities = @(
                @{
                    importedDeviceIdentityType = $ImportedDeviceIdentityType
                    importedDeviceIdentifier = $ImportedDeviceIdentifier
                    description = $Description
                    enrollmentState = $EnrollmentState
                    platform = $Platform
                }
            )
        }

        Write-Verbose "Request body:"
        Write-Verbose ($params | ConvertTo-Json)

        $response = Import-MgBetaDeviceManagementImportedDeviceIdentityList -BodyParameter $params
        Write-Verbose "Device added successfully"
        Write-Verbose ($response | ConvertTo-Json)

        return $response
    }
    catch {
        Write-Error "Failed to add corporate identifier: $_"
        if ($_.ErrorDetails) {
            Write-Error $_.ErrorDetails.Message
        }
        throw
    }
}