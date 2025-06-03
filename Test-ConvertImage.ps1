# Simple test script to isolate Convert-WindowsImage issues
param(
    [string]$IsoPath = "E:\ISO\en-us_windows_11_business_editions_version_24h2_updated_march_2025_x64_dvd_77837751.iso"
)

Write-Host "=== Testing Convert-WindowsImage Isolation ===" -ForegroundColor Cyan

try {
    # Import module
    Write-Host "Importing Hyper-ConvertImage..." -ForegroundColor Yellow
    Import-Module Hyper-ConvertImage -Force
    
    # Get module info
    $module = Get-Module Hyper-ConvertImage
    Write-Host "Module Version: $($module.Version)" -ForegroundColor White
    Write-Host "Module Path: $($module.ModuleBase)" -ForegroundColor White
    
    # Test command availability
    $cmd = Get-Command Convert-WindowsImage -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "Convert-WindowsImage command not found"
    }
    Write-Host "Convert-WindowsImage found: $($cmd.Source)" -ForegroundColor Green
    
    # Try to get help (this sometimes reveals type loading issues)
    Write-Host "Testing Get-Help Convert-WindowsImage..." -ForegroundColor Yellow
    try {
        $help = Get-Help Convert-WindowsImage -ErrorAction Stop
        Write-Host "✓ Help available" -ForegroundColor Green
    } catch {
        Write-Host "✗ Help failed: $_" -ForegroundColor Red
    }
    
    # Try to get parameters (this also can reveal type issues)
    Write-Host "Testing parameter inspection..." -ForegroundColor Yellow
    try {
        $params = (Get-Command Convert-WindowsImage).Parameters
        Write-Host "✓ Parameters accessible: $($params.Count) parameters" -ForegroundColor Green
    } catch {
        Write-Host "✗ Parameter inspection failed: $_" -ForegroundColor Red
    }
    
    # Test with minimal parameters (don't actually run, just validate)
    Write-Host "Testing parameter validation..." -ForegroundColor Yellow
    $testParams = @{
        SourcePath = $IsoPath
        Edition = 1
        VhdType = "Dynamic" 
        VhdFormat = "VHDX"
        VhdPath = "C:\temp\test.vhdx"
        DiskLayout = "UEFI"
        SizeBytes = 60gb
    }
    
    # Check if ISO exists
    if (-not (Test-Path $IsoPath)) {
        Write-Host "✗ ISO not found: $IsoPath" -ForegroundColor Red
        return
    }
    
    Write-Host "✓ ISO found: $IsoPath" -ForegroundColor Green
    
    # Try to validate parameters without executing
    Write-Host "Parameters that would be used:" -ForegroundColor Cyan
    foreach ($key in $testParams.Keys) {
        Write-Host "  $key = $($testParams[$key])" -ForegroundColor White
    }
    
    Write-Host "`n=== Test Results ===" -ForegroundColor Cyan
    Write-Host "If all checks above passed, the issue may be:" -ForegroundColor Yellow
    Write-Host "1. Target directory permissions" -ForegroundColor White
    Write-Host "2. Disk space" -ForegroundColor White  
    Write-Host "3. Internal .NET type conflicts in the function" -ForegroundColor White
    Write-Host "4. Windows ADK/DISM dependencies" -ForegroundColor White
    
} catch {
    Write-Host "✗ Test failed: $_" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    if ($_.Exception.InnerException) {
        Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
    }
}