# Contributing to HVTools

Thank you for considering contributing to HVTools! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contribution Process](#contribution-process)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Reporting Issues](#reporting-issues)
- [Feature Requests](#feature-requests)

## Code of Conduct

### Our Pledge

We are committed to providing a friendly, safe, and welcoming environment for all contributors, regardless of experience level, gender identity and expression, sexual orientation, disability, personal appearance, body size, race, ethnicity, age, religion, nationality, or other similar characteristics.

### Expected Behavior

- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally
3. Create a new branch for your feature or bug fix
4. Make your changes
5. Submit a pull request

## Development Setup

### Prerequisites

- Windows 10/11 or Windows Server with Hyper-V
- PowerShell 5.1 or higher
- Git
- Visual Studio Code (recommended) with PowerShell extension

### Setting Up Your Development Environment

```powershell
# Clone your fork
git clone https://github.com/YOUR-USERNAME/HVTools.git
cd HVTools

# Add the upstream repository
git remote add upstream https://github.com/adamgell/HVTools.git

# Create a new branch
git checkout -b feature/your-feature-name

# Build the module locally
./build.ps1 -modulePath ./HVTools -buildLocal

# Import the module for testing
Import-Module ./HVTools/HVTools.psd1 -Force
```

### Recommended VS Code Extensions

- PowerShell
- GitLens
- Markdown All in One
- EditorConfig for VS Code

## Contribution Process

1. **Check existing issues**: Before starting work, check if there's already an issue for what you want to do
2. **Create/claim an issue**: If no issue exists, create one. Comment on the issue to claim it
3. **Fork and branch**: Fork the repository and create a feature branch
4. **Write code**: Implement your changes following our coding standards
5. **Test**: Ensure your changes don't break existing functionality
6. **Document**: Update documentation if needed
7. **Submit PR**: Submit a pull request with a clear description

## Coding Standards

### PowerShell Style Guide

#### Naming Conventions

```powershell
# Functions: Use approved verbs and PascalCase
function Get-VMConfiguration { }
function New-ClientDevice { }

# Parameters: PascalCase
param (
    [string]$TenantName,
    [int]$NumberOfVMs
)

# Variables: camelCase
$vmConfiguration = Get-VMConfiguration
$clientDetails = @{}

# Script-scoped variables: Use $script: prefix
$script:hvConfig = @{}
```

#### Function Structure

```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
        Brief description of the function
    
    .DESCRIPTION
        Detailed description of what the function does
    
    .PARAMETER ParameterName
        Description of the parameter
    
    .EXAMPLE
        Verb-Noun -ParameterName "Value"
        
        Description of what this example does
    
    .NOTES
        Additional information about the function
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$ParameterName,
        
        [Parameter(Mandatory = $false)]
        [switch]$SwitchParameter
    )
    
    begin {
        Write-Verbose "Starting $($MyInvocation.MyCommand.Name)"
    }
    
    process {
        try {
            # Main logic here
            if ($PSCmdlet.ShouldProcess($ParameterName, "Action description")) {
                # Perform action
            }
        }
        catch {
            Write-LogEntry -Message "Error: $_" -Severity 3
            throw
        }
    }
    
    end {
        Write-Verbose "Completed $($MyInvocation.MyCommand.Name)"
    }
}
```

#### Best Practices

1. **Always use CmdletBinding**: Add `[CmdletBinding()]` to all functions
2. **Support WhatIf**: Add `SupportsShouldProcess` for functions that make changes
3. **Parameter validation**: Use validation attributes
4. **Error handling**: Use try/catch blocks
5. **Logging**: Use `Write-LogEntry` for consistent logging
6. **Verbose output**: Include meaningful verbose messages
7. **No aliases**: Write out full command names
8. **Consistent formatting**: 4-space indentation

### File Organization

- Public functions: `/HVTools/Public/`
- Private functions: `/HVTools/Private/`
- Module manifest: `/HVTools/HVTools.psd1`
- Root module: `/HVTools/HVTools.psm1`

## Testing Guidelines

### Manual Testing

Before submitting a PR, manually test:

1. **Module import**: `Import-Module ./HVTools/HVTools.psd1 -Force`
2. **Function execution**: Test your changes with various parameter combinations
3. **WhatIf support**: Test with `-WhatIf` parameter
4. **Error scenarios**: Test error handling
5. **Existing functionality**: Ensure existing functions still work

### Test Scenarios

```powershell
# Test module import
Remove-Module HVTools -Force -ErrorAction SilentlyContinue
Import-Module ./HVTools/HVTools.psd1 -Force
Get-Command -Module HVTools

# Test your function
Your-Function -Parameter "Value" -Verbose
Your-Function -Parameter "Value" -WhatIf

# Test error handling
Your-Function -Parameter $null  # Should fail gracefully
```

### Future: Automated Testing

We plan to implement Pester tests. When contributing:
- Consider how your code could be tested
- Document test scenarios in your PR
- Help us build the test suite!

## Commit Guidelines

### Commit Message Format

```
<type>: <subject>

<body>

<footer>
```

### Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, missing semicolons, etc.)
- **refactor**: Code refactoring
- **test**: Adding tests
- **chore**: Maintenance tasks

### Examples

```
feat: Add support for Windows 11 24H2

Added new image detection logic to support the latest Windows 11 release.
Updated reference VHDX creation process to handle new image format.

Closes #123
```

```
fix: Correct VM memory allocation for systems with >64GB RAM

The previous logic incorrectly calculated available memory on high-RAM systems.
Now properly accounts for system overhead and Hyper-V requirements.

Fixes #456
```

### Commit Best Practices

1. Keep commits focused and atomic
2. Write clear, descriptive commit messages
3. Reference issues and PRs
4. Sign your commits if possible: `git commit -s`

## Pull Request Process

### Before Submitting

1. **Update from upstream**:
   ```powershell
   git fetch upstream
   git rebase upstream/master
   ```

2. **Test thoroughly**: Run through all test scenarios

3. **Update documentation**: Include any necessary documentation updates

4. **Check code style**: Ensure your code follows our standards

### PR Template

When creating a PR, include:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Module imports successfully
- [ ] Function executes without errors
- [ ] WhatIf parameter works correctly
- [ ] Error scenarios handled properly

## Checklist
- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review
- [ ] I have added/updated documentation
- [ ] My changes generate no new warnings
- [ ] Existing functionality still works

## Related Issues
Closes #(issue number)
```

### Review Process

1. **Automated checks**: Ensure all automated checks pass
2. **Code review**: A maintainer will review your code
3. **Feedback**: Address any feedback or requested changes
4. **Merge**: Once approved, your PR will be merged

## Reporting Issues

### Bug Reports

When reporting bugs, include:

1. **PowerShell version**: `$PSVersionTable`
2. **OS version**: Windows version and build
3. **Module version**: `Get-Module HVTools | Select Version`
4. **Steps to reproduce**: Detailed steps to reproduce the issue
5. **Expected behavior**: What should happen
6. **Actual behavior**: What actually happens
7. **Error messages**: Full error output
8. **Screenshots**: If applicable

### Bug Report Template

```markdown
## Bug Description
Clear description of the bug

## Environment
- PowerShell Version: 
- OS Version: 
- HVTools Version: 
- Hyper-V Version: 

## Steps to Reproduce
1. Step one
2. Step two
3. Step three

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Error Output
```
Paste error here
```

## Additional Context
Any other relevant information
```

## Feature Requests

### Suggesting Features

When suggesting new features:

1. **Check existing issues**: Ensure it hasn't been suggested
2. **Be specific**: Clearly describe the feature
3. **Provide context**: Explain why it's needed
4. **Consider implementation**: Think about how it might work

### Feature Request Template

```markdown
## Feature Description
Clear description of the proposed feature

## Use Case
Why is this feature needed? What problem does it solve?

## Proposed Solution
How might this feature work?

## Alternatives Considered
What alternatives have you considered?

## Additional Context
Any other relevant information, mockups, or examples
```

## Questions?

If you have questions about contributing:

1. Check existing documentation
2. Look through closed issues/PRs
3. Open a new discussion
4. Reach out to maintainers

Thank you for contributing to HVTools! Your efforts help make this tool better for everyone.