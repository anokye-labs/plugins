# Automated E2E Tests for Omanfo Plugin

This directory contains automated E2E tests that use the `@github/copilot-sdk` to programmatically drive Copilot sessions and validate the Omanfo plugin's capabilities.

## ⚠️ Important Notice

**These tests require a running Copilot backend service to function.** The `@github/copilot-sdk` needs to connect to GitHub Copilot's infrastructure. These tests are designed for environments where:

1. The Copilot SDK can authenticate and connect to GitHub Copilot services
2. The environment has proper GitHub credentials (via `GITHUB_TOKEN` or `gh auth`)
3. Network access to GitHub APIs is available

## Overview

Unlike the manual E2E tests (which require a human with the Copilot CLI), these tests use the Copilot SDK to:
- Start Copilot sessions programmatically
- Load plugin skills automatically
- Execute prompts and validate responses
- Track tool usage and verify behavior
- Clean up test artifacts automatically

## Prerequisites

- **Node.js 20+** - Required for ES modules and modern TypeScript
- **GitHub CLI (gh)** - Must be authenticated (`gh auth login`)
- **GitHub Token** - Via `GITHUB_TOKEN` environment variable or gh auth
- **Copilot SDK Access** - Active Copilot subscription and SDK access
- **Network access** - To GitHub API and Copilot services
- **Write access** - To test repository (defaults to anokye-labs/plugins)

## Validation

Before running tests, validate your setup:

```bash
cd tests/omanfo/e2e/automated
npm install
npm run validate
```

This checks:
- Node.js version (20+)
- GitHub CLI availability
- GitHub token presence
- Copilot SDK import capability
- Test file discovery

## Installation

```bash
cd tests/omanfo/e2e/automated
npm install
```

This installs:
- `@github/copilot-sdk` (v0.1.23+) - Copilot client library
- TypeScript and ts-node for running tests

## Test Scenarios

### 1. Sitrep (sitrep.e2e.ts)
Tests the `/sitrep` command for project status reports.

**Validates:**
- Returns TotalOpen, GitStatus, and recent activity
- Calls `Get-Sitrep` tool

**Run:**
```bash
node --loader ts-node/esm sitrep.e2e.ts
```

### 2. Health Check (health.e2e.ts)
Tests the `/health` command for hierarchy health metrics.

**Validates:**
- Returns TypeCounts, Orphans, and HealthScore
- Calls `Invoke-DagHealthCheck` tool

**Run:**
```bash
node --loader ts-node/esm health.e2e.ts
```

### 3. PR Check (prcheck.e2e.ts)
Tests the `/prcheck` command for PR status and review analysis.

**Validates:**
- Returns state, mergeable, and review threads
- Calls `Get-PullRequestStatus` tool

**Run:**
```bash
# Use default PR #107
node --loader ts-node/esm prcheck.e2e.ts

# Or specify a PR
E2E_TEST_PR=123 node --loader ts-node/esm prcheck.e2e.ts
```

### 4. What's Left (whatsleft.e2e.ts)
Tests the `/whatsleft` command for remaining work queries.

**Validates:**
- Returns ready and blocked issue lists
- Calls `Get-ReadyIssues` and `Get-BlockedIssues` tools

**Run:**
```bash
node --loader ts-node/esm whatsleft.e2e.ts
```

### 5. Issue Creation (issue-creation.e2e.ts)
Tests creating issues via natural language prompts.

**Validates:**
- Issue is created in repository
- Issue has correct type (Task)
- Cleans up by closing created issue

**Run:**
```bash
node --loader ts-node/esm issue-creation.e2e.ts
```

### 6. Plan Materialization (plan-materialize.e2e.ts)
Tests materializing a plan.md file into an issue hierarchy.

**Validates:**
- Epic is created
- Child Features and Tasks are created
- Hierarchy relationships are established
- Cleans up all created issues

**Run:**
```bash
node --loader ts-node/esm plan-materialize.e2e.ts
```

## Running All Tests

```bash
npm test
```

This runs `run-tests.mjs` which executes all `*.e2e.ts` files sequentially and reports results.

Or via the master test runner:

```bash
# From repository root
pwsh -File ./tests/omanfo/Run-LocalTests.ps1 -TestLevel E2E

# Or from tests/omanfo directory
cd tests/omanfo
./Run-LocalTests.ps1 -TestLevel E2E
```

## Configuration

### Environment Variables

- `E2E_TEST_REPO` - Target repository (default: `anokye-labs/plugins`)
- `E2E_TEST_PR` - PR number for prcheck test (default: `107`)
- `GITHUB_TOKEN` - GitHub API token (or use gh auth)

**Example:**
```bash
export E2E_TEST_REPO="my-org/my-repo"
export E2E_TEST_PR="42"
node --loader ts-node/esm sitrep.e2e.ts
```

## Test Isolation

All tests that create issues:
- Use unique run IDs: `E2E-SDK-{timestamp}`
- Include cleanup in finally blocks
- Close issues with `state_reason=not_planned`
- Handle cleanup failures gracefully

## Architecture

### copilot-harness.ts
Shared test harness providing:
- `CopilotTestHarness` class for client lifecycle
- `runTest()` helper for simple scenarios
- Tool call tracking via SDK hooks (configured in `createSession`)
- Skill directory auto-detection
- Proper cleanup with `session.destroy()` before `client.stop()`

**Hook Configuration:**
```typescript
hooks: {
  onPreToolUse: (input, invocation) => {
    // input.toolName contains the tool being called
    this.toolCallLog.push(input.toolName);
    return { permissionDecision: "allow" };
  },
  onPostToolUse: (input, invocation) => {
    // Validation after tool execution
  }
}
```

**Response Access:**
The SDK returns `AssistantMessageEvent` with content at `result.data.content`:
```typescript
const content = result?.data?.content || result?.content || '';
```

**Example usage:**
```typescript
import { runTest } from './copilot-harness.js';

const success = await runTest(
  'My Test',
  '/sitrep --owner foo --repo bar',
  {
    shouldNotBeEmpty: true,
    shouldContain: ['TotalOpen'],
    shouldCallTools: ['Get-Sitrep']
  }
);
```

### Individual Test Files
Each test file (`*.e2e.ts`):
- Imports from harness
- Configures test scenario
- Validates response
- Handles cleanup
- Exits with appropriate code

## CI Integration

These tests run in GitHub Actions via the `e2e-automated.yml` workflow on pushes to `main`.

**Workflow steps:**
1. Checkout code
2. Setup Node.js 20
3. Install dependencies (`npm ci`)
4. Run each test scenario
5. Report results

## Troubleshooting

### "Module not found" errors
```bash
# Ensure you're using Node 20+ with ESM support
node --version  # Should be v20.x or higher

# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install
```

### "Copilot SDK failed to start"
- Check that `GITHUB_TOKEN` is set or gh is authenticated
- Verify network access to GitHub API
- Check skill directories exist and are readable

### "Test timeout" or "No response"
- SDK operations can take time, especially on first run
- Check GitHub API rate limits
- Verify repository access permissions

### Issues not cleaned up
If tests fail before cleanup:
```bash
# List test issues
gh issue list --repo anokye-labs/plugins --search "E2E-SDK-202602"

# Close specific issue
gh issue close 123 --repo anokye-labs/plugins --reason "not_planned"
```

## Development

### Adding New Tests

1. Create `my-test.e2e.ts` file
2. Import from `copilot-harness.js`
3. Use `runTest()` helper or create custom harness
4. Add validations
5. Handle cleanup
6. Update this README

### Running Tests Locally

```bash
# Install dependencies
npm install

# Run specific test
node --loader ts-node/esm sitrep.e2e.ts

# Run all tests
npm test

# With custom repo
E2E_TEST_REPO="my-org/my-repo" npm test
```

## See Also

- [Manual E2E Tests](../README.md) - Human-driven Copilot CLI tests
- [Copilot SDK Documentation](https://github.com/github/copilot-sdk)
- [Unit Tests](../../unit/) - PowerShell unit tests
- [Test Runner](../../Run-LocalTests.ps1) - Master test orchestrator
