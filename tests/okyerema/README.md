# Okyerema Tests

Test suite for the Okyerema rhythm engine plugin.

## Structure

| Directory | Purpose |
|-----------|---------|
| `unit/` | Unit tests for individual scripts and functions |
| `integration/` | Integration tests requiring GitHub API access |
| `e2e/` | End-to-end tests for full workflow validation |
| `fixtures/` | Test data and mock responses |

## Running Tests

```powershell
# All tests
pwsh -File tests/okyerema/Run-LocalTests.ps1

# Unit tests only
pwsh -NoProfile -Command "Invoke-Pester -Path tests/okyerema/unit -CI"
```

## Requirements

- PowerShell 7.0+
- Pester 5+
- GitHub CLI (`gh`) authenticated (for integration/e2e)
