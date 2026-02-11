# Automated E2E Tests for Omanfo Plugin

This directory contains automated end-to-end tests for the Omanfo plugin using the **GitHub Copilot SDK** (`@github/copilot-sdk`).

## Overview

Unlike the manual E2E tests that require human interaction with the Copilot CLI, these automated tests use the Copilot SDK to programmatically:
- Load plugin skills
- Send prompts to Copilot
- Validate responses
- Run in CI/CD without human intervention

## Prerequisites

- **Node.js 18+**
- **GitHub authentication** (for SDK access)
- **npm** (comes with Node.js)

## Installation

```bash
cd tests/omanfo/e2e/automated
npm install
```

This installs `@github/copilot-sdk` and dependencies.

## Running Tests

### Run All Tests

```bash
npm test
```

### Run Specific Test

```bash
npm run test:sitrep       # Test /sitrep command
npm run test:health       # Test /health command
npm run test:prcheck      # Test /prcheck command
npm run test:whatsleft    # Test /whatsleft command
npm run test:issue-creation         # Test issue creation
npm run test:plan-materialization   # Test plan materialization
```

### Run from PowerShell (Repository Root)

```powershell
# Run all automated E2E tests
pwsh tests/omanfo/Run-LocalTests.ps1 -TestLevel E2E

# This will:
# 1. Install npm dependencies if needed
# 2. Run automated tests via npm
# 3. Report results
```

## Test Scenarios

### 1. `/sitrep` Command Test
- **Purpose**: Verify status reporting returns structured data
- **Checks**: Response contains `TotalOpen`, `GitStatus`, or `Repository`
- **Command**: `/sitrep --owner anokye-labs --repo plugins`

### 2. `/health` Command Test
- **Purpose**: Verify hierarchy health analysis
- **Checks**: Response contains `TypeCounts`, `HealthScore`, or `Orphans`
- **Command**: `/health --owner anokye-labs --repo plugins`

### 3. `/prcheck` Command Test
- **Purpose**: Verify PR analysis functionality
- **Checks**: Response contains PR state, mergeable status, or review data
- **Command**: `/prcheck --owner anokye-labs --repo plugins --pr <number>`

### 4. `/whatsleft` Command Test
- **Purpose**: Verify work selection returns issue lists
- **Checks**: Response contains `ReadyIssues` or `BlockedIssues`
- **Command**: `/whatsleft --owner anokye-labs --repo plugins`

### 5. Issue Creation Test
- **Purpose**: Verify typed issue creation
- **Checks**: Issue created with correct type
- **Prompt**: "Create a Task issue in anokye-labs/plugins with title..."

### 6. Plan Materialization Test
- **Purpose**: Verify plan-to-issues conversion
- **Checks**: Epic/Feature/Task hierarchy created
- **Prompt**: "Materialize this plan for anokye-labs/plugins: ..."

## Environment Variables

Configure tests via environment variables:

```bash
export E2E_TEST_OWNER="anokye-labs"     # Default repository owner
export E2E_TEST_REPO="plugins"          # Default repository name
export E2E_TEST_PR="1"                  # PR number for prcheck test
export E2E_MODEL="gpt-4o"              # Copilot model to use
```

## CI/CD Integration

### GitHub Actions Workflow

Automated E2E tests are designed to run in CI on `main` branch pushes:

```yaml
- name: Run Automated E2E Tests
  run: |
    cd tests/omanfo/e2e/automated
    npm install
    npm test
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    E2E_TEST_OWNER: anokye-labs
    E2E_TEST_REPO: plugins
```

**Note**: These tests require GitHub authentication. They should run on `main` branch pushes, not PRs, due to auth requirements.

## Architecture

### Copilot SDK Usage

```javascript
import { CopilotClient } from '@github/copilot-sdk';

// 1. Initialize client
const client = new CopilotClient();
await client.start();

// 2. Create session with skills
const session = await client.createSession({
  model: 'gpt-4o',
  skillDirectories: ['./omanfo/skills']
});

// 3. Send prompt and get response
const result = await session.sendAndWait({
  prompt: '/sitrep --owner anokye-labs --repo plugins'
});

// 4. Validate response
console.log(result.content);

// 5. Cleanup
await session.close();
await client.stop();
```

### Test Structure

Each test scenario:
1. **Setup**: Prepare test data and context
2. **Execute**: Send prompt via `session.sendAndWait()`
3. **Validate**: Check response content for expected data
4. **Report**: Log success/failure with details

### Benefits Over Manual E2E Tests

| Feature | Manual E2E | Automated E2E |
|---------|------------|---------------|
| **Human Required** | ✅ Yes | ❌ No |
| **CI/CD Ready** | ❌ No | ✅ Yes |
| **Speed** | Slow (human interaction) | Fast (automated) |
| **Repeatability** | Manual effort | Fully automated |
| **Coverage** | Limited by time | Comprehensive |

## Troubleshooting

### Authentication Errors

```
Error: Authentication failed
```

**Solution**: Ensure `GITHUB_TOKEN` is set or `gh` CLI is authenticated.

### Skills Not Loading

```
Error: Skills directory not found
```

**Solution**: Verify `SKILLS_DIR` points to `omanfo/skills` from repo root.

### Test Failures

Check:
1. Repository exists and is accessible
2. GitHub API is reachable
3. Copilot SDK version is compatible (>= 0.1.23)
4. Skills are properly structured

## Comparison: Manual vs Automated E2E

### Manual E2E Tests (`tests/omanfo/e2e/*.e2e.Tests.ps1`)
- Use Pester + `copilot -p` CLI
- Require authenticated human developer
- Interactive prompts and responses
- Run locally during development
- Validate full workflow with real API calls

### Automated E2E Tests (`tests/omanfo/e2e/automated/`)
- Use Copilot SDK
- Run in CI without human interaction
- Programmatic skill loading and testing
- Fast, repeatable, automated
- Suitable for continuous integration

**Both are valuable**: Manual tests for development, automated tests for CI/CD gates.

## Maintenance

### Adding New Tests

1. Add test function to `automated-tests.mjs`:
   ```javascript
   async newTest(session) {
     logSection('Test N: New Test');
     const result = await session.sendAndWait({ prompt: '...' });
     // Validate result
   }
   ```

2. Register in `tests` object:
   ```javascript
   const tests = {
     sitrep,
     health,
     newTest  // <-- Add here
   };
   ```

3. Add npm script to `package.json`:
   ```json
   "test:new-test": "node automated-tests.mjs newTest"
   ```

### Updating Dependencies

```bash
npm update @github/copilot-sdk
```

## References

- [GitHub Copilot SDK Documentation](https://github.com/github/copilot-sdk)
- [Omanfo Plugin Skills](../../../../omanfo/skills/)
- [Manual E2E Tests](../)
- [Issue #<number>: Enforce test coverage and automate E2E](https://github.com/anokye-labs/plugins/issues/<number>)
