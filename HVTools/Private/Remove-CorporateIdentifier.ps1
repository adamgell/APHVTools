function Remove-CorporateIdentifier {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    try {
        # Ensure MS Graph connection
        if (-not (Get-MgContext)) {
            Connect-MgGraph -Scopes @(
                "DeviceManagementServiceConfig.ReadWrite.All"
            )
        }

        # Delete the identifier by ID
        $uri = "https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities/$Id"
        $null = Invoke-MgGraphRequest -Uri $uri -Method DELETE

        Write-Host "Successfully removed corporate identifier" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to remove corporate identifier: $_"
        throw
    }
}