# Updated Get-AutopilotPolicy.ps1
#requires -Modules @{ ModuleName="Microsoft.Graph.Authentication"; ModuleVersion="2.0.0" }
#requires -Modules @{ ModuleName="Microsoft.Graph.DeviceManagement"; ModuleVersion="2.0.0" }
#requires -Modules @{ ModuleName="Microsoft.Graph.DeviceManagement.Enrollment"; ModuleVersion="2.0.0" }

function Get-AutopilotPolicy {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true)]
        [System.IO.FileInfo]$FileDestination
    )
    try {
        if (!(Test-Path "$FileDestination\AutopilotConfigurationFile.json" -ErrorAction SilentlyContinue)) {
            $modules = @(
                "Microsoft.Graph.Authentication",
                "Microsoft.Graph.DeviceManagement",
                "Microsoft.Graph.DeviceManagement.Enrollment"
            )

            # Import modules properly for PowerShell 7 compatibility
            if ($PSVersionTable.PSVersion.Major -eq 7) {
                $modules | ForEach-Object {
                    Import-Module $_ -UseWindowsPowerShell -ErrorAction SilentlyContinue 3>$null
                }
            }
            else {
                $modules | ForEach-Object {
                    Import-Module $_
                }
            }

            # Connect to Microsoft Graph with proper scopes
            if (-not (Get-MgContext)) {
                Connect-MgGraph -Scopes @(
                    "DeviceManagementServiceConfig.Read.All",
                    "DeviceManagementConfiguration.Read.All"
                )
            }

            try {
                $uri = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles"
                $response = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
                $autopilotProfiles = $response.value
            }
            catch {
                Write-Error "Failed to get Autopilot profiles: $_"
                return
            }

            if (!($autopilotProfiles)) {
                Write-Warning "No Autopilot policies found.."
            }
            else {
                if ($autopilotProfiles.Count -gt 1) {
                    Write-Host "Multiple Autopilot policies found - select the correct one.." -ForegroundColor Cyan
                    $selectedProfile = $autopilotProfiles | Select-Object displayName, id, description |
                        Out-GridView -Title 'Select AutoPilot Profile' -PassThru
                }
                else {
                    Write-Host "Policy found - saving to $FileDestination.." -ForegroundColor Cyan
                    $selectedProfile = $autopilotProfiles[0]
                }

                if ($selectedProfile) {
                    $context = Get-MgContext
                    $tenantId = $context.TenantId
                    $tenantDomain = $context.Account -replace '.*@'

                    # Create profile configuration matching exact format
                    $profileConfig = @{
                        "CloudAssignedOobeConfig" = 1308
                        "ZtdCorrelationId" = [guid]::NewGuid().ToString()
                        "CloudAssignedDeviceName" = "%SERIAL%"
                        "Version" = 2049
                        "CloudAssignedTenantDomain" = $tenantDomain
                        "CloudAssignedLanguage" = "os-default"
                        "CloudAssignedTenantId" = $tenantId
                        "CloudAssignedAutopilotUpdateDisabled" = 1
                        "CloudAssignedAutopilotUpdateTimeout" = 1800000
                        "CloudAssignedDomainJoinMethod" = 0
                        "Comment_File" = "Profile Standard"
                        "CloudAssignedRegion" = "os-default"
                        "CloudAssignedAadServerData" = "{""ZeroTouchConfig"":{""CloudAssignedTenantUpn"":"""",""CloudAssignedTenantDomain"":""$tenantDomain"",""ForcedEnrollment"":1}}"
                        "CloudAssignedForcedEnrollment" = 1
                    }

                    # Save configuration
                    $profileConfig | ConvertTo-Json -Depth 10 |
                        Out-File "$FileDestination\AutopilotConfigurationFile.json" -Encoding ascii -Force

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
    }
    finally {
        if ($PSVersionTable.PSVersion.Major -eq 7) {
            $modules | ForEach-Object {
                Remove-Module $_ -ErrorAction SilentlyContinue 3>$null
            }
        }
    }
}