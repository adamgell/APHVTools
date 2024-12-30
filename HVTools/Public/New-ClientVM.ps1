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
        [int64]$VMMemory,

        [parameter(Position = 6, Mandatory = $false)]
        [switch]$SkipAutoPilot
    )
    try {
        Write-Verbose "Starting New-ClientVM function..."

        #region Config
        Write-Verbose "Entering Config region..."
        #pre-load HV module..
        Write-Verbose "Loading Hyper-V module..."
        Get-Command -Module 'Hyper-V' | Out-Null
        Write-Verbose "Getting client details for tenant: $TenantName"
        $clientDetails = $script:hvConfig.tenantConfig | Where-Object { $_.TenantName -eq $TenantName }
        Write-Verbose "Client details found: $($null -ne $clientDetails)"

        Write-Verbose "Getting image details..."
        if ($OSBuild) {
            Write-Verbose "Looking for OSBuild: $OSBuild"
            $imageDetails = $script:hvConfig.images | Where-Object { $_.imageName -eq $OSBuild }
        }
        else {
            Write-Verbose "Using client default image: $($clientDetails.imageName)"
            $imageDetails = $script:hvConfig.images | Where-Object { $_.imageName -eq $clientDetails.imageName }
        }
        Write-Verbose "Image details found: $($null -ne $imageDetails)"
        $clientPath = "$($script:hvConfig.vmPath)\$($TenantName)"
        if ($imageDetails.refimagePath -like '*wks$($ImageName)ref.vhdx') {
            if (!(Test-Path $imageDetails.imagePath -ErrorAction SilentlyContinue)) {
                throw "Installation media not found at location: $($imageDetails.imagePath)"
            }
        }
        if (!(Test-Path $clientPath)) {
            New-Item -ItemType Directory -Force -Path $clientPath | Out-Null
        }

        Write-Verbose "Autopilot Reference VHDX: $($imageDetails.refImagePath)"
        Write-Verbose "Client name: $TenantName"
        Write-Verbose "Win10 ISO is located:  $($imageDetails.imagePath)"
        Write-Verbose "Path to client VMs will be: $clientPath"
        Write-Verbose "Number of VMs to create:  $NumberOfVMs"
        Write-Verbose "Admin user for $TenantName is:  $($clientDetails.adminUpn)`n"
        #endregion

        #region Check for ref image - if it's not there, build it
        if (!(Test-Path -Path $imageDetails.refImagePath -ErrorAction SilentlyContinue)) {
            Write-Host "Creating reference Autopilot VHDX - this may take some time.." -ForegroundColor Yellow
            New-ClientVHDX -vhdxPath $imageDetails.refImagePath -winIso $imageDetails.imagePath
            Write-Host "Reference Autopilot VHDX has been created.." -ForegroundColor Yellow
        }
        #endregion
        #region Get Autopilot policy
        Write-Verbose "Entering Autopilot policy region..."
        #region Get Autopilot policy
        if (!($SkipAutoPilot)) {
            Write-Host "Grabbing Autopilot config.." -ForegroundColor Yellow
            Write-Verbose "Constructing full AutopilotConfigurationFile path"
            # Change this line - pass only the directory path
            Get-AutopilotPolicy -FileDestination $clientPath
        }
        #endregion
        Write-Verbose "Exiting Autopilot policy region..."
        #endregion

        #region Build the client VMs
        Write-Verbose "Entering VM Build region..."
        if (!(Test-Path -Path $clientPath -ErrorAction SilentlyContinue)) {
            Write-Verbose "Creating client path directory: $clientPath"
            New-Item -Path $clientPath -ItemType Directory -Force | Out-Null
        }

        Write-Verbose "Building vmParams hashtable..."
        $vmParams = @{
            ClientPath  = $clientPath
            RefVHDX     = $imageDetails.refImagePath
            VSwitchName = $script:hvConfig.vSwitchName
            CPUCount    = $CPUsPerVM
            VMMemory    = $VMMemory
        }

        Write-Verbose "Created vmParams with values:"
        $vmParams.GetEnumerator() | ForEach-Object {
            Write-Verbose "  $($_.Key): $($_.Value)"
        }

        Write-Verbose "Processing $NumberOfVMs VM(s)..."
        if ($numberOfVMs -eq 1) {
            Write-Verbose "Single VM mode..."
            $max = ((Get-VM -Name "$TenantName*").name -replace "\D" | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum)
            Write-Verbose "Current max VM number: $max"
            if ($null -eq $max) {
                Write-Verbose "No existing VMs found, starting at 0"
                $max = 0
            }
            $max += 1
            $vmParams.VMName = "$($TenantName)_$max"
            Write-Verbose "Generated VMName: $($vmParams.VMName)"
            Write-Host "Creating VM: $($vmParams.VMName).." -ForegroundColor Yellow
            Write-Verbose "Calling New-ClientDevice with parameters:"
            $vmParams.GetEnumerator() | ForEach-Object {
                Write-Verbose "  $($_.Key): $($_.Value)"
            }
            New-ClientDevice @vmParams -Verbose
        }
        else {
            Write-Verbose "Multiple VM mode..."
            1..$NumberOfVMs | ForEach-Object {
                $currentVM = $_
                Write-Verbose "Processing VM $currentVM of $NumberOfVMs"
                $max = ((Get-VM -Name "$TenantName*").name -replace "\D" | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum)
                if ($null -eq $max) { $max = 0 }
                $max += 1
                $vmParams.VMName = "$($TenantName)_$max"
                Write-Verbose "Generated VMName: $($vmParams.VMName)"
                Write-Host "Creating VM: $($vmParams.VMName).." -ForegroundColor Yellow
                Write-Verbose "Calling New-ClientDevice with parameters:"
                $vmParams.GetEnumerator() | ForEach-Object {
                    Write-Verbose "  $($_.Key): $($_.Value)"
                }
                New-ClientDevice @vmParams -Verbose
            }
        }
        Write-Verbose "VM creation completed"
        #endregion
    }
    catch {
        $errorMsg = $_.Exception.Message
    }
    finally {
        if ($errorMsg) {
            Write-Warning $errorMsg
        }
    }
}