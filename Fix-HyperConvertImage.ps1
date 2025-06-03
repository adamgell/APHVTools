# Script to fix Hyper-ConvertImage module issues
# Run this to clean reinstall the module

Write-Host "=== Fixing Hyper-ConvertImage Module ===" -ForegroundColor Cyan

try {
    # Remove any loaded instances
    Write-Host "Removing loaded Hyper-ConvertImage modules..." -ForegroundColor Yellow
    Get-Module Hyper-ConvertImage -ErrorAction SilentlyContinue | Remove-Module -Force
    
    # Check for multiple versions
    Write-Host "Checking for multiple module versions..." -ForegroundColor Yellow
    $modules = Get-Module -ListAvailable Hyper-ConvertImage
    if ($modules.Count -gt 1) {
        Write-Host "Found multiple versions:" -ForegroundColor Red
        $modules | Format-Table Name, Version, ModuleBase -AutoSize
        
        Write-Host "Removing all versions..." -ForegroundColor Yellow
        foreach ($module in $modules) {
            try {
                Uninstall-Module -Name Hyper-ConvertImage -RequiredVersion $module.Version -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Host "Could not uninstall version $($module.Version): $_" -ForegroundColor Gray
            }
        }
    }
    
    # Clean install
    Write-Host "Installing fresh copy of Hyper-ConvertImage..." -ForegroundColor Green
    Install-Module -Name Hyper-ConvertImage -Force -AllowClobber -Scope CurrentUser
    
    # Test import
    Write-Host "Testing module import..." -ForegroundColor Yellow
    Import-Module Hyper-ConvertImage -Force
    
    $testCmd = Get-Command Convert-WindowsImage -ErrorAction SilentlyContinue
    if ($testCmd) {
        Write-Host "✓ Module installed and imported successfully!" -ForegroundColor Green
        Write-Host "Version: $((Get-Module Hyper-ConvertImage).Version)" -ForegroundColor White
        Write-Host "Path: $((Get-Module Hyper-ConvertImage).ModuleBase)" -ForegroundColor White
    } else {
        Write-Host "✗ Convert-WindowsImage command not found after import" -ForegroundColor Red
    }
}
catch {
    Write-Host "Error fixing module: $_" -ForegroundColor Red
}

Write-Host "`nTry running your CreateRef.ps1 script again after this completes." -ForegroundColor Cyan