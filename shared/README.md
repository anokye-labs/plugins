# Shared Modules

Reusable PowerShell modules shared across Anokye plugins.

## Modules

| Module | Purpose |
|--------|---------|
| [OkyeremanAgentRunner](OkyeremanAgentRunner/) | Runtime foundation — logging, error handling, issue context, PR management, safe output processing, correlation tracking |
| [CLITestHarness](CLITestHarness/) | Test infrastructure — PowerShell module for testing Copilot CLI plugin interactions |

## Usage

```powershell
# Import a shared module
Import-Module ./shared/OkyeremanAgentRunner/OkyeremanAgentRunner.psd1
Import-Module ./shared/CLITestHarness/CLITestHarness.psd1
```
