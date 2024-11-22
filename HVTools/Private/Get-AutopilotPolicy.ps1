function Get-AutopilotPolicy {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true)]
        [System.IO.FileInfo]$FileDestination
    )
    try {
        if (!(Test-Path "$FileDestination\AutopilotConfigurationFile.json" -ErrorAction SilentlyContinue)) {
            # Import required modules
            $modules = @(
                @{Name = "Microsoft.Graph.Authentication"; MinimumVersion = "2.0.0"}
                @{Name = "Microsoft.Graph.DeviceManagement"; MinimumVersion = "2.0.0"}
                @{Name = "Microsoft.Graph.DeviceManagement.Administration"; MinimumVersion = "2.0.0"}
                @{Name = "Microsoft.Graph.DeviceManagement.Enrollment"; MinimumVersion = "2.0.0"}
            )

            foreach ($module in $modules) {
                if (!(Get-Module -ListAvailable -Name $module.Name | Where-Object { $_.Version -ge $module.MinimumVersion })) {
                    Write-Host "Installing $($module.Name)..." -ForegroundColor Yellow
                    Install-Module -Name $module.Name -MinimumVersion $module.MinimumVersion -Force -AllowClobber
                }
                Import-Module -Name $module.Name -MinimumVersion $module.MinimumVersion -Force
            }

            # Connect to Microsoft Graph
            if (-not (Get-MgContext)) {
                Connect-MgGraph -Scopes @(
                    "DeviceManagementServiceConfig.Read.All",
                    "DeviceManagementConfiguration.Read.All",
                    "Organization.Read.All"
                )
            }

            # Get Autopilot deployment profiles
            $uri = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles"
            $autopilotProfiles = Invoke-MgGraphRequest -Uri $uri -Method GET
            $profiles = $autopilotProfiles.value

            if (!($profiles)) {
                Write-Warning "No Autopilot policies found.."
            }
            else {
                $selectedProfile = if ($profiles.Count -gt 1) {
                    Write-Host "Multiple Autopilot policies found - select the correct one.." -ForegroundColor Cyan
                    $profiles | Select-Object displayName, id, description |
                        Out-GridView -Title 'Select AutoPilot Profile' -PassThru
                }
                else {
                    Write-Host "Policy found - saving to $FileDestination.." -ForegroundColor Cyan
                    $profiles[0]
                }

                if ($selectedProfile) {
                    # Create directory if it doesn't exist
                    if (!(Test-Path $FileDestination)) {
                        New-Item -Path $FileDestination -ItemType Directory -Force | Out-Null
                    }

                    # Convert to JSON configuration
                    $json = @{
                        "Comment_File" = "Profile $($selectedProfile.displayName)"
                        "Version" = 2049
                        "ZtdCorrelationId" = $selectedProfile.id
                        "CloudAssignedTenantId" = (Get-MgOrganization).Id
                        "CloudAssignedDeviceName" = $selectedProfile.deviceNameTemplate
                        "CloudAssignedAutopilotUpdateDisabled" = -not $selectedProfile.enableAutopilotUpdateOnFirstLogin
                        "CloudAssignedAutopilotUpdateTimeout" = 1800000
                        "CloudAssignedForcedEnrollment" = 1
                        "CloudAssignedOobeConfig" = 8 + 256
                    } | ConvertTo-Json -Depth 10

                    # Save configuration
                    $json | Out-File "$FileDestination\AutopilotConfigurationFile.json" -Encoding ascii -Force

                    Write-Host "Autopilot profile saved: $($selectedProfile.displayName)" -ForegroundColor Green
                }
            }
        }
        else {
            Write-Host "Autopilot Configuration file found locally: $FileDestination\AutopilotConfigurationFile.json" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Error occurred getting Autopilot policy: $_"
        throw
    }
}