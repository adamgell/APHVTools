function Show-HVToolsConfig {
    <#
    .SYNOPSIS
        Displays detailed HVTools configuration information
    
    .DESCRIPTION
        Shows specific sections of the HVTools configuration with detailed formatting options
    
    .PARAMETER Section
        The configuration section to display: All, Tenants, Images, Network, Tools, Paths
    
    .PARAMETER TenantName
        Filter to show configuration for a specific tenant
    
    .PARAMETER ImageName
        Filter to show configuration for a specific image
    
    .PARAMETER ExportPath
        Export the configuration to a file (JSON or CSV format based on extension)
    
    .EXAMPLE
        Show-HVToolsConfig
        
        Shows all configuration sections
    
    .EXAMPLE
        Show-HVToolsConfig -Section Tenants
        
        Shows only tenant configuration
    
    .EXAMPLE
        Show-HVToolsConfig -TenantName "Contoso"
        
        Shows configuration specific to the Contoso tenant
    
    .EXAMPLE
        Show-HVToolsConfig -ExportPath "C:\Temp\hvconfig.json"
        
        Exports the configuration to a JSON file
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [ValidateSet('All', 'Tenants', 'Images', 'Network', 'Tools', 'Paths', 'Summary')]
        [string]$Section = 'All',
        
        [Parameter()]
        [string]$TenantName,
        
        [Parameter()]
        [string]$ImageName,
        
        [Parameter()]
        [string]$ExportPath
    )
    
    try {
        # Get the raw configuration
        $config = Get-HVToolsConfig -Raw
        
        if (-not $config) {
            throw "Unable to retrieve HVTools configuration"
        }
        
        # Filter by tenant if specified
        if ($TenantName) {
            $tenant = $config.tenantConfig | Where-Object { $_.TenantName -eq $TenantName }
            if (-not $tenant) {
                Write-Warning "Tenant '$TenantName' not found"
                return
            }
            
            Write-Host "`n==== Configuration for Tenant: $TenantName ====" -ForegroundColor Cyan
            Write-Host "Admin UPN: " -NoNewline -ForegroundColor Yellow
            Write-Host $tenant.AdminUpn
            Write-Host "Default Image: " -NoNewline -ForegroundColor Yellow
            Write-Host $tenant.ImageName
            Write-Host "Config Path: " -NoNewline -ForegroundColor Yellow
            Write-Host $tenant.pathToConfig
            
            # Show related image info
            $image = $config.images | Where-Object { $_.imageName -eq $tenant.ImageName }
            if ($image) {
                Write-Host "`nAssociated Image Details:" -ForegroundColor Green
                Write-Host "  ISO: " -NoNewline
                Write-Host (Split-Path $image.imagePath -Leaf) -ForegroundColor White
                Write-Host "  Reference VHDX: " -NoNewline
                Write-Host (Split-Path $image.refImagePath -Leaf) -ForegroundColor White
            }
            
            return
        }
        
        # Filter by image if specified
        if ($ImageName) {
            $image = $config.images | Where-Object { $_.imageName -eq $ImageName }
            if (-not $image) {
                Write-Warning "Image '$ImageName' not found"
                return
            }
            
            Write-Host "`n==== Configuration for Image: $ImageName ====" -ForegroundColor Cyan
            Write-Host "ISO Path: " -ForegroundColor Yellow
            Write-Host "  $($image.imagePath)" -ForegroundColor White
            Write-Host "Reference VHDX: " -ForegroundColor Yellow
            Write-Host "  $($image.refImagePath)" -ForegroundColor White
            
            # Show tenants using this image
            $tenantsUsingImage = $config.tenantConfig | Where-Object { $_.ImageName -eq $ImageName }
            if ($tenantsUsingImage) {
                Write-Host "`nTenants using this image:" -ForegroundColor Green
                $tenantsUsingImage | ForEach-Object {
                    Write-Host "  - $($_.TenantName)" -ForegroundColor White
                }
            }
            
            return
        }
        
        # Display based on section
        switch ($Section) {
            'Summary' {
                Write-Host "`n==== HVTools Configuration Summary ====" -ForegroundColor Cyan
                Write-Host "Configuration File: " -NoNewline -ForegroundColor Yellow
                Write-Host $config.hvConfigPath
                Write-Host "Total Tenants: " -NoNewline -ForegroundColor Yellow
                Write-Host $config.tenantConfig.Count
                Write-Host "Total Images: " -NoNewline -ForegroundColor Yellow
                Write-Host $config.images.Count
                Write-Host "Virtual Switch: " -NoNewline -ForegroundColor Yellow
                Write-Host $config.vSwitchName
                Write-Host "Tools Configured: " -NoNewline -ForegroundColor Yellow
                Write-Host $(if ($config.tools) { "Yes ($($config.tools.Count) tools)" } else { "No" })
            }
            
            'Paths' {
                Write-Host "`n==== Path Configuration ====" -ForegroundColor Cyan
                Write-Host "Configuration File:" -ForegroundColor Yellow
                Write-Host "  $($config.hvConfigPath)" -ForegroundColor White
                Write-Host "VM Storage Path:" -ForegroundColor Yellow
                Write-Host "  $($config.vmPath)" -ForegroundColor White
                Write-Host "Reference VHDX Path:" -ForegroundColor Yellow
                Write-Host "  $(Split-Path ($config.images[0].refImagePath) -Parent)" -ForegroundColor White
            }
            
            'Network' {
                Write-Host "`n==== Network Configuration ====" -ForegroundColor Cyan
                Write-Host "Virtual Switch Name: " -NoNewline -ForegroundColor Yellow
                Write-Host $config.vSwitchName
                if ($config.vLanId) {
                    Write-Host "VLAN ID: " -NoNewline -ForegroundColor Yellow
                    Write-Host $config.vLanId
                }
                else {
                    Write-Host "VLAN: " -NoNewline -ForegroundColor Yellow
                    Write-Host "Not configured" -ForegroundColor DarkGray
                }
            }
            
            'Tenants' {
                Write-Host "`n==== Tenant Configuration ====" -ForegroundColor Cyan
                if ($config.tenantConfig -and $config.tenantConfig.Count -gt 0) {
                    $config.tenantConfig | ForEach-Object {
                        Write-Host "`nTenant: " -NoNewline -ForegroundColor Yellow
                        Write-Host $_.TenantName -ForegroundColor White
                        Write-Host "  Admin UPN: $($_.AdminUpn)"
                        Write-Host "  Default Image: $($_.ImageName)"
                        Write-Host "  Config Path: $(Split-Path $_.pathToConfig -Leaf)"
                    }
                }
                else {
                    Write-Host "No tenants configured" -ForegroundColor Yellow
                }
            }
            
            'Images' {
                Write-Host "`n==== Image Configuration ====" -ForegroundColor Cyan
                if ($config.images -and $config.images.Count -gt 0) {
                    $config.images | ForEach-Object {
                        Write-Host "`nImage: " -NoNewline -ForegroundColor Yellow
                        Write-Host $_.imageName -ForegroundColor White
                        Write-Host "  ISO: $(Split-Path $_.imagePath -Leaf)"
                        Write-Host "  Ref VHDX: $(Split-Path $_.refImagePath -Leaf)"
                        Write-Host "  Full ISO Path: $($_.imagePath)" -ForegroundColor DarkGray
                    }
                }
                else {
                    Write-Host "No images configured" -ForegroundColor Yellow
                }
            }
            
            'Tools' {
                Write-Host "`n==== Troubleshooting Tools ====" -ForegroundColor Cyan
                if ($config.tools -and $config.tools.Count -gt 0) {
                    Write-Host "Configured tools:" -ForegroundColor Yellow
                    $config.tools | ForEach-Object {
                        Write-Host "  - $_" -ForegroundColor White
                    }
                    if ($config.toolsPath) {
                        Write-Host "`nTools Path: " -NoNewline -ForegroundColor Yellow
                        Write-Host $config.toolsPath
                    }
                }
                else {
                    Write-Host "No tools configured" -ForegroundColor Yellow
                }
            }
            
            'All' {
                # Show all sections
                'Summary', 'Paths', 'Network', 'Tenants', 'Images', 'Tools' | ForEach-Object {
                    Show-HVToolsConfig -Section $_
                }
            }
        }
        
        # Export if requested
        if ($ExportPath) {
            $extension = [System.IO.Path]::GetExtension($ExportPath).ToLower()
            
            switch ($extension) {
                '.json' {
                    $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath -Encoding UTF8
                    Write-Host "`nConfiguration exported to: $ExportPath" -ForegroundColor Green
                }
                '.csv' {
                    # Create a flattened view for CSV
                    $flatConfig = @()
                    
                    # Add tenant data
                    $config.tenantConfig | ForEach-Object {
                        $flatConfig += [PSCustomObject]@{
                            Type = 'Tenant'
                            Name = $_.TenantName
                            Value1 = $_.AdminUpn
                            Value2 = $_.ImageName
                            Value3 = $_.pathToConfig
                        }
                    }
                    
                    # Add image data
                    $config.images | ForEach-Object {
                        $flatConfig += [PSCustomObject]@{
                            Type = 'Image'
                            Name = $_.imageName
                            Value1 = $_.imagePath
                            Value2 = $_.refImagePath
                            Value3 = ''
                        }
                    }
                    
                    $flatConfig | Export-Csv -Path $ExportPath -NoTypeInformation
                    Write-Host "`nConfiguration exported to: $ExportPath" -ForegroundColor Green
                }
                default {
                    Write-Warning "Unsupported export format. Use .json or .csv extension"
                }
            }
        }
    }
    catch {
        Write-Warning "Error displaying configuration: $_"
    }
}