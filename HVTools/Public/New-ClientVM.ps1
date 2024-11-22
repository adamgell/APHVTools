function New-ClientVM {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [parameter(Position = 1, Mandatory = $true)]
        [string]$TenantName,

        [parameter(Position = 2, Mandatory = $false)]
        [string]$OSBuild,

        [parameter(Position = 3, Mandatory = $true)]
        [ValidateRange(1, 999)]
        [string]$NumberOfVMs,

        [parameter(Position = 4, Mandatory = $true)]
        [ValidateRange(1, 999)]
        [string]$CPUsPerVM,

        [parameter(Position = 5, Mandatory = $false)]
        [ValidateRange(2gb, 20gb)]
        [int64]$VMMemory = 4GB,

        [parameter(Position = 6, Mandatory = $false)]
        [switch]$SkipAutoPilot,

        [parameter(Position = 7, Mandatory = $false)]
        [switch]$UseAutopilotV2,

        [parameter(Position = 8, Mandatory = $false)]
        [string]$Manufacturer = "Microsoft",

        [parameter(Position = 9, Mandatory = $false)]
        [string]$Model = "Hyper-V Virtual Machine"
    )
    try {
        #region Config
        Get-Command -Module 'Hyper-V' | Out-Null
        $clientDetails = $script:hvConfig.tenantConfig | Where-Object { $_.TenantName -eq $TenantName }
        if ($OSBuild) {
            $imageDetails = $script:hvConfig.images | Where-Object { $_.imageName -eq $OSBuild }
        }
        else {
            $imageDetails = $script:hvConfig.images | Where-Object { $_.imageName -eq $clientDetails.imageName }
        }

        $clientPath = "$($script:hvConfig.vmPath)\$($TenantName)"
        if ($imageDetails.refimagePath -like '*wks$($ImageName)ref.vhdx') {
            if (!(Test-Path $imageDetails.imagePath -ErrorAction SilentlyContinue)) {
                throw "Installation media not found at location: $($imageDetails.imagePath)"
            }
        }
        if (!(Test-Path $clientPath)) {
            New-Item -ItemType Directory -Force -Path $clientPath | Out-Null
        }

        # Create reference image if needed
        if (!(Test-Path -Path $imageDetails.refImagePath -ErrorAction SilentlyContinue)) {
            Write-Host "Creating reference VHDX - this may take some time.." -ForegroundColor Yellow
            New-ClientVHDX -vhdxPath $imageDetails.refImagePath -winIso $imageDetails.imagePath
            Write-Host "Reference VHDX has been created.." -ForegroundColor Yellow
        }

        # Get Autopilot policy if needed
        if (!($SkipAutoPilot)) {
            Write-Host "Grabbing Autopilot config.." -ForegroundColor Yellow
            Get-AutopilotPolicy -FileDestination "$clientPath"
        }

        # Prepare VM parameters
        $vmParams = @{
            ClientPath = $clientPath
            RefVHDX = $imageDetails.refImagePath
            VSwitchName = $script:hvConfig.vSwitchName
            CPUCount = $CPUsPerVM
            VMMMemory = $VMMemory
            UseAutopilotV2 = $UseAutopilotV2
            Manufacturer = $Manufacturer
            Model = $Model
        }

        if ($SkipAutoPilot) {
            $vmParams.skipAutoPilot = $true
        }
        if ($script:hvConfig.vLanId) {
            $vmParams.VLanId = $script:hvConfig.vLanId
        }

        # Create VMs
        $createdVMs = @()

        # Function to get next VM number
        function Get-NextVMNumber {
            $existingVMs = Get-VM -Name "$TenantName*" -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "^$TenantName`_\d+$" }

            if (!$existingVMs) { return 1 }

            $numbers = $existingVMs | ForEach-Object {
                if ($_.Name -match "_(\d+)$") {
                    [int]$matches[1]
                }
            } | Sort-Object

            return ($numbers | Select-Object -Last 1) + 1
        }

        if ($numberOfVMs -eq 1) {
            $nextNum = Get-NextVMNumber
            $vmParams.VMName = "${TenantName}_$nextNum"
            Write-Host "Creating VM: $($vmParams.VMName).." -ForegroundColor Yellow
            $createdVMs += New-ClientDevice @vmParams
        }
        else {
            1..$NumberOfVMs | ForEach-Object {
                $nextNum = Get-NextVMNumber
                $vmParams.VMName = "${TenantName}_$nextNum"
                Write-Host "Creating VM: $($vmParams.VMName).." -ForegroundColor Yellow
                $createdVMs += New-ClientDevice @vmParams
            }
        }

        # Output summary
        Write-Host "`nVM Creation Summary:" -ForegroundColor Cyan
        foreach ($vm in $createdVMs) {
            Write-Host "VM Name: $($vm.VMName)" -ForegroundColor Green
            Write-Host "Serial Number: $($vm.SerialNumber)" -ForegroundColor Green
            Write-Host "Path: $($vm.Path)" -ForegroundColor Green
            Write-Host "------------------"
        }

        if ($UseAutopilotV2) {
            Write-Host "`nAll VMs have been registered with Autopilot V2 corporate identifiers" -ForegroundColor Green
        }

        return $createdVMs
    }
    catch {
        Write-Error "Error creating VMs: $_"
        throw
    }
}