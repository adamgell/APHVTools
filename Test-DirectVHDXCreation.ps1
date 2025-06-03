# Direct test of VHDX creation to isolate the exact error
param(
    [string]$VhdPath = "F:\GellOne\.hvtools\tenantVMs\test-direct.vhdx"
)

Write-Host "=== Testing Direct VHDX Creation ===" -ForegroundColor Cyan

# Step 1: Check if file exists and is mounted
Write-Host "`n1. Checking existing VHDX status..." -ForegroundColor Yellow
if (Test-Path $VhdPath) {
    Write-Host "VHDX exists at: $VhdPath" -ForegroundColor Yellow
    try {
        $vhd = Get-VHD -Path $VhdPath -ErrorAction Stop
        Write-Host "VHDX Status:" -ForegroundColor Gray
        Write-Host "  Attached: $($vhd.Attached)" -ForegroundColor Gray
        Write-Host "  Size: $([math]::Round($vhd.Size/1GB, 2)) GB" -ForegroundColor Gray
        
        if ($vhd.Attached) {
            Write-Host "VHDX is mounted. Attempting to dismount..." -ForegroundColor Yellow
            Dismount-VHD -Path $VhdPath -ErrorAction Stop
            Write-Host "✓ VHDX dismounted" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Error checking VHDX: $_" -ForegroundColor Red
    }
    
    # Remove the file
    Write-Host "Removing existing VHDX..." -ForegroundColor Yellow
    Remove-Item -Path $VhdPath -Force -ErrorAction Stop
    Write-Host "✓ Existing VHDX removed" -ForegroundColor Green
}

# Step 2: Check available drive letters
Write-Host "`n2. Checking available drive letters..." -ForegroundColor Yellow
$usedDrives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Name
Write-Host "Used drives: $($usedDrives -join ', ')" -ForegroundColor Gray

$availableLetters = 69..90 | ForEach-Object { [char]$_ } | Where-Object { 
    $_ -notin $usedDrives
}
Write-Host "Available drives: $($availableLetters -join ', ')" -ForegroundColor Green
Write-Host "Will use: Windows=$($availableLetters[0]), System=$($availableLetters[1])" -ForegroundColor Cyan

# Step 3: Try to create VHDX
Write-Host "`n3. Creating VHDX..." -ForegroundColor Yellow
try {
    $vhdParams = @{
        Path = $VhdPath
        SizeBytes = 60GB
        Dynamic = $true
    }
    
    Write-Host "Parameters:" -ForegroundColor Gray
    $vhdParams.GetEnumerator() | ForEach-Object { Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor Gray }
    
    New-VHD @vhdParams -ErrorAction Stop | Out-Null
    Write-Host "✓ VHDX created successfully" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to create VHDX: $_" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    return
}

# Step 4: Try to mount VHDX
Write-Host "`n4. Mounting VHDX..." -ForegroundColor Yellow
try {
    $mounted = Mount-VHD -Path $VhdPath -Passthru -ErrorAction Stop
    Write-Host "✓ VHDX mounted as disk number: $($mounted.Number)" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to mount VHDX: $_" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    
    # Check if it's the "access path" error
    if ($_.Exception.Message -like "*requested access path is already in use*") {
        Write-Host "`nThis error suggests a system-level conflict." -ForegroundColor Yellow
        Write-Host "Possible causes:" -ForegroundColor Yellow
        Write-Host "- Another VHDX is using the same internal mount point" -ForegroundColor White
        Write-Host "- Hyper-V has a stale mount reference" -ForegroundColor White
        Write-Host "- Windows Storage Service needs restart" -ForegroundColor White
        
        Write-Host "`nTry these solutions:" -ForegroundColor Cyan
        Write-Host "1. Restart-Service -Name ShellHWDetection -Force" -ForegroundColor White
        Write-Host "2. Get-VHD | Where-Object Attached | Dismount-VHD" -ForegroundColor White
        Write-Host "3. Restart the Hyper-V Virtual Machine Management service" -ForegroundColor White
        Write-Host "4. Reboot the system" -ForegroundColor White
    }
    return
}

# Step 5: Clean up
Write-Host "`n5. Cleaning up..." -ForegroundColor Yellow
try {
    Dismount-VHD -Path $VhdPath -ErrorAction Stop
    Write-Host "✓ VHDX dismounted" -ForegroundColor Green
    
    Remove-Item -Path $VhdPath -Force -ErrorAction Stop
    Write-Host "✓ Test VHDX removed" -ForegroundColor Green
}
catch {
    Write-Host "Warning during cleanup: $_" -ForegroundColor Yellow
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Green