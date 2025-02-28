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
}

Describe "Add-ImageToConfig" {
    Context "When adding an ISO image" {
        BeforeAll {
            # Mock Test-Path to return true for ISO
            Mock -CommandName Test-Path -MockWith { return $true }
            
            # Parameters for test
            $TestImageName = "Windows11"
            $TestIsoPath = "C:\path\to\windows11.iso"
        }
        
        It "Should add the image to the configuration" {
            # Execute function
            Add-ImageToConfig -ImageName $TestImageName -IsoPath $TestIsoPath
            
            # Assertions
            Should -Invoke -CommandName Write-LogEntry -ModuleName HVTools
            Should -Invoke -CommandName Get-HVToolsConfig -ModuleName HVTools
        }
    }
    
    Context "When adding a reference VHDX image" {
        BeforeAll {
            # Mock Test-Path to return true for VHDX
            Mock -CommandName Test-Path -MockWith { return $true }
            
            # Parameters for test
            $TestImageName = "Windows10"
            $TestVHDXPath = "C:\path\to\windows10.vhdx"
        }
        
        It "Should add the VHDX image to the configuration" {
            # Execute function
            Add-ImageToConfig -ImageName $TestImageName -ReferenceVHDX $TestVHDXPath
            
            # Assertions
            Should -Invoke -CommandName Write-LogEntry -ModuleName HVTools
            Should -Invoke -CommandName Get-HVToolsConfig -ModuleName HVTools
        }
    }
    
    Context "When providing invalid paths" {
        BeforeAll {
            # Mock Test-Path to return false
            Mock -CommandName Test-Path -MockWith { return $false }
            
            # Parameters for test
            $TestImageName = "Windows11"
            $TestIsoPath = "C:\path\to\nonexistent.iso"
        }
        
        It "Should throw an error when file does not exist" {
            # Execute and verify exception
            { Add-ImageToConfig -ImageName $TestImageName -IsoPath $TestIsoPath } | 
                Should -Throw
        }
    }
}