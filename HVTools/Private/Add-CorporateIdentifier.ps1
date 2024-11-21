function Add-CorporateIdentifier {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Manufacturer,

        [Parameter(Mandatory = $true)]
        [string]$Model,

        [Parameter(Mandatory = $true)]
        [string]$SerialNumber,

        [Parameter(Mandatory = $false)]
        [string[]]$ImportedIdentifiers
    )

    try {
        # Ensure MS Graph connection
        if (-not (Get-MgContext)) {
            Connect-MgGraph -Scopes @(
                "DeviceManagementServiceConfig.ReadWrite.All"
            )
        }

        # Clean serial number (remove periods)
        $SerialNumber = $SerialNumber.Replace(".", "")

        # Format the identifier string
        $identifier = "$Manufacturer,$Model,$SerialNumber"

        # Check if identifier already exists in imported list
        if ($ImportedIdentifiers -contains $identifier) {
            Write-Verbose "Identifier already exists: $identifier"
            return
        }

        # Prepare the request body
        $body = @{
            importedDeviceIdentifiers = @(
                @{
                    manufacturer = $Manufacturer
                    model = $Model
                    serialNumber = $SerialNumber
                }
            )
        }

        # Make the Graph API call
        $uri = "https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities"
        $response = Invoke-MgGraphRequest -Uri $uri -Method POST -Body ($body | ConvertTo-Json)

        Write-Host "Successfully added corporate identifier for $Model (Serial: $SerialNumber)" -ForegroundColor Green
        return $response
    }
    catch {
        Write-Error "Failed to add corporate identifier: $_"
        throw
    }
}