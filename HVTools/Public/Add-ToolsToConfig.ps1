function Add-ToolsToConfig {
    [cmdletbinding()]
    param (
        [parameter(Position = 1, Mandatory = $true)]
        [string[]]$ToolNames
    )
    try {
        Write-Host "Adding tools to configuration... " -ForegroundColor Cyan -NoNewline

        # Ensure the tools property exists in the config
        if (-not $script:hvConfig.PSObject.Properties.Name.Contains('tools')) {
            $script:hvConfig | Add-Member -MemberType NoteProperty -Name 'tools' -Value @()
        }

        # Add each tool to the config if it doesn't already exist
        foreach ($tool in $ToolNames) {
            if ($script:hvConfig.tools -notcontains $tool) {
                $script:hvConfig.tools += $tool
            }
        }

        # Save the updated config
        $script:hvConfig | ConvertTo-Json -Depth 20 | Out-File -FilePath $hvConfig.hvConfigPath -Encoding ascii -Force
        Write-Host $script:tick -ForegroundColor Green

        # Check if tools directory exists, create if not
        $toolsPath = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "Tools"
        if (-not (Test-Path -Path $toolsPath)) {
            Write-Host "Creating tools directory at $toolsPath... " -ForegroundColor Cyan -NoNewline
            New-Item -Path $toolsPath -ItemType Directory -Force | Out-Null
            Write-Host $script:tick -ForegroundColor Green
        }

        # Output guidance for tool placement
        Write-Host "`nTools configuration updated. Please ensure the following tools are placed in $toolsPath :" -ForegroundColor Yellow
        foreach ($tool in $script:hvConfig.tools) {
            $status = Test-Path -Path (Join-Path -Path $toolsPath -ChildPath $tool) -PathType Leaf
            $statusIcon = if ($status) { $script:tick } else { "×" }
            $statusColor = if ($status) { "Green" } else { "Red" }
            Write-Host "  $statusIcon $tool" -ForegroundColor $statusColor
        }
    }
    catch {
        $errorMsg = $_
    }
    finally {
        if ($errorMsg) {
            Write-Warning $errorMsg
        }
    }
}