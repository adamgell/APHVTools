BeforeAll {
    # Import module
    $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module -Name $ModuleRoot -Force
    
    # Mock configuration
    $TestConfig = @{
        ConfigPath = "TestPath"
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
        Tenants = @(
            @{
                TenantName = "Contoso"
                ImageName = "Windows11"
                AdminUpn = "admin@contoso.com"
            }
        )
        Tools = @()
    }
    
    # Mock Get-HVToolsConfig
    Mock -CommandName Get-HVToolsConfig -ModuleName HVTools -MockWith {
        return $TestConfig
    }
    
    # Mock Write-LogEntry
    Mock -CommandName Write-LogEntry -ModuleName HVTools
    
    # Mock New-ClientDevice (Private function)
    Mock -CommandName New-ClientDevice -ModuleName HVTools
    
    # Mock New-ClientVHDX (Private function)
    Mock -CommandName New-ClientVHDX -ModuleName HVTools
    
    # Mock other Hyper-V cmdlets
    Mock -CommandName New-VM -ModuleName HVTools
    Mock -CommandName Set-VMMemory -ModuleName HVTools
    Mock -CommandName Set-VMProcessor -ModuleName HVTools
    Mock -CommandName Add-VMNetworkAdapter -ModuleName HVTools
    Mock -CommandName Connect-VMNetworkAdapter -ModuleName HVTools
    Mock -CommandName Start-VM -ModuleName HVTools
}

Describe "New-ClientVM" {
    Context "When creating a new VM with valid parameters" {
        BeforeAll {
            # Parameters for test
            $TestTenantName = "Contoso"
            $TestNumberOfVMs = 1
            $TestCPUsPerVM = 2
        }
        
        It "Should create the VM with the specified parameters" {
            # Execute function
            New-ClientVM -TenantName $TestTenantName -NumberOfVMs $TestNumberOfVMs -CPUsPerVM $TestCPUsPerVM
            
            # Assertions
            Should -Invoke -CommandName Get-HVToolsConfig -ModuleName HVTools
            Should -Invoke -CommandName Write-LogEntry -ModuleName HVTools
            Should -Invoke -CommandName New-ClientVHDX -ModuleName HVTools
            Should -Invoke -CommandName New-VM -ModuleName HVTools
            Should -Invoke -CommandName Set-VMMemory -ModuleName HVTools
            Should -Invoke -CommandName Set-VMProcessor -ModuleName HVTools
        }
    }
    
    Context "When creating VMs with AutoPilot" {
        BeforeAll {
            # Parameters for test
            $TestTenantName = "Contoso"
            $TestNumberOfVMs = 1
            $TestCPUsPerVM = 2
            
            # Mock New-ClientDevice to return AutoPilot info
            Mock -CommandName New-ClientDevice -ModuleName HVTools -MockWith {
                return @{
                    ClientInfo = @{
                        SerialNumber = "12345"
                        HardwareHash = "abcdef"
                    }
                }
            }
            
            # Mock Publish-AutoPilotConfig (Private function)
            Mock -CommandName Publish-AutoPilotConfig -ModuleName HVTools
        }
        
        It "Should create the VM with AutoPilot configuration" {
            # Execute function
            New-ClientVM -TenantName $TestTenantName -NumberOfVMs $TestNumberOfVMs -CPUsPerVM $TestCPUsPerVM
            
            # Assertions
            Should -Invoke -CommandName New-ClientDevice -ModuleName HVTools
            Should -Invoke -CommandName Publish-AutoPilotConfig -ModuleName HVTools
        }
    }
    
    Context "When creating VMs with SkipAutoPilot switch" {
        BeforeAll {
            # Parameters for test
            $TestTenantName = "Contoso"
            $TestNumberOfVMs = 1
            $TestCPUsPerVM = 2
        }
        
        It "Should create the VM without AutoPilot configuration" {
            # Execute function
            New-ClientVM -TenantName $TestTenantName -NumberOfVMs $TestNumberOfVMs -CPUsPerVM $TestCPUsPerVM -SkipAutoPilot
            
            # Assertions
            Should -Not -Invoke -CommandName Publish-AutoPilotConfig -ModuleName HVTools
        }
    }
    
    Context "When including tools" {
        BeforeAll {
            # Update test config to include tools
            $TestConfig.Tools = @(
                @{
                    ToolName = "CMTrace"
                    ToolPath = "Tools\CMTrace.exe"
                }
            )
            
            # Parameters for test
            $TestTenantName = "Contoso"
            $TestNumberOfVMs = 1
            $TestCPUsPerVM = 2
            
            # Mock Add-TroubleshootingTools (Private function)
            Mock -CommandName Add-TroubleshootingTools -ModuleName HVTools
        }
        
        It "Should add tools to the VM" {
            # Execute function
            New-ClientVM -TenantName $TestTenantName -NumberOfVMs $TestNumberOfVMs -CPUsPerVM $TestCPUsPerVM -IncludeTools
            
            # Assertions
            Should -Invoke -CommandName Add-TroubleshootingTools -ModuleName HVTools
        }
    }
}