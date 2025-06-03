# Test script to verify hardware hash capture functionality

# Import the module
Import-Module HVTools -Force

# Check if the VM exists
$vmName = "HCHB_2"
$vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue

if ($vm) {
    Write-Host "VM '$vmName' found. State: $($vm.State)" -ForegroundColor Green
    
    # Try to capture hardware hash directly
    Write-Host "Testing direct hardware hash capture..." -ForegroundColor Cyan
    
    $tenantPath = "F:\GellOne\.hvtools\tenantVMs\HCHB"
    
    try {
        # Test the Get-VMHardwareHash function directly
        Write-Host "Calling Get-VMHardwareHash..." -ForegroundColor Yellow
        
        # First, let's start the VM if it's not running
        if ($vm.State -ne 'Running') {
            Write-Host "Starting VM..." -ForegroundColor Yellow
            Start-VM -Name $vmName
            Start-Sleep -Seconds 10
        }
        
        # Create test credential (you'll need to modify this)
        Write-Host "Note: You'll need VM credentials to test this." -ForegroundColor Yellow
        Write-Host "The VM needs to complete OOBE first." -ForegroundColor Yellow
        
        # Just test if the function exists and can be called
        $function = Get-Command Get-VMHardwareHash -ErrorAction SilentlyContinue
        if ($function) {
            Write-Host "Get-VMHardwareHash function found!" -ForegroundColor Green
        } else {
            Write-Host "Get-VMHardwareHash function NOT found!" -ForegroundColor Red
        }
        
    }
    catch {
        Write-Host "Error: $_" -ForegroundColor Red
    }
} else {
    Write-Host "VM '$vmName' not found!" -ForegroundColor Red
    Write-Host "Available VMs:" -ForegroundColor Yellow
    Get-VM | Where-Object { $_.Name -like "*HCHB*" } | Select-Object Name, State
}