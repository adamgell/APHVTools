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
        [switch]$unattend

    )
    try {
        # Import Hyper-ConvertImage module efficiently
        $useWinPS = $PSVersionTable.PSVersion.Major -eq 7
        $imported = Import-RequiredModule -ModuleName 'Hyper-ConvertImage' -Install -UseWindowsPowerShell:$useWinPS
        if (-not $imported) {
            throw "Failed to import required module: Hyper-ConvertImage"
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
        if ($unattend) {
            $params.UnattendPath = $unattend
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
    }
}