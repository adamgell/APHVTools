[cmdletbinding()]
param (
    [parameter(Mandatory = $true)]
    [System.IO.FileInfo]$modulePath,

    [parameter(Mandatory = $false)]
    [string]$moduleName,

    [parameter(Mandatory = $false)]
    [switch]$buildLocal
)

try {
    if (!($moduleName)) {
        $moduleName = Split-Path $modulePath -Leaf
    }

    # Define required modules upfront
    $RequiredModules = @(
        @{
            ModuleName = "Microsoft.Graph.Authentication"
            ModuleVersion = "2.0.0"
        },
        @{
            ModuleName = "Microsoft.Graph.DeviceManagement"
            ModuleVersion = "2.0.0"
        },
        @{
            ModuleName = "Microsoft.Graph.DeviceManagement.Enrollment"
            ModuleVersion = "2.0.0"
        },
        @{
            ModuleName = "Hyper-ConvertImage"
            ModuleVersion = "10.2"
        },
        @{
            ModuleName = "WindowsAutoPilotIntune"
            ModuleVersion = "4.3"
        },
        @{
            ModuleName = "Microsoft.Graph.Intune"
            ModuleVersion = "6.1907.1.0"
        }
    )

    #region Generate a new version number
    # Base version components
    $majorVersion = 0
    $minorVersion = 0
    $patchVersion = 1

    # Determine build number
    if ($buildLocal) {
        # Check if there's an existing module manifest in the module path
        $manifestPath = Join-Path -Path $modulePath -ChildPath "$moduleName.psd1"
        if (Test-Path $manifestPath) {
            $existingModule = Import-PowerShellDataFile -Path $manifestPath
            $existingVersion = [version]$existingModule.ModuleVersion

            # Keep major/minor/patch from existing version if greater than our base
            if ($existingVersion.Major -gt $majorVersion) {
                $majorVersion = $existingVersion.Major
                $minorVersion = $existingVersion.Minor
                $patchVersion = $existingVersion.Build
            }
            elseif ($existingVersion.Major -eq $majorVersion -and $existingVersion.Minor -gt $minorVersion) {
                $minorVersion = $existingVersion.Minor
                $patchVersion = $existingVersion.Build
            }
            elseif ($existingVersion.Major -eq $majorVersion -and $existingVersion.Minor -eq $minorVersion -and $existingVersion.Build -gt $patchVersion) {
                $patchVersion = $existingVersion.Build
            }

            # Always increment patch version for a new build
            $patchVersion++
        }
    }
    else {
        # For CI/CD, use the BUILD_BUILDID env variable if available, otherwise use 0
        $buildId = if ($env:BUILD_BUILDID) { [int]$env:BUILD_BUILDID } else { 0 }
    }

    # Create the new version (use 3-part version instead of 4-part for cleaner display)
    if ($buildLocal) {
        # For local builds, use 3-part version (Major.Minor.Patch)
        $newVersion = New-Object version -ArgumentList $majorVersion, $minorVersion, $patchVersion
    } else {
        # For CI/CD builds, include buildId as 4th part
        $newVersion = New-Object version -ArgumentList $majorVersion, $minorVersion, $patchVersion, $buildId
    }
    #endregion

    #region Build out the release
    # Use the version number as the folder name (without the build ID)
    $versionStr = "$majorVersion.$minorVersion.$patchVersion"
    $relPath = "$PSScriptRoot\bin\release\$versionStr\$moduleName"

    Write-Host "Version is $newVersion" -ForegroundColor Cyan
    Write-Host "Source Path is $modulePath" -ForegroundColor Cyan
    Write-Host "Module Name is $moduleName" -ForegroundColor Cyan
    Write-Host "Release Path is $relPath" -ForegroundColor Cyan

    # Create release directory
    if (!(Test-Path $relPath)) {
        New-Item -Path $relPath -ItemType Directory -Force | Out-Null
    }

    # First copy root module files
    Write-Host "`nCopying root module files..." -ForegroundColor Cyan
    Get-ChildItem -Path $modulePath -File | ForEach-Object {
        Write-Host "Copying $($_.Name)" -ForegroundColor Gray
        Copy-Item -Path $_.FullName -Destination $relPath -Force
    }

    # Handle Public and Private folders
    foreach ($folder in @('Public', 'Private')) {
        $folderSourcePath = Join-Path $modulePath $folder
        $destinationPath = Join-Path $relPath $folder

        # Check if source folder exists
        if (Test-Path $folderSourcePath) {
            Write-Host "`nProcessing $folder folder..." -ForegroundColor Cyan

            # Create destination folder
            if (!(Test-Path $destinationPath)) {
                New-Item -Path $destinationPath -ItemType Directory -Force | Out-Null
                Write-Host "Created $folder folder in release directory" -ForegroundColor Gray
            }

            # Copy all files from the source folder
            Get-ChildItem -Path $folderSourcePath -File | ForEach-Object {
                Write-Host "Copying $($_.Name)" -ForegroundColor Gray
                Copy-Item -Path $_.FullName -Destination $destinationPath -Force
            }

            # Count files copied
            $filesCopied = (Get-ChildItem -Path $destinationPath -File).Count
            Write-Host "Copied $filesCopied files to $folder folder" -ForegroundColor Green
        }
        else {
            Write-Warning "Source $folder folder not found at: $folderSourcePath"
        }
    }

    # Copy description.txt
    if (Test-Path "$modulePath\description.txt") {
        Copy-Item -Path "$modulePath\description.txt" -Destination "$relPath\description.txt" -Force
        $description = (Get-Content "$relPath\description.txt" -Raw).ToString()
    }
    else {
        $description = "PowerShell module for managing Intune and Hyper-V integration"
    }

    #region Generate function list and update manifest
    Write-Host "`nScanning for public functions in: $modulePath\Public" -ForegroundColor Cyan
    $publicPath = Join-Path -Path $modulePath -ChildPath "Public"
    $functions = @(Get-ChildItem -Path "$publicPath\*.ps1" -ErrorAction SilentlyContinue).basename

    if ($functions.Count -gt 0) {
        Write-Host "Found public functions:" -ForegroundColor Green
        $functions | ForEach-Object {
            Write-Host "- $_" -ForegroundColor Gray
        }
    }
    else {
        Write-Warning "No public functions found!"
        $functions = @('NoPublicFunctions')
    }

    # Create or update module manifest
    $manifestPath = "$relPath\$moduleName.psd1"
    if (!(Test-Path $manifestPath)) {
        Write-Host "`nCreating new module manifest" -ForegroundColor Cyan
        New-ModuleManifest -Path $manifestPath `
            -RootModule "$moduleName.psm1" `
            -ModuleVersion $newVersion `
            -Description $description `
            -Author "Ben Reader" `
            -CompanyName "Powers-Hell" `
            -RequiredModules $RequiredModules `
            -Tags @("Intune", "Azure", "Automation", "Hyper-V", "Virtualization")
    }

    # Get release notes from git if possible
    $releaseNotes = ""
    try {
        $releaseNotes = (git log --oneline --decorate -- "$modulePath/*.*" -n 10) -join "`n"
        if ([string]::IsNullOrEmpty($releaseNotes)) {
            $releaseNotes = "Version $newVersion"
        }
    }
    catch {
        $releaseNotes = "Version $newVersion"
    }

    Write-Host "Updating module manifest" -ForegroundColor Cyan

    # First remove all old RequiredModules entries by creating a new manifest
    $tempManifestPath = "$relPath\temp.psd1"
    New-ModuleManifest -Path $tempManifestPath `
        -RootModule "$moduleName.psm1" `
        -ModuleVersion $newVersion `
        -Description $description `
        -Author 'Adam Gell'`
        -CompanyName "None" `
        -RequiredModules $RequiredModules `
        -FunctionsToExport $functions `
        -ReleaseNotes $releaseNotes `
        -Tags @("Intune", "Azure", "Automation", "Hyper-V", "Virtualization")

    # Replace the original manifest with the temp one
    Move-Item -Path $tempManifestPath -Destination $manifestPath -Force

    $moduleManifest = Get-Content $manifestPath -raw | Invoke-Expression

    #endregion

    #region Generate the nuspec manifest
    if (Test-Path "$PSScriptRoot\module.nuspec") {
        Write-Host "`nUpdating NuSpec file..." -ForegroundColor Cyan
        $t = [xml](Get-Content "$PSScriptRoot\module.nuspec" -Raw)
        $t.package.metadata.id = $moduleName
        $t.package.metadata.version = $newVersion.ToString()
        $t.package.metadata.authors = $moduleManifest.author.ToString()
        $t.package.metadata.owners = $moduleManifest.author.ToString()
        $t.package.metadata.requireLicenseAcceptance = "false"
        $t.package.metadata.description = $description
        $t.package.metadata.releaseNotes = $releaseNotes
        $t.package.metadata.copyright = $moduleManifest.copyright.ToString()
        $t.package.metadata.tags = ($moduleManifest.PrivateData.PSData.Tags -join ',').ToString()

        $t.Save("$PSScriptRoot\$moduleName.nuspec")
        Write-Host "NuSpec file created: $PSScriptRoot\$moduleName.nuspec" -ForegroundColor Green
    }
    else {
        Write-Host "`nCreating new NuSpec file..." -ForegroundColor Cyan
        $nuspecContent = @"
<?xml version="1.0"?>
<package>
  <metadata>
    <id>$moduleName</id>
    <version>$($newVersion.ToString())</version>
    <authors>$($moduleManifest.author.ToString())</authors>
    <owners>$($moduleManifest.author.ToString())</owners>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <description>$description</description>
    <releaseNotes>$releaseNotes</releaseNotes>
    <copyright>$($moduleManifest.copyright.ToString())</copyright>
    <tags>$($moduleManifest.PrivateData.PSData.Tags -join ',')</tags>
  </metadata>
</package>
"@
        Set-Content -Path "$PSScriptRoot\$moduleName.nuspec" -Value $nuspecContent
        Write-Host "NuSpec file created: $PSScriptRoot\$moduleName.nuspec" -ForegroundColor Green
    }
    #endregion

    Write-Host "`nBuild completed successfully!" -ForegroundColor Green
    Write-Host "Module built at: $relPath" -ForegroundColor Green
    Write-Host "Version: $newVersion" -ForegroundColor Green
    Write-Host "Total public functions: $($functions.Count)" -ForegroundColor Green

    # Verify final structure
    Write-Host "`nFinal module structure:" -ForegroundColor Cyan
    Get-ChildItem -Path $relPath -Recurse | ForEach-Object {
        $indent = "  " * ($_.FullName.Split([IO.Path]::DirectorySeparatorChar).Count - $relPath.Split([IO.Path]::DirectorySeparatorChar).Count)
        Write-Host "$indent$($_.Name)" -ForegroundColor Gray
    }
}
catch {
    Write-Error "Build failed: $_"
    throw
}