#
# Module manifest for module 'HVTools'
#

@{

    # Script module or binary module file associated with this manifest.
    RootModule        = 'HVTools.psm1'

    # Version number of this module.
    ModuleVersion     = '0.0.1'  # Updated version number

    # Supported PSEditions
    # CompatiblePSEditions = @()

    # ID used to uniquely identify this module
    GUID              = 'afa0ac68-0503-453b-a8ab-8db58f6d146e'

    # Author of this module
    Author            = 'Adam Gell'

    # Company or vendor of this module
    CompanyName       = ''

    # Copyright statement for this module
    Copyright         = ''

    # Description of the functionality provided by this module
    Description       = 'Tools for automating Hyper-V client VM creation with Autopilot'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the Windows PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules   = @(
        @{ ModuleName = "WindowsAutoPilotIntune"; ModuleVersion = "4.3" },
        @{ ModuleName = "Microsoft.Graph.Intune"; ModuleVersion = "6.1907.1.0" },
        @{ ModuleName = "Hyper-ConvertImage"; ModuleVersion = "10.2" }
    )

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Initialize-HVTools',
        'Get-HVToolsConfig',
        'Show-HVToolsConfig',
        'Add-ImageToConfig',
        'Add-NetworkToConfig',
        'Add-TenantToConfig',
        'New-ClientVM',
        'Add-ToolsToConfig',
        'Get-ToolsFromConfig',
        'Mount-VMDisk',
        'Get-MountedVMDisk'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport   = @()

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @("Intune", "Azure", "Automation","Hyper-V", "Virtualization")

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/tabs-not-spaces/HVTools'

        } # End of PSData hashtable

    } # End of PrivateData hashtable

}