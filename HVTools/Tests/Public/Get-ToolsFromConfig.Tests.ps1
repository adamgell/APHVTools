BeforeAll {
    # Import module
    $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module -Name $ModuleRoot -Force
    
    # Mock configuration path for testing
    $TestConfigPath = "TestDrive:\HVToolsConfig.json"
    
    # Setup test configuration
    $TestConfig = @{
        ConfigPath = $TestConfigPath
        Networks = @()
        Images = @()
        Tenants = @()
        Tools = @(
            @{
                ToolName = "CMTrace"
                ToolPath = "Tools\CMTrace.exe"
            },
            @{
                ToolName = "Procmon"
                ToolPath = "Tools\Procmon.exe"
            }
        )
    }
    
    # Mock Get-HVToolsConfig
    Mock -CommandName Get-HVToolsConfig -ModuleName HVTools -MockWith {
        return $TestConfig
    }
    
    # Mock Write-LogEntry
    Mock -CommandName Write-LogEntry -ModuleName HVTools
}

Describe "Get-ToolsFromConfig" {
    Context "When tools exist in configuration" {
        It "Should return all configured tools" {
            # Execute function
            $tools = Get-ToolsFromConfig
            
            # Assertions
            $tools | Should -Not -BeNullOrEmpty
            $tools.Count | Should -Be 2
            $tools[0].ToolName | Should -Be "CMTrace"
            $tools[1].ToolName | Should -Be "Procmon"
            Should -Invoke -CommandName Get-HVToolsConfig -ModuleName HVTools
        }
    }
    
    Context "When no tools exist in configuration" {
        BeforeAll {
            # Modify test configuration to have no tools
            $TestConfig.Tools = @()
        }
        
        It "Should return an empty array" {
            # Execute function
            $tools = Get-ToolsFromConfig
            
            # Assertions
            $tools | Should -BeNullOrEmpty
            Should -Invoke -CommandName Get-HVToolsConfig -ModuleName HVTools
        }
    }
}