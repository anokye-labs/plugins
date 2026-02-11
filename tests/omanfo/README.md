# Omanfo Plugin Test Suite

This directory contains the comprehensive test suite for the Omanfo plugin's Okyerema skills.

**Note**: Tests are located at the repository root (`tests/omanfo/`) rather than inside the plugin directory (`omanfo/`). This keeps tests available for development and CI while excluding them from the plugin distribution package.

## Test Coverage Status

✅ **100% Script Coverage** - All 28 scripts in `omanfo/skills/okyerema/scripts/` have unit test coverage

## Test Runner

The master test runner is `Run-LocalTests.ps1`.

### Usage

```powershell
# From the tests/omanfo directory
cd tests/omanfo

# Run all tests (Unit + Smoke + E2E + Automated E2E)
./Run-LocalTests.ps1

# Run only smoke tests
./Run-LocalTests.ps1 -TestLevel Smoke

# Run unit tests
./Run-LocalTests.ps1 -TestLevel Unit

# Run E2E tests (includes both manual Pester E2E and automated Copilot SDK E2E)
./Run-LocalTests.ps1 -TestLevel E2E -TestRepo myorg/myrepo
```

### Parameters

- **`-TestLevel`**: The level of tests to run
  - `Unit` - Unit tests (*.Unit.Tests.ps1) - 100% coverage enforced
  - `Smoke` - Smoke tests (*.Smoke.Tests.ps1 or Smoke/*.Tests.ps1)
  - `E2E` - End-to-end tests (manual Pester + automated Copilot SDK)
  - `All` - All test levels (default)

- **`-TestRepo`**: Repository to use for E2E tests (default: anokye-labs/plugins)

### Test Naming Conventions

The runner discovers test files based on naming conventions:

- **Unit tests**: `*.Unit.Tests.ps1`
- **Smoke tests**: `*.Smoke.Tests.ps1` or files in `Smoke/` subdirectory
- **E2E tests**: `*.E2E.Tests.ps1` or files in `E2E/` subdirectory
- **Automated E2E tests**: Node.js tests in `e2e/automated/` using Copilot SDK

## Test Types

### Unit Tests (`unit/`)

**Purpose**: Test individual script functionality in isolation

- **Count**: 120+ tests across 6 test files
- **Coverage**: All 28 scripts tested
- **Technology**: Pester 5, Mock gh CLI
- **Runtime**: Fast (~5-10 seconds)
- **CI Enforcement**: ✅ Yes - PRs blocked without coverage

**Test Files:**
- `IssueManagement.Unit.Tests.ps1` - Issue creation, hierarchy, project management
- `PRIntelligence.Unit.Tests.ps1` - PR analysis and status
- `StatusHealth.Unit.Tests.ps1` - DAG health and hierarchy validation
- `ThreadManagement.Unit.Tests.ps1` - Review thread operations
- `WorkSelection.Unit.Tests.ps1` - Ready/blocked/stalled/orphaned issue selection
- `PlanMaterialization.Unit.Tests.ps1` - Plan-to-issues conversion

**CI Validation:**
The CI workflow includes `Test-ScriptTestCoverage.ps1` (7th validation step) that:
1. Enumerates all scripts in `omanfo/skills/okyerema/scripts/`
2. Parses all Describe blocks in unit tests
3. Fails if any script lacks test coverage
4. Reports coverage percentage

### Smoke Tests

**Purpose**: Verify basic plugin installation and skill loading

- **Count**: 2 smoke tests
- **Runtime**: Fast (~2-5 seconds)
- **Files**:
  - `Install-Plugin.Smoke.Tests.ps1` - Plugin structure validation
  - `Skill-Loading.Smoke.Tests.ps1` - Skill loading verification

### E2E Tests - Manual (`e2e/*.e2e.Tests.ps1`)

**Purpose**: Full workflow validation with real Copilot CLI interaction

- **Count**: 5 test suites
- **Technology**: Pester 5, real `copilot -p` CLI commands
- **Prerequisites**: Copilot CLI, gh CLI authenticated, network access
- **Runtime**: Slow (~5-15 minutes)
- **CI**: ❌ Not in CI (requires human + auth)

**Test Files:**
- `IssueCreation.e2e.Tests.ps1` - Create typed issues
- `Hierarchy.e2e.Tests.ps1` - Epic/Feature/Task hierarchies
- `StatusReporting.e2e.Tests.ps1` - sitrep and health commands
- `PRWorkflow.e2e.Tests.ps1` - PR analysis and review workflows
- `FullWorkflow.e2e.Tests.ps1` - End-to-end scenarios

### E2E Tests - Automated (`e2e/automated/`)

**Purpose**: Automated E2E testing in CI without human interaction

- **Count**: 6 automated scenarios
- **Technology**: Node.js + @github/copilot-sdk (v0.1.23+)
- **Prerequisites**: Node.js 18+, GitHub auth
- **Runtime**: Fast (~30-60 seconds)
- **CI**: ✅ Yes - Runs on main branch pushes

**Test Scenarios:**
1. `/sitrep` - Structured status reporting
2. `/health` - Hierarchy health metrics
3. `/prcheck` - PR analysis and state
4. `/whatsleft` - Ready/blocked issue lists
5. Issue creation - Typed issues with hierarchy
6. Plan materialization - Markdown to issue tree

**Architecture:**
```javascript
CopilotClient → createSession({skillDirectories}) 
              → sendAndWait({prompt}) 
              → validate response content
```

**Documentation**: See `e2e/automated/README.md` for detailed setup and usage

## Overview

- **Total Tests**: 130+ tests
- **Test Files**: 6 unit test files + smoke tests, organized by capability area
- **Fixture Files**: 6 mock JSON and markdown files
- **Coverage**: All 28 Okyerema scripts

## Unit Test Files

### IssueManagement.Tests.ps1 (24 tests)
Tests for issue creation, hierarchy management, and dependency tracking:
- **Get-IssueTypeIds** (5 tests) - Organization issue type retrieval
- **New-IssueWithType** (5 tests) - Issue creation with proper types
- **Update-IssueHierarchy** (5 tests) - Parent-child relationship management
- **Set-IssueDependency** (5 tests) - Blocking dependency management
- **Test-Hierarchy** (4 tests) - Hierarchy validation

### StatusHealth.Tests.ps1 (25 tests)
Tests for project health monitoring and status reporting:
- **Get-Sitrep** (5 tests) - Tactical status reports
- **Get-HierarchyHealth** (5 tests) - Issue hierarchy health metrics
- **Get-DagStatus** (5 tests) - DAG readiness analysis
- **Invoke-DagHealthCheck** (4 tests) - Cycle detection and DAG validation

### PRIntelligence.Tests.ps1 (24 tests)
Tests for pull request intelligence and analysis:
- **Get-PRStatus** (6 tests) - PR state and merge readiness
- **Get-PRHealth** (4 tests) - Comprehensive PR health metrics
- **Get-ThreadSeverity** (3 tests) - Review thread severity analysis
- **Find-IssueByPR** (3 tests) - Issue-PR linking discovery
- **Get-PRTimeline** (3 tests) - PR timeline event tracking
- **Submit-PRReview** (5 tests) - PR review submission

### ThreadManagement.Tests.ps1 (18 tests)
Tests for PR review thread management:
- **Get-UnresolvedThreads** (3 tests) - Unresolved thread retrieval
- **Reply-ReviewThread** (3 tests) - Thread reply functionality
- **Resolve-ReviewThreads** (3 tests) - Batch thread resolution

### WorkSelection.Tests.ps1 (17 tests)
Tests for work prioritization and issue selection:
- **Get-ReadyIssues** (5 tests) - Ready-to-work issue identification
- **Get-BlockedIssues** (4 tests) - Blocked issue tracking
- **Get-OrphanedIssues** (4 tests) - Orphaned issue detection
- **Get-StalledWork** (4 tests) - Stale issue identification

### PlanMaterialization.Tests.ps1 (8 tests)
Tests for plan-to-issue materialization:
- **Invoke-PlanMaterialization** (4 tests) - Markdown plan parsing and issue creation
- **Sync-PlanToIssues** (4 tests) - Plan-issue synchronization

## Smoke Tests

### Install-Plugin.Smoke.Tests.ps1
Tests the full plugin installation lifecycle via `copilot plugin` CLI:
- Marketplace add
- Plugin install
- Plugin list
- Plugin update
- Plugin uninstall
- Plugin reinstall

**Note**: These tests require the `copilot` CLI to be installed. They will be automatically skipped if the CLI is not available.

### Skill-Loading.Smoke.Tests.ps1
Tests skill discovery and slash command recognition:
- Validates all expected skill directories exist
- Checks skill structure (SKILL.md, scripts, agent files)
- Validates slash command documentation
- Verifies supporting scripts for commands
- Validates skill metadata
- Checks plugin manifest.json
- Verifies agent configuration files

## Test Fixtures

Located in `tests/omanfo/fixtures/`:
- **issue-types.json** - Mock organization issue type data
- **pr-status.json** - Mock PR status and CI check data
- **pr-review-threads.json** - Mock PR review thread data
- **hierarchy-tree.json** - Mock issue hierarchy data
- **dag-health.json** - Mock DAG and blocking dependency data
- **plan-file.md** - Mock markdown plan file

## Running Tests

### Run All Tests (via Runner)
```powershell
cd tests/omanfo
./Run-LocalTests.ps1
```

### Run All Unit Tests
```powershell
cd tests/omanfo/unit
Invoke-Pester
```

### Run Specific Test File
```powershell
Invoke-Pester -Path tests/omanfo/unit/IssueManagement.Tests.ps1
```

### Run with Detailed Output
```powershell
cd tests/omanfo/unit
Invoke-Pester -Output Detailed
```

### Run with Minimal Output
```powershell
$config = New-PesterConfiguration
$config.Run.Path = './tests/omanfo/unit'
$config.Output.Verbosity = 'Minimal'
Invoke-Pester -Configuration $config
```

## Test Patterns

### Mocking GitHub CLI
Tests mock the `gh` CLI command at the command level:
```powershell
Mock gh { return $mockJson } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
Mock gh {
    $global:LASTEXITCODE = 0
    return $mockJson
} -ParameterFilter { $args[0] -eq 'api' }
```

### Capturing Output Streams
Some scripts use Write-Host for output. Capture all output streams:
```powershell
$output = & $scriptPath -Owner "test" -Repo "repo" *>&1
```

### Setting Exit Codes
Scripts check `$LASTEXITCODE`. Set it in mocks:
```powershell
Mock gh {
    $global:LASTEXITCODE = 0
    return $mockData
}
```

## Technical Notes

1. **No Set-StrictMode** - Tests do not use strict mode because scripts check `.errors` property which throws under strict mode

2. **Int64 Hashtable Keys** - Avoid `-RootNumber` parameter in Get-DagStatus tests due to Int64 hashtable key issues

3. **Array Wrapping** - Some scripts return single objects instead of arrays when there's only one result. Wrap results in `@()` to force array type:
   ```powershell
   $result = @(& $scriptPath -Owner "test" -Repo "repo")
   ```

4. **Mock Specificity** - Use parameter filters to differentiate between multiple `gh` calls in the same script

## Coverage

All 28 Okyerema scripts have corresponding tests:
- ✅ Get-IssueTypeIds
- ✅ New-IssueWithType
- ✅ Update-IssueHierarchy
- ✅ Set-IssueDependency
- ✅ Test-Hierarchy
- ✅ Get-Sitrep
- ✅ Get-HierarchyHealth
- ✅ Get-DagStatus
- ✅ Invoke-DagHealthCheck
- ✅ Get-PRStatus
- ✅ Get-PRHealth
- ✅ Get-ThreadSeverity
- ✅ Find-IssueByPR
- ✅ Get-PRTimeline
- ✅ Submit-PRReview
- ✅ Get-UnresolvedThreads
- ✅ Reply-ReviewThread
- ✅ Resolve-ReviewThreads
- ✅ Get-ReadyIssues
- ✅ Get-BlockedIssues
- ✅ Get-OrphanedIssues
- ✅ Get-StalledWork
- ✅ Invoke-PlanMaterialization
- ✅ Sync-PlanToIssues
- ✅ New-IssueBatch
- ✅ New-IssueHierarchy
- ✅ Add-IssuesToProject
- ✅ Invoke-PRCompletion

## Requirements

- **Pester 5.x** - PowerShell testing framework (5.7.1+ recommended)
- **PowerShell 7.x** - Cross-platform PowerShell
- **GitHub CLI** (`gh`) for some tests
- **Copilot CLI** (`copilot`) for Install-Plugin smoke tests (optional)

## Exit Codes

- **0**: All tests passed
- **1**: One or more tests failed

## Contributing

When adding new tests:
1. Follow the existing test patterns and naming conventions
2. Use descriptive test names with "Should" prefix
3. Mock external dependencies (`gh`, `git`)
4. Set `$LASTEXITCODE` in mocks when scripts check it
5. Organize tests by script capability area
6. Add test fixtures to `tests/fixtures/` as needed
7. Place tests in appropriate subdirectories or use naming suffixes
8. Use Pester 5.x syntax
9. Add `-Skip` conditions for tests requiring specific tools
10. Document test requirements in the test file

## CI Integration

These tests can be integrated into GitHub Actions workflows:

```yaml
- name: Run Omanfo Tests
  run: |
    cd tests/omanfo
    pwsh -File Run-LocalTests.ps1 -TestLevel Smoke
```