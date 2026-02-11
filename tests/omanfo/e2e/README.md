# End-to-End (E2E) Tests for Omanfo Plugin

This directory contains comprehensive E2E tests that exercise the Omanfo plugin through live commands against a real GitHub repository.

## Test Types

### 1. Manual E2E Tests (Root Directory)
These tests require a human operator with the Copilot CLI installed and configured. They validate the plugin by executing natural language prompts via `copilot -p "prompt" --allow-all-tools -s` and verifying state changes through the GitHub API.

### 2. Automated E2E Tests (automated/ Directory)
These tests use the `@github/copilot-sdk` to programmatically drive Copilot sessions without human intervention. They're designed for CI/CD pipelines and automated testing. See [automated/README.md](automated/README.md) for details.

## Overview (Manual Tests)

These tests validate the plugin's capabilities by:
- Executing natural language prompts via `copilot -p "prompt" --allow-all-tools -s`
- Verifying state changes via GitHub API (`gh api`)
- Testing complete workflows from planning to execution

## Test Files

### IssueCreation.e2e.Tests.ps1
Tests creating issues with different types (Task, Bug, Feature, Epic) via Copilot prompts.

**Coverage:**
- Single issue creation by type
- Batch issue creation
- Issue metadata validation

### Hierarchy.e2e.Tests.ps1
Tests building Epic→Feature→Task hierarchies and parent-child relationships.

**Coverage:**
- Epic with Feature children
- Feature with Task children
- Three-level hierarchies
- Adding children to existing issues
- Hierarchy validation queries

### StatusReporting.e2e.Tests.ps1
Tests slash commands for status reporting and work selection.

**Coverage:**
- `/sitrep` - Project status reports
- `/health` - Hierarchy health checks
- `/whatsleft` - Remaining work queries
- Work readiness identification
- Blocked issue detection
- DAG status validation

### PRWorkflow.e2e.Tests.ps1
Tests PR-related operations including status checks, health, and review threads.

**Coverage:**
- PR status and check queries
- PR health checks and merge recommendations
- Timeline and activity summaries
- Review thread analysis (automated vs human)
- Conflict detection
- PR comparison

### FullWorkflow.e2e.Tests.ps1
Complete 4-phase end-to-end workflow test covering the entire plugin capability.

**Phases:**
1. **Planning** - Create Epic with Features and Tasks
2. **Issue Management** - Build hierarchy, set dependencies
3. **Status Monitoring** - Health checks, readiness, blockers
4. **Work Selection** - Identify and prioritize next work

## Prerequisites

### Required Tools
- **GitHub Copilot CLI** - Must be on PATH
  - Install: See https://github.com/github/copilot-cli
- **GitHub CLI (gh)** - Must be authenticated
  - Install: https://cli.github.com
  - Authenticate: `gh auth login`
- **PowerShell 7+** - For test execution
- **Pester** - PowerShell testing framework (if running via Pester)

### Required Access
- Network access to GitHub API
- Write access to test repository
- Organization with issue types configured (Epic, Feature, Task, Bug)

## Configuration

### Environment Variables

```powershell
# Set target repository (defaults to anokye-labs/plugins)
$env:E2E_TEST_REPO = "your-org/your-repo"
```

### Test Isolation

Tests use unique run IDs and prefixed issue titles:
- Format: `E2E-{RunId}: {Title}`
- RunId: `yyyyMMdd-HHmmss` timestamp
- All test issues are closed in AfterAll cleanup blocks

## Running Tests

### Run All E2E Tests

```powershell
# Using the test runner
pwsh -File ./tests/omanfo/e2e/Run-E2ETests.ps1

# Or using Pester directly
Invoke-Pester -Path ./tests/omanfo/e2e/
```

### Run Specific Test Suite

```powershell
# Issue creation tests only
Invoke-Pester -Path ./tests/omanfo/e2e/IssueCreation.e2e.Tests.ps1

# Hierarchy tests only
Invoke-Pester -Path ./tests/omanfo/e2e/Hierarchy.e2e.Tests.ps1

# Status reporting tests
Invoke-Pester -Path ./tests/omanfo/e2e/StatusReporting.e2e.Tests.ps1

# PR workflow tests
Invoke-Pester -Path ./tests/omanfo/e2e/PRWorkflow.e2e.Tests.ps1

# Complete workflow test
Invoke-Pester -Path ./tests/omanfo/e2e/FullWorkflow.e2e.Tests.ps1
```

### Run with Custom Repository

```powershell
$env:E2E_TEST_REPO = "my-org/my-test-repo"
Invoke-Pester -Path ./tests/omanfo/e2e/IssueCreation.e2e.Tests.ps1
```

## Test Structure

Each test file follows this pattern:

```powershell
BeforeAll {
    # Verify prerequisites (copilot, gh, authentication)
    # Parse repository configuration
    # Setup test data if needed
}

Describe "Test Suite" {
    Context "Feature Area" {
        It "Should do something" {
            # Execute copilot command
            # Verify via gh api
            # Assert expectations
        }
    }
}

AfterAll {
    # Cleanup: Close all created issues
}
```

## Cleanup

All tests include automatic cleanup:
- Issues are tracked as they're created
- AfterAll blocks close all test issues
- Issues are marked as closed with `state_reason=not_planned`

### Manual Cleanup

If tests fail and don't complete cleanup:

```powershell
# List test issues
gh issue list --repo anokye-labs/plugins --search "E2E-20260210" --json number,title

# Close specific issue
gh issue close 123 --repo anokye-labs/plugins --reason "not_planned"
```

## CI Integration

These tests are intended for manual execution or scheduled CI runs:
- **Manual**: Developer verification before releases
- **Scheduled**: Nightly validation against live environment
- **Note**: Not run on every PR due to live API dependency

## Troubleshooting

### Copilot CLI Not Found

```powershell
# Install from npm (if available)
npm install -g @github/copilot-cli

# Or follow GitHub's installation guide
```

### GitHub CLI Not Authenticated

```powershell
gh auth login
# Follow prompts to authenticate
```

### Test Failures Due to Rate Limits

Tests include sleep delays to avoid rate limits. If you encounter rate limit errors:
- Increase sleep delays in test files
- Run tests with fewer concurrent sessions
- Wait before retrying

### Issue Types Not Available

Issue types only work with organization-owned repositories:
- Verify repository owner is an Organization (not a user account)
- Ensure organization has issue types configured
- Check that you have appropriate permissions

## Notes

### Timing and Delays

Tests include `Start-Sleep` calls to allow:
- API eventual consistency
- Background relationship establishment
- Rate limit compliance

Typical delays:
- 2 seconds: Simple API operations
- 3 seconds: Relationship establishment
- 5 seconds: Complex hierarchy operations

### Test Dependencies

- **PRWorkflow tests**: Some tests skip if no open PRs exist
- **Hierarchy tests**: Depend on organization issue types
- **Status tests**: Create test issues in BeforeAll

### Known Limitations

- Tests require live API access (no mocking)
- Some tests may be flaky due to network conditions
- Copilot responses may vary (natural language processing)
- GraphQL sub-issues API has 100 children limit without pagination

## Contributing

When adding new E2E tests:

1. Follow existing patterns (BeforeAll, AfterAll, cleanup)
2. Use unique issue titles with `E2E-{RunId}:` prefix
3. Track all created issues for cleanup
4. Add appropriate sleep delays for API consistency
5. Include descriptive test names and Because parameters
6. Document any prerequisites in test file header
7. Test against anokye-labs/plugins or your own test repo

## See Also

- [Evaluations](../../../omanfo/evaluations/) - Manual test scenarios
- [Validation Scripts](../../../omanfo/scripts/validation/) - Static validation tests
- [OkyeremanAgentRunner Tests](../../../shared/OkyeremanAgentRunner/Tests/) - Unit tests
