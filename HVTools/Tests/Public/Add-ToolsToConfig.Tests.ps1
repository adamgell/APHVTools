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
        Tools = @()
    }
    
    # Mock Get-HVToolsConfig
    Mock -CommandName Get-HVToolsConfig -ModuleName HVTools -MockWith {
        return $TestConfig
    }
    
    # Mock Write-LogEntry
    Mock -CommandName Write-LogEntry -ModuleName HVTools
    
    # Mock Test-Path for tools
    Mock -CommandName Test-Path -MockWith { return $true }
}

Describe "Add-ToolsToConfig" {
    Context "When adding valid tools" {
        BeforeAll {
            # Parameters for test
            $TestToolNames = @("CMTrace", "Autoruns", "Procmon")
        }
        
        It "Should add the tools to the configuration" {
            # Execute function
            Add-ToolsToConfig -ToolNames $TestToolNames
            
            # Assertions
            Should -Invoke -CommandName Write-LogEntry -ModuleName HVTools
            Should -Invoke -CommandName Get-HVToolsConfig -ModuleName HVTools
            Should -Invoke -CommandName Test-Path
        }
    }
    
    Context "When adding a tool that doesn't exist" {
        BeforeAll {
            # Mock Test-Path to return false
            Mock -CommandName Test-Path -MockWith { return $false }
            
            # Parameters for test
            $TestToolNames = @("NonExistentTool")
        }
        
        It "Should throw an error for non-existent tool" {
            # Execute and verify exception
            { Add-ToolsToConfig -ToolNames $TestToolNames } | 
                Should -Throw
        }
    }
    
    Context "When adding tools that are already in config" {
        BeforeAll {
            # Add tools to the test configuration
            $TestConfig.Tools = @(
                @{
                    ToolName = "CMTrace"
                    ToolPath = "Tools\CMTrace.exe"
                }
            )
            
            # Mock Test-Path to return true
            Mock -CommandName Test-Path -MockWith { return $true }
            
            # Parameters for test
            $TestToolNames = @("CMTrace", "Autoruns")
        }
        
        It "Should only add the new tools to the configuration" {
            # Execute function
            Add-ToolsToConfig -ToolNames $TestToolNames
            
            # Assertions
            Should -Invoke -CommandName Write-LogEntry -ModuleName HVTools
            Should -Invoke -CommandName Get-HVToolsConfig -ModuleName HVTools
        }
    }
}