BeforeAll {
    # Import module
    $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module -Name $ModuleRoot -Force
    
    # Mock Test-Path
    Mock -CommandName Test-Path -ModuleName HVTools -ParameterFilter { $Path -like "*HVToolsConfig.json" } -MockWith { return $false }
    Mock -CommandName Test-Path -ModuleName HVTools -ParameterFilter { $Path -notlike "*HVToolsConfig.json" } -MockWith { return $true }
    
    # Mock New-Item
    Mock -CommandName New-Item -ModuleName HVTools
    
    # Mock Set-Content
    Mock -CommandName Set-Content -ModuleName HVTools
    
    # Mock Write-LogEntry
    Mock -CommandName Write-LogEntry -ModuleName HVTools
}

Describe "Initialize-HVTools" {
    Context "When initializing with valid path" {
        BeforeAll {
            # Parameters for test
            $TestPath = "C:\TestPath"
        }
        
        It "Should create configuration with the specified path" {
            # Execute function
            Initialize-HVTools -Path $TestPath
            
            # Assertions
            Should -Invoke -CommandName Test-Path -ModuleName HVTools
            Should -Invoke -CommandName New-Item -ModuleName HVTools
            Should -Invoke -CommandName Set-Content -ModuleName HVTools
            Should -Invoke -CommandName Write-LogEntry -ModuleName HVTools
        }
    }
    
    Context "When initializing with Reset parameter" {
        BeforeAll {
            # Parameters for test
            $TestPath = "C:\TestPath"
            
            # Mock Test-Path to return true for config file
            Mock -CommandName Test-Path -ModuleName HVTools -ParameterFilter { $Path -like "*HVToolsConfig.json" } -MockWith { return $true }
        }
        
        It "Should reset the existing configuration" {
            # Execute function
            Initialize-HVTools -Path $TestPath -Reset
            
            # Assertions
            Should -Invoke -CommandName Test-Path -ModuleName HVTools
            Should -Invoke -CommandName Set-Content -ModuleName HVTools
            Should -Invoke -CommandName Write-LogEntry -ModuleName HVTools
        }
    }
    
    Context "When path is invalid" {
        BeforeAll {
            # Parameters for test
            $TestPath = "X:\NonExistentPath"
            
            # Mock Test-Path to return false for path
            Mock -CommandName Test-Path -ModuleName HVTools -MockWith { return $false }
        }
        
        It "Should throw an error for invalid path" {
            # Execute and verify exception
            { Initialize-HVTools -Path $TestPath } | 
                Should -Throw
        }
    }
}