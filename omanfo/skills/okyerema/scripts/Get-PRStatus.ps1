<#
.SYNOPSIS
    Comprehensive PR status check (approvals, checks, merge readiness).

.DESCRIPTION
    Provides a complete status overview of a PR including:
    - Approval status (approved, changes requested, pending)
    - CI check status (success, failure, pending)
    - Merge readiness (mergeable state, conflicts)
    - Review decision summary
    Returns a structured object with all status information.

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER PullNumber
    Pull request number.

.PARAMETER Json
    If set, outputs JSON format instead of formatted text.

.EXAMPLE
    .\Get-PRStatus.ps1 -Owner anokye-labs -Repo plugins -PullNumber 50

.EXAMPLE
    .\Get-PRStatus.ps1 -Owner anokye-labs -Repo plugins -PullNumber 50 -Json
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$PullNumber,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\_Invoke-GraphQL.ps1"

$query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    pullRequest(number: $PullNumber) {
      number
      title
      state
      mergeable
      merged
      closed
      isDraft
      reviewDecision
      baseRefName
      headRefName
      commits(last: 1) {
        nodes {
          commit {
            oid
            statusCheckRollup {
              state
              contexts(first: 100) {
                totalCount
                nodes {
                  ... on CheckRun {
                    name
                    conclusion
                    status
                  }
                  ... on StatusContext {
                    context
                    state
                  }
                }
              }
            }
          }
        }
      }
      reviews(last: 20) {
        totalCount
        nodes {
          author { login }
          state
          submittedAt
        }
      }
      latestReviews(first: 10) {
        nodes {
          author { login }
          state
        }
      }
    }
  }
}
"@

$result = Invoke-GraphQL -Query $query
$pr = $result.data.repository.pullRequest

# Calculate approval status
$latestReviews = @{}
foreach ($review in $pr.latestReviews.nodes) {
    $latestReviews[$review.author.login] = $review.state
}

$approved = ($latestReviews.Values | Where-Object { $_ -eq "APPROVED" }).Count
$changesRequested = ($latestReviews.Values | Where-Object { $_ -eq "CHANGES_REQUESTED" }).Count
$commented = ($latestReviews.Values | Where-Object { $_ -eq "COMMENTED" }).Count

# Check CI status
$ciState = "UNKNOWN"
$checks = @()
if ($pr.commits.nodes.Count -gt 0 -and $pr.commits.nodes[0].commit.statusCheckRollup) {
    $rollup = $pr.commits.nodes[0].commit.statusCheckRollup
    $ciState = $rollup.state
    
    foreach ($context in $rollup.contexts.nodes) {
        if ($context.name) {
            # CheckRun
            $checks += @{
                Name = $context.name
                Status = $context.conclusion ?? $context.status
            }
        } elseif ($context.context) {
            # StatusContext
            $checks += @{
                Name = $context.context
                Status = $context.state
            }
        }
    }
}

# Determine merge readiness
$canMerge = $false
$mergeBlockers = @()

if ($pr.state -eq "CLOSED") {
    $mergeBlockers += "PR is closed"
} elseif ($pr.merged) {
    $mergeBlockers += "PR is already merged"
} elseif ($pr.isDraft) {
    $mergeBlockers += "PR is in draft"
} else {
    if ($pr.mergeable -eq "CONFLICTING") {
        $mergeBlockers += "Has merge conflicts"
    }
    if ($changesRequested -gt 0) {
        $mergeBlockers += "Changes requested by reviewers"
    }
    if ($ciState -eq "FAILURE" -or $ciState -eq "ERROR") {
        $mergeBlockers += "CI checks failing"
    } elseif ($ciState -eq "PENDING" -or $ciState -eq "EXPECTED") {
        $mergeBlockers += "CI checks pending"
    }
    if ($pr.reviewDecision -eq "REVIEW_REQUIRED") {
        $mergeBlockers += "Review required"
    }
    
    $canMerge = $mergeBlockers.Count -eq 0
}

# Build status object
$status = [PSCustomObject]@{
    Number = $pr.number
    Title = $pr.title
    State = $pr.state
    IsDraft = $pr.isDraft
    Merged = $pr.merged
    Mergeable = $pr.mergeable
    ReviewDecision = $pr.reviewDecision
    Approvals = @{
        Approved = $approved
        ChangesRequested = $changesRequested
        Commented = $commented
    }
    CI = @{
        State = $ciState
        Checks = $checks
        TotalChecks = $checks.Count
    }
    MergeReadiness = @{
        CanMerge = $canMerge
        Blockers = $mergeBlockers
    }
    Branches = @{
        Base = $pr.baseRefName
        Head = $pr.headRefName
    }
}

if ($Json) {
    $status | ConvertTo-Json -Depth 10
} else {
    # Format output
    Write-Host "`n━━━ PR #$($pr.number): $($pr.title) ━━━" -ForegroundColor Cyan
    Write-Host "State: " -NoNewline -ForegroundColor Gray
    $stateColor = switch ($pr.state) {
        "OPEN" { "Green" }
        "CLOSED" { "Red" }
        "MERGED" { "Magenta" }
        default { "White" }
    }
    Write-Host $pr.state -ForegroundColor $stateColor
    
    if ($pr.isDraft) {
        Write-Host "Status: DRAFT" -ForegroundColor Yellow
    }
    
    Write-Host "`nBranches: " -ForegroundColor Gray
    Write-Host "  $($pr.headRefName) → $($pr.baseRefName)" -ForegroundColor White
    
    Write-Host "`nReviews: " -ForegroundColor Gray
    Write-Host "  ✓ Approved: $approved" -ForegroundColor $(if ($approved -gt 0) { "Green" } else { "Gray" })
    Write-Host "  ✗ Changes Requested: $changesRequested" -ForegroundColor $(if ($changesRequested -gt 0) { "Red" } else { "Gray" })
    Write-Host "  💬 Commented: $commented" -ForegroundColor $(if ($commented -gt 0) { "Yellow" } else { "Gray" })
    Write-Host "  Decision: $($pr.reviewDecision ?? 'NONE')" -ForegroundColor $(if ($pr.reviewDecision -eq "APPROVED") { "Green" } else { "Yellow" })
    
    Write-Host "`nCI Checks: " -ForegroundColor Gray
    $ciColor = switch ($ciState) {
        "SUCCESS" { "Green" }
        "FAILURE" { "Red" }
        "ERROR" { "Red" }
        "PENDING" { "Yellow" }
        "EXPECTED" { "Yellow" }
        default { "Gray" }
    }
    Write-Host "  State: $ciState ($($checks.Count) checks)" -ForegroundColor $ciColor
    
    Write-Host "`nMerge Readiness: " -ForegroundColor Gray
    if ($canMerge) {
        Write-Host "  ✓ Ready to merge" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Not ready to merge" -ForegroundColor Red
        foreach ($blocker in $mergeBlockers) {
            Write-Host "    - $blocker" -ForegroundColor Yellow
        }
    }
    Write-Host ""
}

# Output object to pipeline
Write-Output $status
