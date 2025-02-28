BeforeAll {
    # Import module
    $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module -Name $ModuleRoot -Force
    
    # Mock Test-Path for config file existence
    Mock -CommandName Test-Path -ModuleName HVTools -MockWith { return $true }
    
    # Mock Get-Content for reading config file
    Mock -CommandName Get-Content -ModuleName HVTools -MockWith {
        $testConfig = @{
            ConfigPath = "TestPath"
            Networks = @(@{VSwitchName = "External"})
            Images = @(@{ImageName = "Windows11"})
            Tenants = @(@{TenantName = "Contoso"})
            Tools = @(@{ToolName = "CMTrace"})
        } | ConvertTo-Json
        return $testConfig
    }
    
    # Mock Write-LogEntry
    Mock -CommandName Write-LogEntry -ModuleName HVTools
}

Describe "Get-HVToolsConfig" {
    Context "When configuration file exists" {
        It "Should return the configuration" {
            # Execute function
            $config = Get-HVToolsConfig
            
            # Assertions
            $config | Should -Not -BeNullOrEmpty
            $config.Networks | Should -Not -BeNullOrEmpty
            $config.Images | Should -Not -BeNullOrEmpty
            $config.Tenants | Should -Not -BeNullOrEmpty
            $config.Tools | Should -Not -BeNullOrEmpty
            Should -Invoke -CommandName Test-Path -ModuleName HVTools
            Should -Invoke -CommandName Get-Content -ModuleName HVTools
        }
    }
    
    Context "When configuration file does not exist" {
        BeforeAll {
            # Mock Test-Path to return false
            Mock -CommandName Test-Path -ModuleName HVTools -MockWith { return $false }
        }
        
        It "Should return an empty configuration" {
            # Execute function
            $config = Get-HVToolsConfig
            
            # Assertions
            $config | Should -Not -BeNullOrEmpty
            $config.Networks | Should -BeNullOrEmpty
            $config.Images | Should -BeNullOrEmpty
            $config.Tenants | Should -BeNullOrEmpty
            $config.Tools | Should -BeNullOrEmpty
            Should -Invoke -CommandName Test-Path -ModuleName HVTools
        }
    }
}