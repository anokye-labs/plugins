# Branch Protection Configuration

This document explains how to configure required status checks for pull requests in this repository.

## Overview

After the static validation workflow is stable (see [#57](https://github.com/anokye-labs/plugins/issues/57)), branch protection should be configured to require the validation workflow to pass before PRs can be merged.

This ensures:
- All PRs are validated against plugin quality standards
- Manifest consistency is verified
- PowerShell syntax is validated
- SKILL.md quality requirements are met
- Evaluation coverage is complete
- Markdown structure is correct

## Automated Configuration

A PowerShell script is provided to automate the branch protection configuration via the GitHub API.

### Prerequisites

1. **GitHub CLI** must be installed:
   ```bash
   # macOS
   brew install gh
   
   # Windows
   winget install --id GitHub.cli
   
   # Linux
   # See https://github.com/cli/cli/blob/trunk/docs/install_linux.md
   ```

2. **Authenticate with GitHub CLI**:
   ```bash
   gh auth login
   ```

3. **Admin permissions** on the repository

### Running the Script

**Dry run** (recommended first) - see what would be configured:
```powershell
./scripts/Set-BranchProtection.ps1 -DryRun
```

**Apply configuration**:
```powershell
./scripts/Set-BranchProtection.ps1
```

The script will:
- ✓ Verify GitHub CLI is installed and authenticated
- ✓ Check current branch protection status
- ✓ Configure "Static Validation" as a required status check
- ✓ Display the applied configuration

### Example Output

```
═══════════════════════════════════════
  Branch Protection Configuration
═══════════════════════════════════════

▶ Checking prerequisites...
  ✓ GitHub CLI installed
  ✓ GitHub CLI authenticated

▶ Checking current branch protection on anokye-labs/plugins (main)...
  ℹ No branch protection rule exists

▶ Required status checks to configure:
    - validate

▶ Configuring branch protection...

✅ Branch protection configured successfully!

  Repository: anokye-labs/plugins
  Branch: main
  Required status checks:
    ✓ validate

PRs targeting main now require the validation workflow to pass before merging.

═══════════════════════════════════════
```

## Manual Configuration

If you prefer to configure branch protection manually via the GitHub UI:

1. Go to **Settings** → **Branches** in the repository
2. Add or edit the branch protection rule for `main`
3. Enable **Require status checks to pass before merging**
4. Search for and select: **validate** (it will display as "Static Validation")
5. Save the rule

## Validation Workflow

The validation workflow (`.github/workflows/validate-plugin.yml`) runs on pull requests targeting `main` and pushes to feature branches that modify:
- `omanfo/**`
- `okyeame/**`
- `ahuofe/**`
- `tests/**`
- `.github/workflows/validate-plugin.yml`

The workflow runs two required jobs:

| Job | Checks |
|-----|--------|
| **Static Validation** (`validate`) | File structure, PowerShell syntax, SKILL.md quality, eval coverage, markdown structure, script test coverage |
| **Pester Unit Tests** (`unit-tests`) | 116+ unit tests for all Okyerema scripts |

Both jobs must pass for PRs to be mergeable.

### Branch Protection Settings

| Setting | Value |
|---------|-------|
| Required status checks | `validate`, `unit-tests` |
| Require branches to be up to date | ✅ Yes |
| Required approving reviews | 1 |
| Dismiss stale reviews | ✅ Yes |
| Require conversation resolution | ✅ Yes |

## Troubleshooting

### "Not authenticated with GitHub CLI"

Run `gh auth login` and follow the prompts to authenticate.

### "Permission denied"

You need admin permissions on the repository to configure branch protection. Contact a repository administrator.

### "Failed to query branch protection rules"

Check that:
- The repository name is correct
- You have access to the repository
- Your GitHub token has the necessary scopes

### Verification

After configuration, verify the setup:

1. Create a test PR with an intentional validation error
2. Confirm the "validate" check runs and fails (displays as "Static Validation")
3. Verify the PR shows "Merging is blocked" with the failed check listed
4. Fix the error and confirm the check passes
5. Verify the PR becomes mergeable

## Related Issues

- [#57](https://github.com/anokye-labs/plugins/issues/57) - Add static validation workflow
- [#53](https://github.com/anokye-labs/plugins/issues/53) - Parent issue for validation infrastructure

## References

- [GitHub Branch Protection Rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches)
- [GitHub Required Status Checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches#require-status-checks-before-merging)
- [Validation Scripts Documentation](scripts/README.md#set-branchprotectionps1)
