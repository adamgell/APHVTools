function Initialize-AutopilotV2 {
    [CmdletBinding()]
    param()

    try {
        Write-Host "Initializing Autopilot V2..." -ForegroundColor Cyan

        # Remove existing module if present
        Get-Module Microsoft.Graph.DeviceManagement.Enrollment | Remove-Module -Force -ErrorAction SilentlyContinue

        # Install and import required modules
        $modules = @(
            "Microsoft.Graph.Authentication",
            "Microsoft.Graph.Beta.DeviceManagement.Enrollment",
            "Microsoft.Graph.Beta.DeviceManagement.Actions"
        )

        foreach ($module in $modules) {
            Write-Host "Checking $module..." -ForegroundColor Yellow
            if (!(Get-Module -ListAvailable $module)) {
                Write-Host "Installing $module..." -ForegroundColor Yellow
                Install-Module $module -Force -AllowClobber -Scope CurrentUser -SkipPublisherCheck
            }
            Import-Module $module -Force
            Write-Host "Loaded $module version $(Get-Module $module | Select-Object -ExpandProperty Version)" -ForegroundColor Green
        }

        # Connect to Graph if needed
        if (-not (Get-MgContext)) {
            Connect-MgGraph -Scopes @("DeviceManagementServiceConfig.ReadWrite.All")
        }

        Write-Host "Autopilot V2 initialized successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to initialize Autopilot V2: $_"
        return $false
    }
}