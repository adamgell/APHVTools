# Debug script to test the CaptureHardwareHash parameter

Import-Module HVTools -Force

# Test with a simple VM creation with verbose output
Write-Host "Testing CaptureHardwareHash parameter..." -ForegroundColor Cyan

# Let's test with WhatIf first to see the flow
Write-Host "`nTesting with -WhatIf:" -ForegroundColor Yellow
New-ClientVM -TenantName "HCHB" -OSBuild "Win11_24H2" -NumberOfVMs 1 -CPUsPerVM 1 -VMMemory 2GB -SkipAutoPilot -CaptureHardwareHash -WhatIf -Verbose

Write-Host "`nChecking if Get-VMHardwareHash function is available:" -ForegroundColor Yellow
$function = Get-Command Get-VMHardwareHash -ErrorAction SilentlyContinue
if ($function) {
    Write-Host "✓ Get-VMHardwareHash function is available" -ForegroundColor Green
} else {
    Write-Host "✗ Get-VMHardwareHash function is NOT available" -ForegroundColor Red
}

Write-Host "`nChecking current VMs:" -ForegroundColor Yellow
Get-VM | Where-Object { $_.Name -like "*HCHB*" } | Select-Object Name, State, CreationTime