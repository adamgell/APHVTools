function Get-NextVMNumber {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TenantName
    )

    try {
        # Get all VMs that match the tenant name pattern
        $existingVMs = Get-VM -Name "$TenantName*" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "^$TenantName`_\d+$" }

        if (!$existingVMs) {
            return 1
        }

        # Extract numbers from VM names and find the highest
        $numbers = $existingVMs | ForEach-Object {
            if ($_.Name -match "_(\d+)$") {
                [int]$matches[1]
            }
        } | Sort-Object

        # Return next number in sequence
        return ($numbers | Select-Object -Last 1) + 1
    }
    catch {
        Write-Error "Failed to get next VM number: $_"
        throw
    }
}