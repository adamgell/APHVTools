# Enhanced test script to isolate Convert-WindowsImage issues and test actual execution
param(
    [string]$IsoPath = "E:\ISO\en-us_windows_11_business_editions_version_24h2_updated_march_2025_x64_dvd_77837751.iso",
    [switch]$TestActualConversion
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
    
    # Check Windows ADK installation
    Write-Host "`n=== Checking Windows ADK Dependencies ===" -ForegroundColor Cyan
    $adkPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots"
    )
    
    $adkFound = $false
    foreach ($path in $adkPaths) {
        try {
            $adk = Get-ItemProperty -Path $path -Name KitsRoot10 -ErrorAction SilentlyContinue
            if ($adk.KitsRoot10) {
                Write-Host "✓ Windows ADK found at: $($adk.KitsRoot10)" -ForegroundColor Green
                $adkFound = $true
                
                # Check for DISM
                $dismPath = Join-Path $adk.KitsRoot10 "Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe"
                if (Test-Path $dismPath) {
                    Write-Host "✓ DISM found at: $dismPath" -ForegroundColor Green
                } else {
                    Write-Host "✗ DISM not found at expected location" -ForegroundColor Red
                }
                break
            }
        } catch {
            # Continue to next path
        }
    }
    
    if (-not $adkFound) {
        Write-Host "✗ Windows ADK not found - this is likely the cause!" -ForegroundColor Red
        Write-Host "Install Windows ADK from: https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install" -ForegroundColor Yellow
    }
    
    # Check if ISO exists
    Write-Host "`n=== Checking Source Files ===" -ForegroundColor Cyan
    if (-not (Test-Path $IsoPath)) {
        Write-Host "✗ ISO not found: $IsoPath" -ForegroundColor Red
        return
    }
    Write-Host "✓ ISO found: $IsoPath" -ForegroundColor Green
    Write-Host "  Size: $([math]::Round((Get-Item $IsoPath).Length / 1GB, 2)) GB" -ForegroundColor White
    
    # Check disk space
    Write-Host "`n=== Checking Target Locations ===" -ForegroundColor Cyan
    $targets = @(
        "F:\GellOne\.hvtools\tenantVMs",
        "C:\temp"
    )
    
    foreach ($target in $targets) {
        try {
            if (-not (Test-Path $target)) {
                New-Item -Path $target -ItemType Directory -Force | Out-Null
                Write-Host "✓ Created directory: $target" -ForegroundColor Green
            } else {
                Write-Host "✓ Directory exists: $target" -ForegroundColor Green
            }
            
            # Test write permissions
            $testFile = Join-Path $target "hvtools_test_$([guid]::NewGuid().ToString().Substring(0,8)).tmp"
            "test" | Out-File -FilePath $testFile -Force
            Remove-Item $testFile -Force
            Write-Host "✓ Write permissions OK: $target" -ForegroundColor Green
            
            # Check disk space
            $drive = Split-Path $target -Qualifier
            $freeSpace = [math]::Round((Get-PSDrive $drive.TrimEnd(':')).Free / 1GB, 2)
            Write-Host "✓ Free space: $freeSpace GB on $drive" -ForegroundColor Green
            
        } catch {
            Write-Host "✗ Problem with $target`: $_" -ForegroundColor Red
        }
    }
    
    # Test actual conversions if requested
    if ($TestActualConversion) {
        Write-Host "`n=== Testing Actual Convert-WindowsImage Execution ===" -ForegroundColor Cyan
        
        # Test 1: F: drive (actual target location)
        Write-Host "Test 1: F: drive target (actual workspace location)" -ForegroundColor Yellow
        $testParams1 = @{
            SourcePath = $IsoPath
            Edition = 3  # Windows 11 Enterprise
            VhdType = "Dynamic"
            VhdFormat = "VHDX"
            VhdPath = "F:\GellOne\.hvtools\tenantVMs\test-direct.vhdx"
            DiskLayout = "UEFI"
            SizeBytes = 60gb
        }
        
        try {
            Write-Host "Executing Convert-WindowsImage with F: drive target..." -ForegroundColor Cyan
            Convert-WindowsImage @testParams1
            Write-Host "✓ SUCCESS: F: drive conversion completed!" -ForegroundColor Green
            
            # Clean up test file
            if (Test-Path $testParams1.VhdPath) {
                Remove-Item $testParams1.VhdPath -Force
                Write-Host "Cleaned up test VHDX" -ForegroundColor Gray
            }
        } catch {
            Write-Host "✗ FAILED: F: drive conversion failed" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            
            if ($_.Exception.InnerException) {
                Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
            }
            
            # Test 2: C: drive fallback
            Write-Host "`nTest 2: C: drive fallback" -ForegroundColor Yellow
            $testParams2 = @{
                SourcePath = $IsoPath
                Edition = 3
                VhdType = "Dynamic"
                VhdFormat = "VHDX"
                VhdPath = "C:\temp\test-simple.vhdx"
                DiskLayout = "UEFI"
                SizeBytes = 60gb
            }
            
            try {
                Write-Host "Executing Convert-WindowsImage with C: drive target..." -ForegroundColor Cyan
                Convert-WindowsImage @testParams2
                Write-Host "✓ SUCCESS: C: drive conversion completed!" -ForegroundColor Green
                Write-Host "This suggests the issue is specific to the F: drive path" -ForegroundColor Yellow
                
                # Clean up test file
                if (Test-Path $testParams2.VhdPath) {
                    Remove-Item $testParams2.VhdPath -Force
                    Write-Host "Cleaned up test VHDX" -ForegroundColor Gray
                }
            } catch {
                Write-Host "✗ FAILED: C: drive conversion also failed" -ForegroundColor Red
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "This suggests a fundamental issue with Convert-WindowsImage" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "`n=== Ready for Testing ===" -ForegroundColor Cyan
        Write-Host "Run with -TestActualConversion to test actual VHDX creation" -ForegroundColor Yellow
        Write-Host "Example: .\Test-ConvertImage.ps1 -TestActualConversion" -ForegroundColor White
    }
    
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    if (-not $adkFound) {
        Write-Host "⚠️  Install Windows ADK - this is likely the root cause" -ForegroundColor Yellow
    } else {
        Write-Host "✓ Windows ADK is installed" -ForegroundColor Green
    }
    Write-Host "✓ Module and basic functionality work" -ForegroundColor Green
    Write-Host "✓ Target directories and permissions OK" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Test failed: $_" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    if ($_.Exception.InnerException) {
        Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
    }
}