function Get-APHVToolsConfig {
    <#
    .SYNOPSIS
            Gets the APHVTools configuration with improved formatting

    .DESCRIPTION
    Retrieves and displays the APHVTools configuration in an organized, readable format

    .PARAMETER Raw
        Returns the raw configuration object without formatting

        .EXAMPLE
    Get-APHVToolsConfig

    Displays the configuration in a formatted view

    .EXAMPLE
    Get-APHVToolsConfig -Raw

        Returns the raw configuration object
    #>
    [cmdletbinding()]
    param (
        [switch]$Raw
    )
    try {
        if ($script:hvConfig) {
            $script:hvConfig = (get-content -Path "$(get-content "$env:USERPROFILE\.hvtoolscfgpath" -ErrorAction SilentlyContinue)" -raw -ErrorAction SilentlyContinue | ConvertFrom-Json)

            if ($Raw) {
                return $script:hvConfig
            }

            # Create formatted output
            Write-Host "`n==== APHVTools Configuration ====" -ForegroundColor Cyan
            Write-Host "Configuration Path: " -NoNewline -ForegroundColor Yellow
            Write-Host $script:hvConfig.hvConfigPath

            Write-Host "`nVM Storage Path: " -NoNewline -ForegroundColor Yellow
            Write-Host $script:hvConfig.vmPath

            # Network Configuration
            Write-Host "`n---- Network Configuration ----" -ForegroundColor Green
            Write-Host "Virtual Switch: " -NoNewline
            Write-Host $script:hvConfig.vSwitchName -ForegroundColor White
            if ($script:hvConfig.vLanId) {
                Write-Host "VLAN ID: " -NoNewline
                Write-Host $script:hvConfig.vLanId -ForegroundColor White
            }

            # Tenant Information
            Write-Host "`n---- Tenant Configuration ----" -ForegroundColor Green
            if ($script:hvConfig.tenantConfig -and $script:hvConfig.tenantConfig.Count -gt 0) {
                $tenantTable = $script:hvConfig.tenantConfig | ForEach-Object {
                    [PSCustomObject]@{
                        TenantName = $_.TenantName
                        AdminUPN = $_.AdminUpn
                        DefaultImage = $_.ImageName
                    }
                }
                $tenantTable | Format-Table -AutoSize | Out-String | Write-Host
            }
            else {
                Write-Host "No tenants configured" -ForegroundColor Yellow
            }

            # Image Information
            Write-Host "---- Image Configuration ----" -ForegroundColor Green
            if ($script:hvConfig.images -and $script:hvConfig.images.Count -gt 0) {
                $imageTable = $script:hvConfig.images | ForEach-Object {
                    $isoBasename = Split-Path $_.imagePath -Leaf
                    $isoDirectory = Split-Path $_.imagePath -Parent

                    # Truncate directory path if too long, keeping the beginning
                    $displayDirectory = if ($isoDirectory.Length -gt 30) {
                        $isoDirectory.Substring(0, 27) + "..."
                    } else {
                        $isoDirectory
                    }

                    [PSCustomObject]@{
                        ImageName = $_.imageName
                        ISODirectory = $displayDirectory
                        ISOFile = $isoBasename
                        RefVHDX = Split-Path $_.refImagePath -Leaf
                    }
                }
                $imageTable | Format-Table -AutoSize | Out-String | Write-Host
            }
            else {
                Write-Host "No images configured" -ForegroundColor Yellow
            }

            # Tools Information
            Write-Host "---- Troubleshooting Tools ----" -ForegroundColor Green
            if ($script:hvConfig.tools -and $script:hvConfig.tools.Count -gt 0) {
                Write-Host "Available tools: " -NoNewline
                Write-Host ($script:hvConfig.tools -join ", ") -ForegroundColor White
            }
            else {
                Write-Host "No tools configured" -ForegroundColor Yellow
            }

            Write-Host "`n===============================" -ForegroundColor Cyan

            # Return a summary object for pipeline use
            $summary = [PSCustomObject]@{
                ConfigPath = $script:hvConfig.hvConfigPath
                VMPath = $script:hvConfig.vmPath
                VirtualSwitch = $script:hvConfig.vSwitchName
                VLANId = $script:hvConfig.vLanId
                TenantCount = @($script:hvConfig.tenantConfig).Count
                ImageCount = @($script:hvConfig.images).Count
                ToolCount = @($script:hvConfig.tools).Count
            }

            return $summary
        }
        else {
            throw "Couldnt find APHVTools configuration file - please run Initialize-APHVTools to create the configuration file."
        }
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}