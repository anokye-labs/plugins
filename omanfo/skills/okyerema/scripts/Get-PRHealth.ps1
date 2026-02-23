<#
.SYNOPSIS
    Deep PR health check for the /prcheck command.

.DESCRIPTION
    Queries mergeable state, review threads (resolved/unresolved), CI checks,
    approvals, and commits since last review. Categorizes reviewers as copilot,
    devin, or human. Returns a structured PSCustomObject.

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER PullNumber
    Pull request number.

.PARAMETER Brief
    If set, returns compact one-line summary.

.EXAMPLE
    .\Get-PRHealth.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 12

.EXAMPLE
    .\Get-PRHealth.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 12 -Brief
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$PullNumber,
    [switch]$Brief
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
      baseRefName
      headRefName
      additions
      deletions
      changedFiles
      reviewThreads(first: 100) {
        totalCount
        nodes {
          id
          isResolved
          isOutdated
          isCollapsed
          path
          line
          comments(first: 1) {
            nodes {
              author { login }
              body
            }
          }
        }
      }
      reviews(first: 50) {
        nodes {
          author { login }
          state
          submittedAt
        }
      }
      commits(last: 1) {
        nodes {
          commit {
            oid
            statusCheckRollup {
              state
              contexts(first: 50) {
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
      latestReviews(first: 10) {
        nodes {
          author { login }
          state
          submittedAt
        }
      }
    }
  }
}
"@

$result = Invoke-GraphQL -Query $query

$pr = $result.data.repository.pullRequest
if (-not $pr) {
    Write-Error "PR #$PullNumber not found in $Owner/$Repo"
    return
}

# --- Thread analysis ---

$threads = $pr.reviewThreads.nodes
$totalThreads = $pr.reviewThreads.totalCount
$resolvedThreads = ($threads | Where-Object { $_.isResolved } | Measure-Object).Count
$unresolvedThreads = $totalThreads - $resolvedThreads

$automatedLogins = @('copilot', 'github-actions', 'dependabot', 'devin-ai-integration', 'devin')

$automated = @()
$human = @()
foreach ($t in $threads) {
    $authorLogin = ""
    if ($t.comments.nodes.Count -gt 0 -and $t.comments.nodes[0].author) {
        $authorLogin = $t.comments.nodes[0].author.login.ToLower()
    }

    $isAutomated = $false
    foreach ($bot in $automatedLogins) {
        if ($authorLogin -match $bot) { $isAutomated = $true; break }
    }

    if ($isAutomated) {
        $automated += $t
    } else {
        $human += $t
    }
}

$automatedResolved = ($automated | Where-Object { $_.isResolved } | Measure-Object).Count
$automatedUnresolved = $automated.Count - $automatedResolved
$humanResolved = ($human | Where-Object { $_.isResolved } | Measure-Object).Count
$humanUnresolved = $human.Count - $humanResolved

# --- Checks analysis ---

$checksStatus = "UNKNOWN"
$checksPassed = 0
$checksTotal = 0
$checksFailed = @()

$lastCommit = $pr.commits.nodes | Select-Object -Last 1
if ($lastCommit -and $lastCommit.commit.statusCheckRollup) {
    $rollup = $lastCommit.commit.statusCheckRollup
    $checksStatus = $rollup.state
    $checksTotal = $rollup.contexts.totalCount

    foreach ($ctx in $rollup.contexts.nodes) {
        if ($ctx.conclusion -eq "SUCCESS" -or $ctx.state -eq "SUCCESS") {
            $checksPassed++
        } elseif ($ctx.conclusion -eq "FAILURE" -or $ctx.state -eq "FAILURE") {
            $name = if ($ctx.name) { $ctx.name } else { $ctx.context }
            $checksFailed += $name
        }
    }
}

# --- Approvals ---

$approvals = @()
$changesRequested = @()
if ($pr.latestReviews) {
    foreach ($review in $pr.latestReviews.nodes) {
        if ($review.state -eq "APPROVED") {
            $approvals += $review.author.login
        } elseif ($review.state -eq "CHANGES_REQUESTED") {
            $changesRequested += $review.author.login
        }
    }
}

# --- Recommendation ---

$recommendation = ""
if ($pr.state -ne "OPEN") {
    $recommendation = "PR is $($pr.state.ToLower())"
} elseif ($checksStatus -eq "FAILURE") {
    $recommendation = "Fix failing checks: $($checksFailed -join ', ')"
} elseif ($humanUnresolved -gt 0) {
    $recommendation = "Address $humanUnresolved human review thread(s), then merge"
} elseif ($changesRequested.Count -gt 0) {
    $recommendation = "Changes requested by $($changesRequested -join ', ') — address and re-request review"
} elseif ($automatedUnresolved -gt 0 -and $humanUnresolved -eq 0) {
    $recommendation = "Only automated threads remain ($automatedUnresolved) — resolve or dismiss, then merge"
} elseif ($pr.mergeable -eq "MERGEABLE" -and $unresolvedThreads -eq 0 -and $checksStatus -eq "SUCCESS") {
    $recommendation = "All clear — ready to merge"
} elseif ($pr.mergeable -eq "CONFLICTING") {
    $recommendation = "Resolve merge conflicts first"
} else {
    $recommendation = "Review status and merge when ready"
}

# --- Build result ---

$prHealthReport = [PSCustomObject]@{
    Owner              = $Owner
    Repo               = $Repo
    Number             = $pr.number
    Title              = $pr.title
    State              = $pr.state
    HeadRef            = $pr.headRefName
    BaseRef            = $pr.baseRefName
    Mergeable          = $pr.mergeable
    Additions          = $pr.additions
    Deletions          = $pr.deletions
    ChangedFiles       = $pr.changedFiles
    TotalThreads       = $totalThreads
    ResolvedThreads    = $resolvedThreads
    UnresolvedThreads  = $unresolvedThreads
    AutomatedThreads   = $automated.Count
    AutomatedResolved  = $automatedResolved
    AutomatedUnresolved = $automatedUnresolved
    HumanThreads       = $human.Count
    HumanResolved      = $humanResolved
    HumanUnresolved    = $humanUnresolved
    ChecksStatus       = $checksStatus
    ChecksPassed       = $checksPassed
    ChecksTotal        = $checksTotal
    ChecksFailed       = $checksFailed
    Approvals          = $approvals
    ChangesRequested   = $changesRequested
    Recommendation     = $recommendation
    UnresolvedDetails  = ($threads | Where-Object { -not $_.isResolved } | ForEach-Object {
        $author = if ($_.comments.nodes.Count -gt 0 -and $_.comments.nodes[0].author) {
            $_.comments.nodes[0].author.login
        } else { "unknown" }
        [PSCustomObject]@{
            Path   = $_.path
            Line   = $_.line
            Author = $author
            Preview = if ($_.comments.nodes.Count -gt 0) {
                $body = $_.comments.nodes[0].body
                if ($body.Length -gt 80) { $body.Substring(0, 77) + "..." } else { $body }
            } else { "" }
        }
    })
}

# --- Display ---

if ($Brief) {
    $ciIcon = switch ($checksStatus) {
        "SUCCESS" { "✅" }
        "PENDING" { "⏳" }
        "FAILURE" { "🔴" }
        default   { "❓" }
    }
    Write-Host "🔀 PR #$($pr.number): $unresolvedThreads unresolved ($($human.Count) human, $($automated.Count) bot) │ CI: $ciIcon │ $($pr.mergeable) │ $recommendation" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "🔀 PR #$($pr.number): $($pr.headRefName) → $($pr.baseRefName)" -ForegroundColor Cyan
    Write-Host "   $($pr.title)" -ForegroundColor White
    Write-Host ""
    Write-Host "📊 Threads: $totalThreads total │ $resolvedThreads resolved │ $unresolvedThreads unresolved" -ForegroundColor White
    Write-Host "   🤖 Automated: $($automated.Count) threads ($automatedResolved resolved, $automatedUnresolved unresolved)" -ForegroundColor Gray
    Write-Host "   🧑 Human: $($human.Count) threads ($humanResolved resolved, $humanUnresolved unresolved)" -ForegroundColor Gray

    $ciIcon = switch ($checksStatus) {
        "SUCCESS" { "✅ $checksPassed/$checksTotal passing" }
        "PENDING" { "⏳ $checksPassed/$checksTotal passing (in progress)" }
        "FAILURE" { "🔴 $checksPassed/$checksTotal passing" }
        default   { "❓ unknown" }
    }
    Write-Host "   CI: $ciIcon" -ForegroundColor White

    if ($checksFailed.Count -gt 0) {
        foreach ($f in $checksFailed) {
            Write-Host "      ❌ $f" -ForegroundColor Red
        }
    }

    $approvalText = if ($approvals.Count -gt 0) { "$($approvals.Count) approved ($($approvals -join ', '))" } else { "0 approvals" }
    $crText = if ($changesRequested.Count -gt 0) { ", $($changesRequested.Count) changes requested" } else { "" }
    Write-Host "👤 Reviews: $approvalText$crText" -ForegroundColor White
    Write-Host "🔀 Mergeable: $($pr.mergeable) │ +$($pr.additions) -$($pr.deletions) across $($pr.changedFiles) files" -ForegroundColor White
    Write-Host ""
    Write-Host "📋 Recommendation: $recommendation" -ForegroundColor Yellow

    if ($prHealthReport.UnresolvedDetails.Count -gt 0) {
        Write-Host ""
        Write-Host "Unresolved threads:" -ForegroundColor Gray
        foreach ($detail in $prHealthReport.UnresolvedDetails) {
            Write-Host "   • $($detail.Path):$($detail.Line) (@$($detail.Author))" -ForegroundColor DarkGray
            if ($detail.Preview) {
                Write-Host "     $($detail.Preview)" -ForegroundColor DarkGray
            }
        }
    }
    Write-Host ""
}

# Emit structured object to pipeline
Write-Output $prHealthReport
