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
        Write-Verbose "Using integrated Convert-WindowsImageInternal function (no external dependencies)"
        
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
        
        # Get Windows edition index from ISO/WIM
        $sourceExt = [System.IO.Path]::GetExtension($winIso).ToLower()
        if ($sourceExt -eq ".iso") {
            # Mount ISO temporarily to get edition index
            $currVol = Get-Volume
            Mount-DiskImage -ImagePath $winIso | Out-Null
            try {
                $dl = (Get-Volume | Where-Object { $_.DriveLetter -notin $currVol.DriveLetter }).DriveLetter
                $wimPath = "$dl`:\sources\install.wim"
                $imageIndex = Get-ImageIndexFromWim -wimPath $wimPath
            }
            finally {
                Dismount-DiskImage -ImagePath $winIso | Out-Null
            }
        } else {
            # Direct WIM file
            $imageIndex = Get-ImageIndexFromWim -wimPath $winIso
        }
        
        # Prepare parameters for our internal Convert-WindowsImageInternal function
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
        
        # Log parameters for debugging
        Write-Verbose "Convert-WindowsImageInternal parameters:"
        foreach ($key in $params.Keys) {
            Write-Verbose "  $key = $($params[$key])"
        }
        
        try {
            # Use our integrated function instead of external module
            $result = Convert-WindowsImageInternal @params
            
            if ($result -and (Test-Path $vhdxPath)) {
                Write-Host " completed successfully" -ForegroundColor Green
                Write-Verbose "VHDX created: $($result.FullName) ($([math]::Round($result.Length/1GB, 2)) GB)"
            } else {
                throw "VHDX creation failed - no file created"
            }
        }
        catch {
            Write-Host " FAILED" -ForegroundColor Red
            Write-Host "Error in Convert-WindowsImageInternal:" -ForegroundColor Red
            Write-Host "  Message: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            
            if ($_.Exception.InnerException) {
                Write-Host "  Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
            }
            
            # Enhanced debugging information
            Write-Host "Enhanced Debug Information:" -ForegroundColor Yellow
            Write-Host "  PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
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
            Write-Host "1. Restart PowerShell as Administrator" -ForegroundColor White
            Write-Host "2. Check Windows ADK/DISM installation" -ForegroundColor White
            Write-Host "3. Try a smaller VHDX size (e.g., 60GB instead of 127GB)" -ForegroundColor White
            Write-Host "4. Ensure no other processes are using the target drive" -ForegroundColor White
            
            # Re-throw the error
            throw
        }
    }
    catch {
        Write-Warning $_
    }
    finally {
        # Clean up temporary unattend.xml
        if ($tempUnattendPath -and (Test-Path $tempUnattendPath)) {
            Remove-Item $tempUnattendPath -Force -ErrorAction SilentlyContinue
            Write-Verbose "Cleaned up temporary unattend.xml: $tempUnattendPath"
        }
    }
}