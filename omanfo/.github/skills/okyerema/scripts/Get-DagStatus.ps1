<#
.SYNOPSIS
    Recursive issue hierarchy status (DAG status).

.DESCRIPTION
    Queries the complete issue hierarchy and displays the status of each issue
    in a DAG (Directed Acyclic Graph) view. Shows parent-child relationships,
    issue states, and computes readiness based on child completion.
    
    An issue is "ready" if all its children are closed. This enables agents to
    understand which work items can be started based on dependency completion.

.PARAMETER Owner
    Repository owner (organization or user).

.PARAMETER Repo
    Repository name.

.PARAMETER RootNumber
    Optional root issue number. If omitted, shows all roots (issues without parents).

.PARAMETER MaxDepth
    Maximum depth to traverse. Default is 8.

.PARAMETER Brief
    If set, returns compact tree view without detailed status.

.EXAMPLE
    .\Get-DagStatus.ps1 -Owner anokye-labs -Repo plugins

.EXAMPLE
    .\Get-DagStatus.ps1 -Owner anokye-labs -Repo plugins -RootNumber 10

.EXAMPLE
    .\Get-DagStatus.ps1 -Owner anokye-labs -Repo plugins -Brief
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [int]$RootNumber,
    [int]$MaxDepth = 8,
    [switch]$Brief
)

$ErrorActionPreference = "Stop"

# --- Fetch all open issues with hierarchy information ---

$allIssues = @()
$hasNextPage = $true
$cursor = $null

Write-Host "📊 Fetching issue hierarchy..." -ForegroundColor Cyan

while ($hasNextPage) {
    $afterClause = if ($cursor) { ", after: `"$cursor`"" } else { "" }

    $query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    issues(states: [OPEN, CLOSED], first: 100$afterClause, orderBy: {field: CREATED_AT, direction: ASC}) {
      totalCount
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        number
        title
        state
        issueType { name }
        parentIssue {
          number
          state
        }
        subIssues(first: 100) {
          totalCount
          nodes {
            number
            state
            issueType { name }
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

# --- Build issue map and compute readiness ---

$issueMap = @{}
foreach ($issue in $allIssues) {
    $issueMap[$issue.number] = $issue
}

# Compute readiness: an issue is ready if all its children are closed
function Get-IssueReadiness {
    param([object]$Issue)
    
    if ($Issue.state -eq "CLOSED") {
        return "CLOSED"
    }
    
    if (-not $Issue.subIssues -or $Issue.subIssues.totalCount -eq 0) {
        # Leaf node - ready if open
        return "READY"
    }
    
    $allChildrenClosed = $true
    foreach ($child in $Issue.subIssues.nodes) {
        if ($child.state -eq "OPEN") {
            $allChildrenClosed = $false
            break
        }
    }
    
    if ($allChildrenClosed) {
        return "READY"
    } else {
        return "WAITING"
    }
}

# --- Recursive tree display ---

function Show-IssueTree {
    param(
        [object]$Issue,
        [int]$Depth = 0,
        [int]$MaxDepth,
        [hashtable]$IssueMap,
        [bool]$Brief
    )
    
    if ($Depth -ge $MaxDepth) {
        return
    }
    
    $indent = "  " * $Depth
    $typeName = if ($Issue.issueType) { $Issue.issueType.name } else { "Issue" }
    $readiness = Get-IssueReadiness -Issue $Issue
    
    # Status icons
    $stateIcon = switch ($Issue.state) {
        "OPEN" { "⬜" }
        "CLOSED" { "✅" }
        default { "❓" }
    }
    
    $readyIcon = switch ($readiness) {
        "READY" { "🟢" }
        "WAITING" { "🟡" }
        "CLOSED" { "✅" }
        default { "⚪" }
    }
    
    if ($Brief) {
        Write-Host "$indent$stateIcon #$($Issue.number) $($Issue.title)" -ForegroundColor Gray
    } else {
        $childInfo = if ($Issue.subIssues.totalCount -gt 0) { " ($($Issue.subIssues.totalCount) children)" } else { "" }
        Write-Host "$indent$readyIcon $stateIcon #$($Issue.number) [$typeName] $($Issue.title)$childInfo" -ForegroundColor $(
            switch ($readiness) {
                "READY" { "Green" }
                "WAITING" { "Yellow" }
                "CLOSED" { "DarkGray" }
                default { "White" }
            }
        )
    }
    
    # Recurse to children
    if ($Issue.subIssues -and $Issue.subIssues.nodes) {
        foreach ($childRef in $Issue.subIssues.nodes) {
            $child = $IssueMap[$childRef.number]
            if ($child) {
                Show-IssueTree -Issue $child -Depth ($Depth + 1) -MaxDepth $MaxDepth -IssueMap $IssueMap -Brief $Brief
            }
        }
    }
}

# --- Display DAG ---

Write-Host ""
Write-Host "🌳 Issue Hierarchy DAG: $Owner/$Repo" -ForegroundColor Cyan
Write-Host ""

if (-not $Brief) {
    Write-Host "Legend: 🟢 Ready to work | 🟡 Waiting on children | ✅ Closed | ⬜ Open" -ForegroundColor Gray
    Write-Host ""
}

if ($RootNumber -gt 0) {
    # Show specific root
    $rootIssue = $issueMap[$RootNumber]
    if (-not $rootIssue) {
        Write-Error "Issue #$RootNumber not found"
        exit 1
    }
    Show-IssueTree -Issue $rootIssue -Depth 0 -MaxDepth $MaxDepth -IssueMap $issueMap -Brief $Brief
} else {
    # Show all roots (issues without parents)
    $roots = $allIssues | Where-Object { -not $_.parentIssue }
    
    if ($roots.Count -eq 0) {
        Write-Host "No root issues found" -ForegroundColor Yellow
    } else {
        foreach ($root in $roots) {
            Show-IssueTree -Issue $root -Depth 0 -MaxDepth $MaxDepth -IssueMap $issueMap -Brief $Brief
            Write-Host ""
        }
    }
}

# --- Summary statistics ---

$openCount = ($allIssues | Where-Object { $_.state -eq "OPEN" }).Count
$closedCount = ($allIssues | Where-Object { $_.state -eq "CLOSED" }).Count
$readyCount = 0
$waitingCount = 0

foreach ($issue in $allIssues) {
    if ($issue.state -eq "OPEN") {
        $readiness = Get-IssueReadiness -Issue $issue
        if ($readiness -eq "READY") {
            $readyCount++
        } elseif ($readiness -eq "WAITING") {
            $waitingCount++
        }
    }
}

Write-Host "📊 Summary: $openCount open | $closedCount closed | $readyCount ready | $waitingCount waiting" -ForegroundColor Cyan
Write-Host ""
