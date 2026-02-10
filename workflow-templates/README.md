# Governance Workflow Templates

**Reusable GitHub Actions workflows and branch protection configurations for enforcing agent-only commits and issue-driven development.**

This directory contains three governance components that any repository can adopt:

1. **Commit Validator Workflow** — Validates that all commits reference issues
2. **Agent Authentication Workflow** — Ensures commits come from approved agents
3. **Branch Protection Rulesets** — Exportable configurations for GitHub branch protection

## Quick Start

### 1. Copy Workflows to Your Repository

```bash
# Copy both workflows to your .github/workflows/ directory
cp workflow-templates/commit-validator.yml .github/workflows/
cp workflow-templates/agent-auth.yml .github/workflows/

# Copy the agent auth validation script
mkdir -p workflow-templates/scripts
cp workflow-templates/scripts/Test-AgentAuth.ps1 workflow-templates/scripts/
```

### 2. Import Branch Protection Ruleset

Choose one of the ruleset configurations:

- **`branch-protection-agent-only.json`** — Strict agent-only enforcement with required signatures
- **`branch-protection-with-bypass.json`** — Allows admin bypass for emergencies

#### Via GitHub UI:

1. Go to **Settings** → **Rules** → **Rulesets** in your repository
2. Click **New ruleset** → **Import a ruleset**
3. Upload the JSON file from `workflow-templates/rulesets/`
4. Review and adjust settings as needed
5. Click **Create** to enable

#### Via GitHub API:

```bash
# Set your repository details
OWNER="your-org"
REPO="your-repo"

# Import the ruleset
gh api \
  -X POST \
  "/repos/$OWNER/$REPO/rulesets" \
  --input workflow-templates/rulesets/branch-protection-agent-only.json
```

### 3. Configure Agent Allowlist (Optional)

Edit `.github/workflows/agent-auth.yml` to customize allowed agents:

```yaml
env:
  ALLOWED_AGENTS: "copilot-swe-agent,github-actions,dependabot,renovate"
```

Or edit `workflow-templates/scripts/Test-AgentAuth.ps1` line 49 to change defaults.

## Components

### Commit Validator Workflow

**File:** `commit-validator.yml`

**Purpose:** Validates that all commits in a pull request reference GitHub issues.

**Features:**
- ✅ Validates commit messages reference issues using multiple formats
- ✅ Checks issue existence via GraphQL API
- ✅ Blocks direct pushes to main branch
- ✅ Provides helpful error messages with examples
- ✅ Supports dry-run mode for testing
- ✅ Status check integration

**Supported Issue Reference Formats:**
- `#123` — Simple issue reference
- `GH-123` — GitHub-style reference
- `Closes #123`, `Fixes #456` — GitHub keywords
- `anokye-labs/repo#123` — Cross-repository references

**Trigger:** Runs on all pull request events (opened, synchronize, reopened)

**Permissions Required:**
- `contents: read` — Read repository code
- `pull-requests: write` — Comment on PRs with validation results

**Configuration:**

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened]
  workflow_dispatch:
    inputs:
      dry_run:
        description: 'Dry run mode (show what would be validated without failing)'
        type: boolean
        default: false
```

**Dry Run Mode:**

Test the validator without failing checks:

```bash
# Via GitHub UI: Go to Actions → Commit Validator → Run workflow → Check "Dry run mode"

# Via GitHub CLI:
gh workflow run commit-validator.yml -f dry_run=true
```

**Example Output:**

```
═══════════════════════════════════════
   COMMIT MESSAGE VALIDATOR
═══════════════════════════════════════

▶ Fetching commits in PR #42...
  Found 3 commit(s) to validate

  [1/3] a1b2c3d - Add governance workflow templates (#62)
    ✓ References issue(s): 62
      Issue #62: OPEN

  [2/3] d4e5f6g - Update documentation
    ✗ No issue reference found

═══════════════════════════════════════
   VALIDATION RESULTS
═══════════════════════════════════════

  Total commits validated: 3
  Violations found: 1

❌ Validation failed with 1 violation(s):

  Commit: d4e5f6g
  Message: Update documentation
  Author: John Doe <john@example.com>
  Error: Commit message does not reference an issue

REQUIREMENT:
All commits must reference an issue using one of these formats:
  - #123
  - GH-123
  - Closes #123, Fixes #456
  - anokye-labs/repo#123
```

### Agent Authentication Workflow

**File:** `agent-auth.yml`  
**Script:** `scripts/Test-AgentAuth.ps1`

**Purpose:** Validates that commits come from approved GitHub Apps (agents), not humans.

**Features:**
- ✅ Validates commits are from GitHub Apps
- ✅ Configurable allowlist of approved agents
- ✅ Human override mechanism via commit message flag
- ✅ Audit logging for all authentication attempts
- ✅ Supports dry-run mode
- ✅ Detailed validation reports

**Default Allowed Agents:**
- `copilot-swe-agent` — GitHub Copilot
- `github-actions` — GitHub Actions bot
- `dependabot` — Dependabot
- `renovate` — Renovate bot

**Trigger:** Runs on all pull request events

**Permissions Required:**
- `contents: read` — Read repository code
- `pull-requests: write` — Comment on PRs

**How It Works:**

1. Extracts commit author email and name
2. Detects GitHub Apps by email pattern: `*[bot]@users.noreply.github.com`
3. Checks if app is in allowlist
4. For human commits, checks for `[human-override]` flag (if enabled)
5. Logs all authentication attempts to JSON audit file

**Human Override (Optional):**

If you need to allow emergency human commits:

1. Edit `Test-AgentAuth.ps1` and set `$AllowHumanOverride = $true`
2. Include `[human-override]` in commit messages:

```bash
git commit -m "Emergency hotfix for security issue [human-override] #123"
```

**Configuration:**

Customize allowed agents in `Test-AgentAuth.ps1`:

```powershell
[string[]]$AllowedAgents = @(
    "copilot-swe-agent",
    "github-actions",
    "dependabot",
    "renovate",
    "your-custom-bot"
)
```

**Audit Log:**

The workflow generates `agent-auth-audit.json` with detailed authentication records:

```json
[
  {
    "Commit": "a1b2c3d",
    "Message": "Add feature (#42)",
    "Author": "copilot-swe-agent[bot]",
    "Email": "198982749+copilot-swe-agent[bot]@users.noreply.github.com",
    "IsApp": true,
    "AppName": "copilot-swe-agent",
    "Status": "APPROVED",
    "Reason": "Approved agent: copilot-swe-agent",
    "Timestamp": "2026-02-10T06:42:00Z"
  }
]
```

**Dry Run Mode:**

```bash
gh workflow run agent-auth.yml -f dry_run=true
```

### Branch Protection Rulesets

**Directory:** `rulesets/`

Two pre-configured ruleset templates for different security needs:

#### 1. Agent-Only (Strict)

**File:** `branch-protection-agent-only.json`

**Purpose:** Maximum security for agent-only repositories.

**Rules Enforced:**
- ✅ Require pull request with 1 approval
- ✅ Dismiss stale reviews on new pushes
- ✅ Require all review threads resolved
- ✅ Required status checks: `validate-commits`, `validate-agent-auth`
- ✅ Require linear history (no merge commits)
- ✅ Require signed commits
- ✅ Prevent force pushes
- ✅ Prevent branch deletion
- ✅ Prevent branch creation (except via PR)

**Bypass:** Repository admins can bypass via pull request only

**Use Case:** Production repositories with strict agent-only enforcement

#### 2. With Emergency Bypass

**File:** `branch-protection-with-bypass.json`

**Purpose:** Balanced security with emergency escape hatch.

**Rules Enforced:**
- ✅ Same as agent-only, except:
- ⚠️ Signed commits not required (allows emergency human commits)
- ⚠️ Admins can bypass all rules (always)

**Use Case:** Repositories where emergency human intervention may be needed

## Integration Examples

### Full Governance Stack

For complete agent-only enforcement, use all three components:

```yaml
# .github/workflows/governance.yml
name: Governance Checks

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  commit-validation:
    uses: ./.github/workflows/commit-validator.yml
  
  agent-authentication:
    uses: ./.github/workflows/agent-auth.yml
```

Then import the branch protection ruleset to require both checks.

### Gradual Adoption

Start with commit validation only, then add agent auth later:

```bash
# Week 1: Add commit validator
cp workflow-templates/commit-validator.yml .github/workflows/

# Week 2: Test agent auth in dry-run mode
cp workflow-templates/agent-auth.yml .github/workflows/
# Edit agent-auth.yml to default dry_run: true

# Week 3: Enable agent auth enforcement
# Edit agent-auth.yml to set dry_run: false

# Week 4: Import branch protection ruleset
gh api -X POST "/repos/$OWNER/$REPO/rulesets" \
  --input workflow-templates/rulesets/branch-protection-agent-only.json
```

### Custom Validation Rules

Extend the commit validator with your own rules:

```yaml
# Add to commit-validator.yml
- name: Validate commit message format
  run: |
    # Your custom validation logic
    if ! git log --format=%s origin/$BASE_REF..HEAD | grep -E '^(feat|fix|docs|chore):'; then
      echo "::error::Commits must follow Conventional Commits format"
      exit 1
    fi
```

## Troubleshooting

### Commit Validator Issues

**Problem:** Commits reference issues but validation still fails

**Solution:** Check that issue numbers are correctly formatted. The validator supports:
- `#123` (space before is optional)
- `GH-123`
- `Closes #123`, `Fixes #456`, `Resolves #789`

**Problem:** Cross-repo issues not recognized

**Solution:** Use full format: `owner/repo#123`

### Agent Auth Issues

**Problem:** Copilot commits rejected as unauthorized

**Solution:** Verify the agent name in `AllowedAgents` matches the actual app name. Check audit log for exact name.

**Problem:** Need emergency human commit

**Solution:** 
1. Set `AllowHumanOverride = $true` in `Test-AgentAuth.ps1`
2. Include `[human-override]` in commit message
3. Or temporarily disable the workflow

### Branch Protection Issues

**Problem:** Can't import ruleset via API

**Solution:** Ensure you have admin permissions and use a PAT with `repo` scope:

```bash
gh auth login --scopes repo
```

**Problem:** Status checks not appearing

**Solution:** Workflow must run at least once before GitHub recognizes the check. Open a test PR to trigger workflows.

## Configuration Reference

### Environment Variables

Both workflows support these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `GH_TOKEN` | GitHub token for API access | `${{ github.token }}` |
| `DRY_RUN` | Enable dry-run mode | `false` |
| `PR_NUMBER` | Pull request number | Auto-detected |
| `BASE_REF` | Base branch | Auto-detected |

### PowerShell Script Parameters

**Test-AgentAuth.ps1:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `Owner` | string | Yes | - | Repository owner |
| `Repo` | string | Yes | - | Repository name |
| `PRNumber` | int | Yes | - | Pull request number |
| `BaseRef` | string | Yes | - | Base branch ref |
| `AllowedAgents` | string[] | No | See script | Approved agent names |
| `AllowHumanOverride` | switch | No | `$false` | Allow human commits with flag |
| `DryRun` | switch | No | `$false` | Show results without failing |

## Requirements

### Prerequisites

- **GitHub Actions** — Workflows run on `ubuntu-latest` runners
- **PowerShell 7.0+** — Required for validation scripts
- **GitHub CLI** — Used for GraphQL API access
- **Git** — For commit history analysis

### Permissions

Workflows require these permissions in `GITHUB_TOKEN`:

```yaml
permissions:
  contents: read        # Read repository code
  pull-requests: write  # Comment on PRs (optional)
```

For branch protection rulesets, you need:
- **Admin** access to the repository
- A personal access token with `repo` scope (for API import)

## Related Issues

These templates were designed to support:

- **anokye-labs/akwaaba#145-#154** — Branch Protection Ruleset
- **anokye-labs/akwaaba#155-#165** — Commit Validator Workflow  
- **anokye-labs/akwaaba#166-#177** — Agent Authentication Workflow

## Contributing

Found a bug or have a feature request? Please open an issue in the [anokye-labs/plugins](https://github.com/anokye-labs/plugins) repository.

## License

MIT License - See repository root for details.
