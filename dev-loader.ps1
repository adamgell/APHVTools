# dev-loader.ps1
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$ModulePath = $PSScriptRoot
)

# Get public and private function definitions
$Public = @(Get-ChildItem -Path $ModulePath\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $ModulePath\Private\*.ps1 -ErrorAction SilentlyContinue)

# Import module config if it exists
$cfg = Get-Content "$env:USERPROFILE\.hvtoolscfgpath" -ErrorAction SilentlyContinue
if ($cfg) {
    $script:hvConfig = if (Get-Content -Path $cfg -raw -ErrorAction SilentlyContinue) {
        Get-Content -Path $cfg -raw -ErrorAction SilentlyContinue | ConvertFrom-Json
    }
}

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
        Write-Host "Imported $($import.FullName)" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to import function $($import.FullName): $_"
    }
}

# Register argument completers
$tenantFinder = {
    param($commandName, $parameterName, $stringMatch)
    if ($script:hvConfig) {
        $script:hvConfig.tenantConfig |
            Where-Object { $_.TenantName -like "$stringMatch*" } |
            Select-Object -ExpandProperty TenantName |
            ForEach-Object { $_ }
    }
}
Register-ArgumentCompleter -CommandName New-ClientVM -ParameterName TenantName -ScriptBlock $tenantFinder

$vLan = {
    param($commandName, $parameterName, $stringMatch)
    Get-VMSwitch |
        Where-Object { $_.Name -like "$stringMatch*" } |
        Select-Object -ExpandProperty Name
}
Register-ArgumentCompleter -CommandName Add-NetworkToConfig -ParameterName VSwitchName -ScriptBlock $vLan

$win10Builds = {
    param($commandName, $parameterName, $stringMatch)
    if ($script:hvConfig) {
        $script:hvConfig.Images |
            Where-Object { $_.imageName -like "$stringMatch*" } |
            Select-Object -ExpandProperty imageName
    }
}
Register-ArgumentCompleter -CommandName Add-TenantToConfig -ParameterName ImageName -ScriptBlock $win10Builds
Register-ArgumentCompleter -CommandName New-ClientVM -ParameterName OSBuild -ScriptBlock $win10Builds

Write-Host "`nDevelopment version loaded successfully!" -ForegroundColor Cyan
Write-Host "Available functions:" -ForegroundColor Yellow
$Public.BaseName | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }