# Simple test script to debug VHDX creation step by step
param(
    [string]$IsoPath = "E:\ISO\en-us_windows_11_business_editions_version_24h2_updated_march_2025_x64_dvd_77837751.iso",
    [int]$Edition = 3,
    [string]$VhdPath = "C:\temp\test-debug.vhdx"
)

Write-Host "=== Testing VHDX Creation Step by Step ===" -ForegroundColor Cyan

try {
    # Ensure target directory exists
    $targetDir = Split-Path $VhdPath -Parent
    if (-not (Test-Path $targetDir)) {
        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
        Write-Host "✓ Created target directory: $targetDir" -ForegroundColor Green
    }

    # Mount ISO and get WIM path
    Write-Host "1. Mounting ISO..." -ForegroundColor Yellow
    $currVol = Get-Volume
    Mount-DiskImage -ImagePath $IsoPath | Out-Null
    $dl = (Get-Volume | Where-Object { $_.DriveLetter -notin $currVol.DriveLetter }).DriveLetter
    $wimPath = "$dl`:\sources\install.wim"
    
    if (-not (Test-Path $wimPath)) {
        throw "WIM file not found at: $wimPath"
    }
    Write-Host "✓ WIM found at: $wimPath" -ForegroundColor Green

    # Create VHDX using diskpart
    Write-Host "2. Creating VHDX with diskpart..." -ForegroundColor Yellow
    $diskpartScript = @"
create vdisk file="$VhdPath" maximum=60000 type=expandable
select vdisk file="$VhdPath"
attach vdisk
convert gpt
create partition efi size=100
format quick fs=fat32 label="System"
assign letter=S
create partition msr size=16
create partition primary
format quick fs=ntfs label="Windows"
assign letter=W
"@
    
    $scriptPath = Join-Path $env:TEMP "test_diskpart.txt"
    $diskpartScript | Out-File -FilePath $scriptPath -Encoding ASCII
    
    Write-Host "Diskpart script:" -ForegroundColor Gray
    Write-Host $diskpartScript -ForegroundColor DarkGray
    
    $result = & diskpart /s $scriptPath
    Write-Host "Diskpart output:" -ForegroundColor Gray
    $result | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    
    if ($LASTEXITCODE -ne 0) {
        throw "Diskpart failed with exit code $LASTEXITCODE"
    }
    
    # Wait and verify drives
    Start-Sleep -Seconds 3
    if (-not (Test-Path "W:\")) {
        throw "W: drive not accessible after diskpart"
    }
    Write-Host "✓ W: drive is accessible" -ForegroundColor Green
    
    # Test DISM command
    Write-Host "3. Testing DISM apply..." -ForegroundColor Yellow
    Write-Host "Command: dism /Apply-Image /ImageFile:`"$wimPath`" /Index:$Edition /ApplyDir:W:\" -ForegroundColor Gray
    
    $dismResult = & dism /Apply-Image /ImageFile:"$wimPath" /Index:$Edition /ApplyDir:W:\
    
    Write-Host "DISM exit code: $LASTEXITCODE" -ForegroundColor Gray
    Write-Host "DISM output:" -ForegroundColor Gray
    $dismResult | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ DISM apply succeeded!" -ForegroundColor Green
        
        # Check what was created
        $windowsDir = Get-ChildItem "W:\" -ErrorAction SilentlyContinue
        Write-Host "Contents of W: drive:" -ForegroundColor Gray
        $windowsDir | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor DarkGray }
        
    } else {
        Write-Host "✗ DISM apply failed" -ForegroundColor Red
        
        # Show DISM log
        $dismLog = "C:\Windows\Logs\DISM\dism.log"
        if (Test-Path $dismLog) {
            Write-Host "Last 10 lines of DISM log:" -ForegroundColor Yellow
            Get-Content $dismLog -Tail 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow }
        }
    }
    
    # Cleanup - detach VHDX
    Write-Host "4. Cleaning up..." -ForegroundColor Yellow
    $detachScript = @"
select vdisk file="$VhdPath"
detach vdisk
"@
    
    $detachScriptPath = Join-Path $env:TEMP "test_detach.txt"
    $detachScript | Out-File -FilePath $detachScriptPath -Encoding ASCII
    & diskpart /s $detachScriptPath | Out-Null
    
    # Remove test files
    Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
    Remove-Item $detachScriptPath -Force -ErrorAction SilentlyContinue
    if (Test-Path $VhdPath) {
        Remove-Item $VhdPath -Force -ErrorAction SilentlyContinue
    }
    
} catch {
    Write-Host "✗ Error: $_" -ForegroundColor Red
} finally {
    # Dismount ISO
    try {
        Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Warning: Could not dismount ISO" -ForegroundColor Yellow
    }
}