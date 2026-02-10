# Quick Reference

Fast reference for deploying and configuring governance workflow templates.

## 30-Second Setup

```bash
# 1. Copy workflows
curl -sL https://raw.githubusercontent.com/anokye-labs/plugins/main/workflow-templates/commit-validator.yml > .github/workflows/commit-validator.yml
curl -sL https://raw.githubusercontent.com/anokye-labs/plugins/main/workflow-templates/agent-auth.yml > .github/workflows/agent-auth.yml

# 2. Copy agent auth script
mkdir -p workflow-templates/scripts
curl -sL https://raw.githubusercontent.com/anokye-labs/plugins/main/workflow-templates/scripts/Test-AgentAuth.ps1 > workflow-templates/scripts/Test-AgentAuth.ps1

# 3. Import branch protection
gh api -X POST /repos/OWNER/REPO/rulesets \
  --input <(curl -sL https://raw.githubusercontent.com/anokye-labs/plugins/main/workflow-templates/rulesets/branch-protection-agent-only.json)

# 4. Done! Open a PR to test.
```

## Command Cheat Sheet

### Dry Run Testing

```bash
# Test commit validator without failing
gh workflow run commit-validator.yml -f dry_run=true

# Test agent auth without failing
gh workflow run agent-auth.yml -f dry_run=true
```

### View Workflow Runs

```bash
# List recent runs
gh run list --workflow=commit-validator.yml --limit 5

# View specific run
gh run view <run-id> --log
```

### Check Branch Protection

```bash
# List all rulesets
gh api repos/OWNER/REPO/rulesets | jq '.[] | {name, enforcement}'

# Get specific ruleset
gh api repos/OWNER/REPO/rulesets/RULESET_ID
```

### Local Testing

```bash
# Test commit message format
git log --format='%s' origin/main..HEAD | grep -E '#[0-9]+'

# Test agent auth script locally
pwsh workflow-templates/scripts/Test-AgentAuth.ps1 \
  -Owner "org" -Repo "repo" -PRNumber 42 -BaseRef "main" -DryRun

# Check agent email pattern
git log --format='%ae' -1 | grep '\[bot\]@users.noreply.github.com'
```

## Configuration Quick Fixes

### Add Custom Agent

Edit `workflow-templates/scripts/Test-AgentAuth.ps1` line 49:

```powershell
[string[]]$AllowedAgents = @(
    "copilot-swe-agent",
    "your-bot-name"  # Add here
)
```

### Allow Human Commits

Edit `workflow-templates/scripts/Test-AgentAuth.ps1`:

```powershell
[Parameter()]
[switch]$AllowHumanOverride = $true  # Change to $true
```

Then commit with:
```bash
git commit -m "Emergency fix [human-override] #123"
```

### Add Custom Issue Pattern

Edit `workflow-templates/commit-validator.yml` line 66:

```powershell
$issuePatterns = @(
    '#(\d+)',
    'JIRA-([A-Z]+-\d+)'  # Add custom pattern
)
```

### Change Required Reviews

Edit ruleset JSON:

```json
"required_approving_review_count": 2  // Change from 1 to 2
```

## Troubleshooting Quick Fixes

### Workflow Not Running

```bash
# Check workflow file exists
ls -la .github/workflows/commit-validator.yml

# Check if workflow is enabled
gh workflow list | grep commit-validator
```

### Check Not Appearing in PR

```bash
# Workflow must run once first
gh run list --workflow=commit-validator.yml --limit 1

# Check branch protection recognizes it
gh api repos/OWNER/REPO/branches/main/protection/required_status_checks
```

### PowerShell Script Fails

```bash
# Check PowerShell version (need 7.0+)
pwsh --version

# Test script syntax
pwsh -File workflow-templates/scripts/Test-AgentAuth.ps1 -?
```

### Issue Reference Not Recognized

```bash
# Test pattern matching
pwsh -Command "
  \$message = 'Your commit message here'
  \$pattern = '#(\d+)'
  if (\$message -match \$pattern) {
    Write-Host 'Match: #' + \$matches[1]
  } else {
    Write-Host 'No match'
  }
"
```

## Status Codes Reference

| Exit Code | Meaning |
|-----------|---------|
| 0 | Validation passed |
| 1 | Validation failed |

## Issue Reference Formats

| Format | Example | Status |
|--------|---------|--------|
| `#N` | `#123` | ✅ Supported |
| `GH-N` | `GH-123` | ✅ Supported |
| `Closes #N` | `Closes #123` | ✅ Supported |
| `Fixes #N` | `Fixes #456` | ✅ Supported |
| `Resolves #N` | `Resolves #789` | ✅ Supported |
| `org/repo#N` | `anokye-labs/plugins#42` | ✅ Supported |

## Agent Email Patterns

| Pattern | Example | Detected As |
|---------|---------|-------------|
| `*[bot]@users.noreply.github.com` | `copilot-swe-agent[bot]@users.noreply.github.com` | ✅ GitHub App |
| `ID+*[bot]@users.noreply.github.com` | `198982749+copilot-swe-agent[bot]@users.noreply.github.com` | ✅ GitHub App |
| `user@example.com` | `john@example.com` | ❌ Human |

## Common Workflows

### Deploy to New Repo

```bash
git clone https://github.com/your-org/new-repo
cd new-repo
mkdir -p .github/workflows workflow-templates/scripts

# Copy files
curl -sL https://github.com/anokye-labs/plugins/raw/main/workflow-templates/commit-validator.yml > .github/workflows/commit-validator.yml
curl -sL https://github.com/anokye-labs/plugins/raw/main/workflow-templates/agent-auth.yml > .github/workflows/agent-auth.yml
curl -sL https://github.com/anokye-labs/plugins/raw/main/workflow-templates/scripts/Test-AgentAuth.ps1 > workflow-templates/scripts/Test-AgentAuth.ps1

# Commit
git add .github/ workflow-templates/
git commit -m "Add governance workflows (#issue)"
git push

# Import ruleset
gh api -X POST /repos/your-org/new-repo/rulesets \
  --input <(curl -sL https://github.com/anokye-labs/plugins/raw/main/workflow-templates/rulesets/branch-protection-agent-only.json)
```

### Test Before Enforcing

```bash
# Week 1: Deploy with dry-run
# Edit workflows to set dry_run: true by default

# Week 2: Monitor results
gh run list --workflow=commit-validator.yml --json conclusion,createdAt

# Week 3: Enable enforcement
# Edit workflows to set dry_run: false

# Week 4: Import branch protection
gh api -X POST /repos/OWNER/REPO/rulesets --input ruleset.json
```

### Emergency Bypass

```bash
# Option 1: Use admin bypass (if configured)
# Push directly as admin (allowed by ruleset)

# Option 2: Temporarily disable workflow
gh workflow disable commit-validator.yml
# ... make changes ...
gh workflow enable commit-validator.yml

# Option 3: Use human override flag (if enabled)
git commit -m "Emergency fix [human-override] #123"
```

## File Locations

| File | Purpose | Location |
|------|---------|----------|
| Commit validator | Workflow | `.github/workflows/commit-validator.yml` |
| Agent auth | Workflow | `.github/workflows/agent-auth.yml` |
| Auth script | PowerShell | `workflow-templates/scripts/Test-AgentAuth.ps1` |
| Ruleset (strict) | JSON config | Import from `workflow-templates/rulesets/branch-protection-agent-only.json` |
| Ruleset (bypass) | JSON config | Import from `workflow-templates/rulesets/branch-protection-with-bypass.json` |

## More Help

- 📖 Full documentation: [README.md](README.md)
- ⚙️ Configuration guide: [CONFIGURATION.md](CONFIGURATION.md)
- 💡 Usage examples: [EXAMPLES.md](EXAMPLES.md)
- 🐛 Report issues: [anokye-labs/plugins/issues](https://github.com/anokye-labs/plugins/issues)
