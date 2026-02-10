# Omanfo Plugin Test Suite

This directory contains the Pester 5 unit test suite for the Omanfo plugin's Okyerema scripts.

**Note**: Tests are located at the repository root (`tests/omanfo/`) rather than inside the plugin directory (`omanfo/`). This keeps tests available for development and CI while excluding them from the plugin distribution package.

## Overview

- **Total Tests**: 116 tests
- **Test Files**: 6 organized by capability area
- **Fixture Files**: 6 mock JSON and markdown files
- **Coverage**: All 28 Okyerema scripts

## Test Files

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

## Test Fixtures

Located in `tests/omanfo/fixtures/`:
- **issue-types.json** - Mock organization issue type data
- **pr-status.json** - Mock PR status and CI check data
- **pr-review-threads.json** - Mock PR review thread data
- **hierarchy-tree.json** - Mock issue hierarchy data
- **dag-health.json** - Mock DAG and blocking dependency data
- **plan-file.md** - Mock markdown plan file

## Running Tests

### Run All Tests
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

## Dependencies

- **Pester 5.x** - PowerShell testing framework (5.7.1+ recommended)
- **PowerShell 7.x** - Cross-platform PowerShell

## Contributing

When adding new tests:
1. Follow the existing test patterns
2. Use descriptive test names with "Should" prefix
3. Mock external dependencies (`gh`, `git`)
4. Set `$LASTEXITCODE` in mocks when scripts check it
5. Organize tests by script capability area
6. Add test fixtures to `tests/fixtures/` as needed
