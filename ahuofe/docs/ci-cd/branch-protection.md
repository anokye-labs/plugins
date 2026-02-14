# Branch Protection Configuration

Recommended branch protection settings for the `main` branch of `copilot-media-plugins`.

## Required Status Checks

Enable **"Require status checks to pass before merging"** with the following checks:

| Workflow | Job Name | Required |
|----------|----------|----------|
| `test-plugin.yml` | `Run Pester Tests` | ✅ Yes |
| `doc-sync.yml` | `Validate Documentation` | ✅ Yes |
| `performance-check.yml` | `Performance Benchmark` | ⚠️ Optional |
| `media-workflow.yml` | `Generate & Validate Media` | ⚠️ Optional |

> **Note:** `performance-check` and `media-workflow` require the `FAL_KEY` secret and are optional because they depend on external API availability.

## Required Reviewers

- **Minimum approvals:** 1
- **Dismiss stale reviews:** Yes — re-review after new pushes
- **Require review from code owners:** Yes (when `CODEOWNERS` is configured)

## Merge Method

- **Recommended:** Squash and merge
- Keeps `main` history linear and readable
- PR title becomes the commit message

## Additional Settings

| Setting | Value |
|---------|-------|
| Require branches to be up-to-date | Yes |
| Require signed commits | Optional |
| Require linear history | Yes |
| Allow force pushes | No |
| Allow deletions | No |

## Programmatic Configuration

Use `gh api` to apply these settings:

```bash
# Set branch protection on main
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Run Pester Tests (7.4)",
      "Run Pester Tests (7.5)",
      "Validate Documentation"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

```bash
# Verify current protection settings
gh api repos/{owner}/{repo}/branches/main/protection \
  --jq '{
    status_checks: .required_status_checks.contexts,
    approvals: .required_pull_request_reviews.required_approving_review_count,
    linear_history: .required_linear_history.enabled,
    force_push: .allow_force_pushes.enabled
  }'
```

```bash
# Enable squash merge only
gh api repos/{owner}/{repo} \
  --method PATCH \
  --field allow_squash_merge=true \
  --field allow_merge_commit=false \
  --field allow_rebase_merge=false \
  --field squash_merge_commit_title=PR_TITLE \
  --field squash_merge_commit_message=PR_BODY
```
