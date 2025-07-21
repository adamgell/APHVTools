function Get-ToolsFromConfig {
    [cmdletbinding()]
    param ()
    try {
        # Ensure the hvConfig is loaded
        if (-not $script:hvConfig) {
            $script:hvConfig = (Get-Content -Path "$(Get-Content "$env:USERPROFILE\.hvtoolscfgpath" -ErrorAction SilentlyContinue)" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json)
            if (-not $script:hvConfig) {
                throw "Could not find APHVTools configuration. Please run Initialize-APHVTools first."
            }
        }

        # Return the tools array (or create it if it doesn't exist)
        if (-not $script:hvConfig.PSObject.Properties.Name.Contains('tools')) {
            # Add default tools if not configured
            $defaultTools = @("psexec.exe", "procmon.exe", "cmtrace.exe")
            $script:hvConfig | Add-Member -MemberType NoteProperty -Name 'tools' -Value $defaultTools
            $script:hvConfig | ConvertTo-Json -Depth 20 | Out-File -FilePath $script:hvConfig.hvConfigPath -Encoding ascii -Force
        }

        return $script:hvConfig.tools
    }
    catch {
        Write-Warning $_.Exception.Message
        return @()
    }
}