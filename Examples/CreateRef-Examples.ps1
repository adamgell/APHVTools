# Examples for using CreateRef.ps1

# Basic usage - creates reference image with auto-generated name
.\CreateRef.ps1 -IsoPath "C:\ISOs\Windows11_24H2.iso"

# Custom image name
.\CreateRef.ps1 -IsoPath "C:\ISOs\Windows10_22H2.iso" -ImageName "Win10-Enterprise"

# Initialize HVTools and create reference image
.\CreateRef.ps1 -IsoPath "E:\ISOs\Windows11.iso" -WorkspacePath "D:\HVTools" -ImageName "Win11-Lab"

# Force overwrite existing reference VHDX
.\CreateRef.ps1 -IsoPath "C:\ISOs\Windows11_24H2.iso" -ImageName "Win11-Updated" -Force

# Test run (WhatIf)
.\CreateRef.ps1 -IsoPath "C:\ISOs\test.iso" -ImageName "TestImage" -WhatIf

# Note: For admin account injection, use New-ClientVM with -CaptureHardwareHash:
# New-ClientVM -TenantName "Test" -OSBuild "Win11-24H2" -NumberOfVMs 1 -CPUsPerVM 2 -CaptureHardwareHash
# This will recreate the reference image with admin account automatically when needed