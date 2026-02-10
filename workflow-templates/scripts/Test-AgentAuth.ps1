#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates that commits in a PR are from approved agents (GitHub Apps) or authorized users.

.DESCRIPTION
    This script checks all commits in a Pull Request to ensure they come from:
    - Approved GitHub Apps (e.g., Copilot, Dependabot)
    - Users with explicit human override authorization
    
    It supports:
    - Configurable allowlist of GitHub Apps
    - Human override mechanism via commit message flag
    - Audit logging for all authentication attempts
    - Dry run mode for testing

.PARAMETER Owner
    The repository owner (organization or user).

.PARAMETER Repo
    The repository name.

.PARAMETER PRNumber
    The pull request number to validate.

.PARAMETER BaseRef
    The base branch reference (e.g., 'main').

.PARAMETER AllowedAgents
    Array of allowed GitHub App names. Defaults to common Copilot agents.

.PARAMETER AllowHumanOverride
    If specified, allows human commits with [human-override] flag in commit message.

.PARAMETER DryRun
    If specified, shows validation results without failing.

.EXAMPLE
    Test-AgentAuth -Owner "anokye-labs" -Repo "plugins" -PRNumber 42 -BaseRef "main"

.EXAMPLE
    Test-AgentAuth -Owner "myorg" -Repo "myrepo" -PRNumber 10 -BaseRef "main" -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Owner,

    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [Parameter(Mandatory = $true)]
    [int]$PRNumber,

    [Parameter(Mandatory = $true)]
    [string]$BaseRef,

    [Parameter()]
    [string[]]$AllowedAgents = @(
        "copilot-swe-agent",
        "github-actions",
        "dependabot",
        "renovate"
    ),

    [Parameter()]
    [switch]$AllowHumanOverride,

    [Parameter()]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ANSI color codes
$script:Colors = @{
    Reset   = "`e[0m"
    Red     = "`e[31m"
    Green   = "`e[32m"
    Yellow  = "`e[33m"
    Blue    = "`e[34m"
    Cyan    = "`e[36m"
    White   = "`e[37m"
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

function Test-IsGitHubApp {
    param(
        [string]$Email,
        [string]$Author
    )
    
    # GitHub Apps typically have email patterns like:
    # - <id>+<app-name>[bot]@users.noreply.github.com
    # - <app-name>[bot]@users.noreply.github.com
    # - github-actions[bot]@users.noreply.github.com
    
    if ($Email -match '(\d+\+)?([a-zA-Z0-9-]+)\[bot\]@users\.noreply\.github\.com') {
        return @{
            IsApp = $true
            AppName = $matches[2]
        }
    }
    
    # Also check author name for [bot] suffix
    if ($Author -match '^(.+)\[bot\]$') {
        return @{
            IsApp = $true
            AppName = $matches[1]
        }
    }
    
    return @{
        IsApp = $false
        AppName = $null
    }
}

function Test-AgentAuth {
    Write-Header "AGENT AUTHENTICATION VALIDATOR"
    
    if ($DryRun) {
        Write-ColorOutput "▶ DRY RUN MODE - No failures will be reported`n" -Color Yellow
    }
    
    Write-ColorOutput "▶ Configuration:" -Color Blue
    Write-Host "  Repository: $Owner/$Repo"
    Write-Host "  PR Number: #$PRNumber"
    Write-Host "  Base Ref: $BaseRef"
    Write-Host "  Allowed Agents: $($AllowedAgents -join ', ')"
    Write-Host "  Human Override: $AllowHumanOverride"
    Write-Host ""
    
    # Fetch commits in PR
    Write-ColorOutput "▶ Fetching commits in PR #${PRNumber}..." -Color Blue
    git fetch origin $BaseRef 2>&1 | Out-Null
    $commits = git log --format="%H|%s|%an|%ae" origin/${BaseRef}..HEAD
    
    if (-not $commits) {
        Write-ColorOutput "  ✓ No commits to validate`n" -Color Green
        return 0
    }
    
    $commitList = $commits -split "`n" | Where-Object { $_ }
    Write-Host "  Found $($commitList.Count) commit(s) to validate`n"
    
    # Validation tracking
    $violations = @()
    $approvedCommits = @()
    $auditLog = @()
    
    foreach ($commitLine in $commitList) {
        $parts = $commitLine -split '\|'
        $hash = $parts[0]
        $message = $parts[1]
        $author = $parts[2]
        $email = $parts[3]
        
        $shortHash = $hash.Substring(0, 7)
        Write-ColorOutput "  Validating $shortHash - $message" -Color White
        
        # Test if this is a GitHub App
        $appTest = Test-IsGitHubApp -Email $email -Author $author
        
        $auditEntry = @{
            Commit = $shortHash
            Message = $message
            Author = $author
            Email = $email
            IsApp = $appTest.IsApp
            AppName = $appTest.AppName
            Timestamp = Get-Date -Format 'o'
        }
        
        if ($appTest.IsApp) {
            $appName = $appTest.AppName
            if ($AllowedAgents -contains $appName) {
                Write-ColorOutput "    ✓ Approved agent: $appName" -Color Green
                $auditEntry.Status = "APPROVED"
                $auditEntry.Reason = "Approved agent: $appName"
                $approvedCommits += $shortHash
            } else {
                Write-ColorOutput "    ✗ Unauthorized agent: $appName" -Color Red
                $auditEntry.Status = "REJECTED"
                $auditEntry.Reason = "Agent '$appName' not in allowlist"
                $violations += @{
                    Commit = $shortHash
                    Message = $message
                    Author = $author
                    Email = $email
                    Error = "Unauthorized agent: $appName. Allowed agents: $($AllowedAgents -join ', ')"
                }
            }
        } else {
            # Human commit - check for override
            $hasOverride = $message -match '\[human-override\]'
            
            if ($hasOverride -and $AllowHumanOverride) {
                Write-ColorOutput "    ✓ Human override authorized" -Color Green
                $auditEntry.Status = "APPROVED"
                $auditEntry.Reason = "Human override flag present"
                $approvedCommits += $shortHash
            } else {
                if ($AllowHumanOverride) {
                    Write-ColorOutput "    ✗ Human commit without override flag" -Color Red
                    $error = "Human commit requires [human-override] flag in message"
                } else {
                    Write-ColorOutput "    ✗ Human commit not allowed" -Color Red
                    $error = "Only approved agents can commit to this repository"
                }
                
                $auditEntry.Status = "REJECTED"
                $auditEntry.Reason = $error
                $violations += @{
                    Commit = $shortHash
                    Message = $message
                    Author = $author
                    Email = $email
                    Error = $error
                }
            }
        }
        
        $auditLog += $auditEntry
        Write-Host ""
    }
    
    # Write audit log
    $auditLogPath = Join-Path $PWD "agent-auth-audit.json"
    $auditLog | ConvertTo-Json -Depth 10 | Out-File -FilePath $auditLogPath -Encoding utf8
    Write-ColorOutput "▶ Audit log written to: $auditLogPath`n" -Color Blue
    
    # Summary
    Write-Header "VALIDATION RESULTS"
    
    Write-Host "  Total commits: $($commitList.Count)"
    Write-Host "  Approved: $($approvedCommits.Count)"
    Write-Host "  Rejected: $($violations.Count)"
    Write-Host ""
    
    if ($violations.Count -eq 0) {
        Write-ColorOutput "✅ All commits authenticated successfully!`n" -Color Green
        return 0
    } else {
        Write-ColorOutput "❌ Authentication failed with $($violations.Count) violation(s):`n" -Color Red
        
        foreach ($v in $violations) {
            Write-ColorOutput "  Commit: $($v.Commit)" -Color Red
            Write-Host "  Message: $($v.Message)"
            Write-Host "  Author: $($v.Author) <$($v.Email)>"
            Write-ColorOutput "  Error: $($v.Error)" -Color Red
            Write-Host ""
        }
        
        Write-ColorOutput "REQUIREMENTS:" -Color Yellow
        Write-Host "Commits must be from one of these approved agents:"
        foreach ($agent in $AllowedAgents) {
            Write-Host "  - $agent"
        }
        
        if ($AllowHumanOverride) {
            Write-Host "`nHuman commits are allowed with [human-override] flag in message"
        } else {
            Write-Host "`nHuman commits are not allowed in this repository"
        }
        Write-Host ""
        
        if ($DryRun) {
            Write-ColorOutput "DRY RUN MODE: Violations detected but not failing`n" -Color Yellow
            return 0
        } else {
            return 1
        }
    }
}

# Execute validation
$exitCode = Test-AgentAuth
exit $exitCode
