#region Get public and private function definition files.
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)
$cfg = Get-Content "$env:USERPROFILE\.hvtoolscfgpath" -ErrorAction SilentlyContinue
$script:tick = [char]0x221a

if ($cfg) {
    $script:hvConfig = if (Get-Content -Path $cfg -raw -ErrorAction SilentlyContinue) {
        Get-Content -Path $cfg -raw -ErrorAction SilentlyContinue | ConvertFrom-Json
    }
    else {
        $script:hvConfig = $null
    }
}
#endregion

#region Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($import.FullName): $_"
    }
}
#endregion

#region Export Public Functions
Export-ModuleMember -Function $Public.BaseName
#endregion

#region Register Argument Completers

# Tenant Name Completer
$tenantNameCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    
    if ($script:hvConfig -and $script:hvConfig.tenantConfig) {
        $script:hvConfig.tenantConfig | 
            Where-Object { $_.TenantName -like "$wordToComplete*" } |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_.TenantName,
                    $_.TenantName,
                    'ParameterValue',
                    "Tenant: $($_.TenantName) - Admin: $($_.AdminUpn)"
                )
            }
    }
}

# Image Name Completer
$imageNameCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    
    if ($script:hvConfig -and $script:hvConfig.images) {
        $script:hvConfig.images | 
            Where-Object { $_.imageName -like "$wordToComplete*" } |
            ForEach-Object {
                $isoName = Split-Path $_.imagePath -Leaf
                [System.Management.Automation.CompletionResult]::new(
                    $_.imageName,
                    $_.imageName,
                    'ParameterValue',
                    "Image: $($_.imageName) - ISO: $isoName"
                )
            }
    }
}

# Virtual Switch Completer
$vSwitchCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    
    Get-VMSwitch -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -like "$wordToComplete*" } |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(
                $_.Name,
                $_.Name,
                'ParameterValue',
                "Switch: $($_.Name) - Type: $($_.SwitchType)"
            )
        }
}

# Tools Name Completer
$toolsCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    
    # Common troubleshooting tools
    $commonTools = @(
        'ProcMon.exe',
        'ProcExp.exe',
        'Autoruns.exe',
        'Handle.exe',
        'PsExec.exe',
        'CMTrace.exe',
        'NotMyFault.exe',
        'DebugView.exe',
        'TCPView.exe',
        'RAMMap.exe',
        'VMMap.exe',
        'DiskMon.exe'
    )
    
    $commonTools | 
        Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(
                $_,
                $_,
                'ParameterValue',
                "Tool: $_"
            )
        }
}

# Register completers for TenantName parameters
Register-ArgumentCompleter -CommandName 'New-ClientVM' -ParameterName 'TenantName' -ScriptBlock $tenantNameCompleter
Register-ArgumentCompleter -CommandName 'Show-HVToolsConfig' -ParameterName 'TenantName' -ScriptBlock $tenantNameCompleter

# Register completers for ImageName/OSBuild parameters
Register-ArgumentCompleter -CommandName 'Add-TenantToConfig' -ParameterName 'ImageName' -ScriptBlock $imageNameCompleter
Register-ArgumentCompleter -CommandName 'New-ClientVM' -ParameterName 'OSBuild' -ScriptBlock $imageNameCompleter
Register-ArgumentCompleter -CommandName 'Show-HVToolsConfig' -ParameterName 'ImageName' -ScriptBlock $imageNameCompleter

# Register completers for VSwitchName parameters
Register-ArgumentCompleter -CommandName 'Add-NetworkToConfig' -ParameterName 'VSwitchName' -ScriptBlock $vSwitchCompleter

# Register completers for ToolNames parameters
Register-ArgumentCompleter -CommandName 'Add-ToolsToConfig' -ParameterName 'ToolNames' -ScriptBlock $toolsCompleter

#endregion