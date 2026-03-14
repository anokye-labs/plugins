#Requires -Version 5.1
<#
.SYNOPSIS
    Detect stalled work items (assigned issues with no recent updates).

.DESCRIPTION
    Queries all open assigned issues and identifies those with no updates within
    the specified threshold (default: 30 days). Checks both the issue's updatedAt
    timestamp and the most recent comment/activity. Returns a structured report
    grouped by assignee.

.PARAMETER Owner
    Repository owner (organization or user).

.PARAMETER Repo
    Repository name.

.PARAMETER ThresholdDays
    Number of days without updates to consider an issue stalled (default: 30).

.PARAMETER Brief
    If set, returns compact single-line summary.

.EXAMPLE
    .\Get-StalledWork.ps1 -Owner anokye-labs -Repo akwaaba

.EXAMPLE
    .\Get-StalledWork.ps1 -Owner anokye-labs -Repo akwaaba -ThresholdDays 14 -Brief
#>
[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [int]$ThresholdDays = 30,
    [switch]$Brief
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\_Invoke-GraphQL.ps1"

# Calculate threshold date
$thresholdDate = (Get-Date).AddDays(-$ThresholdDays)

# --- Paginated fetch of all open assigned issues ---

$allIssues = @()
$hasNextPage = $true
$cursor = $null

while ($hasNextPage) {
    $afterClause = if ($cursor) { ", after: `"$cursor`"" } else { "" }

    $query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    issues(states: OPEN, first: 100$afterClause, orderBy: {field: UPDATED_AT, direction: DESC}) {
      totalCount
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        number
        title
        state
        createdAt
        updatedAt
        issueType { name }
        assignees(first: 10) {
          nodes {
            login
          }
        }
        comments(first: 1, orderBy: {field: UPDATED_AT, direction: DESC}) {
          totalCount
          nodes {
            createdAt
            author {
              login
            }
          }
        }
        labels(first: 10) {
          nodes {
            name
          }
        }
      }
    }
  }
}
"@

    $result = Invoke-GraphQL -Query $query

    $page = $result.data.repository.issues
    $allIssues += $page.nodes
    $hasNextPage = $page.pageInfo.hasNextPage
    $cursor = $page.pageInfo.endCursor
}

$totalIssues = $allIssues.Count

# --- Filter assigned issues and check staleness ---

$stalledIssues = @()

foreach ($issue in $allIssues) {
    # Skip unassigned issues
    if (-not $issue.assignees -or -not $issue.assignees.nodes -or $issue.assignees.nodes.Count -eq 0) {
        continue
    }

    # Parse updatedAt timestamp
    $updatedAt = [DateTime]::Parse($issue.updatedAt)
    
    # Determine last activity date
    # Note: issue.updatedAt reflects all activity including comment edits, label changes, etc.
    # The last comment createdAt is checked separately to ensure we catch comment activity
    $lastActivityDate = $updatedAt
    if ($issue.comments -and $issue.comments.nodes -and $issue.comments.nodes.Count -gt 0) {
        $lastCommentDate = [DateTime]::Parse($issue.comments.nodes[0].createdAt)
        if ($lastCommentDate -gt $lastActivityDate) {
            $lastActivityDate = $lastCommentDate
        }
    }

    # Check if stalled
    if ($lastActivityDate -lt $thresholdDate) {
        $daysSinceUpdate = [math]::Floor(((Get-Date) - $lastActivityDate).TotalDays)
        
        # Get assignee logins
        $assigneeLogins = @()
        foreach ($assignee in $issue.assignees.nodes) {
            $assigneeLogins += $assignee.login
        }

        # Get labels
        $labelNames = @()
        if ($issue.labels -and $issue.labels.nodes) {
            foreach ($label in $issue.labels.nodes) {
                $labelNames += $label.name
            }
        }

        # Check if blocked
        $isBlocked = $labelNames -contains "blocked"

        $stalledIssues += [PSCustomObject]@{
            Number           = $issue.number
            Title            = $issue.title
            Type             = if ($issue.issueType) { $issue.issueType.name } else { "Unknown" }
            Assignees        = $assigneeLogins
            DaysSinceUpdate  = $daysSinceUpdate
            LastActivityDate = $lastActivityDate
            UpdatedAt        = $updatedAt
            IsBlocked        = $isBlocked
            Labels           = $labelNames
            CommentCount     = if ($issue.comments) { $issue.comments.totalCount } else { 0 }
        }
    }
}

# --- Group by assignee ---

$byAssignee = @{}
foreach ($stalled in $stalledIssues) {
    foreach ($assignee in $stalled.Assignees) {
        if (-not $byAssignee.ContainsKey($assignee)) {
            $byAssignee[$assignee] = @()
        }
        $byAssignee[$assignee] += $stalled
    }
}

# Sort assignees by number of stalled issues (descending)
$sortedAssignees = $byAssignee.Keys | Sort-Object { $byAssignee[$_].Count } -Descending

# --- Calculate statistics ---

$assignedIssueCount = ($allIssues | Where-Object { 
    $_.assignees -and $_.assignees.nodes -and $_.assignees.nodes.Count -gt 0 
}).Count

$stalledCount = $stalledIssues.Count
$stalledRatio = if ($assignedIssueCount -gt 0) { $stalledCount / $assignedIssueCount } else { 0 }
$avgDaysSinceUpdate = if ($stalledCount -gt 0) { 
    [math]::Round(($stalledIssues | Measure-Object -Property DaysSinceUpdate -Average).Average, 1) 
} else { 
    0 
}

$blockedCount = ($stalledIssues | Where-Object { $_.IsBlocked }).Count

# --- Health score (0-100) ---

$score = 100

# Deduct for stalled ratio
$score -= [math]::Min(40, [math]::Floor($stalledRatio * 100))

# Deduct for average age
if ($avgDaysSinceUpdate -gt 60) {
    $score -= 20
} elseif ($avgDaysSinceUpdate -gt 45) {
    $score -= 10
}

# Deduct for blocked stalled issues
if ($blockedCount -gt 0) {
    $score -= [math]::Min(20, $blockedCount * 5)
}

$score = [math]::Max(0, $score)

# --- Build result ---

$stalledReport = [PSCustomObject]@{
    Owner               = $Owner
    Repo                = $Repo
    ThresholdDays       = $ThresholdDays
    TotalOpenIssues     = $totalIssues
    AssignedIssues      = $assignedIssueCount
    StalledIssues       = $stalledIssues
    StalledCount        = $stalledCount
    StalledRatio        = [math]::Round($stalledRatio, 2)
    AvgDaysSinceUpdate  = $avgDaysSinceUpdate
    BlockedCount        = $blockedCount
    ByAssignee          = $byAssignee
    AssigneeCount       = $sortedAssignees.Count
    HealthScore         = $score
}

# --- Display ---

if ($Brief) {
    $stalledIcon = if ($stalledCount -eq 0) { "✅" } elseif ($stalledCount -lt 5) { "⚠️" } else { "🔴" }
    $blockedIcon = if ($blockedCount -eq 0) { "✅" } else { "⚠️" }
    $summary = "${Owner}/${Repo}: ${assignedIssueCount} assigned | ${stalledIcon} ${stalledCount} stalled (${ThresholdDays}d) | ${blockedIcon} ${blockedCount} blocked | Score: ${score}/100"
    Write-Host $summary -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "⏰ Stalled Work Report: $Owner/$Repo" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📊 Summary: $assignedIssueCount assigned issues | Threshold: ${ThresholdDays} days" -ForegroundColor White

    if ($stalledCount -eq 0) {
        Write-Host "✅ No stalled work — all assigned issues are active" -ForegroundColor Green
    } else {
        $stalledPercentage = [math]::Round($stalledRatio * 100, 1)
        $stalledColor = if ($stalledRatio -lt 0.2) { "Yellow" } else { "Red" }
        Write-Host "⚠️ Stalled issues: $stalledCount ($stalledPercentage%)" -ForegroundColor $stalledColor
        Write-Host "   Average days since update: $avgDaysSinceUpdate" -ForegroundColor Gray
        
        if ($blockedCount -gt 0) {
            Write-Host "   🚫 Blocked (stalled): $blockedCount" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "👥 By Assignee:" -ForegroundColor White
        
        foreach ($assignee in $sortedAssignees | Select-Object -First 10) {
            $assigneeIssues = $byAssignee[$assignee]
            $assigneeCount = $assigneeIssues.Count
            $assigneeAvgDays = [math]::Round(($assigneeIssues | Measure-Object -Property DaysSinceUpdate -Average).Average, 1)
            
            Write-Host "   @$assignee : $assigneeCount stalled (avg ${assigneeAvgDays}d)" -ForegroundColor Cyan
            
            # Show top 3 stalled issues for this assignee
            foreach ($issue in $assigneeIssues | Sort-Object DaysSinceUpdate -Descending | Select-Object -First 3) {
                $blockedTag = if ($issue.IsBlocked) { " 🚫" } else { "" }
                Write-Host "      #$($issue.Number) $($issue.Type): $($issue.Title) ($($issue.DaysSinceUpdate)d)$blockedTag" -ForegroundColor DarkGray
            }
            
            if ($assigneeCount -gt 3) {
                Write-Host "      ... and $($assigneeCount - 3) more" -ForegroundColor DarkGray
            }
        }
        
        if ($sortedAssignees.Count -gt 10) {
            Write-Host "   ... and $($sortedAssignees.Count - 10) more assignees" -ForegroundColor DarkGray
        }
    }

    # Score
    $scoreColor = if ($score -ge 80) { "Green" } elseif ($score -ge 50) { "Yellow" } else { "Red" }
    Write-Host ""
    Write-Host "💯 Stalled Work Score: $score/100" -ForegroundColor $scoreColor
    Write-Host ""
}

# Emit structured object to pipeline
Write-Output $stalledReport
