<#
.SYNOPSIS
    Find issues that are ready to work on (all dependencies met).

.DESCRIPTION
    Queries open issues and determines which ones are ready for work by checking:
    1. All child sub-issues are closed (hierarchy-based dependencies)
    2. No open blocking issues referenced in body/comments (cross-reference dependencies)
    
    This enables agents to self-select work items that have all dependencies resolved.
    
    LIMITATION: Due to GraphQL pagination constraints, only the first 100 sub-issues
    per issue are checked. Issues with more than 100 children may be misclassified.

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
# Returns objects with Owner, Repo, and Number to handle cross-repo references correctly

function Get-BlockingReferences {
    param(
        [object]$Issue,
        [string]$CurrentOwner,
        [string]$CurrentRepo
    )
    
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
    
    # Match patterns with capture groups for owner/repo and issue number
    # Pattern 1: Cross-repo reference "owner/repo#123"
    $crossRepoPattern = 'blocked\s+by[:\s]+([\w-]+)/([\w-]+)#(\d+)|depends\s+on[:\s]+([\w-]+)/([\w-]+)#(\d+)'
    $crossRepoMatches = [regex]::Matches($text, $crossRepoPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    
    foreach ($match in $crossRepoMatches) {
        # Extract owner, repo, and number from whichever set of capture groups matched
        $owner = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[4].Value }
        $repo = if ($match.Groups[2].Success) { $match.Groups[2].Value } else { $match.Groups[5].Value }
        $number = if ($match.Groups[3].Success) { [int]$match.Groups[3].Value } else { [int]$match.Groups[6].Value }
        
        if ($number -gt 0) {
            $blockers += [PSCustomObject]@{
                Owner = $owner
                Repo = $repo
                Number = $number
                IsExternal = ($owner -ne $CurrentOwner -or $repo -ne $CurrentRepo)
            }
        }
    }
    
    # Pattern 2: Local reference "#123"
    $localPattern = 'blocked\s+by[:\s]+#(\d+)|depends\s+on[:\s]+#(\d+)'
    $localMatches = [regex]::Matches($text, $localPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    
    foreach ($match in $localMatches) {
        # Skip if this was already matched as part of a cross-repo reference
        $alreadyMatched = $false
        foreach ($crossMatch in $crossRepoMatches) {
            if ($match.Index -ge $crossMatch.Index -and $match.Index -lt ($crossMatch.Index + $crossMatch.Length)) {
                $alreadyMatched = $true
                break
            }
        }
        
        if (-not $alreadyMatched) {
            $number = if ($match.Groups[1].Success) { [int]$match.Groups[1].Value } else { [int]$match.Groups[2].Value }
            if ($number -gt 0) {
                $blockers += [PSCustomObject]@{
                    Owner = $CurrentOwner
                    Repo = $CurrentRepo
                    Number = $number
                    IsExternal = $false
                }
            }
        }
    }
    
    # Return unique blockers (by Owner/Repo/Number combination)
    return $blockers | Sort-Object -Property Owner, Repo, Number -Unique
}

# --- Determine if an issue is ready ---

function Test-IssueReady {
    param(
        [object]$Issue,
        [hashtable]$IssueMap,
        [bool]$IncludeClosed,
        [string]$CurrentOwner,
        [string]$CurrentRepo
    )
    
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
    $blockerRefs = Get-BlockingReferences -Issue $Issue -CurrentOwner $CurrentOwner -CurrentRepo $CurrentRepo
    foreach ($blockerRef in $blockerRefs) {
        # Only check local issues in our issue map
        if (-not $blockerRef.IsExternal) {
            $blocker = $IssueMap[$blockerRef.Number]
            if ($blocker -and $blocker.state -eq "OPEN") {
                return $false
            }
        } else {
            # External blocker - we can't check its state, so assume it's blocking unless IncludeClosed
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
    
    if (Test-IssueReady -Issue $issue -IssueMap $issueMap -IncludeClosed $IncludeClosed -CurrentOwner $Owner -CurrentRepo $Repo) {
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
