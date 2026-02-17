# Plugin Scripts

Repository-wide scripts for managing and validating plugins.

## Set-BranchProtection.ps1

Configure branch protection rules with required status checks for the repository.

### Synopsis

This script sets up branch protection rules on the main branch to require the "Static Validation" status check from the `validate-plugin.yml` workflow to pass before PRs can be merged.

### Usage

```powershell
# Configure branch protection for anokye-labs/plugins
./scripts/Set-BranchProtection.ps1

# Dry run - see what would be done without making changes
./scripts/Set-BranchProtection.ps1 -DryRun

# Configure for a different repository
./scripts/Set-BranchProtection.ps1 -Owner myorg -Repo myrepo -Branch develop
```

### Parameters

- **Owner** - Repository owner (organization or user). Defaults to `anokye-labs`.
- **Repo** - Repository name. Defaults to `plugins`.
- **Branch** - Branch to protect. Defaults to `main`.
- **DryRun** - Show what would be done without making changes.

### Prerequisites

- GitHub CLI (`gh`) must be installed
- Must be authenticated with GitHub CLI (`gh auth login`)
- Must have admin permissions on the repository

### Exit Codes

- **0** - Branch protection configured successfully
- **1** - Configuration failed (missing prerequisites, API error, etc.)

### What It Does

The script:
1. Validates that GitHub CLI is installed and authenticated
2. Queries current branch protection rules
3. Configures or updates the branch protection rule to require:
   - The "Static Validation" status check to pass before merging

### Required Status Checks

The following status checks are configured as required:
- **Static Validation** - From the `validate-plugin.yml` workflow

### Examples

Configure branch protection (requires admin permissions):
```powershell
./scripts/Set-BranchProtection.ps1
```

Preview changes without applying them:
```powershell
./scripts/Set-BranchProtection.ps1 -DryRun
```

### Integration

This script should be run:
- After the validation workflow is stable (issue #57)
- By repository administrators to enforce PR quality gates
- When setting up a new repository with the plugin infrastructure

### Related

- [.github/workflows/validate-plugin.yml](../.github/workflows/validate-plugin.yml) - Validation workflow
- [omanfo/scripts/validation/](../omanfo/scripts/validation/) - Validation scripts

---

### Related

- [omanfo/evaluations/README.md](../omanfo/evaluations/README.md) - Evaluation scenarios
- [omanfo/.github/plugin/plugin.json](../omanfo/.github/plugin/plugin.json) - Copilot CLI plugin metadata
