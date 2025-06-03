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
        # Import Hyper-ConvertImage module efficiently
        $useWinPS = $PSVersionTable.PSVersion.Major -eq 7
        $imported = Import-RequiredModule -ModuleName 'Hyper-ConvertImage' -Install -UseWindowsPowerShell:$useWinPS
        if (-not $imported) {
            throw "Failed to import required module: Hyper-ConvertImage"
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
        Convert-WindowsImage @params
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