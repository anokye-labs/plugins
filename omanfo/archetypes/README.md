# Agent Archetype Templates

Reusable agent templates for common automation patterns in the Anokye System. These templates provide standardized workflows, behavioral rules, and integration points that can be customized for any repository.

## Available Archetypes

| Archetype | Purpose | Workflow |
|-----------|---------|----------|
| [doc-sync](doc-sync.agent.md) | Documentation synchronization | Watch merged PRs → Analyze changes → Detect doc gaps → Create PR |
| [issue-labeler](issue-labeler.agent.md) | Issue classification | New issue → Analyze content → Apply labels (type, priority, phase) |
| [pr-reviewer](pr-reviewer.agent.md) | Pull request reviews | PR opened → Analyze diff → Post review → Track resolution |

## What Are Agent Archetypes?

Agent archetypes are reusable `.agent.md` templates that define:

- **Persona** — The agent's role and voice
- **Workflows** — Step-by-step processes the agent executes
- **Behavioral Rules** — Conventions and decision-making logic
- **Configuration** — Environment variables and repo-specific settings
- **Integration Points** — GitHub Actions, manual invocation, OkyeremanAgentRunner usage

Think of them as blueprints for automation. You copy a template into your repository, customize the configuration, and deploy the workflow.

## Quick Start

### 1. Choose an Archetype

Pick the agent pattern that matches your need:
- Need docs to stay current? → `doc-sync`
- Want automatic issue tagging? → `issue-labeler`
- Need automated PR reviews? → `pr-reviewer`

### 2. Copy to Your Repository

```bash
# Example: Add doc-sync agent to your repo
cp omanfo/archetypes/doc-sync.agent.md .github/agents/doc-sync.agent.md
```

### 3. Create Configuration

Each archetype includes a configuration section. Create the config file:

```bash
# Example: Doc-sync configuration
cat > .github/docsync-config.json <<EOF
{
  "enabled": true,
  "watchBranches": ["main"],
  "documentationPaths": ["README.md", "docs/**/*.md"],
  "autoCreatePR": true
}
EOF
```

### 4. Implement Agent Script

Each archetype requires a PowerShell script to implement the logic:

```bash
# Example: Create doc-sync script
touch .github/agents/doc-sync.ps1
```

See the **Customization Guide** section in each archetype for implementation details.

### 5. Set Up Workflow

Create a GitHub Actions workflow to trigger the agent:

```bash
# Example: Doc-sync workflow
cp templates/doc-sync-workflow.yml .github/workflows/doc-sync.yml
```

### 6. Test and Deploy

```powershell
# Test with dry run
pwsh .github/agents/doc-sync.ps1 -DryRun

# Enable by merging workflow to main branch
git add .github/
git commit -m "feat: Add doc-sync agent"
git push
```

## Deployment Patterns

### Pattern 1: GitHub Actions (Recommended)

Agent runs automatically in CI/CD:

**Pros:**
- Fully automated
- Consistent execution
- Audit trail in Actions logs

**Cons:**
- Requires workflow setup
- CI minutes usage

**Best for:** Production use, consistent enforcement

### Pattern 2: Manual Invocation

Agent run on-demand via PowerShell:

**Pros:**
- No CI setup required
- Full control over execution
- Great for testing

**Cons:**
- Requires manual trigger
- Inconsistent enforcement

**Best for:** Testing, ad-hoc runs, local development

### Pattern 3: Scheduled Patrol

Agent runs on schedule (e.g., daily):

**Pros:**
- Automated cleanup
- Batched processing
- Lower event noise

**Cons:**
- Delayed feedback
- Fixed schedule

**Best for:** Non-urgent checks (stale issues, documentation audits)

## Integration with OkyeremanAgentRunner

All archetypes use the [OkyeremanAgentRunner](../../shared/OkyeremanAgentRunner/) shared module for common operations:

```powershell
# Import in your agent script
$modulePath = Join-Path $PSScriptRoot "../../shared/OkyeremanAgentRunner/OkyeremanAgentRunner.psd1"
Import-Module $modulePath -Force

# Use shared functions
$cid = New-CorrelationId -Prefix "myagent"
Write-AgentLog "Starting work" -Agent "MyAgent" -CorrelationId $cid
$context = Get-IssueContext -Owner $owner -Repo $repo -IssueNumber $issueNum
```

**Available functions:**
- `Write-AgentLog` — Structured logging
- `Invoke-WithRetry` — Retry with backoff
- `Get-IssueContext` — Load issue details
- `New-AgentPR` — Create pull request
- `Get-PRStatus` — Check PR status
- `Add-PRReviewComment` — Post review
- `ConvertTo-SafeOutput` — Sanitize output
- `New-CorrelationId` — Generate tracking ID

See the [OkyeremanAgentRunner README](../../shared/OkyeremanAgentRunner/README.md) for full documentation.

## Customization Guide

Each archetype template includes a `<customization>` section with:

1. **Repository setup steps** — What files to create and where
2. **Required functions** — PowerShell functions you need to implement
3. **Configuration options** — Environment variables and JSON settings
4. **Language-specific patterns** — Examples for JavaScript, Python, Go, etc.

### Example: Customizing Doc-Sync for Python

```powershell
# In .github/agents/doc-sync.ps1

function Extract-PublicSignatures-Python {
    param([string]$Diff)
    
    # Your custom logic to parse Python function signatures
    $pattern = '^\+\s*(def|class)\s+([a-zA-Z][a-zA-Z0-9_]*)'
    Select-String -Pattern $pattern -InputObject $Diff | 
        Where-Object { $_.Matches[0].Groups[2].Value -notmatch '^_' }
}

function Test-DocumentationMatch-Python {
    param([string]$DocContent, [string]$Signature)
    
    # Your custom logic to compare docs to code
    # Return true if mismatch detected
}
```

## Testing Strategies

### 1. Dry Run Mode

Test agents without making changes:

```powershell
pwsh .github/agents/doc-sync.ps1 -DryRun
```

### 2. Test on Specific Items

Target a single issue or PR:

```powershell
pwsh .github/agents/issue-labeler.ps1 -IssueNumber 42 -DryRun
pwsh .github/agents/pr-reviewer.ps1 -PRNumber 99 -DryRun
```

### 3. Batch Test on Recent Items

Test on last N items:

```powershell
pwsh .github/agents/issue-labeler.ps1 -RecentCount 10 -DryRun
```

### 4. Monitor Correlation IDs

Track agent execution across logs:

```powershell
# Find all actions for a specific correlation ID
gh api graphql -f query='{ ... }' | jq '.[] | select(.correlationId == "reviewer-plugins-pr99-20260210")'
```

## Best Practices

### 1. Start with One Archetype

Don't deploy all three at once. Start with the one that solves your biggest pain point:
- High documentation drift? → `doc-sync`
- Issues piling up unorganized? → `issue-labeler`
- PR reviews taking too long? → `pr-reviewer`

### 2. Test in Dry Run First

Always test with `-DryRun` before enabling:

```powershell
# Test on 5 recent items
pwsh .github/agents/issue-labeler.ps1 -RecentCount 5 -DryRun

# Review output, adjust config, test again
vim .github/labeler-config.json
pwsh .github/agents/issue-labeler.ps1 -RecentCount 5 -DryRun

# When satisfied, deploy
git add .github/
git commit -m "feat: Add issue labeler agent"
```

### 3. Use Confidence Thresholds

Don't let agents be overly aggressive. Set confidence thresholds:

```json
{
  "confidenceThreshold": 0.70,
  "autoApprove": false,
  "respectManual": true
}
```

### 4. Monitor and Tune

Track agent effectiveness:
- How often do humans override agent decisions?
- Which labels are most helpful vs. noisy?
- Are agent PRs actually reducing work?

Adjust configuration based on feedback.

### 5. Respect Human Overrides

If a human removes a label or rejects a review, respect that decision:

```json
{
  "respectManual": true
}
```

Agents should assist humans, not fight them.

## Architecture

### How Archetypes Fit in the Anokye System

```
┌─────────────────────────────────────┐
│   Okyeame (CLI Agent)               │  ← Human interaction
│   - Project management              │
│   - Status reporting                │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│   Okyerema (Orchestration Skill)    │  ← Deployed to repos
│   - Scripts, references, workflows  │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│   Agent Archetypes                  │  ← This directory
│   - doc-sync.agent.md               │
│   - issue-labeler.agent.md          │
│   - pr-reviewer.agent.md            │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│   OkyeremanAgentRunner (Shared)     │  ← Common runtime
│   - Logging, errors, context, PRs   │
└─────────────────────────────────────┘
```

### Execution Model

1. **Template** — `.agent.md` defines the agent pattern
2. **Configuration** — JSON file customizes for the repo
3. **Implementation** — PowerShell script implements logic
4. **Trigger** — GitHub Actions or manual invocation
5. **Runtime** — OkyeremanAgentRunner provides shared functions
6. **Output** — Labels, PRs, reviews, issues

## Examples

See the `<examples>` section in each archetype for specific scenarios:

- **doc-sync** — Function signature change, missing documentation
- **issue-labeler** — Bug detection, feature request, low confidence
- **pr-reviewer** — Security issue, missing tests, agent PR auto-approval

## Related Issues

- anokye-labs/akwaaba#226-#232 (Doc-Sync Agent)
- anokye-labs/akwaaba#233-#241 (Issue Labeler Agent)
- anokye-labs/akwaaba#243-#253 (PR Reviewer Agent)
- anokye-labs/plugins#40 (Shared Agent Runner Module)
- anokye-labs/plugins#8 (PR Completion)
- anokye-labs/plugins#34 (Auto-approval)

## Contributing

To add a new archetype:

1. Create `{name}.agent.md` following the template structure
2. Include all sections: persona, role, conventions, workflow, config, integration, customization, examples
3. Use OkyeremanAgentRunner for shared operations
4. Document configuration options clearly
5. Provide language-specific customization examples
6. Test in a real repository

## License

MIT License - See LICENSE file for details
