# Debug script to diagnose Convert-WindowsImage issues

Write-Host "=== Debugging Convert-WindowsImage Issue ===" -ForegroundColor Cyan

try {
    # Check PowerShell version
    Write-Host "`nPowerShell Version Information:" -ForegroundColor Yellow
    $PSVersionTable | Format-Table -AutoSize

    # Check if running as admin
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    Write-Host "Running as Administrator: $isAdmin" -ForegroundColor $(if($isAdmin){'Green'}else{'Red'})

    # Check Hyper-V status
    Write-Host "`nHyper-V Feature Status:" -ForegroundColor Yellow
    try {
        $hyperV = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
        Write-Host "Hyper-V State: $($hyperV.State)" -ForegroundColor $(if($hyperV.State -eq 'Enabled'){'Green'}else{'Red'})
    }
    catch {
        Write-Host "Could not check Hyper-V status: $_" -ForegroundColor Red
    }

    # Check for Hyper-ConvertImage module
    Write-Host "`nHyper-ConvertImage Module Information:" -ForegroundColor Yellow
    $module = Get-Module -ListAvailable -Name Hyper-ConvertImage
    if ($module) {
        Write-Host "Module found:" -ForegroundColor Green
        $module | Format-Table Name, Version, ModuleBase -AutoSize
        
        # Try to import the module
        Write-Host "Attempting to import Hyper-ConvertImage module..." -ForegroundColor Cyan
        try {
            if ($PSVersionTable.PSVersion.Major -eq 7) {
                Write-Host "PowerShell 7 detected - using Windows PowerShell compatibility" -ForegroundColor Yellow
                Import-Module -Name (Split-Path $module.ModuleBase -Parent) -UseWindowsPowerShell -ErrorAction Stop 3>$null
            } else {
                Import-Module -Name Hyper-ConvertImage -ErrorAction Stop
            }
            Write-Host "✓ Module imported successfully" -ForegroundColor Green
            
            # Check if Convert-WindowsImage is available
            $convertCmd = Get-Command Convert-WindowsImage -ErrorAction SilentlyContinue
            if ($convertCmd) {
                Write-Host "✓ Convert-WindowsImage command found" -ForegroundColor Green
                Write-Host "Command Source: $($convertCmd.Source)" -ForegroundColor White
            } else {
                Write-Host "✗ Convert-WindowsImage command not found after import" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "✗ Failed to import module: $_" -ForegroundColor Red
            Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor DarkRed
            Write-Host "Stack Trace:" -ForegroundColor DarkRed
            Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
        }
    } else {
        Write-Host "✗ Hyper-ConvertImage module not found" -ForegroundColor Red
        Write-Host "Attempting to install..." -ForegroundColor Yellow
        try {
            Install-Module -Name Hyper-ConvertImage -Force -AllowClobber
            Write-Host "✓ Module installed" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ Failed to install module: $_" -ForegroundColor Red
        }
    }

    # Check .NET Framework version
    Write-Host "`n.NET Framework Information:" -ForegroundColor Yellow
    try {
        $dotNetVersion = Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release -ErrorAction SilentlyContinue
        if ($dotNetVersion) {
            $version = switch ($dotNetVersion.Release) {
                {$_ -ge 533320} { "4.8.1 or later" }
                {$_ -ge 528040} { "4.8" }
                {$_ -ge 461808} { "4.7.2" }
                {$_ -ge 461308} { "4.7.1" }
                {$_ -ge 460798} { "4.7" }
                {$_ -ge 394802} { "4.6.2" }
                {$_ -ge 394254} { "4.6.1" }
                {$_ -ge 393295} { "4.6" }
                {$_ -ge 378389} { "4.5" }
                default { "Unknown" }
            }
            Write-Host ".NET Framework Version: $version (Release: $($dotNetVersion.Release))" -ForegroundColor Green
        } else {
            Write-Host "Could not determine .NET Framework version" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Error checking .NET Framework: $_" -ForegroundColor Red
    }

    # Check available disk space
    Write-Host "`nDisk Space Information:" -ForegroundColor Yellow
    Get-PSDrive -PSProvider FileSystem | Select-Object Name, @{N='FreeGB';E={[math]::Round($_.Free/1GB,2)}}, @{N='UsedGB';E={[math]::Round($_.Used/1GB,2)}} | Format-Table -AutoSize

    # Check Windows ADK
    Write-Host "Windows ADK Information:" -ForegroundColor Yellow
    $adkPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots"
    )
    
    $adkFound = $false
    foreach ($path in $adkPaths) {
        try {
            $adk = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            if ($adk.KitsRoot10) {
                Write-Host "Windows ADK found at: $($adk.KitsRoot10)" -ForegroundColor Green
                $adkFound = $true
                
                # Check for DISM
                $dismPath = Join-Path $adk.KitsRoot10 "Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe"
                if (Test-Path $dismPath) {
                    Write-Host "DISM found at: $dismPath" -ForegroundColor Green
                } else {
                    Write-Host "DISM not found in expected location" -ForegroundColor Yellow
                }
                break
            }
        }
        catch {
            # Continue to next path
        }
    }
    
    if (-not $adkFound) {
        Write-Host "Windows ADK not found - this may be required for Convert-WindowsImage" -ForegroundColor Yellow
    }

    # Test a simple Convert-WindowsImage call with verbose error handling
    Write-Host "`nTesting Convert-WindowsImage with minimal parameters..." -ForegroundColor Yellow
    try {
        # Try to get help for the command first
        $help = Get-Help Convert-WindowsImage -ErrorAction SilentlyContinue
        if ($help) {
            Write-Host "✓ Convert-WindowsImage help available" -ForegroundColor Green
        } else {
            Write-Host "✗ Convert-WindowsImage help not available" -ForegroundColor Red
        }
        
        # Try to inspect the command parameters
        $params = (Get-Command Convert-WindowsImage -ErrorAction SilentlyContinue).Parameters
        if ($params) {
            Write-Host "✓ Convert-WindowsImage parameters accessible" -ForegroundColor Green
            Write-Host "Available parameters: $($params.Keys -join ', ')" -ForegroundColor White
        } else {
            Write-Host "✗ Convert-WindowsImage parameters not accessible" -ForegroundColor Red
        }
        
    }
    catch {
        Write-Host "✗ Error testing Convert-WindowsImage: $_" -ForegroundColor Red
        Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor DarkRed
        
        if ($_.Exception.InnerException) {
            Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor DarkRed
        }
    }

    Write-Host "`n=== Recommendations ===" -ForegroundColor Cyan
    
    if ($PSVersionTable.PSVersion.Major -eq 7) {
        Write-Host "• You're using PowerShell 7 - consider testing with Windows PowerShell 5.1" -ForegroundColor Yellow
    }
    
    if (-not $adkFound) {
        Write-Host "• Consider installing Windows ADK: https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install" -ForegroundColor Yellow
    }
    
    Write-Host "• Try running the following to get more detailed error information:" -ForegroundColor Yellow
    Write-Host "  `$VerbosePreference = 'Continue'" -ForegroundColor White
    Write-Host "  `$DebugPreference = 'Continue'" -ForegroundColor White
    Write-Host "  Add-ImageToConfig -ImageName 'TestImage' -IsoPath 'path\to\iso' -Verbose" -ForegroundColor White

}
catch {
    Write-Host "Error in debug script: $_" -ForegroundColor Red
}

Write-Host "`nDebug completed." -ForegroundColor Gray