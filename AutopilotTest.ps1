# AutopilotTest.ps1

function Initialize-RequiredModules {
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
    $modules = @("Microsoft.Graph.Authentication", "Microsoft.Graph.Beta.DeviceManagement.Enrollment", "Microsoft.Graph.Beta.DeviceManagement.Actions")

    foreach ($module in $modules) {
        Write-Host "Installing and importing $module..." -ForegroundColor Yellow
        if (!(Get-Module -ListAvailable $module)) {
            Install-Module $module -Force -AllowClobber -Scope CurrentUser -SkipPublisherCheck
        }
        Import-Module $module -Force
    }

    Write-Host "`nVerifying loaded modules:" -ForegroundColor Cyan
    Get-Module Microsoft.Graph* | Format-Table Name, Version | Out-String | Write-Host
}

function Test-AddDeviceIdentity {
    param (
        [string]$ImportedDeviceIdentifier,
        [string]$ImportedDeviceIdentityType,
        [string]$Description,
        [string]$EnrollmentState,
        [string]$Platform
    )

    Write-Host "`nTesting Add Device Identity..." -ForegroundColor Cyan

    # Validate input parameters
    if (-not $ImportedDeviceIdentifier -or -not $ImportedDeviceIdentityType -or -not $Description -or -not $EnrollmentState -or -not $Platform) {
        Write-Host "Error: All parameters are required." -ForegroundColor Red
        return $null
    }

    try {
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

        Write-Host "Request body:" -ForegroundColor Yellow
        $params | ConvertTo-Json | Write-Host

        $response = Import-MgBetaDeviceManagementImportedDeviceIdentityList -BodyParameter $params

        Write-Host "Success! Device added:" -ForegroundColor Green
        $response | ConvertTo-Json | Write-Host

        return $response
    }
    catch {
        Write-Host "Error adding device:" -ForegroundColor Red
        Write-Host $_.Exception.Message

        if ($_.ErrorDetails) {
            Write-Host "Error Details:" -ForegroundColor Red
            Write-Host $_.ErrorDetails.Message

            try {
                $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json
                Write-Host "Detailed error message:" -ForegroundColor Red
                $errorBody.error.message | Write-Host
            }
            catch {
                # Not a JSON error message
            }
        }
        return $null
    }
}

function Test-GetDeviceIdentities {
    Write-Host "`nGetting existing device identities..." -ForegroundColor Cyan

    try {
        $response = Get-MgBetaDeviceManagementImportedDeviceIdentity -Top 25

        Write-Host "Found $($response.value.Count) devices:" -ForegroundColor Green
        $response.value | ForEach-Object {
            Write-Host "- Identifier: $($_.importedDeviceIdentifier), Type: $($_.importedDeviceIdentityType)" -ForegroundColor Gray
        }

        return $response.value
    }
    catch {
        Write-Host "Error getting devices:" -ForegroundColor Red
        Write-Host $_.Exception.Message
        return @()
    }
}

# Main execution
Write-Host "Starting Autopilot V2 Tests" -ForegroundColor Cyan

Initialize-RequiredModules

if (-not (Get-MgContext)) {
    Write-Host "Connecting to Graph API..." -ForegroundColor Yellow
    try {
        Connect-MgGraph -Scopes @("DeviceManagementServiceConfig.ReadWrite.All")
    }
    catch {
        Write-Host "Error connecting to Graph API:" -ForegroundColor Red
        Write-Host $_.Exception.Message
        return
    }
}

$testParams = @{
    ImportedDeviceIdentifier = "1234567890123456"
    ImportedDeviceIdentityType = "serialNumber"
    Description = "Test Device"
    EnrollmentState = "enrolled"
    Platform = "windows"
}

Write-Host "`nUsing test parameters:" -ForegroundColor Yellow
$testParams | Format-Table | Out-String | Write-Host

$existing = Test-GetDeviceIdentities
$newDevice = Test-AddDeviceIdentity @testParams
$updated = Test-GetDeviceIdentities

Write-Host "`nTest Summary:" -ForegroundColor Cyan
Write-Host "Initial count: $($existing.Count)" -ForegroundColor Gray
Write-Host "After add: $($updated.Count)" -ForegroundColor Gray