# Test script to verify APHVTools configuration loading
Write-Host "Testing APHVTools Configuration Loading..." -ForegroundColor Cyan

# Import the module
try {
    Import-Module "..\APHVTools" -Force
    Write-Host "✓ Module loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Check if required functions are available
$requiredFunctions = @('Get-APHVToolsConfig')
foreach ($func in $requiredFunctions) {
    if (Get-Command -Name $func -ErrorAction SilentlyContinue) {
        Write-Host "✓ Function $func is available" -ForegroundColor Green
    } else {
        Write-Host "✗ Function $func is not available" -ForegroundColor Red
        exit 1
    }
}

# Test configuration loading
try {
    $config = Get-APHVToolsConfig -Raw
    if ($config) {
        Write-Host "✓ Configuration loaded successfully" -ForegroundColor Green
        Write-Host "  - Config Path: $($config.hvConfigPath)" -ForegroundColor Yellow
        Write-Host "  - VM Path: $($config.vmPath)" -ForegroundColor Yellow
        Write-Host "  - Tenants: $($config.tenantConfig.Count)" -ForegroundColor Yellow
        Write-Host "  - Images: $($config.images.Count)" -ForegroundColor Yellow
        Write-Host "  - Tools: $($config.tools.Count)" -ForegroundColor Yellow
    } else {
        Write-Host "✗ Configuration is null or empty" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "✗ Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`nAll tests passed! The GUI should work correctly." -ForegroundColor Green