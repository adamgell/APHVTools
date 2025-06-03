function New-UnattendXml {
    <#
    .SYNOPSIS
        Creates an unattend.xml file with local administrator account for hardware hash capture
    
    .DESCRIPTION
        Generates an unattend.xml file that creates a local administrator account
        named "HVToolsAdmin" for automated hardware hash capture scenarios
    
    .PARAMETER OutputPath
        Path where the unattend.xml file will be created
    
    .PARAMETER AdminUsername
        Username for the local administrator (default: HVToolsAdmin)
    
    .PARAMETER AdminPassword
        Password for the local administrator (default: HVTools@2024!)
    
    .PARAMETER ComputerName
        Computer name to set during setup
    
    .EXAMPLE
        New-UnattendXml -OutputPath "C:\Temp\unattend.xml" -ComputerName "TEST-VM-001"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter()]
        [string]$AdminUsername,
        
        [Parameter()]
        [string]$AdminPassword,
        
        [Parameter()]
        [string]$ComputerName = "HVTOOLS-VM"
    )
    
    try {
        # Generate random credentials if not provided
        if (-not $AdminUsername) {
            $AdminUsername = "admin" + (Get-Random -Minimum 100 -Maximum 999)
        }
        
        if (-not $AdminPassword) {
            # Generate a random password with uppercase, lowercase, numbers, and special chars
            $characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%'
            $AdminPassword = -join ((1..12) | ForEach-Object { $characters[(Get-Random -Maximum $characters.Length)] })
            # Ensure it meets complexity requirements by adding required character types
            $AdminPassword = "A1!" + $AdminPassword
        }
        
        Write-Verbose "Generated admin credentials - Username: $AdminUsername, Password: $AdminPassword"
        
        # Create the unattend.xml content
        $unattendXml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserData>
                <AcceptEula>true</AcceptEula>
                <FullName>HVTools User</FullName>
                <Organization>HVTools</Organization>
            </UserData>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>$ComputerName</ComputerName>
            <RegisteredOrganization>HVTools</RegisteredOrganization>
            <RegisteredOwner>HVTools User</RegisteredOwner>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <ProtectYourPC>1</ProtectYourPC>
                <SkipUserOOBE>true</SkipUserOOBE>
                <SkipMachineOOBE>true</SkipMachineOOBE>
            </OOBE>
            <UserAccounts>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Password>
                            <Value>$AdminPassword</Value>
                            <PlainText>true</PlainText>
                        </Password>
                        <Description>HVTools Local Administrator</Description>
                        <DisplayName>$AdminUsername</DisplayName>
                        <Group>Administrators</Group>
                        <Name>$AdminUsername</Name>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
            <AutoLogon>
                <Password>
                    <Value>$AdminPassword</Value>
                    <PlainText>true</PlainText>
                </Password>
                <Enabled>true</Enabled>
                <LogonCount>3</LogonCount>
                <Username>$AdminUsername</Username>
            </AutoLogon>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>powershell.exe -Command "Set-ExecutionPolicy RemoteSigned -Force"</CommandLine>
                    <Description>Set PowerShell execution policy</Description>
                    <Order>1</Order>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>powershell.exe -Command "Enable-PSRemoting -Force -SkipNetworkProfileCheck"</CommandLine>
                    <Description>Enable PowerShell remoting</Description>
                    <Order>2</Order>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>powershell.exe -Command "Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force"</CommandLine>
                    <Description>Set trusted hosts for PowerShell remoting</Description>
                    <Order>3</Order>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>powershell.exe -Command "New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'EnableLUA' -Value 0 -PropertyType DWord -Force"</CommandLine>
                    <Description>Disable UAC for automation</Description>
                    <Order>4</Order>
                </SynchronousCommand>
            </FirstLogonCommands>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>en-US</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UserLocale>en-US</UserLocale>
        </component>
    </settings>
</unattend>
"@

        # Save the unattend.xml file
        $unattendXml | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
        
        Write-Verbose "Unattend.xml created at: $OutputPath"
        Write-Verbose "Local Admin Username: $AdminUsername"
        Write-Verbose "Local Admin Password: $AdminPassword"
        
        # Return an object with the path and credentials
        return [PSCustomObject]@{
            UnattendPath = $OutputPath
            AdminUsername = $AdminUsername
            AdminPassword = $AdminPassword
        }
    }
    catch {
        Write-Warning "Failed to create unattend.xml: $_"
        return $null
    }
}