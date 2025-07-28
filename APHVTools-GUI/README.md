# APHVTools GUI

This directory contains graphical user interface tools for managing APHVTools.

## Available GUIs

### 1. Show-APHVToolsConfig.ps1
A simple configuration viewer that displays the APHVTools configuration in JSON and Tree view formats.

**Features:**
- View configuration in formatted JSON
- Navigate configuration in tree view
- Export configuration to JSON file
- Refresh configuration

**Usage:**
```powershell
.\Show-APHVToolsConfig.ps1
```

### 2. APHVTools-Manager.ps1
A comprehensive management interface for APHVTools with multiple tabs for different management tasks.

**Features:**

#### VM Management Tab
- List all VMs created by APHVTools
- View VM status (Running/Stopped)
- Start, Stop, and Restart VMs
- Delete VMs with confirmation
- Connect to VM console
- View VM details (CPU, Memory, Uptime, Tenant)

#### Create VMs Tab
- Form-based VM creation wizard
- Select tenant and image from dropdowns
- Configure number of VMs (1-50) with slider
- Set CPU cores and memory
- Optional VM name prefix
- Skip Autopilot configuration option
- Include troubleshooting tools option
- Real-time creation progress
- Creation log output

#### Image Management Tab
- View all configured images
- Add new ISO/VHDX images
- Delete unused images
- Create reference VHDX from ISO
- Validate image status
- View image details

#### Tenant Management Tab
- Add new tenants
- Edit tenant details
- Delete tenants
- Test tenant authentication
- View tenant-specific VM count
- View tenant configuration paths

#### Configuration Tab
- View raw configuration in JSON format
- Export configuration to file
- Refresh configuration display

**Usage:**
```powershell
.\APHVTools-Manager.ps1
```

## Requirements

- PowerShell 5.1 or higher
- APHVTools module installed or available in the parent directory
- Windows with .NET Framework (for WPF)
- Hyper-V role enabled (for VM management features)

## Troubleshooting

### Module Loading Issues
If the GUI can't find the APHVTools module, it will search in these locations:
1. `../APHVTools` (relative to GUI directory)
2. Current directory
3. User's PowerShell modules directory
4. System PowerShell modules directory

### Permission Issues
- VM management operations require administrator privileges
- Ensure you have appropriate Hyper-V permissions

### Testing
Use `test-config.ps1` to verify that the APHVTools module can be loaded and configuration can be accessed:

```powershell
.\test-config.ps1
```

## Future Enhancements

Planned features for future versions:
- Real-time dashboard with resource usage
- Bulk VM operations
- Network topology viewer
- Autopilot enrollment status tracking
- Log viewer with filtering
- Settings management
- Module update checker