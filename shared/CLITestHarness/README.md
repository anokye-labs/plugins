# CLITestHarness

PowerShell module for testing Copilot CLI plugin interactions. Provides mock infrastructure and assertion helpers for validating plugin behavior without requiring a live Copilot session.

## Installation

```powershell
Import-Module ./shared/CLITestHarness/CLITestHarness.psd1
```

## Structure

| File | Purpose |
|------|---------|
| `CLITestHarness.psd1` | Module manifest |
| `CLITestHarness.psm1` | Module implementation |
| `Tests/` | Unit tests for the harness itself |

## Requirements

- PowerShell 7.0+
- Pester 5+ (for running tests)
