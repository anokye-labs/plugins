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

    $query = @"
query {
  repository(owner: "$Owner", name: "$Repo") {
    branchProtectionRules(first: 10) {
      nodes {
        id
        pattern
        requiresStatusChecks
        requiredStatusChecks {
          contexts
        }
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
            RequiredStatusChecks = $existingRule.requiredStatusChecks.contexts
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

    if ($RuleId) {
        # Update existing rule
        # Note: gh CLI accepts '-f query=' for both queries and mutations
        $graphqlMutation = @"
mutation {
  updateBranchProtectionRule(input: {
    branchProtectionRuleId: "$RuleId"
    requiresStatusChecks: true
    requiredStatusCheckContexts: $(ConvertTo-JsonArray $RequiredStatusChecks)
    requiresStrictStatusChecks: false
  }) {
    branchProtectionRule {
      id
      pattern
      requiredStatusChecks {
        contexts
      }
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
    repositoryId: "$RepoId"
    pattern: "$Branch"
    requiresStatusChecks: true
    requiredStatusCheckContexts: $(ConvertTo-JsonArray $RequiredStatusChecks)
    requiresStrictStatusChecks: false
  }) {
    branchProtectionRule {
      id
      pattern
      requiredStatusChecks {
        contexts
      }
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

function ConvertTo-JsonArray {
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
# The job ID in the workflow is "validate" (display name is "Static Validation")
# GitHub status checks use the job ID, not the display name
$requiredChecks = @("validate")

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
        Write-Host "  Required status checks:"
        foreach ($check in $requiredChecks) {
            Write-Host "    ✓ $check"
        }
        Write-Host ""
        Write-ColorOutput "PRs targeting $Branch now require the validation workflow to pass before merging." -Color Cyan
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
