# Examples for using CreateRef.ps1

# Basic usage - creates reference image with auto-generated name
.\CreateRef.ps1 -IsoPath "C:\ISOs\Windows11_24H2.iso"

# Custom image name
.\CreateRef.ps1 -IsoPath "C:\ISOs\Windows10_22H2.iso" -ImageName "Win10-Enterprise"

# With admin account injection for automation
.\CreateRef.ps1 -IsoPath "C:\ISOs\Windows11_23H2.iso" -ImageName "Win11-AutoHash" -CreateAdminAccount

# Initialize HVTools and create reference image
.\CreateRef.ps1 -IsoPath "E:\ISOs\Windows11.iso" -WorkspacePath "D:\HVTools" -ImageName "Win11-Lab"

# Force overwrite existing reference VHDX
.\CreateRef.ps1 -IsoPath "C:\ISOs\Windows11_24H2.iso" -ImageName "Win11-Updated" -Force

# Custom output location with admin account
.\CreateRef.ps1 -IsoPath "C:\ISOs\Windows11.iso" -ImageName "Win11-Custom" -OutputPath "D:\ReferenceImages" -CreateAdminAccount

# Test run (WhatIf)
.\CreateRef.ps1 -IsoPath "C:\ISOs\test.iso" -ImageName "TestImage" -WhatIf