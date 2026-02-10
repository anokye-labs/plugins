# OkyeremanAgentRunner

Shared agent runner PowerShell module for Anokye Labs agent archetypes. This is the runtime foundation that agent definitions build on.

## Overview

The OkyeremanAgentRunner module provides common functions that all agent archetypes share, including:

- **Logging** — Structured logging with GitHub Actions integration
- **Error Handling** — Retry logic with configurable backoff
- **Issue Context** — Load and cache issue details, hierarchies, and labels
- **PR Management** — Create PRs, query status, post review comments
- **Safe Output Processing** — Sanitize agent responses, truncate outputs, format markdown
- **Correlation Tracking** — Generate and propagate correlation IDs

## Installation

### As a Module

```powershell
# Import the module
Import-Module ./shared/OkyeremanAgentRunner/OkyeremanAgentRunner.psd1

# Or install to PowerShell modules directory
Copy-Item -Recurse ./shared/OkyeremanAgentRunner "$env:PSModulePath\OkyeremanAgentRunner"
Import-Module OkyeremanAgentRunner
```

### In Agent Scripts

```powershell
# At the top of your agent script
$modulePath = Join-Path $PSScriptRoot "../../shared/OkyeremanAgentRunner/OkyeremanAgentRunner.psd1"
Import-Module $modulePath -Force
```

## Usage Examples

### Logging

```powershell
# Basic logging
Write-AgentLog "Processing issue #42" -Level Info

# With agent name and correlation ID
$cid = New-CorrelationId -Prefix "asafo"
Write-AgentLog "Starting task" -Level Info -Agent "AsafoAgent" -CorrelationId $cid

# Pipeline-friendly object output
$log = Write-AgentLog "Task completed" -AsObject
```

### Error Handling

```powershell
# Retry with backoff
$result = Invoke-WithRetry -ScriptBlock {
    gh api graphql -f query=$query
} -MaxRetries 5 -InitialDelaySeconds 2

# Create structured error
$error = New-AgentError -Message "Failed to create issue" -ErrorCode "GraphQLError" -Details $_.Exception.Message
```

### Issue Context

```powershell
# Load issue context (auto-cached)
$context = Get-IssueContext -Owner anokye-labs -Repo plugins -IssueNumber 42

# Access context properties
Write-Host "Issue: $($context.title)"
Write-Host "Type: $($context.issueType.name)"
Write-Host "Parent: $($context.parentIssue.number)"
Write-Host "Sub-issues: $($context.subIssues.nodes.Count)"

# Clear cache when needed
Clear-IssueContextCache
```

### PR Management

```powershell
# Create a PR linked to an issue
$pr = New-AgentPR `
    -Owner anokye-labs `
    -Repo plugins `
    -Title "Implement shared agent runner" `
    -Body "This PR implements the shared agent runner module" `
    -IssueNumber 14

# Get PR status
$status = Get-PRStatus -Owner anokye-labs -Repo plugins -PullNumber 42
Write-Host "PR state: $($status.state)"
Write-Host "Mergeable: $($status.mergeable)"
Write-Host "Review decision: $($status.reviewDecision)"

# Add review comment
Add-PRReviewComment `
    -Owner anokye-labs `
    -Repo plugins `
    -PullNumber 42 `
    -Body "LGTM! ✓" `
    -Event APPROVE
```

### Safe Output Processing

```powershell
# Sanitize output (removes secrets and PII)
$agentOutput = "My token is ghp_1234567890 and email is user@example.com"
$safe = ConvertTo-SafeOutput $agentOutput
# Output: "My token is [REDACTED] and email is [REDACTED]"

# Truncate long output
$longText = "..." # 5000 characters
$short = Limit-OutputLength $longText -MaxLength 500

# Format as GitHub markdown
$code = "Get-Process | Where-Object CPU -gt 50"
$formatted = ConvertTo-GitHubMarkdown $code -Format CodeBlock -Language powershell
```

### Correlation Tracking

```powershell
# Generate correlation ID
$cid = New-CorrelationId -Prefix "asafo"

# Store for session
Set-CorrelationId -CorrelationId $cid

# Retrieve current correlation ID
$currentCid = Get-CorrelationId

# Use in logging
Write-AgentLog "Action completed" -CorrelationId $currentCid
```

## Function Reference

### Logging Functions

| Function | Description |
|----------|-------------|
| `Write-AgentLog` | Writes structured log entry with timestamp, level, agent, correlation ID |

### Error Handling Functions

| Function | Description |
|----------|-------------|
| `Invoke-WithRetry` | Executes script block with retry logic and exponential backoff |
| `New-AgentError` | Creates standardized error object for graceful failure handling |

### Issue Context Functions

| Function | Description |
|----------|-------------|
| `Get-IssueContext` | Loads issue details including parent, sub-issues, labels, project items |
| `Clear-IssueContextCache` | Clears cached issue contexts from current session |

### PR Management Functions

| Function | Description |
|----------|-------------|
| `New-AgentPR` | Creates pull request from current branch with issue linkage |
| `Get-PRStatus` | Gets PR status including checks, reviews, and mergeable state |
| `Add-PRReviewComment` | Posts structured review comment on a pull request |

### Safe Output Processing Functions

| Function | Description |
|----------|-------------|
| `ConvertTo-SafeOutput` | Sanitizes text by removing secrets and PII patterns |
| `Limit-OutputLength` | Truncates text to maximum length with ellipsis |
| `ConvertTo-GitHubMarkdown` | Formats text for GitHub comment markdown |

### Correlation Tracking Functions

| Function | Description |
|----------|-------------|
| `New-CorrelationId` | Generates unique correlation ID for tracking agent actions |
| `Set-CorrelationId` | Stores correlation ID for current session |
| `Get-CorrelationId` | Retrieves current session correlation ID |

## Requirements

- PowerShell 7.0+
- GitHub CLI (`gh`) configured with authentication
- GraphQL API access to GitHub repositories

## Design Principles

- **Pipeline-friendly** — All functions support pipeline input where appropriate
- **Session caching** — Issue contexts cached within session to minimize API calls
- **Graceful failure** — Structured error objects instead of throwing exceptions where appropriate
- **GitHub Actions aware** — Automatically adds annotations for warnings and errors
- **GraphQL-first** — All GitHub operations use GraphQL API for consistency

## Related Issues

- anokye-labs/akwaaba#202-#214 (Shared Agent Runner Module)
- anokye-labs/plugins#13 (Write-OkyeremaLog) — Logging component
- anokye-labs/plugins#4 (Foundation layer) — Uses Invoke-GraphQL and Get-RepoContext

## License

MIT License - See LICENSE file for details
