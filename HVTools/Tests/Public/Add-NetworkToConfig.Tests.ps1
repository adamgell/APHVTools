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
    
    # Mock Get-VMSwitch
    Mock -CommandName Get-VMSwitch -MockWith {
        return @(
            [PSCustomObject]@{
                Name = "External Virtual Switch"
                SwitchType = "External"
            }
        )
    }
}

Describe "Add-NetworkToConfig" {
    Context "When adding a valid network configuration" {
        BeforeAll {
            # Parameters for test
            $TestVSwitchName = "External Virtual Switch"
            $TestVLanId = 10
        }
        
        It "Should add the network to the configuration" {
            # Execute function
            Add-NetworkToConfig -VSwitchName $TestVSwitchName -VLanId $TestVLanId
            
            # Assertions
            Should -Invoke -CommandName Write-LogEntry -ModuleName HVTools
            Should -Invoke -CommandName Get-HVToolsConfig -ModuleName HVTools
            Should -Invoke -CommandName Get-VMSwitch
        }
    }
    
    Context "When using a switch name that doesn't exist" {
        BeforeAll {
            # Mock Get-VMSwitch to return empty result
            Mock -CommandName Get-VMSwitch -MockWith { return $null }
            
            # Parameters for test
            $TestVSwitchName = "NonExistent Switch"
        }
        
        It "Should throw an error for non-existent switch" {
            # Execute and verify exception
            { Add-NetworkToConfig -VSwitchName $TestVSwitchName } | 
                Should -Throw
        }
    }
    
    Context "When adding a network with VLAN ID" {
        BeforeAll {
            # Parameters for test
            $TestVSwitchName = "External Virtual Switch"
            $TestVLanId = 100
        }
        
        It "Should add the network with VLAN ID to the configuration" {
            # Execute function
            Add-NetworkToConfig -VSwitchName $TestVSwitchName -VLanId $TestVLanId
            
            # Assertions
            Should -Invoke -CommandName Write-LogEntry -ModuleName HVTools
            Should -Invoke -CommandName Get-HVToolsConfig -ModuleName HVTools
        }
    }
}