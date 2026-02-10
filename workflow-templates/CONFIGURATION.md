# Configuration Guide

This guide helps you customize the governance workflow templates for your repository's specific needs.

## Quick Configuration Checklist

Before deploying, review these configuration points:

- [ ] **Allowed Agents** — Which GitHub Apps can commit to your repo?
- [ ] **Human Override** — Should emergency human commits be allowed?
- [ ] **Issue Reference Format** — Which issue reference patterns are valid?
- [ ] **Branch Protection Level** — Strict enforcement or emergency bypass?
- [ ] **Required Approvals** — How many reviews are required?
- [ ] **Status Checks** — Which checks must pass before merge?

## Agent Authentication Configuration

### Customize Allowed Agents

Edit `scripts/Test-AgentAuth.ps1` around line 49:

```powershell
[Parameter()]
[string[]]$AllowedAgents = @(
    "copilot-swe-agent",    # GitHub Copilot
    "github-actions",       # GitHub Actions bot
    "dependabot",           # Dependabot
    "renovate",             # Renovate bot
    # Add your custom agents below:
    # "your-bot-name",
    # "another-bot"
)
```

**Finding Your Bot Name:**

1. Check a commit from your bot on GitHub
2. Look at the author email: `*[bot]@users.noreply.github.com`
3. The bot name is the part before `[bot]`

**Example:**
- Email: `198982749+copilot-swe-agent[bot]@users.noreply.github.com`
- Bot name: `copilot-swe-agent`

### Enable Human Override

Edit `scripts/Test-AgentAuth.ps1` to allow human commits with override flag:

```powershell
[Parameter()]
[switch]$AllowHumanOverride = $true  # Change from default $false
```

Then humans can commit with:
```bash
git commit -m "Emergency fix [human-override] #123"
```

### Customize Error Messages

Edit the error messages in `Test-AgentAuth.ps1`:

```powershell
# Around line 210
if ($hasOverride -and $AllowHumanOverride) {
    Write-ColorOutput "    ✓ Human override authorized" -Color Green
    $auditEntry.Status = "APPROVED"
    $auditEntry.Reason = "Human override flag present"
    $approvedCommits += $shortHash
} else {
    if ($AllowHumanOverride) {
        Write-ColorOutput "    ✗ Human commit without override flag" -Color Red
        $error = "Human commit requires [human-override] flag in message"  # Customize this
    } else {
        Write-ColorOutput "    ✗ Human commit not allowed" -Color Red
        $error = "Only approved agents can commit to this repository"  # Customize this
    }
    # ...
}
```

## Commit Validator Configuration

### Customize Issue Reference Patterns

Edit `commit-validator.yml` around line 66:

```powershell
# Issue reference patterns (flexible to support various formats)
$issuePatterns = @(
    '#(\d+)',                           # #123
    'GH-(\d+)',                         # GH-123
    '(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+#(\d+)',  # Closes #123
    '(?:anokye-labs/\w+)?#(\d+)'       # anokye-labs/repo#123
    # Add your custom patterns below:
    # 'JIRA-(\d+)',                     # JIRA-123
    # 'ISSUE-(\d+)',                    # ISSUE-123
)
```

**Pattern Examples:**

| Pattern | Matches | Description |
|---------|---------|-------------|
| `#(\d+)` | `#123`, `#4567` | Simple issue reference |
| `GH-(\d+)` | `GH-123` | Prefixed reference |
| `JIRA-([A-Z]+-\d+)` | `JIRA-PROJ-123` | JIRA integration |
| `\[#(\d+)\]` | `[#123]` | Bracketed reference |

### Exclude Certain Commits

Add commit exclusion logic around line 58:

```powershell
foreach ($commitLine in $commitList) {
    if (-not $commitLine) { continue }
    
    $parts = $commitLine -split '\|'
    $hash = $parts[0]
    $message = $parts[1]
    $author = $parts[2]
    
    # Skip bot commits
    if ($message -match '^\[bot\]') {
        continue
    }
    
    # Skip merge commits
    if ($message -match '^Merge (branch|pull request)') {
        continue
    }
    
    # Your validation logic here...
}
```

### Change Validation Strictness

Control whether to verify issue existence:

```powershell
# Around line 96
# Verify issues exist (via GraphQL)
$verifyIssueExists = $true  # Set to $false to skip verification

if ($verifyIssueExists) {
    foreach ($issueNum in $referencedIssues) {
        # ... verification logic ...
    }
}
```

## Branch Protection Configuration

### Modify Required Approvals

Edit either ruleset JSON file:

```json
{
  "type": "pull_request",
  "parameters": {
    "required_approving_review_count": 1,  // Change to 2 or more
    "dismiss_stale_reviews_on_push": true,
    "require_code_owner_review": false,     // Set true to require CODEOWNERS
    "require_last_push_approval": false,    // Set true for stricter review
    "required_review_thread_resolution": true
  }
}
```

### Add/Remove Status Checks

Edit the `required_status_checks` section:

```json
{
  "type": "required_status_checks",
  "parameters": {
    "strict_required_status_checks_policy": true,
    "required_status_checks": [
      {
        "context": "validate-commits",      // Commit validator
        "integration_id": null
      },
      {
        "context": "validate-agent-auth",   // Agent authentication
        "integration_id": null
      },
      {
        "context": "validate-plugin",       // Add custom check
        "integration_id": null
      }
    ]
  }
}
```

**Finding Status Check Names:**

1. Go to a PR with the check
2. Look at the "Checks" section
3. The context name is what appears there

### Configure Bypass Actors

Control who can bypass branch protection:

```json
{
  "bypass_actors": [
    {
      "actor_id": null,                    // null = applies to role
      "actor_type": "RepositoryRole",      // RepositoryRole, Team, or Integration
      "bypass_mode": "always",             // always or pull_request
      "comment": "Admins can bypass for emergencies"
    }
  ]
}
```

**Bypass Modes:**
- `always` — Bypass all rules
- `pull_request` — Must still use PR, but can bypass status checks

**Actor Types:**
- `RepositoryRole` — Repository admins, maintainers, etc.
- `Team` — Specific GitHub team (requires team ID)
- `Integration` — GitHub App (requires app ID)

### Add Protected File Paths

Restrict changes to sensitive files:

```json
{
  "type": "file_path_restriction",
  "parameters": {
    "restricted_file_paths": [
      ".github/workflows/*",
      "workflow-templates/*",
      "CODEOWNERS"
    ]
  }
}
```

## Workflow Customization

### Change Workflow Triggers

Edit the workflow file `on:` section:

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened]
    branches:
      - main
      - develop    # Add more branches
    paths:
      - '**'       # Or restrict to certain paths
  
  push:
    branches:
      - main       # Run on direct pushes too
  
  schedule:
    - cron: '0 0 * * *'  # Daily validation
```

### Add Pre/Post Steps

Insert additional steps before or after validation:

```yaml
jobs:
  validate-commits:
    name: Validate Commit Messages
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      # Add pre-validation steps
      - name: Setup custom environment
        run: |
          echo "Setting up..."
      
      - name: Validate commit messages
        # ... existing validation ...
      
      # Add post-validation steps
      - name: Send notification
        if: failure()
        run: |
          echo "Validation failed, sending alert..."
```

### Change Runner Environment

Use different runner types:

```yaml
jobs:
  validate-commits:
    runs-on: ubuntu-latest    # Options: ubuntu-latest, macos-latest, windows-latest
    # Or use self-hosted:
    # runs-on: [self-hosted, linux]
```

## Repository-Specific Overrides

### Create Local Configuration File

Add a `.github/governance-config.json` in your repository:

```json
{
  "commit_validator": {
    "enabled": true,
    "issue_patterns": ["#(\\d+)", "JIRA-([A-Z]+-\\d+)"],
    "verify_issue_exists": true,
    "allow_merge_commits": false
  },
  "agent_auth": {
    "enabled": true,
    "allowed_agents": [
      "copilot-swe-agent",
      "github-actions"
    ],
    "allow_human_override": false,
    "audit_log_retention_days": 90
  },
  "branch_protection": {
    "required_reviews": 1,
    "require_code_owners": false,
    "required_checks": [
      "validate-commits",
      "validate-agent-auth",
      "build",
      "test"
    ]
  }
}
```

Then modify workflows to read this config:

```yaml
- name: Load configuration
  id: config
  run: |
    if [ -f .github/governance-config.json ]; then
      echo "config_file=.github/governance-config.json" >> $GITHUB_OUTPUT
    else
      echo "config_file=workflow-templates/default-config.json" >> $GITHUB_OUTPUT
    fi

- name: Validate with custom config
  env:
    CONFIG_FILE: ${{ steps.config.outputs.config_file }}
  run: |
    # Use $CONFIG_FILE in validation
```

## Testing Configuration Changes

### Test Locally

Before committing configuration changes:

```bash
# Test PowerShell script locally
pwsh -File workflow-templates/scripts/Test-AgentAuth.ps1 \
  -Owner "your-org" \
  -Repo "your-repo" \
  -PRNumber 42 \
  -BaseRef "main" \
  -DryRun

# Validate JSON syntax
jq empty workflow-templates/rulesets/branch-protection-agent-only.json
```

### Test in CI with Dry Run

Temporarily enable dry run to test without failing:

```yaml
env:
  DRY_RUN: true  # Add this temporarily
```

Open a test PR and verify output in Actions logs.

### Staged Rollout

1. **Week 1:** Enable workflows in dry-run mode, monitor results
2. **Week 2:** Enable commit validator only
3. **Week 3:** Enable agent auth (if applicable)
4. **Week 4:** Import branch protection ruleset

## Common Configuration Scenarios

### Scenario 1: Open Source Project

**Needs:** 
- Human contributions welcomed
- Commit messages must reference issues
- No agent enforcement

**Configuration:**
```yaml
# commit-validator.yml: ✅ Enabled
# agent-auth.yml: ❌ Disabled
# branch-protection: Use "with-bypass" variant
```

### Scenario 2: Enterprise Agent-Only

**Needs:**
- Only approved bots can commit
- Strict enforcement
- Emergency admin override

**Configuration:**
```yaml
# commit-validator.yml: ✅ Enabled
# agent-auth.yml: ✅ Enabled, AllowHumanOverride = false
# branch-protection: Use "agent-only" variant
```

### Scenario 3: Hybrid Approach

**Needs:**
- Agents preferred, humans allowed with flag
- Commit validator for all
- Moderate protection

**Configuration:**
```yaml
# commit-validator.yml: ✅ Enabled
# agent-auth.yml: ✅ Enabled, AllowHumanOverride = true
# branch-protection: Use "with-bypass" variant
```

## Advanced Configurations

### Multi-Branch Protection

Protect multiple branches with different rules:

```json
{
  "conditions": {
    "ref_name": {
      "include": [
        "refs/heads/main",
        "refs/heads/develop",
        "refs/heads/release/*"
      ]
    }
  }
}
```

### Time-Based Bypass

Allow bypasses only during certain times (requires custom logic):

```powershell
# Add to validation script
$currentHour = (Get-Date).Hour
$isBusinessHours = $currentHour -ge 9 -and $currentHour -lt 17

if (-not $isBusinessHours) {
    Write-Host "Outside business hours - stricter validation applied"
    # Apply stricter rules
}
```

### Integration with External Systems

Post validation results to external systems:

```yaml
- name: Post to Slack
  if: failure()
  env:
    SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
  run: |
    curl -X POST $SLACK_WEBHOOK \
      -H 'Content-Type: application/json' \
      -d '{"text":"Governance check failed on PR #${{ github.event.pull_request.number }}"}'
```

## Getting Help

- **Issues:** Open an issue in [anokye-labs/plugins](https://github.com/anokye-labs/plugins/issues)
- **Documentation:** See [README.md](README.md) for usage examples
- **GitHub Docs:** [Branch protection rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches)
