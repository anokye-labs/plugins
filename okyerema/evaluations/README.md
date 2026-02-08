# Plugin Evaluations

Test scenarios to validate the Okyerema plugin after installation. Each evaluation is a self-contained test that can be run independently.

## Running Evaluations

Evaluations are markdown files with structured test steps. They are designed to be executed by a human or agent in a Copilot chat session.

### Quick Validation

Run the verification script first:

```powershell
& .\scripts\Verify-Installation.ps1 -TargetRepo <path> -Owner <org>
```

### Full Evaluation

Work through each `.eval.md` file in order:

| # | Evaluation | Tests | Priority |
|---|------------|-------|----------|
| 1 | [install-verify](01-install-verify.eval.md) | Installation & file structure | 🔴 Critical |
| 2 | [issue-types](02-issue-types.eval.md) | Organization issue type discovery | 🔴 Critical |
| 3 | [create-issues](03-create-issues.eval.md) | Creating typed issues via GraphQL | 🔴 Critical |
| 4 | [hierarchy](04-hierarchy.eval.md) | Building parent-child relationships | 🔴 Critical |
| 5 | [projects](05-projects.eval.md) | GitHub Projects V2 integration | 🟡 Important |
| 6 | [pr-reviews](06-pr-reviews.eval.md) | PR review thread management | 🟡 Important |
| 7 | [labels](07-labels.eval.md) | Label operations and best practices | 🟢 Nice-to-have |
| 8 | [end-to-end](08-end-to-end.eval.md) | Full workflow: plan → implement → review | 🔴 Critical |

### Pass Criteria

- **Critical** evaluations must all pass for the plugin to be considered functional
- **Important** evaluations should pass for production use
- **Nice-to-have** evaluations test edge cases and best practices

### Environment

Each evaluation assumes:
- Plugin is installed in a test repository
- GitHub CLI is authenticated
- Organization has issue types configured
- PowerShell 7+ is available
