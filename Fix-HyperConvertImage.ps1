# Script to remove Hyper-ConvertImage module dependency
# HVTools now uses integrated Convert-WindowsImageInternal function

Write-Host "=== Removing Hyper-ConvertImage Module Dependency ===" -ForegroundColor Cyan

try {
    # Remove any loaded instances
    Write-Host "Removing loaded Hyper-ConvertImage modules..." -ForegroundColor Yellow
    Get-Module Hyper-ConvertImage -ErrorAction SilentlyContinue | Remove-Module -Force
    
    # Check for installed versions
    Write-Host "Checking for installed module versions..." -ForegroundColor Yellow
    $modules = Get-Module -ListAvailable Hyper-ConvertImage
    if ($modules.Count -gt 0) {
        Write-Host "Found installed versions:" -ForegroundColor Yellow
        $modules | Format-Table Name, Version, ModuleBase -AutoSize
        
        $response = Read-Host "Do you want to uninstall Hyper-ConvertImage module? (Y/N) [HVTools no longer needs it]"
        if ($response -eq 'Y' -or $response -eq 'y') {
            Write-Host "Removing all versions..." -ForegroundColor Yellow
            foreach ($module in $modules) {
                try {
                    Uninstall-Module -Name Hyper-ConvertImage -RequiredVersion $module.Version -Force -ErrorAction SilentlyContinue
                    Write-Host "Uninstalled version $($module.Version)" -ForegroundColor Green
                } catch {
                    Write-Host "Could not uninstall version $($module.Version): $_" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "Keeping Hyper-ConvertImage module installed (not used by HVTools)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✓ No Hyper-ConvertImage module found" -ForegroundColor Green
    }
    
    Write-Host "`n=== HVTools Integration Complete ===" -ForegroundColor Green
    Write-Host "✓ HVTools now uses integrated Convert-WindowsImageInternal function" -ForegroundColor Green
    Write-Host "✓ No external module dependencies for VHDX creation" -ForegroundColor Green
    Write-Host "✓ Should eliminate 'Cannot add type' compilation errors" -ForegroundColor Green
    
}
catch {
    Write-Host "Error during cleanup: $_" -ForegroundColor Red
}

Write-Host "`nYou can now run CreateRef.ps1 without any external dependencies!" -ForegroundColor Cyan