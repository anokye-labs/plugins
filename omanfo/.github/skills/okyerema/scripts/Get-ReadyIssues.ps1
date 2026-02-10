<#
.SYNOPSIS
    Find issues that are ready to work on (all dependencies met).

.DESCRIPTION
    Queries open issues and determines which ones are ready for work by checking:
    1. All child sub-issues are closed (hierarchy-based dependencies)
    2. No open blocking issues referenced in body/comments (cross-reference dependencies)
    
    This enables agents to self-select work items that have all dependencies resolved.

.PARAMETER Owner
    Repository owner (organization or user).

.PARAMETER Repo
    Repository name.

.PARAMETER IssueType
    Optional filter by issue type (Epic, Feature, Task, Bug).

.PARAMETER MaxResults
    Maximum number of ready issues to return. Default is 10.

.PARAMETER IncludeClosed
    If set, includes closed issues in blocker analysis (default: only checks open blockers).

.EXAMPLE
    .\Get-ReadyIssues.ps1 -Owner anokye-labs -Repo plugins

.EXAMPLE
    .\Get-ReadyIssues.ps1 -Owner anokye-labs -Repo plugins -IssueType Task -MaxResults 5
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [string]$IssueType,
    [int]$MaxResults = 10,
    [switch]$IncludeClosed
)

$ErrorActionPreference = "Stop"

# --- Fetch all issues with hierarchy and body/comments for dependency analysis ---

$allIssues = @()
$hasNextPage = $true
$cursor = $null

Write-Host "🔍 Fetching issues and dependencies..." -ForegroundColor Cyan

while ($hasNextPage) {
    $afterClause = if ($cursor) { ", after: `"$cursor`"" } else { "" }

    $query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    issues(states: [OPEN, CLOSED], first: 100$afterClause, orderBy: {field: CREATED_AT, direction: ASC}) {
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        number
        title
        state
        body
        issueType { name }
        subIssues(first: 100) {
          nodes {
            number
            state
          }
        }
        comments(first: 100) {
          nodes {
            body
          }
        }
      }
    }
  }
}
"@

    $rawResult = gh api graphql -H "GraphQL-Features: sub_issues" -f query="$query" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "GraphQL query failed: $rawResult"
        exit 1
    }
    
    $result = $rawResult | ConvertFrom-Json
    if ($result.errors) {
        Write-Error "GraphQL errors: $($result.errors | ConvertTo-Json -Compress)"
        exit 1
    }

    $page = $result.data.repository.issues
    $allIssues += $page.nodes
    $hasNextPage = $page.pageInfo.hasNextPage
    $cursor = $page.pageInfo.endCursor
}

Write-Host "✓ Fetched $($allIssues.Count) issues" -ForegroundColor Gray

# --- Build issue map ---

$issueMap = @{}
foreach ($issue in $allIssues) {
    $issueMap[$issue.number] = $issue
}

# --- Parse blocking references from body and comments ---
# Looks for patterns like "Blocked by #123" or "Depends on anokye-labs/plugins#45"

function Get-BlockingReferences {
    param([object]$Issue)
    
    $blockers = @()
    $text = $Issue.body
    
    # Add comment bodies
    if ($Issue.comments -and $Issue.comments.nodes) {
        foreach ($comment in $Issue.comments.nodes) {
            $text += "`n" + $comment.body
        }
    }
    
    if (-not $text) {
        return $blockers
    }
    
    # Match patterns: "blocked by #123", "depends on #456", "blocked by owner/repo#789"
    $patterns = @(
        'blocked\s+by[:\s]+#(\d+)',
        'depends\s+on[:\s]+#(\d+)',
        'blocked\s+by[:\s]+[\w-]+/[\w-]+#(\d+)',
        'depends\s+on[:\s]+[\w-]+/[\w-]+#(\d+)'
    )
    
    foreach ($pattern in $patterns) {
        $matches = [regex]::Matches($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        foreach ($match in $matches) {
            $blockerNumber = [int]$match.Groups[1].Value
            if ($blockerNumber -gt 0) {
                $blockers += $blockerNumber
            }
        }
    }
    
    return $blockers | Select-Object -Unique
}

# --- Determine if an issue is ready ---

function Test-IssueReady {
    param([object]$Issue, [hashtable]$IssueMap, [bool]$IncludeClosed)
    
    # Skip closed issues
    if ($Issue.state -eq "CLOSED") {
        return $false
    }
    
    # Check 1: All child sub-issues must be closed
    if ($Issue.subIssues -and $Issue.subIssues.nodes) {
        foreach ($child in $Issue.subIssues.nodes) {
            if ($child.state -eq "OPEN") {
                return $false
            }
        }
    }
    
    # Check 2: No open blocking issues
    $blockerNumbers = Get-BlockingReferences -Issue $Issue
    foreach ($blockerNum in $blockerNumbers) {
        $blocker = $IssueMap[$blockerNum]
        if ($blocker -and $blocker.state -eq "OPEN") {
            return $false
        }
        if (-not $blocker) {
            # Blocker might be in a different repo - assume it's open unless we're explicitly including closed
            if (-not $IncludeClosed) {
                return $false
            }
        }
    }
    
    return $true
}

# --- Find ready issues ---

$readyIssues = @()

foreach ($issue in $allIssues) {
    if ($issue.state -ne "OPEN") {
        continue
    }
    
    # Apply type filter if specified
    if ($IssueType) {
        $typeName = if ($issue.issueType) { $issue.issueType.name } else { "" }
        if ($typeName -ne $IssueType) {
            continue
        }
    }
    
    if (Test-IssueReady -Issue $issue -IssueMap $issueMap -IncludeClosed $IncludeClosed) {
        $readyIssues += $issue
    }
}

# --- Display results ---

Write-Host ""
Write-Host "🟢 Ready Issues: $Owner/$Repo" -ForegroundColor Green
Write-Host ""

if ($readyIssues.Count -eq 0) {
    Write-Host "No ready issues found" -ForegroundColor Yellow
} else {
    $displayCount = [Math]::Min($readyIssues.Count, $MaxResults)
    
    for ($i = 0; $i -lt $displayCount; $i++) {
        $issue = $readyIssues[$i]
        $typeName = if ($issue.issueType) { $issue.issueType.name } else { "Issue" }
        $childCount = if ($issue.subIssues) { $issue.subIssues.nodes.Count } else { 0 }
        $childInfo = if ($childCount -gt 0) { " ($childCount children done)" } else { "" }
        
        Write-Host "  🟢 #$($issue.number) [$typeName] $($issue.title)$childInfo" -ForegroundColor Green
    }
    
    if ($readyIssues.Count -gt $MaxResults) {
        Write-Host ""
        Write-Host "  ... and $($readyIssues.Count - $MaxResults) more" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "📊 Summary: $($readyIssues.Count) issues ready to work on" -ForegroundColor Cyan
Write-Host ""

# Output structured data
$output = [PSCustomObject]@{
    Owner = $Owner
    Repo = $Repo
    ReadyIssues = $readyIssues | Select-Object number, title, @{Name="Type"; Expression={if ($_.issueType) {$_.issueType.name} else {"Unknown"}}}
    TotalReady = $readyIssues.Count
}

Write-Output $output
