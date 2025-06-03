#requires -Modules "Hyper-ConvertImage"
function New-ClientVHDX {
    [cmdletbinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Position = 1, Mandatory = $true)]
        [string]$vhdxPath,

        [Parameter(Position = 2, Mandatory = $true)]
        [string]$winIso,

        [Parameter(Position = 3, Mandatory = $false)]
        [string]$UnattendPath,
        
        [Parameter(Position = 4, Mandatory = $false)]
        [switch]$CreateAdminAccount

    )
    try {
        # Try to import Hyper-ConvertImage module
        try {
            Import-Module Hyper-ConvertImage -Force -ErrorAction Stop
            Write-Verbose "Successfully imported Hyper-ConvertImage module"
        }
        catch {
            Write-Warning "Failed to import Hyper-ConvertImage module directly: $_"
            
            # Try with Import-RequiredModule helper if available
            if (Get-Command Import-RequiredModule -ErrorAction SilentlyContinue) {
                Write-Verbose "Attempting import with Import-RequiredModule helper..."
                $imported = Import-RequiredModule -ModuleName 'Hyper-ConvertImage' -Install
                if (-not $imported) {
                    throw "Failed to import required module: Hyper-ConvertImage using both methods"
                }
            } else {
                throw "Hyper-ConvertImage module import failed and Import-RequiredModule helper not available"
            }
        }
        
        # Create unattend.xml if CreateAdminAccount is specified
        $tempUnattendPath = $null
        if ($CreateAdminAccount) {
            $tempUnattendPath = Join-Path $env:TEMP "hvtools_unattend_$([guid]::NewGuid().ToString().Substring(0,8)).xml"
            $computerName = [System.IO.Path]::GetFileNameWithoutExtension($vhdxPath)
            Write-Verbose "Creating unattend.xml with admin account for: $computerName"
            
            $unattendResult = New-UnattendXml -OutputPath $tempUnattendPath -ComputerName $computerName
            if ($unattendResult) {
                $UnattendPath = $unattendResult.UnattendPath
                # Store credentials in a script variable for later use
                $script:vmAdminCredentials = @{
                    Username = $unattendResult.AdminUsername
                    Password = $unattendResult.AdminPassword
                }
                Write-Host " (with admin account: $($unattendResult.AdminUsername))" -ForegroundColor Yellow -NoNewline
            } else {
                Write-Warning "Failed to create unattend.xml, proceeding without it"
            }
        }
        
        $currVol = Get-Volume
        Mount-DiskImage -ImagePath $winIso | Out-Null
        $dl = (Get-Volume | Where-Object { $_.DriveLetter -notin $currVol.DriveLetter}).DriveLetter
        $imageIndex = Get-ImageIndexFromWim -wimPath "$dl`:\sources\install.wim"
        Dismount-DiskImage -ImagePath $winIso | Out-Null
        $params = @{
            SourcePath = $winIso
            Edition    = $imageIndex
            VhdType    = "Dynamic"
            VhdFormat  = "VHDX"
            VhdPath    = $vhdxPath
            DiskLayout = "UEFI"
            SizeBytes  = 127gb
        }
        if ($UnattendPath -and (Test-Path $UnattendPath)) {
            $params.UnattendPath = $UnattendPath
            Write-Verbose "Using unattend.xml: $UnattendPath"
        }
        Write-Host "Building reference image.." -ForegroundColor Cyan -NoNewline
        
        # Add detailed debugging for Convert-WindowsImage
        Write-Verbose "Convert-WindowsImage parameters:"
        foreach ($key in $params.Keys) {
            Write-Verbose "  $key = $($params[$key])"
        }
        
        try {
            # Check if Convert-WindowsImage command is available
            $convertCmd = Get-Command Convert-WindowsImage -ErrorAction SilentlyContinue
            if (-not $convertCmd) {
                throw "Convert-WindowsImage command not found. Ensure Hyper-ConvertImage module is properly loaded."
            }
            
            Write-Verbose "Convert-WindowsImage command found at: $($convertCmd.Source)"
            Write-Verbose "Starting Windows image conversion..."
            
            # Additional pre-execution diagnostics
            Write-Verbose "Pre-execution diagnostics:"
            Write-Verbose "  PowerShell Version: $($PSVersionTable.PSVersion)"
            Write-Verbose "  Execution Policy: $(Get-ExecutionPolicy)"
            Write-Verbose "  Current User: $($env:USERNAME)"
            Write-Verbose "  Running as Admin: $(([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))"
            Write-Verbose "  Module Base: $((Get-Module Hyper-ConvertImage).ModuleBase)"
            Write-Verbose "  .NET Framework: $([System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription)"
            
            # Check critical paths and permissions
            $targetDir = Split-Path $params.VhdPath -Parent
            if (-not (Test-Path $targetDir)) {
                Write-Verbose "Creating target directory: $targetDir"
                New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            }
            
            # Test write permissions
            $testFile = Join-Path $targetDir "hvtools_test_$([guid]::NewGuid().ToString().Substring(0,8)).tmp"
            try {
                "test" | Out-File -FilePath $testFile -Force
                Remove-Item $testFile -Force
                Write-Verbose "  Write permissions to target directory: OK"
            }
            catch {
                Write-Warning "Limited write permissions to target directory: $_"
            }
            
            # Enable detailed error reporting
            $oldErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Stop'
            
            Convert-WindowsImage @params
            
            Write-Verbose "Windows image conversion completed successfully"
        }
        catch {
            Write-Host " FAILED" -ForegroundColor Red
            Write-Host "Error in Convert-WindowsImage:" -ForegroundColor Red
            Write-Host "  Message: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            
            if ($_.Exception.InnerException) {
                Write-Host "  Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
            }
            
            # Enhanced debugging information
            Write-Host "Enhanced Debug Information:" -ForegroundColor Yellow
            Write-Host "  PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
            Write-Host "  Module Version: $((Get-Module Hyper-ConvertImage).Version)" -ForegroundColor Yellow
            Write-Host "  Module Path: $((Get-Module Hyper-ConvertImage).Path)" -ForegroundColor Yellow
            Write-Host "  Current Directory: $(Get-Location)" -ForegroundColor Yellow
            Write-Host "  Source ISO exists: $(Test-Path $params.SourcePath)" -ForegroundColor Yellow
            Write-Host "  Source ISO size: $([math]::Round((Get-Item $params.SourcePath).Length / 1GB, 2)) GB" -ForegroundColor Yellow
            Write-Host "  Target directory exists: $(Test-Path (Split-Path $params.VhdPath -Parent))" -ForegroundColor Yellow
            Write-Host "  Available disk space: $([math]::Round((Get-PSDrive (Split-Path $params.VhdPath -Qualifier).TrimEnd(':')).Free / 1GB, 2)) GB" -ForegroundColor Yellow
            
            # Check for conflicting processes
            $vhdxProcesses = Get-Process | Where-Object { $_.ProcessName -match "diskpart|dism|imagex" } -ErrorAction SilentlyContinue
            if ($vhdxProcesses) {
                Write-Host "  Potentially conflicting processes running: $($vhdxProcesses.ProcessName -join ', ')" -ForegroundColor Yellow
            }
            
            Write-Host "`nSuggested Solutions:" -ForegroundColor Cyan
            Write-Host "1. Try running: Import-Module Hyper-ConvertImage -Force" -ForegroundColor White
            Write-Host "2. Restart PowerShell as Administrator" -ForegroundColor White
            Write-Host "3. Check Windows ADK installation" -ForegroundColor White
            Write-Host "4. Try a smaller VHDX size (e.g., 60GB instead of 127GB)" -ForegroundColor White
            
            # Re-throw the error
            throw
        }
        finally {
            if ($oldErrorActionPreference) {
                $ErrorActionPreference = $oldErrorActionPreference
            }
        }
    }
    catch {
        Write-Warning $_
    }
    finally {
        if ($PSVersionTable.PSVersion.Major -eq 7) {
            Remove-Module -Name 'Hyper-ConvertImage' -Force
        }
        
        # Clean up temporary unattend.xml
        if ($tempUnattendPath -and (Test-Path $tempUnattendPath)) {
            Remove-Item $tempUnattendPath -Force -ErrorAction SilentlyContinue
            Write-Verbose "Cleaned up temporary unattend.xml: $tempUnattendPath"
        }
    }
}