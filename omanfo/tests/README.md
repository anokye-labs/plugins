# Omanfo Plugin Tests

This directory contains the test suite for the Omanfo plugin.

## Test Runner

The master test runner is `Run-LocalTests.ps1`.

### Usage

```powershell
# Run all tests
./Run-LocalTests.ps1

# Run only smoke tests
./Run-LocalTests.ps1 -TestLevel Smoke

# Run unit tests
./Run-LocalTests.ps1 -TestLevel Unit

# Run E2E tests with custom repository
./Run-LocalTests.ps1 -TestLevel E2E -TestRepo myorg/myrepo
```

### Parameters

- **`-TestLevel`**: The level of tests to run
  - `Unit` - Unit tests (*.Unit.Tests.ps1)
  - `Smoke` - Smoke tests (*.Smoke.Tests.ps1 or Smoke/*.Tests.ps1)
  - `E2E` - End-to-end tests (*.E2E.Tests.ps1 or E2E/*.Tests.ps1)
  - `All` - All test levels (default)

- **`-TestRepo`**: Repository to use for E2E tests (default: anokye-labs/plugins)

### Test Naming Conventions

The runner discovers test files based on naming conventions:

- **Unit tests**: `*.Unit.Tests.ps1`
- **Smoke tests**: `*.Smoke.Tests.ps1` or files in `Smoke/` subdirectory
- **E2E tests**: `*.E2E.Tests.ps1` or files in `E2E/` subdirectory

## Current Tests

### Smoke Tests

#### Install-Plugin.Smoke.Tests.ps1
Tests the full plugin installation lifecycle via `copilot plugin` CLI:
- Marketplace add
- Plugin install
- Plugin list
- Plugin update
- Plugin uninstall
- Plugin reinstall

**Note**: These tests require the `copilot` CLI to be installed. They will be automatically skipped if the CLI is not available.

#### Skill-Loading.Smoke.Tests.ps1
Tests skill discovery and slash command recognition:
- Validates all expected skill directories exist
- Checks skill structure (SKILL.md, scripts, agent files)
- Validates slash command documentation
- Verifies supporting scripts for commands
- Validates skill metadata
- Checks plugin manifest.json
- Verifies agent configuration files

## Requirements

- PowerShell 7.0+
- Pester 5.x (automatically installed if not present)
- GitHub CLI (`gh`) for some tests
- Copilot CLI (`copilot`) for Install-Plugin tests (optional)

## Exit Codes

- **0**: All tests passed
- **1**: One or more tests failed

## Output

The runner prints:
- List of discovered test files
- Detailed test results (Pester output)
- Summary table by test level
- Overall pass/fail/skip counts
- Test duration

## Development

When adding new tests:

1. Follow the naming conventions above
2. Place tests in appropriate subdirectories or use naming suffixes
3. Use Pester 5.x syntax
4. Add `-Skip` conditions for tests requiring specific tools
5. Document test requirements in the test file

## CI Integration

These tests can be integrated into GitHub Actions workflows:

```yaml
- name: Run Omanfo Tests
  run: |
    cd omanfo/tests
    pwsh -File Run-LocalTests.ps1 -TestLevel Smoke
```
