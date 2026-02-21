# Usage Examples

Real-world examples of deploying and using the governance workflow templates.

## Table of Contents

- [Basic Deployment](#basic-deployment)
- [Agent-Only Repository](#agent-only-repository)
- [Open Source Project](#open-source-project)
- [Enterprise Setup](#enterprise-setup)
- [Testing and Validation](#testing-and-validation)
- [Troubleshooting Examples](#troubleshooting-examples)

## Basic Deployment

### Step-by-Step: First Time Setup

```bash
# 1. Clone your repository
git clone https://github.com/your-org/your-repo.git
cd your-repo

# 2. Create workflow directory if it doesn't exist
mkdir -p .github/workflows

# 3. Copy commit validator
curl -o .github/workflows/commit-validator.yml \
  https://raw.githubusercontent.com/anokye-labs/plugins/main/workflow-templates/commit-validator.yml

# 4. Copy agent auth workflow and script
curl -o .github/workflows/agent-auth.yml \
  https://raw.githubusercontent.com/anokye-labs/plugins/main/workflow-templates/agent-auth.yml

mkdir -p workflow-templates/scripts
curl -o workflow-templates/scripts/Test-AgentAuth.ps1 \
  https://raw.githubusercontent.com/anokye-labs/plugins/main/workflow-templates/scripts/Test-AgentAuth.ps1

# 5. Commit and push
git add .github/workflows/ workflow-templates/
git commit -m "Add governance workflows (#issue-number)"
git push

# 6. Import branch protection ruleset
gh api -X POST /repos/your-org/your-repo/rulesets \
  --input <(curl -s https://raw.githubusercontent.com/anokye-labs/plugins/main/workflow-templates/rulesets/branch-protection-agent-only.json)
```

### Verify Installation

```bash
# Check workflows are in place
ls -la .github/workflows/

# Trigger a test run
gh workflow run commit-validator.yml -f dry_run=true

# Check workflow status
gh run list --workflow=commit-validator.yml
```

## Agent-Only Repository

For repositories where only approved bots can commit.

### Setup

```bash
# Deploy workflows
cp workflow-templates/commit-validator.yml .github/workflows/
cp workflow-templates/agent-auth.yml .github/workflows/
mkdir -p workflow-templates/scripts
cp workflow-templates/scripts/Test-AgentAuth.ps1 workflow-templates/scripts/

# Configure allowed agents
cat > .github/governance-config.yml <<EOF
allowed_agents:
  - copilot-swe-agent
  - github-actions
  - dependabot
  - renovate
allow_human_override: false
EOF

# Import strict ruleset
gh api -X POST /repos/$OWNER/$REPO/rulesets \
  --input workflow-templates/rulesets/branch-protection-agent-only.json
```

### Expected Behavior

**✅ Valid Copilot Commit:**
```bash
# Copilot commits automatically include issue reference
git log --format="%an|%ae|%s" -1
# Output: copilot-swe-agent[bot]|198982749+copilot-swe-agent[bot]@users.noreply.github.com|Fix bug in auth handler (#123)
```

**❌ Human Commit Rejected:**
```bash
git commit -m "Quick fix"
git push
# PR fails with: "Only approved agents can commit to this repository"
```

### Monitoring

```bash
# View audit logs
gh run download <run-id>
cat agent-auth-audit.json | jq '.'

# Check recent violations
gh run list --workflow=agent-auth.yml --json conclusion,name,createdAt
```

## Open Source Project

For repositories accepting human contributions with issue references required.

### Setup

```bash
# Deploy only commit validator
cp workflow-templates/commit-validator.yml .github/workflows/

# Configure for open source
cat > .github/workflows/commit-validator.yml <<EOF
name: Commit Validator

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  validate-commits:
    # ... standard configuration ...
EOF

# Use bypass-friendly branch protection
gh api -X POST /repos/$OWNER/$REPO/rulesets \
  --input workflow-templates/rulesets/branch-protection-with-bypass.json
```

### Contributor Workflow

**Valid Contribution:**
```bash
# Fork repository
gh repo fork your-org/your-repo

# Make changes
git checkout -b fix-typo
# ... edit files ...

# Commit with issue reference
git commit -m "Fix typo in README (#42)"

# Push and create PR
git push origin fix-typo
gh pr create --fill

# Validation passes ✅
```

**Invalid Contribution:**
```bash
# Commit without issue reference
git commit -m "Fix typo in README"

# PR fails validation ❌
# Message: "Commit message does not reference an issue"
```

### Maintainer Actions

```bash
# Review PR with validation failures
gh pr view 123

# Ask contributor to update commit message
gh pr comment 123 --body "Please update your commit message to reference an issue. Example: 'Fix typo in README (#42)'"

# Or amend and force push (if allowed)
git commit --amend -m "Fix typo in README (#42)"
git push --force-with-lease
```

## Enterprise Setup

For organizations with multiple repositories and strict governance.

### Organization-Wide Deployment

```bash
# Create a script to deploy to all repos
cat > deploy-governance.sh <<'EOF'
#!/bin/bash
set -e

ORG="your-org"
REPOS=$(gh repo list $ORG --json name --jq '.[].name')

for REPO in $REPOS; do
  echo "Deploying to $ORG/$REPO..."
  
  # Clone repo
  gh repo clone $ORG/$REPO /tmp/$REPO
  cd /tmp/$REPO
  
  # Deploy workflows
  mkdir -p .github/workflows workflow-templates/scripts
  curl -o .github/workflows/commit-validator.yml \
    https://raw.githubusercontent.com/anokye-labs/plugins/main/workflow-templates/commit-validator.yml
  curl -o .github/workflows/agent-auth.yml \
    https://raw.githubusercontent.com/anokye-labs/plugins/main/workflow-templates/agent-auth.yml
  curl -o workflow-templates/scripts/Test-AgentAuth.ps1 \
    https://raw.githubusercontent.com/anokye-labs/plugins/main/workflow-templates/scripts/Test-AgentAuth.ps1
  
  # Commit and push
  git checkout -b add-governance
  git add .github/ workflow-templates/
  git commit -m "Add governance workflows"
  git push origin add-governance
  
  # Create PR
  gh pr create --title "Add governance workflows" \
    --body "Deploying organization-wide governance policies" \
    --base main --head add-governance
  
  cd -
  rm -rf /tmp/$REPO
done
EOF

chmod +x deploy-governance.sh
./deploy-governance.sh
```

### Centralized Configuration

Create a shared configuration repository:

```bash
# Create config repo
gh repo create your-org/governance-config --public

# Add organization defaults
cat > governance-defaults.json <<EOF
{
  "commit_validator": {
    "enabled": true,
    "patterns": ["#(\\d+)", "JIRA-([A-Z]+-\\d+)"]
  },
  "agent_auth": {
    "enabled": true,
    "allowed_agents": [
      "copilot-swe-agent",
      "github-actions",
      "dependabot"
    ]
  }
}
EOF

git add governance-defaults.json
git commit -m "Add organization governance defaults"
git push
```

Update workflows to fetch org defaults:

```yaml
- name: Load org defaults
  run: |
    curl -o config.json \
      https://raw.githubusercontent.com/your-org/governance-config/main/governance-defaults.json
    # Use config.json in validation
```

## Testing and Validation

### Test Commit Validator Locally

```bash
# Create a test branch
git checkout -b test-commit-validator

# Make a commit without issue reference
git commit --allow-empty -m "Test commit without issue"

# Run validator locally
pwsh -Command "
  \$commits = git log --format='%H|%s|%an|%ae' origin/main..HEAD
  foreach (\$commit in \$commits -split '`n') {
    \$parts = \$commit -split '|'
    \$message = \$parts[1]
    if (\$message -notmatch '#(\d+)') {
      Write-Host 'FAIL: Commit does not reference issue' -ForegroundColor Red
      exit 1
    }
  }
  Write-Host 'PASS: All commits reference issues' -ForegroundColor Green
"
```

### Test Agent Auth Locally

```bash
# Run agent auth validation locally
pwsh workflow-templates/scripts/Test-AgentAuth.ps1 \
  -Owner "your-org" \
  -Repo "your-repo" \
  -PRNumber 42 \
  -BaseRef "main" \
  -DryRun

# Check audit log
cat agent-auth-audit.json | jq '.[] | {Commit, Status, Reason}'
```

### Validate Ruleset JSON

```bash
# Validate JSON syntax
jq empty workflow-templates/rulesets/branch-protection-agent-only.json
echo "✅ JSON is valid"

# Dry run ruleset import
gh api repos/$OWNER/$REPO/rulesets --dry-run \
  --input workflow-templates/rulesets/branch-protection-agent-only.json
```

### Create Test PR

```bash
# Create test commits
git checkout -b test-governance
echo "test" > test-file.txt
git add test-file.txt

# Test 1: Commit with issue reference (should pass)
git commit -m "Add test file (#999)"

# Test 2: Commit without issue reference (should fail)
echo "test2" >> test-file.txt
git commit -am "Update test file"

# Push and create PR
git push origin test-governance
gh pr create --title "Test governance workflows" --body "Testing validation"

# View check results
gh pr checks 999
```

## Troubleshooting Examples

### Example 1: Commit Validator False Positive

**Problem:** Commit references issue but validation fails.

```bash
# Commit message
git log -1 --format=%s
# Output: "Fix bug (#123)"

# But validation shows: "No issue reference found"
```

**Solution:**

```bash
# Check if pattern matches
pwsh -Command "
  \$message = 'Fix bug (#123)'
  \$pattern = '#(\d+)'
  if (\$message -match \$pattern) {
    Write-Host 'Pattern matches: #' + \$matches[1]
  } else {
    Write-Host 'Pattern does not match'
  }
"

# If pattern doesn't match, check for unicode/special characters
echo "Fix bug (#123)" | hexdump -C
```

### Example 2: Agent Not Recognized

**Problem:** Copilot commit rejected as unauthorized.

```bash
# Check commit author
git log -1 --format="%an|%ae"
# Output: copilot-swe-agent[bot]|198982749+copilot-swe-agent[bot]@users.noreply.github.com

# But validation shows: "Unauthorized agent"
```

**Solution:**

```bash
# Extract bot name from email
pwsh -Command "
  \$email = '198982749+copilot-swe-agent[bot]@users.noreply.github.com'
  if (\$email -match '(\d+\+)?([a-zA-Z0-9-]+)\[bot\]@') {
    Write-Host 'Bot name: ' + \$matches[2]
  }
"
# Output: Bot name: copilot-swe-agent

# Check allowlist in Test-AgentAuth.ps1
grep -A5 "AllowedAgents" workflow-templates/scripts/Test-AgentAuth.ps1
```

### Example 3: Branch Protection Not Working

**Problem:** Branch protection rules not enforced.

```bash
# Check if ruleset exists
gh api repos/$OWNER/$REPO/rulesets | jq '.[] | {name, enforcement}'

# Check if checks are recognized
gh api repos/$OWNER/$REPO/commits/$(git rev-parse HEAD)/status | jq '.statuses[].context'
```

**Solution:**

```bash
# Ensure workflows have run at least once
gh run list --limit 1

# Update ruleset to use correct check names
gh api repos/$OWNER/$REPO/rulesets | jq '.[] | .rules[] | select(.type=="required_status_checks")'

# Verify check names match workflow job names
grep "name:" .github/workflows/commit-validator.yml
```

### Example 4: Dry Run Not Working

**Problem:** Dry run mode still causes failures.

```bash
# Check if DRY_RUN is passed correctly
gh run view --log | grep DRY_RUN
```

**Solution:**

```yaml
# Ensure workflow_dispatch input is used
env:
  DRY_RUN: ${{ github.event.inputs.dry_run || 'false' }}

# Verify in script
- name: Debug dry run
  run: echo "DRY_RUN=$DRY_RUN"
```

### Example 5: PowerShell Script Errors

**Problem:** Script fails with syntax errors.

```bash
# Test script syntax
pwsh -File workflow-templates/scripts/Test-AgentAuth.ps1 -WhatIf

# Check PowerShell version
pwsh --version
# Must be 7.0+
```

**Solution:**

```bash
# Install PowerShell 7 if needed
# Ubuntu/Debian
sudo apt install powershell

# macOS
brew install powershell

# Windows
winget install Microsoft.PowerShell
```

## Advanced Examples

### Custom Issue Pattern

Add support for JIRA tickets:

```powershell
# In commit-validator.yml, around line 66
$issuePatterns = @(
    '#(\d+)',
    'GH-(\d+)',
    'JIRA-([A-Z]+-\d+)',  # Add JIRA pattern
    '(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+#(\d+)',
    '(?:anokye-labs/\w+)?#(\d+)'
)
```

### Multiple Branch Protection

Protect main and develop with different rules:

```bash
# Import main branch ruleset (strict)
gh api -X POST /repos/$OWNER/$REPO/rulesets \
  --input <(jq '.conditions.ref_name.include=["refs/heads/main"]' \
    workflow-templates/rulesets/branch-protection-agent-only.json)

# Import develop branch ruleset (relaxed)
gh api -X POST /repos/$OWNER/$REPO/rulesets \
  --input <(jq '.conditions.ref_name.include=["refs/heads/develop"] | 
    .rules[] |= select(.type != "required_signatures")' \
    workflow-templates/rulesets/branch-protection-with-bypass.json)
```

### Conditional Validation

Only validate certain paths:

```yaml
on:
  pull_request:
    paths:
      - 'src/**'
      - 'lib/**'
    paths-ignore:
      - 'docs/**'
      - '**.md'
```

## Getting Help

- **GitHub Discussions:** Ask questions in [anokye-labs/plugins discussions](https://github.com/anokye-labs/plugins/discussions)
- **Issues:** Report bugs at [anokye-labs/plugins/issues](https://github.com/anokye-labs/plugins/issues)
- **Documentation:** See [README.md](README.md) and [CONFIGURATION.md](CONFIGURATION.md)
