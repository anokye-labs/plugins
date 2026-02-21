# Branch Protection Configuration

This document explains how branch protection is configured for this repository.

## Overview

Branch protection on `main` enforces the following rules:

- **No direct pushes** — all changes must go through a PR, including for admins and org owners (`enforce_admins: true`)
- **Linked issue required** — every PR must reference a GitHub issue via the Development sidebar or closing keywords (`Closes #N`, `Fixes #N`, `Resolves #N`)
- **Required status checks** — the following checks must pass before a PR can enter the merge queue:
  - `Static Validation` (from `validate-plugin.yml`)
  - `Check Linked Issue` (from `require-linked-issue.yml`)
- **Required review** — at least 1 approving review; stale reviews are dismissed; auto-approved for trusted actors
- **Merge queue** — PRs are merged via GitHub's merge queue, which re-runs CI against the merged result before committing
- **Conversation resolution** — all review comments must be resolved

## Agent-Only PR Lifecycle

This repository is designed for zero human intervention in the PR lifecycle:

1. **Agent opens PR** linked to a GitHub issue
2. **`auto-approve.yml`** fires — approves the PR and enables auto-merge
3. **`require-linked-issue.yml`** and **`validate-plugin.yml`** checks run on the PR
4. Once all requirements are satisfied, the PR is **automatically added to the merge queue**
5. **Merge queue** runs `Static Validation` against the merged result
6. If all checks pass, the **PR merges automatically**

Trusted actors (auto-approved): `hoopsomuah`, `devin-ai-integration[bot]`, `claude[bot]`, `chatgpt-codex-connector[bot]`, `dependabot[bot]`, `renovate[bot]`


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

| Workflow | Trigger | Job display name | Purpose |
|----------|---------|--------|---------|
| `validate-plugin.yml` | Push to non-main branches; `merge_group` | `Static Validation` | Plugin quality checks (manifest, syntax, SKILL.md, eval coverage) |
| `e2e-automated.yml` | Push to main | `e2e-automated` | End-to-end tests |
| `require-linked-issue.yml` | PR targeting main | `Check Linked Issue` | Verifies PR has a linked GitHub issue |
| `auto-approve.yml` | PR targeting main | `Auto Approve` | Approves PRs from trusted actors and enables auto-merge |

## Troubleshooting

### "Not authenticated with GitHub CLI"

Run `gh auth login` and follow the prompts to authenticate.

### "Permission denied"

You need admin permissions on the repository to configure branch protection. Contact a repository administrator.

### "PR is missing a linked issue"

Link an issue using either method:

1. **Development sidebar** (recommended) — click "Link an issue" in the PR sidebar
2. **PR description** — add `Closes #N`, `Fixes #N`, or `Resolves #N`

The check queries GitHub's `closingIssuesReferences` API, so both methods are equally valid. It re-runs automatically when the PR is updated. Bot PRs (dependabot, github-actions) are exempt.

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

- [#178](https://github.com/anokye-labs/plugins/issues/178) - Agent-only PR workflow: merge queues and zero human intervention
- [#170](https://github.com/anokye-labs/plugins/issues/170) - Harden main branch protection
- [#171](https://github.com/anokye-labs/plugins/issues/171) - Enable enforce_admins on branch protection
- [#172](https://github.com/anokye-labs/plugins/issues/172) - Add linked-issue requirement for PRs
- [#57](https://github.com/anokye-labs/plugins/issues/57) - Add static validation workflow
- [#53](https://github.com/anokye-labs/plugins/issues/53) - Parent issue for validation infrastructure

## References

- [GitHub Branch Protection Rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches)
- [GitHub Required Status Checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches#require-status-checks-before-merging)
- [Validation Scripts Documentation](scripts/README.md#set-branchprotectionps1)

