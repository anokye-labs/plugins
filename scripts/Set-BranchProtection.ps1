#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configures branch protection rules with required status checks for the repository.

.DESCRIPTION
    This script sets up branch protection rules on the main branch to require the
    "Static Validation" status check from the validate-plugin.yml workflow to pass
    before PRs can be merged.

.PARAMETER Owner
    The repository owner (organization or user). Defaults to "anokye-labs".

.PARAMETER Repo
    The repository name. Defaults to "plugins".

.PARAMETER Branch
    The branch to protect. Defaults to "main".

.PARAMETER DryRun
    If specified, shows what would be done without making any changes.

.EXAMPLE
    ./Set-BranchProtection.ps1
    Configures branch protection on anokye-labs/plugins main branch.

.EXAMPLE
    ./Set-BranchProtection.ps1 -DryRun
    Shows what would be configured without making changes.

.EXAMPLE
    ./Set-BranchProtection.ps1 -Owner myorg -Repo myrepo -Branch develop
    Configures branch protection on a different repository and branch.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Owner = "anokye-labs",

    [Parameter()]
    [string]$Repo = "plugins",

    [Parameter()]
    [string]$Branch = "main",

    [Parameter()]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ANSI color codes for output
$script:Colors = @{
    Reset   = "`e[0m"
    Red     = "`e[31m"
    Green   = "`e[32m"
    Yellow  = "`e[33m"
    Blue    = "`e[34m"
    Cyan    = "`e[36m"
    Bold    = "`e[1m"
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "Reset"
    )
    $colorCode = $script:Colors[$Color]
    $resetCode = $script:Colors["Reset"]
    Write-Host "${colorCode}${Message}${resetCode}"
}

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-ColorOutput "═══════════════════════════════════════" -Color Cyan
    Write-ColorOutput "  $Text" -Color Cyan
    Write-ColorOutput "═══════════════════════════════════════" -Color Cyan
    Write-Host ""
}

function Test-GitHubCLI {
    try {
        $null = & gh --version 2>&1
        return $true
    }
    catch {
        return $false
    }
}

function Test-GitHubAuth {
    try {
        $result = & gh auth status 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Get-BranchProtectionId {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Branch
    )

    # Escape backslashes and double quotes to prevent GraphQL injection
    # Backslashes must be escaped first to avoid double-escaping
    $escapedOwner = $Owner.Replace('\', '\\').Replace('"', '\"')
    $escapedRepo = $Repo.Replace('\', '\\').Replace('"', '\"')
    $escapedBranch = $Branch.Replace('\', '\\').Replace('"', '\"')

    $query = @"
query {
  repository(owner: "$escapedOwner", name: "$escapedRepo") {
    branchProtectionRules(first: 10) {
      nodes {
        id
        pattern
        requiresStatusChecks
        requiredStatusCheckContexts
      }
    }
    id
  }
}
"@

    try {
        $response = & gh api graphql -f query="$query" | ConvertFrom-Json
        
        $repoId = $response.data.repository.id
        $existingRule = $response.data.repository.branchProtectionRules.nodes | 
            Where-Object { $_.pattern -eq $Branch }
        
        return @{
            RepoId = $repoId
            RuleId = $existingRule.id
            Pattern = $existingRule.pattern
            RequiresStatusChecks = $existingRule.requiresStatusChecks
            RequiredStatusChecks = $existingRule.requiredStatusCheckContexts
        }
    }
    catch {
        Write-ColorOutput "❌ Failed to query branch protection rules: $_" -Color Red
        throw
    }
}

function Set-BranchProtectionRule {
    param(
        [string]$RepoId,
        [string]$RuleId,
        [string]$Branch,
        [string[]]$RequiredStatusChecks
    )

    # Escape backslashes and double quotes to prevent GraphQL injection
    # Backslashes must be escaped first to avoid double-escaping
    $escapedRepoId = $RepoId.Replace('\', '\\').Replace('"', '\"')
    $escapedRuleId = $RuleId.Replace('\', '\\').Replace('"', '\"')
    $escapedBranch = $Branch.Replace('\', '\\').Replace('"', '\"')

    if ($RuleId) {
        # Update existing rule
        # Note: gh CLI accepts '-f query=' for both queries and mutations
        $graphqlMutation = @"
mutation {
  updateBranchProtectionRule(input: {
    branchProtectionRuleId: "$escapedRuleId"
    requiresStatusChecks: true
    requiredStatusCheckContexts: $(ConvertTo-JsonArray $RequiredStatusChecks)
    requiresStrictStatusChecks: false
    isAdminEnforced: true
  }) {
    branchProtectionRule {
      id
      pattern
      requiredStatusCheckContexts
      isAdminEnforced
    }
  }
}
"@
    }
    else {
        # Create new rule
        # Note: gh CLI accepts '-f query=' for both queries and mutations
        $graphqlMutation = @"
mutation {
  createBranchProtectionRule(input: {
    repositoryId: "$escapedRepoId"
    pattern: "$escapedBranch"
    requiresStatusChecks: true
    requiredStatusCheckContexts: $(ConvertTo-JsonArray $RequiredStatusChecks)
    requiresStrictStatusChecks: false
    isAdminEnforced: true
  }) {
    branchProtectionRule {
      id
      pattern
      requiredStatusCheckContexts
      isAdminEnforced
    }
  }
}
"@
    }

    try {
        $response = & gh api graphql -f query="$graphqlMutation" | ConvertFrom-Json
        return $response.data
    }
    catch {
        Write-ColorOutput "❌ Failed to set branch protection rule: $_" -Color Red
        throw
    }
}

function Set-MergeQueueRuleset {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Branch
    )

    $rulesetName = "Merge queue for $Branch"
    $existing = & gh api /repos/$Owner/$Repo/rulesets | ConvertFrom-Json |
        Where-Object { $_.name -eq $rulesetName } | Select-Object -First 1

    $payload = @{
        name        = $rulesetName
        target      = "branch"
        enforcement = "active"
        conditions  = @{
            ref_name = @{
                include = @("refs/heads/$Branch")
                exclude = @()
            }
        }
        rules = @(
            @{
                type = "merge_queue"
                parameters = @{
                    check_response_timeout_minutes    = 60
                    grouping_strategy                 = "ALLGREEN"
                    max_entries_to_build              = 5
                    max_entries_to_merge              = 5
                    merge_method                      = "MERGE"
                    min_entries_to_merge              = 1
                    min_entries_to_merge_wait_minutes = 0
                }
            }
        )
    } | ConvertTo-Json -Depth 10

    try {
        if ($existing) {
            $response = $payload | & gh api /repos/$Owner/$Repo/rulesets/$($existing.id) --method PUT --input - | ConvertFrom-Json
        } else {
            $response = $payload | & gh api /repos/$Owner/$Repo/rulesets --method POST --input - | ConvertFrom-Json
        }
        return $response
    }
    catch {
        Write-ColorOutput "❌ Failed to configure merge queue ruleset: $_" -Color Red
        throw
    }
}


    param([string[]]$Array)
    
    if (-not $Array -or $Array.Count -eq 0) {
        return "[]"
    }
    
    $quoted = $Array | ForEach-Object { "`"$_`"" }
    return "[" + ($quoted -join ", ") + "]"
}

# ============================================================================
# Main Script
# ============================================================================

Write-Header "Branch Protection Configuration"

# Validate prerequisites
Write-ColorOutput "▶ Checking prerequisites..." -Color Blue

if (-not (Test-GitHubCLI)) {
    Write-ColorOutput "❌ GitHub CLI (gh) is not installed or not in PATH" -Color Red
    Write-ColorOutput "   Install from: https://cli.github.com/" -Color Yellow
    exit 1
}
Write-ColorOutput "  ✓ GitHub CLI installed" -Color Green

if (-not (Test-GitHubAuth)) {
    Write-ColorOutput "❌ Not authenticated with GitHub CLI" -Color Red
    Write-ColorOutput "   Run: gh auth login" -Color Yellow
    exit 1
}
Write-ColorOutput "  ✓ GitHub CLI authenticated" -Color Green

# Get current branch protection status
Write-Host ""
Write-ColorOutput "▶ Checking current branch protection on $Owner/$Repo ($Branch)..." -Color Blue

$protection = Get-BranchProtectionId -Owner $Owner -Repo $Repo -Branch $Branch

if ($protection.RuleId) {
    Write-ColorOutput "  ✓ Branch protection rule exists" -Color Green
    Write-Host "    Current required status checks:"
    if ($protection.RequiredStatusChecks) {
        foreach ($check in $protection.RequiredStatusChecks) {
            Write-Host "      - $check"
        }
    }
    else {
        Write-Host "      (none)"
    }
}
else {
    Write-ColorOutput "  ℹ No branch protection rule exists" -Color Yellow
}

# Define required status checks
# GitHub matches these contexts against the job DISPLAY NAME (the `name:` field in the workflow),
# not the job ID. Use the display name exactly as it appears in the workflow file.
#   "Static Validation"  — validate-plugin.yml (job: validate, name: Static Validation)
#   "Check Linked Issue" — require-linked-issue.yml (job: check-linked-issue, name: Check Linked Issue)
$requiredChecks = @("Static Validation", "Check Linked Issue")

Write-Host ""
Write-ColorOutput "▶ Required status checks to configure:" -Color Blue
foreach ($check in $requiredChecks) {
    Write-Host "    - $check"
}

# Apply configuration
Write-Host ""
if ($DryRun) {
    Write-ColorOutput "▶ DRY RUN MODE - No changes will be made" -Color Yellow
    Write-Host ""
    Write-ColorOutput "Would configure:" -Color Cyan
    Write-Host "  Repository: $Owner/$Repo"
    Write-Host "  Branch: $Branch"
    Write-Host "  Admin enforcement: enabled"
    Write-Host "  Required status checks:"
    foreach ($check in $requiredChecks) {
        Write-Host "    - $check"
    }
    Write-Host ""
    Write-ColorOutput "✓ Dry run complete" -Color Green
}
else {
    Write-ColorOutput "▶ Configuring branch protection..." -Color Blue
    
    try {
        $result = Set-BranchProtectionRule `
            -RepoId $protection.RepoId `
            -RuleId $protection.RuleId `
            -Branch $Branch `
            -RequiredStatusChecks $requiredChecks
        
        Write-Host ""
        Write-ColorOutput "✅ Branch protection configured successfully!" -Color Green
        Write-Host ""
        Write-Host "  Repository: $Owner/$Repo"
        Write-Host "  Branch: $Branch"
        Write-Host "  Admin enforcement: enabled"
        Write-Host "  Required status checks:"
        foreach ($check in $requiredChecks) {
            Write-Host "    ✓ $check"
        }
        Write-Host ""
        Write-ColorOutput "PRs targeting $Branch now require the validation workflow to pass before merging." -Color Cyan

        # Configure merge queue ruleset
        Write-Host ""
        Write-ColorOutput "▶ Configuring merge queue ruleset..." -Color Blue
        $mqResult = Set-MergeQueueRuleset -Owner $Owner -Repo $Repo -Branch $Branch
        Write-ColorOutput "  ✓ Merge queue ruleset: $($mqResult.name) (id=$($mqResult.id))" -Color Green
    }
    catch {
        Write-Host ""
        Write-ColorOutput "❌ Failed to configure branch protection" -Color Red
        Write-Host ""
        Write-Host "Error: $_"
        exit 1
    }
}

Write-Host ""
Write-ColorOutput "═══════════════════════════════════════" -Color Cyan
Write-Host ""
