function Get-VMHardwareHash {
    <#
    .SYNOPSIS
        Captures hardware hash from a VM using Get-WindowsAutoPilotInfo
    
    .DESCRIPTION
        Installs Get-WindowsAutoPilotInfo script in the VM, captures the hardware hash,
        and saves it to the tenant folder
    
    .PARAMETER VMName
        The name of the VM to capture hardware hash from
    
    .PARAMETER TenantPath
        The path to the tenant folder where the hash file will be saved
    
    .PARAMETER Credential
        Credentials to connect to the VM
    
    .EXAMPLE
        Get-VMHardwareHash -VMName "HVTOOLS-TEST-001" -TenantPath "C:\HVTools\Test"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantPath,
        
        [Parameter()]
        [PSCredential]$Credential
    )
    
    try {
        Write-Verbose "Starting hardware hash capture for VM: $VMName"
        
        # Ensure VM is running
        $vm = Get-VM -Name $VMName -ErrorAction Stop
        if ($vm.State -ne 'Running') {
            Write-Verbose "Starting VM $VMName..."
            Start-VM -Name $VMName -ErrorAction Stop
            
            # Wait for VM to be ready
            Write-Verbose "Waiting for VM to be ready..."
            $timeout = 300 # 5 minutes
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            while ($stopwatch.Elapsed.TotalSeconds -lt $timeout) {
                $vm = Get-VM -Name $VMName
                if ($vm.State -eq 'Running' -and $vm.Heartbeat -eq 'OkApplicationsHealthy') {
                    Write-Verbose "VM is ready"
                    break
                }
                Start-Sleep -Seconds 5
            }
            
            if ($stopwatch.Elapsed.TotalSeconds -ge $timeout) {
                throw "Timeout waiting for VM to be ready"
            }
        }
        
        # Get VM serial number for filename
        $vmSerial = (Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_VirtualSystemSettingData | 
                     Where-Object { $_.ElementName -eq $VMName }).BIOSSerialNumber
        
        if (-not $vmSerial) {
            Write-Warning "Could not get VM serial number, using VM name instead"
            $vmSerial = $VMName
        }
        
        Write-Verbose "VM Serial Number: $vmSerial"
        
        # Create hardware hash directory
        $hashDir = Join-Path $TenantPath ".hvtools\HardwareHashes"
        if (-not (Test-Path $hashDir)) {
            New-Item -Path $hashDir -ItemType Directory -Force | Out-Null
        }
        
        # Define output file path
        $hashFileName = "${vmSerial}_hwid.csv"
        $localHashFile = Join-Path $hashDir $hashFileName
        $vmHashFile = "C:\Windows\Temp\$hashFileName"
        
        # Create PowerShell Direct session
        Write-Verbose "Creating PowerShell Direct session to VM..."
        if (-not $Credential) {
            Write-Warning "No credentials provided. You will be prompted for VM credentials."
            $Credential = Get-Credential -Message "Enter credentials for VM: $VMName"
        }
        
        $session = New-PSSession -VMName $VMName -Credential $Credential -ErrorAction Stop
        
        try {
            # Install Get-WindowsAutoPilotInfo in the VM
            Write-Verbose "Installing Get-WindowsAutoPilotInfo script in VM..."
            $installScript = {
                # Check if NuGet provider is installed
                if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
                    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
                }
                
                # Set PSGallery as trusted
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
                
                # Install the script
                Install-Script -Name Get-WindowsAutoPilotInfo -Force -ErrorAction Stop
                
                # Verify installation
                $scriptPath = Get-InstalledScript -Name Get-WindowsAutoPilotInfo -ErrorAction SilentlyContinue
                if ($scriptPath) {
                    Write-Output "Get-WindowsAutoPilotInfo installed successfully"
                } else {
                    throw "Failed to install Get-WindowsAutoPilotInfo"
                }
            }
            
            Invoke-Command -Session $session -ScriptBlock $installScript
            
            # Capture hardware hash
            Write-Verbose "Capturing hardware hash..."
            $captureScript = {
                param($OutputFile)
                
                # Run Get-WindowsAutoPilotInfo and save to file
                & "$env:ProgramFiles\WindowsPowerShell\Scripts\Get-WindowsAutoPilotInfo.ps1" -OutputFile $OutputFile
                
                # Verify file was created
                if (Test-Path $OutputFile) {
                    Write-Output "Hardware hash captured successfully"
                } else {
                    throw "Hardware hash file was not created"
                }
            }
            
            Invoke-Command -Session $session -ScriptBlock $captureScript -ArgumentList $vmHashFile
            
            # Copy file from VM to host
            Write-Verbose "Copying hardware hash file from VM to host..."
            Copy-Item -FromSession $session -Path $vmHashFile -Destination $localHashFile -Force
            
            # Verify file was copied
            if (Test-Path $localHashFile) {
                Write-Host "Hardware hash saved to: $localHashFile" -ForegroundColor Green
                
                # Read and display basic info
                $hashData = Import-Csv $localHashFile
                Write-Host "Device Serial Number: $($hashData.'Device Serial Number')" -ForegroundColor Cyan
                Write-Host "Windows Product ID: $($hashData.'Windows Product ID')" -ForegroundColor Cyan
                
                return $localHashFile
            } else {
                throw "Failed to copy hardware hash file from VM"
            }
        }
        finally {
            # Clean up session
            if ($session) {
                Remove-PSSession -Session $session -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        Write-Warning "Failed to capture hardware hash for VM $VMName : $_"
        return $null
    }
}