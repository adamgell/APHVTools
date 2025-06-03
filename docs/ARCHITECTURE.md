# HVTools Architecture

## Overview

HVTools is a PowerShell module designed with a modular architecture that separates concerns and provides a clean API for managing Hyper-V virtual machines with Intune integration.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        User Interface                        │
│                    (PowerShell Console)                      │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                     Public Functions                         │
│  (Initialize-HVTools, New-ClientVM, Add-*ToConfig, etc.)   │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                    Private Functions                         │
│  (New-ClientVHDX, Get-AutopilotPolicy, Write-LogEntry)     │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                   Core Components                            │
├─────────────────┬───────────────┬───────────────────────────┤
│  Configuration  │  VM Creation  │  Intune Integration       │
│    Manager      │    Engine     │      Service              │
└─────────────────┴───────────────┴───────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                 External Dependencies                        │
├─────────────┬────────────┬──────────────┬──────────────────┤
│   Hyper-V   │ Microsoft  │ Windows      │ File System      │
│   Module    │   Graph    │ Autopilot    │                  │
└─────────────┴────────────┴──────────────┴──────────────────┘
```

## Component Details

### 1. Public Functions Layer

This layer provides the user-facing API:

- **Initialize-HVTools**: Sets up the workspace and configuration
- **Add-*ToConfig**: Configuration management functions
- **New-ClientVM**: Main VM creation entry point
- **Get-HVToolsConfig**: Configuration retrieval

### 2. Private Functions Layer

Internal functions that handle specific tasks:

- **New-ClientVHDX**: Creates differencing disks
- **New-ClientDevice**: Generates device details
- **Get-AutopilotPolicy**: Fetches Intune policies
- **Publish-AutoPilotConfig**: Injects configuration
- **Write-LogEntry**: Centralized logging

### 3. Core Components

#### Configuration Manager
- Manages JSON-based configuration
- Stores at `$env:USERPROFILE\.hvtoolscfgpath`
- Handles tenant, network, and image configurations
- Provides validation and persistence

#### VM Creation Engine
- Orchestrates VM creation workflow
- Manages reference VHDX creation
- Handles differencing disk creation
- Configures VM hardware settings

#### Intune Integration Service
- Authenticates with Microsoft Graph
- Fetches Autopilot policies
- Manages device enrollment
- Handles credential storage

## Data Flow

### 1. Initialization Flow
```
User → Initialize-HVTools → Create Directories → Initialize Config → Save to JSON
```

### 2. Configuration Flow
```
User → Add-*ToConfig → Validate Input → Update $script:hvConfig → Persist to JSON
```

### 3. VM Creation Flow
```
User → New-ClientVM
         ├→ Validate Configuration
         ├→ Get/Create Reference VHDX
         ├→ Fetch Autopilot Config (if needed)
         └→ For Each VM:
              ├→ Generate Device Details
              ├→ Create Differencing Disk
              ├→ Inject Autopilot Config
              ├→ Create VM in Hyper-V
              └→ Configure VM Settings
```

## Configuration Structure

### Global Configuration Object
```powershell
$script:hvConfig = @{
    vmPath = "C:\HVTools\VMs"
    referenceVHDXPath = "C:\HVTools\ReferenceVHDX"
    tenantConfig = @()
    networkConfig = @{}
    images = @()
    toolsConfig = @{}
}
```

### Tenant Configuration
```powershell
@{
    tenantName = "Contoso"
    adminUpn = "admin@contoso.com"
    imageName = "Win11-23H2"
    pathToConfig = "C:\HVTools\Contoso"
}
```

### Image Configuration
```powershell
@{
    imageName = "Win11-23H2"
    imagePath = "C:\ISOs\Win11.iso"
    imageIndex = 3  # Edition index
    refVHDX = "C:\HVTools\ReferenceVHDX\Win11-23H2.vhdx"
}
```

## Module Loading

The root module (`HVTools.psm1`) uses dynamic loading:

```powershell
# Load Public Functions
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1)
Foreach ($import in $Public) {
    . $import.fullname
}

# Load Private Functions
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1)
Foreach ($import in $Private) {
    . $import.fullname
}

# Export only Public functions
Export-ModuleMember -Function $Public.Basename
```

## Security Considerations

### Credential Management
- Credentials stored in configuration file
- Uses Windows Data Protection API (DPAPI)
- Per-user encryption
- No plaintext passwords

### Autopilot Configuration
- Fetched dynamically from Intune
- Cached locally per tenant
- Injected into offline VMs
- No sensitive data in VMs

### Access Control
- Requires local admin for Hyper-V
- Requires Intune admin for Autopilot
- Configuration file per-user
- VM files inherit NTFS permissions

## Performance Optimizations

### Reference VHDX
- Created once per image
- Differencing disks for VMs
- Reduces storage requirements
- Faster VM creation

### Parallel Operations
- Multiple VMs created in sequence
- Potential for parallel creation
- Disk operations are bottleneck

### Caching
- Autopilot config cached
- Image details cached
- Reduces API calls

## Extension Points

### Adding New Functions
1. Create in appropriate directory (Public/Private)
2. Follow naming conventions
3. Update module manifest if needed
4. Add help documentation

### Custom Tools Integration
- Tools stored in tenant directory
- Copied during VM creation
- Extensible for custom packages

### Additional Providers
- Current: Intune/Autopilot
- Potential: ConfigMgr, MDT
- Modular design allows expansion

## Error Handling Strategy

### Validation Layers
1. Parameter validation (built-in)
2. Configuration validation
3. Prerequisite checking
4. Runtime validation

### Error Propagation
- Try/catch at function level
- Logging via Write-LogEntry
- Meaningful error messages
- Proper cleanup on failure

### Recovery Mechanisms
- Configuration backup
- VM creation rollback
- Partial success handling
- Manual intervention points

## Future Considerations

### Scalability
- Batch processing improvements
- Async/parallel operations
- Progress reporting
- Queue management

### Extensibility
- Plugin architecture
- Custom providers
- Event hooks
- API endpoints

### Monitoring
- Performance metrics
- Success/failure tracking
- Resource utilization
- Health checks