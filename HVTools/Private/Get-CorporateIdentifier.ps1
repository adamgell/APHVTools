function Get-CorporateIdentifiers {
    [CmdletBinding()]
    param()

    try {
        # Ensure MS Graph connection
        if (-not (Get-MgContext)) {
            Connect-MgGraph -Scopes @(
                "DeviceManagementServiceConfig.Read.All"
            )
        }

        # Get all imported device identities
        $uri = "https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities"
        $response = Invoke-MgGraphRequest -Uri $uri -Method GET

        # Format the response into identifier strings
        $identifiers = $response.value | ForEach-Object {
            "$($_.manufacturer),$($_.model),$($_.serialNumber)"
        }

        return $identifiers
    }
    catch {
        Write-Error "Failed to get corporate identifiers: $_"
        throw
    }
}