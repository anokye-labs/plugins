<#
.SYNOPSIS
    Orchestrate review-classify-fix-commit-push-reply-resolve cycle for PR completion.

.DESCRIPTION
    Automates the PR completion workflow:
    1. Fetch unresolved review threads
    2. Classify threads by severity using Get-ThreadSeverity.ps1
    3. Generate fixes for review comments (integration point)
    4. Commit and push changes
    5. Reply to review threads with fix details
    6. Resolve threads
    
    Supports dry-run mode to preview actions without making changes.
    Supports max iterations to limit the number of completion cycles.

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER PullNumber
    Pull request number.

.PARAMETER Branch
    Branch name to work on. Defaults to current branch.

.PARAMETER DryRun
    If set, shows what would be done without making any changes.

.PARAMETER MaxIterations
    Maximum number of fix-push-reply cycles. Defaults to 3.

.PARAMETER AutoResolve
    If set, automatically resolves threads after replying. Otherwise prompts.

.PARAMETER MinSeverity
    Minimum severity level to process (Critical, High, Medium, Low, Info). Defaults to Low.

.PARAMETER ScriptRoot
    Root directory for okyerema scripts. Defaults to script's parent directory.

.EXAMPLE
    .\Invoke-PRCompletion.ps1 -Owner anokye-labs -Repo plugins -PullNumber 6
    
    Runs the completion loop for PR #6.

.EXAMPLE
    .\Invoke-PRCompletion.ps1 -Owner anokye-labs -Repo plugins -PullNumber 6 -DryRun
    
    Shows what would be done without making changes.

.EXAMPLE
    .\Invoke-PRCompletion.ps1 -Owner anokye-labs -Repo plugins -PullNumber 6 -MaxIterations 1 -AutoResolve -MinSeverity High
    
    Runs one iteration, auto-resolves threads, processes only High and Critical severity.
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$PullNumber,
    [string]$Branch,
    [switch]$DryRun,
    [int]$MaxIterations = 3,
    [switch]$AutoResolve,
    [ValidateSet("Critical", "High", "Medium", "Low", "Info")]
    [string]$MinSeverity = "Low",
    [string]$ScriptRoot = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

# Severity priority for filtering
$severityPriority = @{
    "Critical" = 5
    "High" = 4
    "Medium" = 3
    "Low" = 2
    "Info" = 1
}

$minPriority = $severityPriority[$MinSeverity]

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       PR Completion Loop - Review Fix Push Orchestration       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Repository: $Owner/$Repo" -ForegroundColor White
Write-Host "Pull Request: #$PullNumber" -ForegroundColor White
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Green' })
Write-Host "Max Iterations: $MaxIterations" -ForegroundColor Gray
Write-Host "Min Severity: $MinSeverity" -ForegroundColor Gray
Write-Host "Auto Resolve: $(if ($AutoResolve) { 'Yes' } else { 'No' })" -ForegroundColor Gray
Write-Host ""

# Determine branch
if (-not $Branch) {
    $Branch = git rev-parse --abbrev-ref HEAD
    Write-Host "Using current branch: $Branch" -ForegroundColor Cyan
}

# Verify we're on the right branch
$currentBranch = git rev-parse --abbrev-ref HEAD
if ($currentBranch -ne $Branch) {
    Write-Error "Current branch '$currentBranch' does not match specified branch '$Branch'"
    exit 1
}

# Check for uncommitted changes
$gitStatus = git status --porcelain
if ($gitStatus) {
    Write-Warning "Working directory has uncommitted changes:"
    Write-Host $gitStatus -ForegroundColor Yellow
    if (-not $DryRun) {
        $response = Read-Host "Continue anyway? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "Aborted." -ForegroundColor Red
            exit 1
        }
    }
}

# Script paths
$getSeverityScript = Join-Path $ScriptRoot "Get-ThreadSeverity.ps1"
$getThreadsScript = Join-Path $ScriptRoot "Get-UnresolvedThreads.ps1"
$replyThreadScript = Join-Path $ScriptRoot "Reply-ReviewThread.ps1"
$resolveThreadsScript = Join-Path $ScriptRoot "Resolve-ReviewThreads.ps1"

# Verify scripts exist
$requiredScripts = @($getSeverityScript, $getThreadsScript, $replyThreadScript, $resolveThreadsScript)
foreach ($script in $requiredScripts) {
    if (-not (Test-Path $script)) {
        Write-Error "Required script not found: $script"
        exit 1
    }
}

# Main loop
$iteration = 0
$totalThreadsProcessed = 0
$totalThreadsResolved = 0

while ($iteration -lt $MaxIterations) {
    $iteration++
    
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "ITERATION $iteration of $MaxIterations" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""
    
    # Step 1: Fetch unresolved threads
    Write-Host "[1/6] Fetching unresolved review threads..." -ForegroundColor White
    $threads = & $getThreadsScript -Owner $Owner -Repo $Repo -PullNumber $PullNumber 2>&1 | 
        Where-Object { $_ -is [PSCustomObject] }
    
    if (-not $threads -or $threads.Count -eq 0) {
        Write-Host "✓ No unresolved threads remaining." -ForegroundColor Green
        Write-Host ""
        break
    }
    
    Write-Host "  Found $($threads.Count) unresolved thread(s)" -ForegroundColor Gray
    Write-Host ""
    
    # Step 2: Classify threads by severity
    Write-Host "[2/6] Classifying threads by severity..." -ForegroundColor White
    $severityResults = & $getSeverityScript -Owner $Owner -Repo $Repo -PullNumber $PullNumber 2>&1 |
        Where-Object { $_ -is [PSCustomObject] }
    
    if (-not $severityResults) {
        Write-Warning "Failed to classify threads. Skipping iteration."
        break
    }
    
    # Filter by minimum severity
    $threadsToProcess = $severityResults | Where-Object { 
        $severityPriority[$_.Severity] -ge $minPriority 
    }
    
    if (-not $threadsToProcess -or $threadsToProcess.Count -eq 0) {
        Write-Host "✓ No threads meet minimum severity threshold ($MinSeverity)." -ForegroundColor Green
        Write-Host ""
        break
    }
    
    Write-Host "  Processing $($threadsToProcess.Count) thread(s) (>= $MinSeverity severity)" -ForegroundColor Gray
    foreach ($t in $threadsToProcess) {
        $color = switch ($t.Severity) {
            "Critical" { "Red" }
            "High" { "Magenta" }
            "Medium" { "Yellow" }
            "Low" { "Blue" }
            "Info" { "Cyan" }
        }
        Write-Host "    - [$($t.Severity)] $($t.Path):$($t.Line)" -ForegroundColor $color
    }
    Write-Host ""
    
    # Step 3: Generate fixes (integration point)
    Write-Host "[3/6] Generating fixes..." -ForegroundColor White
    Write-Host "  ⚠ Fix generation integration point - currently a placeholder" -ForegroundColor Yellow
    Write-Host "  This is where an AI coding agent or manual fix process would be invoked" -ForegroundColor Gray
    Write-Host "  Integration options:" -ForegroundColor Gray
    Write-Host "    - Call @copilot agent via GitHub API" -ForegroundColor Gray
    Write-Host "    - Invoke language-specific linters/fixers" -ForegroundColor Gray
    Write-Host "    - Run automated refactoring tools" -ForegroundColor Gray
    Write-Host "    - Pause for manual fixes" -ForegroundColor Gray
    Write-Host ""
    
    if ($DryRun) {
        Write-Host "  [DRY RUN] Would generate fixes for $($threadsToProcess.Count) thread(s)" -ForegroundColor Yellow
    } else {
        Write-Host "  ⏸ Pausing for manual fixes..." -ForegroundColor Yellow
        Write-Host "  Please review the threads above and make necessary code changes." -ForegroundColor Gray
        Write-Host "  Press Enter when fixes are ready to commit..." -ForegroundColor Gray
        Read-Host
    }
    Write-Host ""
    
    # Step 4: Commit and push changes
    Write-Host "[4/6] Committing and pushing changes..." -ForegroundColor White
    
    $gitStatus = git status --porcelain
    if (-not $gitStatus) {
        Write-Host "  No changes to commit." -ForegroundColor Yellow
        Write-Host ""
    } else {
        $commitMessage = "Address review comments (iteration $iteration)"
        $commitDetails = @"
Address $($threadsToProcess.Count) review thread(s):

$($threadsToProcess | ForEach-Object { "- [$($_.Severity)] $($_.Path):$($_.Line)" } | Out-String)

Iteration $iteration of $MaxIterations
"@
        
        if ($DryRun) {
            Write-Host "  [DRY RUN] Would commit with message:" -ForegroundColor Yellow
            Write-Host "    $commitMessage" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  [DRY RUN] Would push to $Branch" -ForegroundColor Yellow
        } else {
            git add .
            git commit -m $commitMessage -m $commitDetails
            $commitSha = git rev-parse --short HEAD
            Write-Host "  ✓ Committed: $commitSha" -ForegroundColor Green
            
            git push origin $Branch
            Write-Host "  ✓ Pushed to $Branch" -ForegroundColor Green
        }
    }
    Write-Host ""
    
    # Step 5: Reply to threads
    Write-Host "[5/6] Replying to review threads..." -ForegroundColor White
    
    foreach ($thread in $threadsToProcess) {
        $replyBody = @"
Fixed in iteration $iteration. Changes committed.

**Severity**: $($thread.Severity) ($($thread.Confidence) confidence)
**Reason**: $($thread.Reason)

Please review the changes.
"@
        
        if ($DryRun) {
            Write-Host "  [DRY RUN] Would reply to thread $($thread.ThreadId)" -ForegroundColor Yellow
            Write-Host "    Preview: Fixed in iteration $iteration..." -ForegroundColor Gray
        } else {
            try {
                & $replyThreadScript -Owner $Owner -Repo $Repo -PullNumber $PullNumber `
                    -ThreadId $thread.ThreadId -Body $replyBody | Out-Null
                Write-Host "  ✓ Replied to $($thread.Path):$($thread.Line)" -ForegroundColor Green
            } catch {
                Write-Warning "Failed to reply to thread $($thread.ThreadId): $_"
            }
        }
        
        $totalThreadsProcessed++
    }
    Write-Host ""
    
    # Step 6: Resolve threads
    Write-Host "[6/6] Resolving threads..." -ForegroundColor White
    
    if ($AutoResolve) {
        $shouldResolve = $true
        Write-Host "  Auto-resolve enabled" -ForegroundColor Cyan
    } elseif ($DryRun) {
        $shouldResolve = $false
        Write-Host "  [DRY RUN] Would prompt for resolution" -ForegroundColor Yellow
    } else {
        Write-Host "  Resolve $($threadsToProcess.Count) thread(s)?" -ForegroundColor Cyan
        $response = Read-Host "  (y/N)"
        $shouldResolve = ($response -eq 'y' -or $response -eq 'Y')
    }
    
    if ($shouldResolve) {
        $threadIds = $threadsToProcess | ForEach-Object { $_.ThreadId }
        
        if ($DryRun) {
            Write-Host "  [DRY RUN] Would resolve $($threadIds.Count) thread(s)" -ForegroundColor Yellow
        } else {
            try {
                & $resolveThreadsScript -Owner $Owner -Repo $Repo -PullNumber $PullNumber `
                    -ThreadIds $threadIds | Out-Null
                Write-Host "  ✓ Resolved $($threadIds.Count) thread(s)" -ForegroundColor Green
                $totalThreadsResolved += $threadIds.Count
            } catch {
                Write-Warning "Failed to resolve threads: $_"
            }
        }
    } else {
        Write-Host "  Skipped resolution" -ForegroundColor Yellow
    }
    Write-Host ""
    
    # Check if we should continue
    if ($iteration -lt $MaxIterations) {
        Write-Host "Checking for remaining threads..." -ForegroundColor Gray
        Start-Sleep -Seconds 2
    }
}

# Summary
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                         Summary                                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Iterations completed: $iteration" -ForegroundColor White
Write-Host "Threads processed: $totalThreadsProcessed" -ForegroundColor White
Write-Host "Threads resolved: $totalThreadsResolved" -ForegroundColor White
Write-Host ""

if ($DryRun) {
    Write-Host "This was a DRY RUN - no changes were made" -ForegroundColor Yellow
} else {
    Write-Host "PR completion loop finished" -ForegroundColor Green
}

Write-Host ""
