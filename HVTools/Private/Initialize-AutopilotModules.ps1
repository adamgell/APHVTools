function Initialize-AutopilotModules {
    [CmdletBinding()]
    param()

    Write-Host "Checking required modules..." -ForegroundColor Cyan

    # Remove existing module if present
    try {
        Get-Module Microsoft.Graph.DeviceManagement.Enrollment | Remove-Module -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host "Error removing module:" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }

    # Install and import required modules
    $modules = @(
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph.Beta.DeviceManagement.Enrollment",
        "Microsoft.Graph.Beta.DeviceManagement.Actions"
    )

    foreach ($module in $modules) {
        Write-Host "Installing and importing $module..." -ForegroundColor Yellow
        if (!(Get-Module -ListAvailable $module)) {
            Install-Module $module -Force -AllowClobber -Scope CurrentUser -SkipPublisherCheck
        }
        Import-Module $module -Force
    }

    Write-Host "`nVerifying loaded modules:" -ForegroundColor Cyan
    Get-Module Microsoft.Graph* | Format-Table Name, Version | Out-String | Write-Host

    return $true
}