function Get-CorporateIdentifier {
    [CmdletBinding()]
    param()

    try {
        Write-Host "`nGetting existing device identities..." -ForegroundColor Cyan

        $response = Get-MgBetaDeviceManagementImportedDeviceIdentity -Top 25

        Write-Host "Found $($response.value.Count) devices:" -ForegroundColor Green
        $response.value | ForEach-Object {
            Write-Host "- Identifier: $($_.importedDeviceIdentifier), Type: $($_.importedDeviceIdentityType)" -ForegroundColor Gray
        }

        return $response.value
    }
    catch {
        Write-Error "Failed to get corporate identifiers: $_"
        return @()
    }
}