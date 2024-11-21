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

    if ($buildLocal) {
        [int32]$env:BUILD_BUILDID = 69
        if (Test-Path $PSScriptRoot\localenv.ps1 -ErrorAction SilentlyContinue) {
            . $PSScriptRoot\localenv.ps1
        }
        if (Test-Path "$PSScriptRoot\bin\release\*") {
            [int32]$env:BUILD_BUILDID = ((Get-ChildItem $PSScriptRoot\bin\release\).Name |
                Measure-Object -Maximum |
                Select-Object -ExpandProperty Maximum) + 1
        }
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
        }
    )

    #region Generate a new version number
    $newVersion = New-Object version -ArgumentList 1, 0, 0, $env:BUILD_BUILDID
    #endregion

    #region Build out the release
    $relPath = "$PSScriptRoot\bin\release\$env:BUILD_BUILDID\$moduleName"
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

    $releaseNotes = (git log --oneline --decorate -- "$modulePath/*.*") -join "`n"

    Write-Host "Updating module manifest" -ForegroundColor Cyan

    # First remove all old RequiredModules entries by creating a new manifest
    $tempManifestPath = "$relPath\temp.psd1"
    New-ModuleManifest -Path $tempManifestPath `
        -RootModule "$moduleName.psm1" `
        -ModuleVersion $newVersion `
        -Description $description `
        -Author "Ben Reader" `
        -CompanyName "Powers-Hell" `
        -RequiredModules $RequiredModules `
        -FunctionsToExport $functions `
        -ReleaseNotes $releaseNotes `
        -Tags @("Intune", "Azure", "Automation", "Hyper-V", "Virtualization")

    # Replace the original manifest with the temp one
    Move-Item -Path $tempManifestPath -Destination $manifestPath -Force

    $moduleManifest = Get-Content $manifestPath -raw | Invoke-Expression

    #endregion

    #region Generate the nuspec manifest
    $t = [xml](Get-Content $PSScriptRoot\module.nuspec -Raw)
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
    #endregion

    Write-Host "`nBuild completed successfully!" -ForegroundColor Green
    Write-Host "Module built at: $relPath" -ForegroundColor Green
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
