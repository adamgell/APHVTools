BeforeAll {
    # Import module
    $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module -Name $ModuleRoot -Force
    
    # Mock configuration path for testing
    $TestConfigPath = "TestDrive:\HVToolsConfig.json"
    
    # Setup test configuration
    $TestConfig = @{
        ConfigPath = $TestConfigPath
        Networks = @(
            @{
                VSwitchName = "External Virtual Switch"
                VLanId = 10
            }
        )
        Images = @(
            @{
                ImageName = "Windows11"
                IsoPath = "C:\path\to\windows11.iso"
            }
        )
        Tenants = @()
        Tools = @()
    }
    
    # Mock Get-HVToolsConfig
    Mock -CommandName Get-HVToolsConfig -ModuleName HVTools -MockWith {
        return $TestConfig
    }
    
    # Mock Write-LogEntry
    Mock -CommandName Write-LogEntry -ModuleName HVTools
}

Describe "Add-TenantToConfig" {
    Context "When adding a valid tenant configuration" {
        BeforeAll {
            # Parameters for test
            $TestTenantName = "Contoso"
            $TestImageName = "Windows11"
            $TestAdminUpn = "admin@contoso.com"
        }
        
        It "Should add the tenant to the configuration" {
            # Execute function
            Add-TenantToConfig -TenantName $TestTenantName -ImageName $TestImageName -AdminUpn $TestAdminUpn
            
            # Assertions
            Should -Invoke -CommandName Write-LogEntry -ModuleName HVTools
            Should -Invoke -CommandName Get-HVToolsConfig -ModuleName HVTools
        }
    }
    
    Context "When using an image name that doesn't exist in config" {
        BeforeAll {
            # Parameters for test
            $TestTenantName = "Contoso"
            $TestImageName = "NonExistentImage"
            $TestAdminUpn = "admin@contoso.com"
        }
        
        It "Should throw an error for non-existent image" {
            # Execute and verify exception
            { Add-TenantToConfig -TenantName $TestTenantName -ImageName $TestImageName -AdminUpn $TestAdminUpn } | 
                Should -Throw
        }
    }
    
    Context "When a tenant with the same name already exists" {
        BeforeAll {
            # Add a tenant to the test configuration
            $TestConfig.Tenants = @(
                @{
                    TenantName = "Contoso"
                    ImageName = "Windows11"
                    AdminUpn = "admin@contoso.com"
                }
            )
            
            # Parameters for test
            $TestTenantName = "Contoso" # Same name as existing
            $TestImageName = "Windows11"
            $TestAdminUpn = "admin@contoso.com"
        }
        
        It "Should update the existing tenant" {
            # Execute function
            Add-TenantToConfig -TenantName $TestTenantName -ImageName $TestImageName -AdminUpn $TestAdminUpn
            
            # Assertions
            Should -Invoke -CommandName Write-LogEntry -ModuleName HVTools
            Should -Invoke -CommandName Get-HVToolsConfig -ModuleName HVTools
        }
    }
}