<#
.SYNOPSIS
    DAG progress completion report for issue hierarchies.

.DESCRIPTION
    Queries the complete issue hierarchy and generates a progress report showing
    overall and per-root percent complete, blocked dependency paths (chains where
    every issue is still open), and critical path analysis (the longest all-open
    dependency chain). Suitable for /sitrep and /recap output.

.PARAMETER Owner
    Repository owner (organization or user).

.PARAMETER Repo
    Repository name.

.PARAMETER RootNumber
    Optional root issue number. If omitted, reports on all roots (issues without
    a parent issue).

.PARAMETER Brief
    If set, returns compact single-line summary.

.EXAMPLE
    .\Get-DagCompletionReport.ps1 -Owner anokye-labs -Repo plugins

.EXAMPLE
    .\Get-DagCompletionReport.ps1 -Owner anokye-labs -Repo plugins -RootNumber 10

.EXAMPLE
    .\Get-DagCompletionReport.ps1 -Owner anokye-labs -Repo plugins -Brief
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [int]$RootNumber,
    [switch]$Brief
)

$ErrorActionPreference = "Stop"

# --- Fetch all issues (OPEN + CLOSED) with hierarchy fields ---

$allIssues = @()
$hasNextPage = $true
$cursor = $null

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
        issueType { name }
        parentIssue {
          number
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
        return
    }
    $result = $rawResult | ConvertFrom-Json

    if ($result.errors) {
        Write-Error "GraphQL errors: $($result.errors | ConvertTo-Json -Compress)"
        return
    }

    $page = $result.data.repository.issues
    $allIssues += $page.nodes
    $hasNextPage = $page.pageInfo.hasNextPage
    $cursor = $page.pageInfo.endCursor
}

$totalIssues = $allIssues.Count
$openCount   = ($allIssues | Where-Object { $_.state -eq "OPEN"   }).Count
$closedCount = ($allIssues | Where-Object { $_.state -eq "CLOSED" }).Count
$percentComplete = if ($totalIssues -gt 0) { [math]::Round($closedCount / $totalIssues * 100, 1) } else { 0 }

# --- Build issue map ---

$issueMap = @{}
foreach ($issue in $allIssues) {
    $issueMap[[int]$issue.number] = $issue
}

# --- Compute subtree completion stats (recursive) ---

function Get-SubtreeStats {
    param(
        [int]$Number,
        [hashtable]$IssueMap,
        [System.Collections.Generic.HashSet[int]]$Seen
    )

    if ($Seen.Contains($Number) -or -not $IssueMap.ContainsKey($Number)) {
        return @{ Total = 0; Closed = 0 }
    }

    [void]$Seen.Add($Number)
    $issue = $IssueMap[$Number]

    $total  = 1
    $closed = if ($issue.state -eq "CLOSED") { 1 } else { 0 }

    if ($issue.subIssues -and $issue.subIssues.nodes) {
        foreach ($child in $issue.subIssues.nodes) {
            $childStats = Get-SubtreeStats -Number $child.number -IssueMap $IssueMap -Seen $Seen
            $total  += $childStats.Total
            $closed += $childStats.Closed
        }
    }

    return @{ Total = $total; Closed = $closed }
}

# --- Collect root-to-leaf paths (cap at depth 8 to guard against cycles) ---

$allPaths = [System.Collections.Generic.List[object]]::new()

function Get-Paths {
    param(
        [int]$Number,
        [hashtable]$IssueMap,
        [System.Collections.Generic.List[int]]$CurrentPath,
        [int]$MaxDepth = 8
    )

    if (-not $IssueMap.ContainsKey($Number) -or $CurrentPath.Contains($Number)) {
        return
    }

    $issue = $IssueMap[$Number]
    $CurrentPath.Add($Number)

    if (-not $issue.subIssues -or $issue.subIssues.totalCount -eq 0 -or $CurrentPath.Count -ge $MaxDepth) {
        # Leaf node or depth cap — record this path
        $script:allPaths.Add($CurrentPath.ToArray())
    } else {
        foreach ($child in $issue.subIssues.nodes) {
            Get-Paths -Number $child.number -IssueMap $IssueMap -CurrentPath $CurrentPath -MaxDepth $MaxDepth
        }
    }

    $CurrentPath.RemoveAt($CurrentPath.Count - 1)
}

# --- Determine roots ---

if ($RootNumber -gt 0) {
    if (-not $issueMap.ContainsKey($RootNumber)) {
        Write-Error "Issue #$RootNumber not found"
        return
    }
    $roots = @($issueMap[$RootNumber])
} else {
    $roots = $allIssues | Where-Object { -not $_.parentIssue }
}

# --- Per-root reports ---

$rootReports = @()
foreach ($root in $roots) {
    $seen  = [System.Collections.Generic.HashSet[int]]::new()
    $stats = Get-SubtreeStats -Number $root.number -IssueMap $issueMap -Seen $seen

    $pct = if ($stats.Total -gt 0) { [math]::Round($stats.Closed / $stats.Total * 100, 1) } else { 0 }

    # Collect paths rooted here
    $pathList = New-Object System.Collections.Generic.List[int]
    Get-Paths -Number $root.number -IssueMap $issueMap -CurrentPath $pathList

    $rootReports += [PSCustomObject]@{
        Number          = $root.number
        Title           = $root.title
        Type            = if ($root.issueType) { $root.issueType.name } else { "Issue" }
        State           = $root.state
        TotalIssues     = $stats.Total
        ClosedIssues    = $stats.Closed
        PercentComplete = $pct
    }
}

# --- Blocked paths and critical path ---
# Blocked path : a root-to-leaf path where every issue is OPEN (no progress started).
# Critical path: the longest blocked path (determines the minimum remaining steps).

$blockedPaths       = @()
$criticalPath       = @()
$criticalPathLength = 0

foreach ($path in $allPaths) {
    $allOpen = $true
    foreach ($num in $path) {
        if (-not $issueMap.ContainsKey($num) -or $issueMap[$num].state -ne "OPEN") {
            $allOpen = $false
            break
        }
    }

    if ($allOpen) {
        $blockedPaths += ,@($path)
        if ($path.Count -gt $criticalPathLength) {
            $criticalPathLength = $path.Count
            $criticalPath       = $path
        }
    }
}

# --- Build result ---

$report = [PSCustomObject]@{
    Owner               = $Owner
    Repo                = $Repo
    TotalIssues         = $totalIssues
    OpenCount           = $openCount
    ClosedCount         = $closedCount
    PercentComplete     = $percentComplete
    RootCount           = $roots.Count
    RootReports         = $rootReports
    BlockedPaths        = $blockedPaths
    BlockedPathCount    = $blockedPaths.Count
    CriticalPath        = $criticalPath
    CriticalPathLength  = $criticalPathLength
}

# --- Display ---

if ($Brief) {
    $pctIcon = if ($percentComplete -ge 75) { "🟢" } elseif ($percentComplete -ge 25) { "🟡" } else { "🔴" }
    $summary = "${Owner}/${Repo}: $pctIcon ${percentComplete}% complete | ${closedCount}/${totalIssues} closed | $($blockedPaths.Count) blocked paths | Critical path: ${criticalPathLength} steps"
    Write-Host $summary -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "📈 DAG Completion Report: $Owner/$Repo" -ForegroundColor Cyan
    Write-Host ""

    $pctColor = if ($percentComplete -ge 75) { "Green" } elseif ($percentComplete -ge 25) { "Yellow" } else { "Red" }
    Write-Host "✅ Overall Progress: ${percentComplete}% complete ($closedCount/$totalIssues issues closed)" -ForegroundColor $pctColor
    Write-Host ""

    # Per-root breakdown
    if ($rootReports.Count -gt 0) {
        Write-Host "🌳 Hierarchy Breakdown:" -ForegroundColor White
        foreach ($rr in $rootReports) {
            $rrPctColor = if ($rr.PercentComplete -ge 75) { "Green" } elseif ($rr.PercentComplete -ge 25) { "Yellow" } else { "Red" }
            $filled = [math]::Floor($rr.PercentComplete / 10)
            $bar    = ("█" * $filled) + ("░" * (10 - $filled))
            Write-Host "   #$($rr.Number) [$($rr.Type)] $($rr.Title)" -ForegroundColor White
            Write-Host "   [$bar] $($rr.PercentComplete)% ($($rr.ClosedIssues)/$($rr.TotalIssues))" -ForegroundColor $rrPctColor
        }
        Write-Host ""
    }

    # Blocked paths
    if ($blockedPaths.Count -eq 0) {
        Write-Host "✅ No blocked paths — all chains have started" -ForegroundColor Green
    } else {
        Write-Host "🚧 Blocked paths (all-open dependency chains): $($blockedPaths.Count)" -ForegroundColor Yellow
        foreach ($path in $blockedPaths | Select-Object -First 5) {
            $pathStr = ($path | ForEach-Object { "#$_" }) -join " → "
            Write-Host "   $pathStr" -ForegroundColor DarkGray
        }
        if ($blockedPaths.Count -gt 5) {
            Write-Host "   ... and $($blockedPaths.Count - 5) more" -ForegroundColor DarkGray
        }
        Write-Host ""
    }

    # Critical path
    if ($criticalPathLength -eq 0) {
        Write-Host "✅ No critical path — no fully open dependency chains" -ForegroundColor Green
    } else {
        Write-Host "⚡ Critical path ($criticalPathLength steps):" -ForegroundColor Cyan
        $cpStr = ($criticalPath | ForEach-Object {
            $iss      = $issueMap[$_]
            $typeName = if ($iss -and $iss.issueType) { $iss.issueType.name } else { "Issue" }
            "#$_ [$typeName]"
        }) -join " → "
        Write-Host "   $cpStr" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# Emit structured object to pipeline
Write-Output $report
