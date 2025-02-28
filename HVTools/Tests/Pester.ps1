param (
    [string]$TestName = "*.Tests.ps1"
)

# Import Pester module
Import-Module Pester -MinimumVersion 5.0

# Define Pester configuration
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = "$PSScriptRoot"
$pesterConfig.Run.PassThru = $true
$pesterConfig.Output.Verbosity = 'Detailed'
$pesterConfig.TestResult.Enabled = $true
$pesterConfig.TestResult.OutputPath = "$PSScriptRoot\TestResults.xml"

if ($TestName -ne "*.Tests.ps1") {
    $pesterConfig.Filter.FullName = $TestName
}

# Run Pester tests
Invoke-Pester -Configuration $pesterConfig