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
        [string]$Model = "Hyper-V Virtual Machine",

        [parameter(Position = 10, Mandatory = $false)]
        [switch]$Force
    )
    try {
        # Pre-load HV module
        Get-Command -Module 'Hyper-V' | Out-Null

        # Get client and image details from config
        $clientDetails = $script:hvConfig.tenantConfig | Where-Object { $_.TenantName -eq $TenantName }
        if ($OSBuild) {
            $imageDetails = $script:hvConfig.images | Where-Object { $_.imageName -eq $OSBuild }
        }
        else {
            $imageDetails = $script:hvConfig.images | Where-Object { $_.imageName -eq $clientDetails.imageName }
        }
        # Validate virtual switch
        if (!$script:hvConfig.vSwitchName) {
            throw "No virtual switch configured. Please run Update-HVToolsConfig to configure a virtual switch."
        }

        if (!(Get-VMSwitch -Name $script:hvConfig.vSwitchName -ErrorAction SilentlyContinue)) {
            throw "Configured virtual switch '$($script:hvConfig.vSwitchName)' not found. Please run Update-HVToolsConfig to select a valid switch."
        }

        # Validate image details
        if (!$imageDetails) {
            $availableImages = $script:hvConfig.images.imageName | Select-Object -Unique
            throw "Image '$OSBuild' not found. Available images: $($availableImages -join ', ')"
        }

        # Validate reference image path
        if (![System.IO.Path]::IsPathRooted($imageDetails.refImagePath)) {
            throw "Invalid reference image path: $($imageDetails.refImagePath). Path must be absolute."
        }

        # Create reference path directory if it doesn't exist
        $refImageDir = Split-Path $imageDetails.refImagePath -Parent
        if (!(Test-Path $refImageDir)) {
            New-Item -Path $refImageDir -ItemType Directory -Force | Out-Null
        }

        # Validate ISO path
        if (!(Test-Path $imageDetails.imagePath)) {
            throw "Windows ISO not found at: $($imageDetails.imagePath)"
        }

        # Debug output
        Write-Verbose "Configuration validation passed:"
        Write-Verbose "Virtual Switch: $($script:hvConfig.vSwitchName)"
        Write-Verbose "Image Name: $($imageDetails.imageName)"
        Write-Verbose "ISO Path: $($imageDetails.imagePath)"
        Write-Verbose "Reference VHDX: $($imageDetails.refImagePath)"

        # Validate paths and configuration
        $clientPath = "$($script:hvConfig.vmPath)\$($TenantName)"
        if ($imageDetails.refimagePath -like '*wks$($ImageName)ref.vhdx') {
            if (!(Test-Path $imageDetails.imagePath -ErrorAction SilentlyContinue)) {
                throw "Installation media not found at location: $($imageDetails.imagePath)"
            }
        }
        if (!(Test-Path $clientPath)) {
            New-Item -ItemType Directory -Force -Path $clientPath | Out-Null
        }

        # Log configuration details
        Write-Verbose "Autopilot Reference VHDX: $($imageDetails.refImagePath)"
        Write-Verbose "Client name: $TenantName"
        Write-Verbose "Win10/11 ISO location: $($imageDetails.imagePath)"
        Write-Verbose "Client VM path: $clientPath"
        Write-Verbose "Number of VMs: $NumberOfVMs"
        Write-Verbose "Admin user: $($clientDetails.adminUpn)"
        if ($UseAutopilotV2) {
            Write-Verbose "Using Autopilot V2 with Manufacturer: $Manufacturer, Model: $Model"
        }

        # Check for Windows version compatibility if using Autopilot V2
        if ($UseAutopilotV2) {
            Write-Host "Note: Autopilot V2 requires Windows 10 KB5039299 (OS Build 19045.4598) or later" -ForegroundColor Yellow
            if (!$Force) {
                $confirmation = Read-Host "Are you sure your image meets this requirement? (Y/N)"
                if ($confirmation -ne 'Y') {
                    throw "Operation cancelled by user"
                }
            }
        }

        # Create or verify reference image
        if (!(Test-Path -Path $imageDetails.refImagePath -ErrorAction SilentlyContinue)) {
            Write-Host "Creating reference Autopilot VHDX - this may take some time.." -ForegroundColor Yellow
            New-ClientVHDX -vhdxPath $imageDetails.refImagePath -winIso $imageDetails.imagePath
            Write-Host "Reference Autopilot VHDX has been created.." -ForegroundColor Yellow
        }

        # Get Autopilot policy if needed
        if (!($SkipAutoPilot)) {
            Write-Host "Grabbing Autopilot config.." -ForegroundColor Yellow
            Get-AutopilotPolicy -FileDestination "$clientPath"
        }

        # Update the vmParams section
        $vmParams = @{
            ClientPath  = $clientPath
            RefVHDX     = $imageDetails.refImagePath
            VSwitchName = $script:hvConfig.vSwitchName
            CPUCount    = $CPUsPerVM
            VMMMemory   = $VMMemory
        }

        if ($UseAutopilotV2) {
            $vmParams['UseAutopilotV2'] = $true
            $vmParams['Manufacturer'] = $Manufacturer
            $vmParams['Model'] = $Model
        }

        if ($SkipAutoPilot) {
            $vmParams['skipAutoPilot'] = $true
        }

        if ($script:hvConfig.vLanId) {
            $vmParams['VLanId'] = $script:hvConfig.vLanId
        }

        Write-Verbose "Debug: VM Parameters"
        Write-Verbose ($vmParams | ConvertTo-Json)

        # Before creating the VM
        if ([string]::IsNullOrEmpty($vmParams.RefVHDX)) {
            throw "Reference VHDX path is null or empty. Image details may be incorrect."
        }

        if (!(Test-Path $vmParams.RefVHDX)) {
            throw "Reference VHDX not found at: $($vmParams.RefVHDX)"
        }

        # Create VMs
        Write-Verbose "Debug: Image Details"
        Write-Verbose ($imageDetails | ConvertTo-Json)
        Write-Verbose "Reference VHDX Path: $($imageDetails.refImagePath)"
        $createdVMs = @()
        if ($numberOfVMs -eq 1) {
            $max = ((Get-VM -Name "$TenantName*").name -replace "\D" |
                Measure-Object -Maximum |
                Select-Object -ExpandProperty Maximum) + 1
            $vmParams.VMName = "$($TenantName)_$max"
            Write-Host "Creating VM: $($vmParams.VMName).." -ForegroundColor Yellow
            $createdVMs += New-ClientDevice @vmParams
        }
        else {
            (1..$NumberOfVMs) | ForEach-Object {
                $max = ((Get-VM -Name "$TenantName*").name -replace "\D" |
                    Measure-Object -Maximum |
                    Select-Object -ExpandProperty Maximum) + 1
                $vmParams.VMName = "$($TenantName)_$max"
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
            Write-Host "Please ensure your Autopilot deployment profile is configured correctly" -ForegroundColor Yellow
        }

        return $createdVMs
    }
    catch {
        Write-Error "Error creating VMs: $_"
        throw
    }
}