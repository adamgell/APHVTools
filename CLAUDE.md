# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## APHVTools PowerShell Module

APHVTools automates the creation and management of Intune-managed virtual machines in Hyper-V. The module creates VMs pre-configured for Windows Autopilot enrollment, supporting multi-tenant scenarios.

## Build and Development Commands

### Building
- Build module locally: `./build.ps1 -modulePath ./APHVTools -buildLocal`
- Build for CI/CD: `./build.ps1 -modulePath ./APHVTools` (uses BUILD_BUILDID env var)

### Module Management
- Import module: `Import-Module ./APHVTools/APHVTools.psd1 -Force`
- Reload module: `Remove-Module APHVTools -Force; Import-Module ./APHVTools/APHVTools.psd1 -Force`
- Test import: `Get-Command -Module APHVTools`

### Common Development Tasks
- Create new public function: Add to `/APHVTools/Public/` directory
- Create new private function: Add to `/APHVTools/Private/` directory
- Update module version: Handled automatically by build.ps1
- Generate release notes: `git log --pretty=format:"- %s" > APHVTools/ReleaseNotes.txt`
- Commit and push to origin each time you finish a file

## Architecture and Key Components

### Module Loading Pattern
The root module (`APHVTools.psm1`) dynamically loads all functions from Public/ and Private/ directories. Public functions are automatically exported, while Private functions remain internal.

### Configuration Management
- Config stored at: `$env:USERPROFILE\.hvtoolscfgpath` (JSON format)
- Global config object: `$script:hvConfig` (loaded by Initialize-HVTools)
- Config structure includes: tenantConfig, networkConfig, images, vmPath, referenceVHDXPath

### VM Creation Workflow
1. `Initialize-HVTools` - Sets up workspace and loads configuration
2. `Add-ImageToConfig` - Registers Windows ISO images and creates reference VHDX
3. `Add-TenantToConfig` - Adds tenant with Intune credentials
4. `New-ClientVM` - Creates VMs with:
   - `New-ClientDevice` - Generates device details and fetches Autopilot config
   - `New-ClientVHDX` - Creates differencing disk from reference VHDX
   - `Publish-AutoPilotConfig` - Injects Autopilot config into VM

### Authentication Flow
- Uses Microsoft Graph for Intune access
- Credentials stored per tenant in config
- Supports both interactive and stored credential authentication

## Code Style Guidelines

### Naming Conventions
- **Functions**: PascalCase verb-noun (e.g., `Initialize-HVTools`, `New-ClientVM`)
- **Parameters**: PascalCase (e.g., `$TenantName`, `$NumberOfVMs`)
- **Variables**: camelCase (e.g., `$clientDetails`, `$vmParams`)
- **Script-scope**: Prefix with `$script:` (e.g., `$script:hvConfig`)

### Function Structure
```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
        Brief description
    .PARAMETER ParameterName
        Parameter description
    .EXAMPLE
        Usage example
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ParameterName
    )
    
    try {
        # Implementation
    }
    catch {
        Write-LogEntry -Message "Error: $_" -Severity 3
        throw
    }
}
```

### Best Practices
- Use `[CmdletBinding()]` with `SupportsShouldProcess` for functions that make changes
- Validate parameters with `[ValidateSet()]`, `[ValidateRange()]`, etc.
- Use `Write-LogEntry` for consistent logging (Severity: 1=Info, 2=Warning, 3=Error)
- Handle errors with try/catch blocks
- Use `#region`/`#endregion` for code organization in large functions
- Check for required modules/features before execution

## Required Dependencies
- PowerShell 5.1+
- Hyper-V PowerShell module
- Microsoft.Graph modules (Authentication, DeviceManagement, Intune)
- Hyper-ConvertImage module
- WindowsAutoPilotIntune module

## Testing Considerations
- Currently no automated tests - consider adding Pester tests
- Test VM creation with `-WhatIf` parameter
- Verify Autopilot config injection using `Get-AutopilotPolicy`
- Check VM network connectivity after creation