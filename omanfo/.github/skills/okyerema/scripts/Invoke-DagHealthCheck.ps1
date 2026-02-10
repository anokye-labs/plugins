<#
.SYNOPSIS
    DAG structural validation for issue hierarchies.

.DESCRIPTION
    Validates the Directed Acyclic Graph (DAG) structure of issue hierarchies.
    Checks for cycles (circular dependencies), orphaned issues (not reachable from
    any root), and validates parent-child relationship integrity. Returns a
    structured health report with a 0-100 score.

.PARAMETER Owner
    Repository owner (organization or user).

.PARAMETER Repo
    Repository name.

.PARAMETER Brief
    If set, returns compact single-line summary.

.EXAMPLE
    .\Invoke-DagHealthCheck.ps1 -Owner anokye-labs -Repo akwaaba

.EXAMPLE
    .\Invoke-DagHealthCheck.ps1 -Owner anokye-labs -Repo akwaaba -Brief
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [switch]$Brief
)

$ErrorActionPreference = "Stop"

# --- Paginated fetch of all open issues with hierarchy fields ---

$allIssues = @()
$hasNextPage = $true
$cursor = $null

while ($hasNextPage) {
    $afterClause = if ($cursor) { ", after: `"$cursor`"" } else { "" }

    $query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    issues(states: OPEN, first: 100$afterClause, orderBy: {field: CREATED_AT, direction: ASC}) {
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
          issueType { name }
        }
        subIssues(first: 100) {
          totalCount
          nodes {
            number
            issueType { name }
            state
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

# --- Build adjacency map and reverse map ---

$childToParent = @{}  # number -> parent number
$parentToChildren = @{}  # number -> array of child numbers

foreach ($issue in $allIssues) {
    $num = $issue.number
    
    # Track parent relationship
    if ($issue.parentIssue) {
        $childToParent[$num] = $issue.parentIssue.number
    }
    
    # Track children relationships
    if ($issue.subIssues -and $issue.subIssues.nodes) {
        $children = @()
        foreach ($child in $issue.subIssues.nodes) {
            if ($child.state -eq "OPEN") {
                $children += $child.number
            }
        }
        if ($children.Count -gt 0) {
            $parentToChildren[$num] = $children
        }
    }
}

# --- Cycle detection using DFS with colors ---
# White (0) = unvisited, Gray (1) = in progress, Black (2) = completed

$colors = @{}
$cycles = @()

function Find-Cycles {
    param([int]$Node, [System.Collections.Generic.List[int]]$Path)
    
    if ($colors[$Node] -eq 1) {
        # Back edge detected - cycle found
        $cycleStart = $Path.IndexOf($Node)
        if ($cycleStart -ge 0) {
            $cycle = $Path.GetRange($cycleStart, $Path.Count - $cycleStart)
            $cycle += $Node
            return $cycle
        }
    }
    
    if ($colors[$Node] -eq 2) {
        # Already processed
        return $null
    }
    
    $colors[$Node] = 1  # Gray - in progress
    $Path.Add($Node)
    
    # Visit children
    if ($parentToChildren.ContainsKey($Node)) {
        foreach ($child in $parentToChildren[$Node]) {
            $cycle = Find-Cycles -Node $child -Path $Path
            if ($cycle) {
                # Clean up before returning cycle
                $Path.RemoveAt($Path.Count - 1)
                $colors[$Node] = 2  # Black - completed
                return $cycle
            }
        }
    }
    
    $Path.RemoveAt($Path.Count - 1)
    $colors[$Node] = 2  # Black - completed
    return $null
}

# Initialize all nodes as unvisited
foreach ($issue in $allIssues) {
    $colors[$issue.number] = 0
}

# Run cycle detection from each unvisited node
foreach ($issue in $allIssues) {
    if ($colors[$issue.number] -eq 0) {
        $path = New-Object System.Collections.Generic.List[int]
        $cycle = Find-Cycles -Node $issue.number -Path $path
        if ($cycle) {
            $cycles += ,@($cycle)  # Add as array element
        }
    }
}

# Remove duplicate cycles (same cycle detected from different starting points)
$uniqueCycles = @()
$seenCycles = @{}
foreach ($cycle in $cycles) {
    $sorted = ($cycle | Sort-Object) -join ","
    if (-not $seenCycles.ContainsKey($sorted)) {
        $seenCycles[$sorted] = $true
        $uniqueCycles += ,$cycle
    }
}

# --- Orphan detection (issues not reachable from any root) ---

$roots = @()
foreach ($issue in $allIssues) {
    if (-not $childToParent.ContainsKey($issue.number)) {
        $roots += $issue.number
    }
}

$reachable = @{}

function Mark-Reachable {
    param([int]$Node)
    
    if ($reachable.ContainsKey($Node)) {
        return  # Already visited
    }
    
    $reachable[$Node] = $true
    
    # Visit children
    if ($parentToChildren.ContainsKey($Node)) {
        foreach ($child in $parentToChildren[$Node]) {
            Mark-Reachable -Node $child
        }
    }
}

# Mark all nodes reachable from roots
foreach ($root in $roots) {
    Mark-Reachable -Node $root
}

# Find orphans (not reachable from any root)
$orphans = @()
foreach ($issue in $allIssues) {
    if (-not $reachable.ContainsKey($issue.number)) {
        $orphans += [PSCustomObject]@{
            Number = $issue.number
            Title  = $issue.title
            Type   = if ($issue.issueType) { $issue.issueType.name } else { "Unknown" }
        }
    }
}

# --- Broken relationship validation ---
# Check for issues that reference parents that don't exist or aren't open

$brokenRefs = @()
$issueNumbers = @{}
foreach ($issue in $allIssues) {
    $issueNumbers[$issue.number] = $true
}

foreach ($issue in $allIssues) {
    if ($issue.parentIssue) {
        $parentNum = $issue.parentIssue.number
        if (-not $issueNumbers.ContainsKey($parentNum)) {
            $brokenRefs += [PSCustomObject]@{
                ChildNumber = $issue.number
                ChildTitle  = $issue.title
                ParentNumber = $parentNum
                Reason = "Parent issue #$parentNum not found or not open"
            }
        }
    }
}

# --- Health score calculation (0-100) ---

$score = 100

# Deduct for cycles (critical - up to 40 points total)
# Use logarithmic scaling to penalize additional cycles while respecting the cap
if ($uniqueCycles.Count -gt 0) {
    $cycleDeduction = [math]::Min(40, 15 + [math]::Floor(15 * [math]::Log($uniqueCycles.Count + 1, 2)))
    $score -= $cycleDeduction
}

# Deduct for orphans (up to 30 points penalty, scaled by ratio)
if ($totalIssues -gt 0) {
    $orphanRatio = $orphans.Count / $totalIssues
    $score -= [math]::Min(30, [math]::Floor($orphanRatio * 100))
}

# Deduct for broken relationships (15 points per broken ref, max 25)
$score -= [math]::Min(25, $brokenRefs.Count * 15)

$score = [math]::Max(0, $score)

# --- Build result ---

$dagReport = [PSCustomObject]@{
    Owner           = $Owner
    Repo            = $Repo
    TotalIssues     = $totalIssues
    RootCount       = $roots.Count
    Cycles          = $uniqueCycles
    CycleCount      = $uniqueCycles.Count
    Orphans         = $orphans
    OrphanCount     = $orphans.Count
    BrokenRefs      = $brokenRefs
    BrokenRefCount  = $brokenRefs.Count
    ReachableCount  = $reachable.Count
    HealthScore     = $score
}

# --- Display ---

if ($Brief) {
    $cycleIcon = if ($uniqueCycles.Count -eq 0) { "✅" } else { "🔴" }
    $orphanIcon = if ($orphans.Count -eq 0) { "✅" } else { "⚠️" }
    $refIcon = if ($brokenRefs.Count -eq 0) { "✅" } else { "❌" }
    $summary = "${Owner}/${Repo}: ${totalIssues} issues | ${cycleIcon} $($uniqueCycles.Count) cycles | ${orphanIcon} $($orphans.Count) orphans | ${refIcon} $($brokenRefs.Count) broken refs | Score: ${score}/100"
    Write-Host $summary -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "🔍 DAG Health Check: $Owner/$Repo" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📊 Structure: $totalIssues open issues | $($roots.Count) roots | $($reachable.Count) reachable" -ForegroundColor White

    # Cycles
    if ($uniqueCycles.Count -eq 0) {
        Write-Host "✅ No cycles detected — DAG is acyclic" -ForegroundColor Green
    } else {
        Write-Host "🔴 Cycles detected: $($uniqueCycles.Count)" -ForegroundColor Red
        foreach ($cycle in $uniqueCycles | Select-Object -First 5) {
            $cycleStr = ($cycle | ForEach-Object { "#$_" }) -join " → "
            Write-Host "   $cycleStr" -ForegroundColor DarkGray
        }
        if ($uniqueCycles.Count -gt 5) {
            Write-Host "   ... and $($uniqueCycles.Count - 5) more cycles" -ForegroundColor DarkGray
        }
    }

    # Orphans
    if ($orphans.Count -eq 0) {
        Write-Host "✅ No orphans — all issues reachable from roots" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Orphans (not reachable from roots): $($orphans.Count)" -ForegroundColor Yellow
        foreach ($o in $orphans | Select-Object -First 10) {
            Write-Host "   #$($o.Number) $($o.Type): $($o.Title)" -ForegroundColor DarkGray
        }
        if ($orphans.Count -gt 10) {
            Write-Host "   ... and $($orphans.Count - 10) more" -ForegroundColor DarkGray
        }
    }

    # Broken refs
    if ($brokenRefs.Count -eq 0) {
        Write-Host "✅ No broken references" -ForegroundColor Green
    } else {
        Write-Host "❌ Broken references: $($brokenRefs.Count)" -ForegroundColor Red
        foreach ($br in $brokenRefs | Select-Object -First 5) {
            Write-Host "   #$($br.ChildNumber) references #$($br.ParentNumber) ($($br.Reason))" -ForegroundColor DarkGray
        }
        if ($brokenRefs.Count -gt 5) {
            Write-Host "   ... and $($brokenRefs.Count - 5) more" -ForegroundColor DarkGray
        }
    }

    # Score
    $scoreColor = if ($score -ge 80) { "Green" } elseif ($score -ge 50) { "Yellow" } else { "Red" }
    Write-Host "💯 DAG Health Score: $score/100" -ForegroundColor $scoreColor
    Write-Host ""
}

# Emit structured object to pipeline
Write-Output $dagReport
