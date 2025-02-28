# HVTools Unit Tests

This directory contains unit tests for the HVTools PowerShell module using the Pester testing framework.

## Structure

- `/Public` - Tests for all public functions in the module
- `Pester.ps1` - Script to run all tests with proper configuration

## Running Tests

To run all tests:

```powershell
cd <HVTools Directory>
./Tests/Pester.ps1
```

To run a specific test:

```powershell
cd <HVTools Directory>
./Tests/Pester.ps1 -TestName "Add-ImageToConfig.Tests.ps1"
```

## Requirements

- PowerShell 5.1 or PowerShell Core 6.0+
- Pester 5.0 or higher (`Install-Module -Name Pester -MinimumVersion 5.0 -Force`)

## Test Design

Each test file follows these principles:

1. Mocking dependencies to isolate the function being tested
2. Testing various input scenarios (valid inputs, edge cases, error conditions)
3. Verifying both function output and side effects (like calls to other functions)

## Adding New Tests

When adding a new function to the module, create a corresponding test file in the appropriate directory following the existing patterns.