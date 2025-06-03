<#
.SYNOPSIS
    Creates a reference VHDX image from a Windows ISO file using HVTools

.DESCRIPTION
    This script automates the creation of reference VHDX images from Windows ISO files.
    It initializes HVTools (if needed) and adds the image to configuration, which automatically
    creates the reference VHDX.

.PARAMETER IsoPath
    Full path to the Windows ISO file

.PARAMETER ImageName
    Friendly name for the image (if not specified, will be generated from ISO filename)

.PARAMETER WorkspacePath
    Path to initialize HVTools workspace (only used if HVTools not already initialized)

.PARAMETER Force
    Recreate reference VHDX if it already exists

.EXAMPLE
    .\CreateRef.ps1 -IsoPath "C:\ISOs\Windows11_24H2.iso"
    
    Creates a reference image using the default naming

.EXAMPLE
    .\CreateRef.ps1 -IsoPath "C:\ISOs\Windows10_22H2.iso" -ImageName "Win10-Enterprise"
    
    Creates a reference image with custom name

.EXAMPLE
    .\CreateRef.ps1 -IsoPath "E:\ISOs\Windows11.iso" -WorkspacePath "D:\HVTools" -Force
    
    Initializes HVTools workspace and creates reference image, overwriting if exists

.NOTES
    Requires HVTools module and administrator privileges
    For admin account injection, use New-ClientVM with -CaptureHardwareHash switch
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
    
    [Parameter(HelpMessage = "HVTools workspace path (for initialization)")]
    [string]$WorkspacePath,
    
    [Parameter(HelpMessage = "Recreate reference VHDX if it exists")]
    [switch]$Force,
    
    [Parameter(HelpMessage = "Enable debug output for detailed troubleshooting")]
    [switch]$Debug
)

# Requires Administrator
#Requires -RunAsAdministrator

# Set debug preference (Verbose is handled automatically by CmdletBinding)
if ($Debug) {
    $DebugPreference = 'Continue'
    # Also enable verbose when debug is enabled
    $VerbosePreference = 'Continue'
}

Write-Host "=== HVTools Reference Image Creator ===" -ForegroundColor Cyan
Write-Host "Creating reference VHDX from: $IsoPath" -ForegroundColor Green

# Show debug information if requested
if ($Debug) {
    Write-Host "`n=== Debug Information ===" -ForegroundColor Magenta
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "OS Version: $([System.Environment]::OSVersion.VersionString)" -ForegroundColor Gray
    Write-Host "Current User: $($env:USERNAME)" -ForegroundColor Gray
    Write-Host "Working Directory: $(Get-Location)" -ForegroundColor Gray
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    Write-Host "Running as Admin: $isAdmin" -ForegroundColor $(if($isAdmin){'Green'}else{'Red'})
    Write-Host "=========================" -ForegroundColor Magenta
}

try {
    # Import HVTools module
    Write-Host "`n[1/5] Importing HVTools module..." -ForegroundColor Yellow
    Import-Module HVTools -Force -ErrorAction Stop
    Write-Host "✓ HVTools module imported successfully" -ForegroundColor Green
    
    # Check if HVTools is initialized
    Write-Host "`n[2/5] Checking HVTools initialization..." -ForegroundColor Yellow
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
        if ($PSCmdlet.ShouldProcess($WorkspacePath, "Initialize HVTools")) {
            Initialize-HVTools -Path $WorkspacePath
        }
        Write-Host "✓ HVTools initialized successfully" -ForegroundColor Green
        
        # Get config after initialization
        $hvConfig = Get-HVToolsConfig -Raw
    } else {
        Write-Host "✓ HVTools already initialized" -ForegroundColor Green
    }
    
    # Generate image name if not provided
    Write-Host "`n[3/5] Preparing image configuration..." -ForegroundColor Yellow
    if (-not $ImageName) {
        $isoBaseName = [System.IO.Path]::GetFileNameWithoutExtension($IsoPath)
        # Clean up the name to make it more user-friendly
        $ImageName = $isoBaseName -replace '_', '-' -replace '\s+', '-'
        Write-Host "Generated image name: $ImageName" -ForegroundColor Cyan
    }
    
    # Check if image already exists
    $existingImage = $hvConfig.images | Where-Object { $_.imageName -eq $ImageName }
    if ($existingImage) {
        Write-Host "Image '$ImageName' already exists in configuration" -ForegroundColor Yellow
        
        if ((Test-Path $existingImage.refImagePath) -and -not $Force) {
            Write-Host "Reference VHDX already exists at: $($existingImage.refImagePath)" -ForegroundColor Yellow
            $proceed = Read-Host "Reference image already exists. Recreate? (Y/N)"
            if ($proceed -ne 'Y' -and $proceed -ne 'y') {
                Write-Host "`n=== Using Existing Reference Image ===" -ForegroundColor Green
                $vhdxInfo = Get-Item $existingImage.refImagePath
                $sizeGB = [math]::Round($vhdxInfo.Length / 1GB, 2)
                Write-Host "Path: $($existingImage.refImagePath)" -ForegroundColor White
                Write-Host "Size: $sizeGB GB" -ForegroundColor White
                Write-Host "Created: $($vhdxInfo.CreationTime)" -ForegroundColor White
                
                Write-Host "`nYou can use this image name in New-ClientVM:" -ForegroundColor Cyan
                Write-Host "  New-ClientVM -TenantName 'YourTenant' -OSBuild '$ImageName' -NumberOfVMs 1 -CPUsPerVM 2" -ForegroundColor White
                return
            }
            $Force = $true
        }
        
        if ($Force) {
            Write-Host "Removing existing image configuration and reference VHDX..." -ForegroundColor Yellow
            
            # Remove from configuration
            $script:hvConfig.images = @($hvConfig.images | Where-Object { $_.imageName -ne $ImageName })
            $script:hvConfig | ConvertTo-Json -Depth 20 | Out-File -FilePath $hvConfig.hvConfigPath -Encoding ascii -Force
            
            # Remove reference VHDX if it exists
            if (Test-Path $existingImage.refImagePath) {
                Remove-Item $existingImage.refImagePath -Force
                Write-Host "Removed existing reference VHDX" -ForegroundColor Yellow
            }
        }
    }
    
    Write-Host "Reference VHDX will be created during image addition..." -ForegroundColor Cyan
    
    # Add image to configuration (this automatically creates the reference VHDX)
    Write-Host "`n[4/5] Adding image to HVTools configuration..." -ForegroundColor Yellow
    Write-Host "Note: This will prompt for Windows edition selection and then create the reference VHDX" -ForegroundColor Cyan
    
    if ($Debug) {
        Write-Host "`nDEBUG - Before Add-ImageToConfig:" -ForegroundColor Magenta
        Write-Host "  Image Name: $ImageName" -ForegroundColor Gray
        Write-Host "  ISO Path: $IsoPath" -ForegroundColor Gray
        Write-Host "  ISO Exists: $(Test-Path $IsoPath)" -ForegroundColor Gray
        Write-Host "  ISO Size: $([math]::Round((Get-Item $IsoPath).Length / 1GB, 2)) GB" -ForegroundColor Gray
        
        # Check Hyper-ConvertImage module status
        $hyperConvertModule = Get-Module -Name Hyper-ConvertImage
        if ($hyperConvertModule) {
            Write-Host "  Hyper-ConvertImage Module: Loaded" -ForegroundColor Green
            Write-Host "  Module Path: $($hyperConvertModule.Path)" -ForegroundColor Gray
        } else {
            Write-Host "  Hyper-ConvertImage Module: NOT loaded" -ForegroundColor Red
        }
        
        # Check Convert-WindowsImage availability
        $convertCmd = Get-Command Convert-WindowsImage -ErrorAction SilentlyContinue
        if ($convertCmd) {
            Write-Host "  Convert-WindowsImage: Available" -ForegroundColor Green
            Write-Host "  Command Source: $($convertCmd.Source)" -ForegroundColor Gray
        } else {
            Write-Host "  Convert-WindowsImage: NOT available" -ForegroundColor Red
        }
    }
    
    if ($PSCmdlet.ShouldProcess($ImageName, "Add image to configuration and create reference VHDX")) {
        try {
            # Enable verbose output for Add-ImageToConfig if debug is enabled or verbose is on
            if ($Debug -or $VerbosePreference -eq 'Continue') {
                $oldVerbosePreference = $VerbosePreference
                $VerbosePreference = 'Continue'
            }
            
            Add-ImageToConfig -ImageName $ImageName -IsoPath $IsoPath
            
            if ($Debug) {
                Write-Host "`nDEBUG - After Add-ImageToConfig attempt:" -ForegroundColor Magenta
                # Check if the image was added to config
                $updatedConfig = Get-HVToolsConfig -Raw -ErrorAction SilentlyContinue
                $addedImage = $updatedConfig.images | Where-Object { $_.imageName -eq $ImageName }
                if ($addedImage) {
                    Write-Host "  Image added to config: YES" -ForegroundColor Green
                    Write-Host "  Expected VHDX path: $($addedImage.refImagePath)" -ForegroundColor Gray
                    Write-Host "  VHDX exists: $(Test-Path $addedImage.refImagePath)" -ForegroundColor $(if(Test-Path $addedImage.refImagePath){'Green'}else{'Red'})
                } else {
                    Write-Host "  Image added to config: NO" -ForegroundColor Red
                }
            }
        }
        catch {
            Write-Host "`nERROR in Add-ImageToConfig:" -ForegroundColor Red
            Write-Host "  Message: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            
            if ($_.Exception.InnerException) {
                Write-Host "  Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
            }
            
            Write-Host "  Stack Trace:" -ForegroundColor Red
            Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
            
            throw
        }
        finally {
            if ($oldVerbosePreference) {
                $VerbosePreference = $oldVerbosePreference
            }
        }
    }
    
    # Verify creation
    Write-Host "`n[5/5] Verifying reference VHDX creation..." -ForegroundColor Yellow
    
    # Get updated configuration
    $updatedConfig = Get-HVToolsConfig -Raw
    $imageEntry = $updatedConfig.images | Where-Object { $_.imageName -eq $ImageName }
    
    if ($imageEntry -and (Test-Path $imageEntry.refImagePath)) {
        $vhdxInfo = Get-Item $imageEntry.refImagePath
        $sizeGB = [math]::Round($vhdxInfo.Length / 1GB, 2)
        
        Write-Host "✓ Reference VHDX created successfully!" -ForegroundColor Green
        Write-Host "  Image Name: $($imageEntry.imageName)" -ForegroundColor White
        Write-Host "  ISO Path: $(Split-Path $imageEntry.imagePath -Leaf)" -ForegroundColor White
        Write-Host "  Reference VHDX: $($imageEntry.refImagePath)" -ForegroundColor White
        Write-Host "  Size: $sizeGB GB" -ForegroundColor White
        Write-Host "  Created: $($vhdxInfo.CreationTime)" -ForegroundColor White
        
        Write-Host "`n=== Reference Image Creation Complete ===" -ForegroundColor Green
        Write-Host "You can now use this image name in New-ClientVM:" -ForegroundColor Cyan
        Write-Host "  New-ClientVM -TenantName 'YourTenant' -OSBuild '$ImageName' -NumberOfVMs 1 -CPUsPerVM 2" -ForegroundColor White
        
        Write-Host "`nFor hardware hash capture with auto-injected admin account:" -ForegroundColor Cyan
        Write-Host "  New-ClientVM -TenantName 'YourTenant' -OSBuild '$ImageName' -NumberOfVMs 1 -CPUsPerVM 2 -CaptureHardwareHash" -ForegroundColor White
        Write-Host "  (This will recreate the reference image with admin account injection)" -ForegroundColor DarkGray
        
    } else {
        throw "Reference VHDX creation failed or file not found"
    }
}
catch {
    Write-Host "`n❌ Error creating reference image: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ScriptStackTrace) {
        Write-Host "Stack trace:" -ForegroundColor DarkRed
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    }
    exit 1
}
finally {
    Write-Host "`nScript execution completed." -ForegroundColor Gray
}