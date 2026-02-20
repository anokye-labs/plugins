# Branch Protection Configuration

This document explains how branch protection is configured for this repository.

## Overview

Branch protection on `main` enforces the following rules:

- **No direct pushes** — all changes must go through a PR, including for admins and org owners (`enforce_admins: true`)
- **Linked issue required** — every PR must reference a GitHub issue using a closing keyword (`Closes #N`, `Fixes #N`, or `Resolves #N`)
- **Required status checks** — the following checks must pass before a PR can merge:
  - `Static Validation` (from `validate-plugin.yml`)
  - `Check Linked Issue` (from `require-linked-issue.yml`)
- **Required review** — at least 1 approving review; stale reviews are dismissed
- **Conversation resolution** — all review comments must be resolved

## Automated Configuration

A PowerShell script is provided to configure branch protection via the GitHub GraphQL API.

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
- ✓ Configure all required status checks
- ✓ Enable admin enforcement
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
  ✓ Branch protection rule exists

▶ Required status checks to configure:
    - Static Validation
    - Check Linked Issue

▶ Configuring branch protection...

✅ Branch protection configured successfully!

  Repository: anokye-labs/plugins
  Branch: main
  Admin enforcement: enabled
  Required status checks:
    ✓ Static Validation
    ✓ Check Linked Issue

PRs targeting main now require the validation workflow to pass before merging.

═══════════════════════════════════════
```

## Manual Configuration

If you prefer to configure branch protection manually via the GitHub UI:

1. Go to **Settings** → **Branches** in the repository
2. Add or edit the branch protection rule for `main`
3. Enable **Do not allow bypassing the above settings** (enforces rules for admins)
4. Enable **Require status checks to pass before merging**
5. Search for and select:
   - **Static Validation** (from `validate-plugin.yml`)
   - **Check Linked Issue** (from `require-linked-issue.yml`)
6. Save the rule

## Workflows

| Workflow | Trigger | Job ID | Purpose |
|----------|---------|--------|---------|
| `validate-plugin.yml` | Push to non-main branches | `validate` | Plugin quality checks (manifest, syntax, SKILL.md, eval coverage) |
| `e2e-automated.yml` | Push to main | `e2e-automated` | End-to-end tests |
| `require-linked-issue.yml` | PR targeting main | `check-linked-issue` | Verifies PR body contains `Closes/Fixes/Resolves #N` |

## Troubleshooting

### "Not authenticated with GitHub CLI"

Run `gh auth login` and follow the prompts to authenticate.

### "Permission denied"

You need admin permissions on the repository to configure branch protection. Contact a repository administrator.

### "PR is missing a linked issue"

Add a closing keyword to your PR description:

```
Closes #123
```

Supported keywords: `close`, `closes`, `closed`, `fix`, `fixes`, `fixed`, `resolve`, `resolves`, `resolved`.

The check re-runs automatically when you edit the PR description. Bot PRs (dependabot, github-actions) are exempt.

### "Failed to query branch protection rules"

Check that:
- The repository name is correct
- You have access to the repository
- Your GitHub token has the necessary scopes

### Verification

After configuration, verify the setup:

1. Create a test PR without an issue reference — confirm `check-linked-issue` fails
2. Edit the PR body to add `Closes #N` — confirm the check re-runs and passes
3. Confirm `enforce_admins.enabled` is `true`:
   ```bash
   gh api /repos/anokye-labs/plugins/branches/main/protection | jq .enforce_admins.enabled
   ```

## Related Issues

- [#170](https://github.com/anokye-labs/plugins/issues/170) - Harden main branch protection
- [#171](https://github.com/anokye-labs/plugins/issues/171) - Enable enforce_admins on branch protection
- [#172](https://github.com/anokye-labs/plugins/issues/172) - Add linked-issue requirement for PRs
- [#57](https://github.com/anokye-labs/plugins/issues/57) - Add static validation workflow
- [#53](https://github.com/anokye-labs/plugins/issues/53) - Parent issue for validation infrastructure

## References

- [GitHub Branch Protection Rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches)
- [GitHub Required Status Checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches#require-status-checks-before-merging)
- [Validation Scripts Documentation](scripts/README.md#set-branchprotectionps1)

