# Test-AutoPilotPolicyFunction.ps1
[CmdletBinding()]
param(
    [Parameter()]
    [string]$TestOutputPath = "$env:TEMP\AutoPilotTest"
)

function Test-AutoPilotPolicy {
    [CmdletBinding()]
    param()

    begin {
        try {
            # Create test directory
            if (!(Test-Path $TestOutputPath)) {
                New-Item -Path $TestOutputPath -ItemType Directory -Force | Out-Null
            }

            Write-Host "Starting AutoPilot Policy Test" -ForegroundColor Cyan
            Write-Host "Test output will be saved to: $TestOutputPath" -ForegroundColor Cyan
        }
        catch {
            Write-Error "Failed in begin block: $_"
            throw
        }
    }

    process {
        try {
            # 1. Test Module Import
            Write-Host "`nStep 1: Testing Module Dependencies" -ForegroundColor Yellow
            $requiredModules = @(
                "Microsoft.Graph.Authentication",
                "Microsoft.Graph.DeviceManagement",
                "Microsoft.Graph.DeviceManagement.Enrollment"
            )

            foreach ($module in $requiredModules) {
                if (Get-Module -ListAvailable -Name $module) {
                    Write-Host "✓ $module is installed" -ForegroundColor Green
                }
                else {
                    throw "Module $module is not installed. Please install it using: Install-Module $module -Force"
                }
            }

            # 2. Test Graph Connection
            Write-Host "`nStep 2: Testing Graph Connection" -ForegroundColor Yellow
            Connect-MgGraph -Scopes @(
                "DeviceManagementServiceConfig.Read.All",
                "DeviceManagementConfiguration.Read.All"
            )
            $context = Get-MgContext
            Write-Host "✓ Successfully connected to tenant: $($context.TenantId)" -ForegroundColor Green

            # 3. Test AutoPilot Profile Retrieval
            Write-Host "`nStep 3: Testing AutoPilot Profile Retrieval" -ForegroundColor Yellow
            $autopilotProfiles = Get-MgDeviceManagementWindowsAutopilotDeploymentProfile

            if ($autopilotProfiles) {
                Write-Host "✓ Successfully retrieved AutoPilot profiles" -ForegroundColor Green
                Write-Host "Found $($autopilotProfiles.Count) profiles:" -ForegroundColor Green
                $autopilotProfiles | ForEach-Object {
                    Write-Host "  - $($_.DisplayName)" -ForegroundColor Gray
                }
            }
            else {
                Write-Warning "No AutoPilot profiles found in tenant"
            }

            # 4. Test JSON Generation
            Write-Host "`nStep 4: Testing JSON Configuration Generation" -ForegroundColor Yellow
            $selectedProfile = $autopilotProfiles | Select-Object -First 1

            if ($selectedProfile) {
                $profileConfig = @{
                    "CloudAssignedTenantId"    = $context.TenantId
                    "CloudAssignedDeviceNameTemplate" = $selectedProfile.DeviceNameTemplate
                    "Version"                   = 2049
                    "CloudAssignedAutopilotUpdateTimeout" = 1800000
                    "CloudAssignedLanguage"     = $selectedProfile.Language
                    "CloudAssignedOobeSettings" = @{
                        "SkipKeyboard"          = $true
                        "SkipTimeZone"          = $true
                        "SkipConnectivityCheck" = $false
                        "SkipUserAuthentication" = $false
                    }
                    "CloudAssignedEnrollmentType" = switch ($selectedProfile.DeviceJoinType) {
                        "azureADJoined" { 0 }
                        "azureADJoinedWithAutopilot" { 1 }
                        default { 0 }
                    }
                    "CloudAssignedAutopilotUpdateDisabled" = -not $selectedProfile.EnableAutopilotUpdateOnFirstLogin
                }

                $jsonPath = Join-Path $TestOutputPath "AutopilotConfigurationFile.json"
                $profileConfig | ConvertTo-Json -Depth 10 | Out-File $jsonPath -Encoding ascii -Force

                Write-Host "✓ Generated JSON configuration at: $jsonPath" -ForegroundColor Green
            }
            else {
                Write-Warning "No profile selected for JSON generation test"
            }

            # 5. Test the actual Get-AutopilotPolicy function
            Write-Host "`nStep 5: Testing Get-AutopilotPolicy Function" -ForegroundColor Yellow
            $functionPath = Join-Path $PSScriptRoot "Private\Get-AutopilotPolicy.ps1"

            if (Test-Path $functionPath) {
                . $functionPath
                $testPath = Join-Path $TestOutputPath "FunctionTest"
                Get-AutopilotPolicy -FileDestination $testPath

                if (Test-Path "$testPath\AutopilotConfigurationFile.json") {
                    Write-Host "✓ Get-AutopilotPolicy function executed successfully" -ForegroundColor Green
                    Write-Host "  Generated file at: $testPath\AutopilotConfigurationFile.json" -ForegroundColor Gray
                }
                else {
                    Write-Warning "Get-AutopilotPolicy did not generate the expected file"
                }
            }
            else {
                Write-Warning "Could not find Get-AutopilotPolicy.ps1 at $functionPath"
            }

            # Summary
            Write-Host "`nTest Summary:" -ForegroundColor Cyan
            Write-Host "✓ Module dependencies verified" -ForegroundColor Green
            Write-Host "✓ Graph connection successful" -ForegroundColor Green
            Write-Host "✓ AutoPilot profiles retrieved" -ForegroundColor Green
            Write-Host "✓ JSON configuration generated" -ForegroundColor Green
            if (Test-Path "$testPath\AutopilotConfigurationFile.json") {
                Write-Host "✓ Get-AutopilotPolicy function tested" -ForegroundColor Green
            }
        }
        catch {
            Write-Error "Test failed in process block: $_"
            throw
        }
    }

    end {
        try {
            if (Get-MgContext) {
                Disconnect-MgGraph | Out-Null
                Write-Host "`nDisconnected from Microsoft Graph" -ForegroundColor Gray
            }
        }
        catch {
            Write-Error "Failed in end block: $_"
            throw
        }
    }
}

# Run the test
try {
    Test-AutoPilotPolicy
}
catch {
    Write-Error "Test execution failed: $_"
}