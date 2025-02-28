# HVTools PowerShell Module Guide

## Commands
- Import module: `Import-Module HVTools`
- Initialize: `Initialize-HVTools -Path C:\path\to\workspace`
- Configure: 
  - `Add-TenantToConfig`
  - `Add-NetworkToConfig`
  - `Add-ImageToConfig`
  - `Add-ToolsToConfig`
- Create VMs: `New-ClientVM -TenantName "ClientName" -NumberOfVMs 1 -CPUsPerVM 2`

## Code Style
- Follow PowerShell verb-noun function naming (PascalCase): `New-ClientVM`
- Use camelCase for variables: `$clientDetails`
- Use PascalCase for parameters: `$TenantName`
- Include `[CmdletBinding()]` with `SupportsShouldProcess` where appropriate
- Use parameter validation attributes (`[ValidateSet()]`, `[ValidateRange()]`)
- Use 4-space indentation
- Organize code with `#region` and `#endregion`
- Use try/catch for error handling
- Use `Write-LogEntry` for consistent logging
- Place curly braces on same line as control statements