<#
.SYNOPSIS
    Creates a reference VHDX image from a Windows ISO file using HVTools

.DESCRIPTION
    This script automates the creation of reference VHDX images from Windows ISO files.
    It initializes HVTools (if needed), adds the image to configuration, and creates
    the reference VHDX with optional local admin account injection.

.PARAMETER IsoPath
    Full path to the Windows ISO file

.PARAMETER ImageName
    Friendly name for the image (if not specified, will be generated from ISO filename)

.PARAMETER OutputPath
    Directory where the reference VHDX will be created (default: uses HVTools config)

.PARAMETER WorkspacePath
    Path to initialize HVTools workspace (only used if HVTools not already initialized)

.PARAMETER CreateAdminAccount
    Creates a local admin account in the reference image for automation scenarios

.PARAMETER Force
    Overwrite existing reference VHDX if it exists

.EXAMPLE
    .\CreateRef.ps1 -IsoPath "C:\ISOs\Windows11_24H2.iso"
    
    Creates a reference image using the default naming and paths

.EXAMPLE
    .\CreateRef.ps1 -IsoPath "C:\ISOs\Win10_22H2.iso" -ImageName "Win10-Enterprise" -CreateAdminAccount
    
    Creates a reference image with custom name and admin account injection

.EXAMPLE
    .\CreateRef.ps1 -IsoPath "E:\ISOs\Windows11.iso" -WorkspacePath "D:\HVTools" -Force
    
    Initializes HVTools workspace and creates reference image, overwriting if exists

.NOTES
    Requires HVTools module and administrator privileges
    Hyper-V must be enabled and Hyper-ConvertImage module will be installed if needed
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Full path to Windows ISO file")]
    [ValidateScript({
        if (-not (Test-Path $_)) {
            throw "ISO file not found: $_"
        }
        if ([System.IO.Path]::GetExtension($_) -ne '.iso') {
            throw "File must be an ISO: $_"
        }
        return $true
    })]
    [string]$IsoPath,
    
    [Parameter(Position = 1, HelpMessage = "Friendly name for the image")]
    [string]$ImageName,
    
    [Parameter(HelpMessage = "Directory for reference VHDX output")]
    [string]$OutputPath,
    
    [Parameter(HelpMessage = "HVTools workspace path (for initialization)")]
    [string]$WorkspacePath,
    
    [Parameter(HelpMessage = "Create local admin account in reference image")]
    [switch]$CreateAdminAccount,
    
    [Parameter(HelpMessage = "Overwrite existing reference VHDX")]
    [switch]$Force
)

# Requires Administrator
#Requires -RunAsAdministrator

Write-Host "=== HVTools Reference Image Creator ===" -ForegroundColor Cyan
Write-Host "Creating reference VHDX from: $IsoPath" -ForegroundColor Green

try {
    # Import HVTools module
    Write-Host "`n[1/6] Importing HVTools module..." -ForegroundColor Yellow
    Import-Module HVTools -Force -ErrorAction Stop
    Write-Host "✓ HVTools module imported successfully" -ForegroundColor Green
    
    # Check if HVTools is initialized
    Write-Host "`n[2/6] Checking HVTools initialization..." -ForegroundColor Yellow
    $hvConfig = $null
    try {
        $hvConfig = Get-HVToolsConfig -Raw -ErrorAction SilentlyContinue
    }
    catch {
        # HVTools not initialized
    }
    
    if (-not $hvConfig) {
        if (-not $WorkspacePath) {
            $WorkspacePath = Read-Host "HVTools not initialized. Enter workspace path (e.g., C:\HVTools)"
            if (-not $WorkspacePath) {
                throw "Workspace path is required to initialize HVTools"
            }
        }
        
        Write-Host "Initializing HVTools workspace at: $WorkspacePath" -ForegroundColor Cyan
        Initialize-HVTools -Path $WorkspacePath
        Write-Host "✓ HVTools initialized successfully" -ForegroundColor Green
        
        # Get config after initialization
        $hvConfig = Get-HVToolsConfig -Raw
    } else {
        Write-Host "✓ HVTools already initialized" -ForegroundColor Green
    }
    
    # Generate image name if not provided
    Write-Host "`n[3/6] Preparing image configuration..." -ForegroundColor Yellow
    if (-not $ImageName) {
        $isoBaseName = [System.IO.Path]::GetFileNameWithoutExtension($IsoPath)
        # Clean up the name to make it more user-friendly
        $ImageName = $isoBaseName -replace '_', '-' -replace '\s+', '-'
        Write-Host "Generated image name: $ImageName" -ForegroundColor Cyan
    }
    
    # Determine output path
    if (-not $OutputPath) {
        $referenceDir = Split-Path $hvConfig.images[0].refImagePath -Parent -ErrorAction SilentlyContinue
        if (-not $referenceDir) {
            # Fallback to default structure
            $workspaceRoot = Split-Path $hvConfig.vmPath -Parent
            $referenceDir = Join-Path $workspaceRoot "ReferenceVHDX"
        }
        $OutputPath = $referenceDir
    }
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-Host "Created output directory: $OutputPath" -ForegroundColor Cyan
    }
    
    $vhdxPath = Join-Path $OutputPath "$ImageName.vhdx"
    Write-Host "Reference VHDX will be created at: $vhdxPath" -ForegroundColor Cyan
    
    # Check if reference VHDX already exists
    if ((Test-Path $vhdxPath) -and -not $Force) {
        $overwrite = Read-Host "Reference VHDX already exists. Overwrite? (Y/N)"
        if ($overwrite -ne 'Y' -and $overwrite -ne 'y') {
            Write-Host "Operation cancelled by user" -ForegroundColor Yellow
            return
        }
        $Force = $true
    }
    
    if ($Force -and (Test-Path $vhdxPath)) {
        Write-Host "Removing existing reference VHDX..." -ForegroundColor Yellow
        Remove-Item $vhdxPath -Force
    }
    
    # Add image to HVTools configuration
    Write-Host "`n[4/6] Adding image to HVTools configuration..." -ForegroundColor Yellow
    
    # Check if image already exists in config
    $existingImage = $hvConfig.images | Where-Object { $_.imageName -eq $ImageName }
    if ($existingImage) {
        Write-Host "Image '$ImageName' already exists in configuration, updating..." -ForegroundColor Cyan
        # Remove existing image config (we'll re-add it)
        # Note: This could be improved to update in place, but for simplicity we'll re-add
    }
    
    Add-ImageToConfig -ImageName $ImageName -IsoPath $IsoPath
    Write-Host "✓ Image added to configuration" -ForegroundColor Green
    
    # Create the reference VHDX
    Write-Host "`n[5/6] Creating reference VHDX..." -ForegroundColor Yellow
    if ($CreateAdminAccount) {
        Write-Host "Admin account will be injected into the reference image" -ForegroundColor Cyan
    }
    
    $createParams = @{
        vhdxPath = $vhdxPath
        winIso = $IsoPath
        CreateAdminAccount = $CreateAdminAccount
        Verbose = $VerbosePreference -eq 'Continue'
    }
    
    if ($PSCmdlet.ShouldProcess($vhdxPath, "Create reference VHDX")) {
        New-ClientVHDX @createParams
    }
    
    # Verify creation
    Write-Host "`n[6/6] Verifying reference VHDX creation..." -ForegroundColor Yellow
    if (Test-Path $vhdxPath) {
        $vhdxInfo = Get-Item $vhdxPath
        $sizeGB = [math]::Round($vhdxInfo.Length / 1GB, 2)
        Write-Host "✓ Reference VHDX created successfully!" -ForegroundColor Green
        Write-Host "  Path: $vhdxPath" -ForegroundColor White
        Write-Host "  Size: $sizeGB GB" -ForegroundColor White
        Write-Host "  Created: $($vhdxInfo.CreationTime)" -ForegroundColor White
        
        if ($CreateAdminAccount -and $script:vmAdminCredentials) {
            Write-Host "`n✓ Local admin account injected:" -ForegroundColor Green
            Write-Host "  Username: $($script:vmAdminCredentials.Username)" -ForegroundColor White
            Write-Host "  Password: $($script:vmAdminCredentials.Password)" -ForegroundColor White
            Write-Host "  Note: Save these credentials for VM automation" -ForegroundColor Yellow
        }
        
        # Update HVTools config with the actual path
        Write-Host "`nUpdating HVTools configuration with reference VHDX path..." -ForegroundColor Cyan
        
        # Get updated config and show the image entry
        $updatedConfig = Get-HVToolsConfig -Raw
        $imageEntry = $updatedConfig.images | Where-Object { $_.imageName -eq $ImageName }
        if ($imageEntry) {
            Write-Host "✓ Image configuration updated" -ForegroundColor Green
            Write-Host "  Image Name: $($imageEntry.imageName)" -ForegroundColor White
            Write-Host "  ISO Path: $(Split-Path $imageEntry.imagePath -Leaf)" -ForegroundColor White
            Write-Host "  Reference VHDX: $(Split-Path $imageEntry.refImagePath -Leaf)" -ForegroundColor White
        }
        
        Write-Host "`n=== Reference Image Creation Complete ===" -ForegroundColor Green
        Write-Host "You can now use this image name in New-ClientVM:" -ForegroundColor Cyan
        Write-Host "  New-ClientVM -TenantName 'YourTenant' -OSBuild '$ImageName' -NumberOfVMs 1 -CPUsPerVM 2" -ForegroundColor White
        
        if ($CreateAdminAccount) {
            Write-Host "`nFor hardware hash capture:" -ForegroundColor Cyan
            Write-Host "  New-ClientVM -TenantName 'YourTenant' -OSBuild '$ImageName' -NumberOfVMs 1 -CPUsPerVM 2 -CaptureHardwareHash" -ForegroundColor White
        }
    } else {
        throw "Reference VHDX creation failed - file not found at expected location"
    }
}
catch {
    Write-Host "`n❌ Error creating reference image: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor DarkRed
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    exit 1
}
finally {
    Write-Host "`nScript execution completed." -ForegroundColor Gray
}