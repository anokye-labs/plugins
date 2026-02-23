<#
.SYNOPSIS
    Gather tactical status for the /sitrep command.

.DESCRIPTION
    Queries open issues, recent commits, unresolved PR threads, and git status
    to produce a structured status report. Returns a PSCustomObject for agent
    formatting.

.PARAMETER Owner
    Repository owner (organization or user).

.PARAMETER Repo
    Repository name.

.PARAMETER IssueNumber
    Optional focus issue number. If omitted, infers from recent activity.

.PARAMETER PullNumber
    Optional PR number to check. If omitted, finds the most recent open PR.

.PARAMETER Brief
    If set, returns compact single-line summary.

.EXAMPLE
    .\Get-Sitrep.ps1 -Owner anokye-labs -Repo akwaaba

.EXAMPLE
    .\Get-Sitrep.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 12 -Brief
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [int]$IssueNumber,
    [int]$PullNumber,
    [switch]$Brief
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\_Invoke-GraphQL.ps1"

# --- Query open issues, recent commits, and optionally a PR ---

$prFragment = ""
if ($PullNumber -gt 0) {
    $prFragment = @"
    pullRequest(number: $PullNumber) {
      number
      title
      state
      mergeable
      reviewThreads(first: 100) {
        totalCount
        nodes {
          isResolved
          comments(first: 1) {
            nodes { author { login } }
          }
        }
      }
      commits(last: 1) {
        nodes {
          commit {
            statusCheckRollup {
              state
            }
          }
        }
      }
    }
"@
}

$focusFragment = ""
if ($IssueNumber -gt 0) {
    $focusFragment = @"
    focusIssue: issue(number: $IssueNumber) {
      number
      title
      state
      issueType { name }
    }
"@
}

$query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    openIssues: issues(states: OPEN, first: 100) {
      totalCount
      nodes {
        number
        title
        state
        issueType { name }
        labels(first: 5) { nodes { name } }
      }
    }
    closedRecent: issues(states: CLOSED, first: 10, orderBy: {field: UPDATED_AT, direction: DESC}) {
      nodes {
        number
        title
        closedAt
      }
    }
    defaultBranchRef {
      target {
        ... on Commit {
          history(first: 5) {
            nodes {
              oid
              messageHeadline
              committedDate
              author { user { login } }
            }
          }
        }
      }
    }
    $focusFragment
    $prFragment
  }
}
"@

$result = Invoke-GraphQL -Query $query

$repoData = $result.data.repository

# --- Compute issue counts ---

$openIssues = $repoData.openIssues.nodes
$totalOpen = $repoData.openIssues.totalCount

$doneCount = ($repoData.closedRecent.nodes | Measure-Object).Count
$pendingCount = ($openIssues | Where-Object {
    $blocked = $false
    foreach ($label in $_.labels.nodes) {
        if ($label.name -match 'blocked') { $blocked = $true }
    }
    -not $blocked
} | Measure-Object).Count

$blockedCount = ($openIssues | Where-Object {
    foreach ($label in $_.labels.nodes) {
        if ($label.name -match 'blocked') { return $true }
    }
    return $false
} | Measure-Object).Count

# --- Focus ---

$focus = $null
if ($IssueNumber -gt 0 -and $repoData.focusIssue) {
    $fi = $repoData.focusIssue
    $focus = "#$($fi.number) [$($fi.issueType.name)] $($fi.title)"
} elseif ($openIssues.Count -gt 0) {
    $top = $openIssues[0]
    $typeName = if ($top.issueType) { $top.issueType.name } else { "Issue" }
    $focus = "#$($top.number) [$typeName] $($top.title)"
}

# --- PR health ---

$prHealth = $null
$ciStatus = $null
if ($PullNumber -gt 0 -and $repoData.pullRequest) {
    $pr = $repoData.pullRequest
    $threads = $pr.reviewThreads.nodes
    $totalThreads = $pr.reviewThreads.totalCount
    $resolvedThreads = ($threads | Where-Object { $_.isResolved } | Measure-Object).Count
    $unresolvedThreads = $totalThreads - $resolvedThreads

    $prHealth = [PSCustomObject]@{
        Number            = $pr.number
        Title             = $pr.title
        State             = $pr.state
        Mergeable         = $pr.mergeable
        TotalThreads      = $totalThreads
        ResolvedThreads   = $resolvedThreads
        UnresolvedThreads = $unresolvedThreads
    }

    $lastCommit = $pr.commits.nodes | Select-Object -Last 1
    if ($lastCommit -and $lastCommit.commit.statusCheckRollup) {
        $ciStatus = $lastCommit.commit.statusCheckRollup.state
    } else {
        $ciStatus = "UNKNOWN"
    }
}

# --- Recent commits ---

$recentCommits = @()
if ($repoData.defaultBranchRef -and $repoData.defaultBranchRef.target.history) {
    $recentCommits = $repoData.defaultBranchRef.target.history.nodes | ForEach-Object {
        [PSCustomObject]@{
            SHA     = $_.oid.Substring(0, 7)
            Message = $_.messageHeadline
            Date    = $_.committedDate
            Author  = if ($_.author.user) { $_.author.user.login } else { "unknown" }
        }
    }
}

# --- Git working directory status (if inside the repo) ---

$gitStatus = $null
try {
    $statusOutput = git status --porcelain 2>$null
    if ($null -ne $statusOutput) {
        $modified = ($statusOutput | Where-Object { $_ -match '^ ?M' } | Measure-Object).Count
        $added = ($statusOutput | Where-Object { $_ -match '^\?\?' } | Measure-Object).Count
        $staged = ($statusOutput | Where-Object { $_ -match '^[MADRC]' } | Measure-Object).Count
        $gitStatus = [PSCustomObject]@{
            Modified  = $modified
            Untracked = $added
            Staged    = $staged
            Clean     = ($statusOutput.Count -eq 0)
        }
    }
} catch {
    # Not in a git repo or git not available — skip
}

# --- Build result ---

$sitrep = [PSCustomObject]@{
    Owner        = $Owner
    Repo         = $Repo
    Focus        = $focus
    TotalOpen    = $totalOpen
    DoneCount    = $doneCount
    PendingCount = $pendingCount
    BlockedCount = $blockedCount
    PRHealth     = $prHealth
    CIStatus     = $ciStatus
    RecentCommits = $recentCommits
    GitStatus    = $gitStatus
}

# --- Output ---

if ($Brief) {
    $prSummary = ""
    if ($prHealth) {
        $ciIcon = switch ($ciStatus) {
            "SUCCESS" { "✅" }
            "PENDING" { "⏳" }
            "FAILURE" { "🔴" }
            default   { "❓" }
        }
        $prSummary = " │ PR #$($prHealth.Number): $($prHealth.UnresolvedThreads) unresolved │ CI: $ciIcon"
    }
    Write-Host "🎯 $focus │ ✅$doneCount ⬜$pendingCount 🔴$blockedCount$prSummary" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "🎯 Focus: $focus" -ForegroundColor Cyan
    Write-Host "📊 Done: $doneCount │ Pending: $pendingCount │ Blocked: $blockedCount │ Total open: $totalOpen" -ForegroundColor White

    if ($prHealth) {
        $ciIcon = switch ($ciStatus) {
            "SUCCESS" { "✅ passing" }
            "PENDING" { "⏳ running" }
            "FAILURE" { "🔴 failing" }
            default   { "❓ unknown" }
        }
        Write-Host "🔀 PR #$($prHealth.Number): $($prHealth.UnresolvedThreads) unresolved threads │ CI: $ciIcon │ Mergeable: $($prHealth.Mergeable)" -ForegroundColor White
    }

    if ($blockedCount -gt 0) {
        $blockedIssues = $openIssues | Where-Object {
            foreach ($label in $_.labels.nodes) {
                if ($label.name -match 'blocked') { return $true }
            }
            return $false
        }
        foreach ($bi in $blockedIssues) {
            Write-Host "⚠️  Blocked: #$($bi.number) $($bi.title)" -ForegroundColor Yellow
        }
    }

    if ($recentCommits.Count -gt 0) {
        Write-Host ""
        Write-Host "📝 Recent commits:" -ForegroundColor Gray
        foreach ($c in $recentCommits | Select-Object -First 3) {
            Write-Host "   $($c.SHA) $($c.Message)" -ForegroundColor DarkGray
        }
    }

    if ($gitStatus -and -not $gitStatus.Clean) {
        Write-Host ""
        Write-Host "📁 Working tree: $($gitStatus.Modified) modified, $($gitStatus.Untracked) untracked, $($gitStatus.Staged) staged" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Emit structured object to pipeline
Write-Output $sitrep
