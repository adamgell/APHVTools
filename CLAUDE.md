# HVTools Configuration for Claude

## Build Commands
- Build module: `./build.ps1 -modulePath ./HVTools -buildLocal`
- Import module: `Import-Module ./HVTools/HVTools.psd1 -Force`
- Reload module: `Remove-Module HVTools -Force; Import-Module ./HVTools/HVTools.psd1 -Force`

## Code Style Guidelines
- **Naming**: 
  - PascalCase for functions and parameters (e.g., `Initialize-HVTools`, `$TenantName`)
  - camelCase for variables (e.g., `$initCfg`, `$cfgPath`)
  - Script-scope variables prefixed with `$script:` (e.g., `$script:hvConfig`)
- **Formatting**: 4-space indentation, use `[cmdletbinding()]` for functions
- **Error Handling**: Use `try/catch` blocks with `Write-LogEntry` for errors
- **Documentation**: Begin functions with comment-based help (synopsis, parameters, examples)
- **Exports**: Place public functions in `/HVTools/Public/` directory
- **Logging**: Use `Write-LogEntry` for consistent logging

## Module Structure
- Root module loads all functions from Public/ and Private/ directories
- Configuration stored in JSON at `$env:USERPROFILE\.hvtoolscfgpath`
- Initialize with `Initialize-HVTools` before using other commands