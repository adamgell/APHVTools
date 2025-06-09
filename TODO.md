# HVTools TODO List

## In Progress  
- [x] Add -CaptureHardwareHash switch to New-ClientVM
  - [x] Add switch parameter to New-ClientVM
  - [x] Install Get-WindowsAutoPilotInfo script in VM
  - [x] Capture hardware hash and save to tenant folder
  - [x] Name file according to VM serial number
  - [x] Pull file back to host in tenant folder under .hvtools
  - [x] Create unattend.xml with random local admin account
  - [x] Inject admin account during reference image creation
  - [x] Auto-use injected credentials for hash capture
  - [ ] Test the complete functionality

## Completed
- [x] Add argument completers for all HVTools cmdlet parameters
- [x] Improve Get-HVToolsConfig output formatting
- [x] Add Show-HVToolsConfig for detailed configuration views
- [x] Make Import-Module only import if needed (created Import-RequiredModule helper)
- [x] Fix module import order issue
- [x] Created CreateRef.ps1 standalone script for reference image creation

## Future Enhancements
- [ ] Add parallel VM creation support
- [ ] Add VM template support
- [ ] Add support for custom unattend.xml
- [ ] Add VM snapshot management
- [ ] Add bulk VM operations (start/stop/remove)
- [ ] Add VM export/import functionality
- [ ] Add support for nested virtualization
- [ ] Add integration with Azure DevOps pipelines
- [ ] Add Pester tests for all functions
- [ ] Add performance metrics and reporting

## Notes
- Hardware hash capture requires Get-WindowsAutoPilotInfo script from PowerShell Gallery
- Hardware hash files should be named: `<SerialNumber>_hwid.csv`
- Files should be stored in: `<TenantPath>\.hvtools\HardwareHashes\`


## Adam's List
- [x] Make a public function to call a VM and mount its disk. Then make another function that checks for mounted disks and gives the option to dismount them via a numbered menu.
  - [x] Created Mount-VMDisk function to mount VM disks
  - [x] Created Get-MountedVMDisk function with interactive menu for dismounting 
