<#
.SYNOPSIS
    Structural validation for the /health command.

.DESCRIPTION
    Queries all open issues, checks type distribution, finds orphans (issues
    without parents), validates hierarchy depth and type correctness. Returns a
    structured health report with a score.

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER Brief
    If set, returns compact summary.

.EXAMPLE
    .\Get-HierarchyHealth.ps1 -Owner anokye-labs -Repo akwaaba

.EXAMPLE
    .\Get-HierarchyHealth.ps1 -Owner anokye-labs -Repo akwaaba -Brief
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
        parent {
          number
          issueType { name }
        }
        subIssues(first: 50) {
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

# --- Type distribution ---

$typeCounts = @{
    Epic    = 0
    Feature = 0
    Task    = 0
    Bug     = 0
    Unknown = 0
}

foreach ($issue in $allIssues) {
    $typeName = if ($issue.issueType) { $issue.issueType.name } else { "Unknown" }
    if ($typeCounts.ContainsKey($typeName)) {
        $typeCounts[$typeName]++
    } else {
        $typeCounts["Unknown"]++
    }
}

# --- Orphan detection (issues with no parent that aren't Epics) ---

$orphans = @()
foreach ($issue in $allIssues) {
    $typeName = if ($issue.issueType) { $issue.issueType.name } else { "Unknown" }
    # Epics are roots — not orphans. Everything else needs a parent.
    if ($typeName -ne "Epic" -and -not $issue.parent) {
        $orphans += [PSCustomObject]@{
            Number = $issue.number
            Title  = $issue.title
            Type   = $typeName
        }
    }
}

# --- Type mismatch detection ---
# Rules: Epic can parent Feature or Task. Feature can parent Task. Task/Bug cannot parent.

$validChildren = @{
    "Epic"    = @("Feature", "Task")
    "Feature" = @("Task")
}

$typeMismatches = @()
foreach ($issue in $allIssues) {
    if (-not $issue.parent) { continue }

    $childType = if ($issue.issueType) { $issue.issueType.name } else { "Unknown" }
    $parentType = if ($issue.parent.issueType) { $issue.parent.issueType.name } else { "Unknown" }

    $allowed = $validChildren[$parentType]
    if ($null -eq $allowed -or $childType -notin $allowed) {
        $typeMismatches += [PSCustomObject]@{
            ChildNumber = $issue.number
            ChildType   = $childType
            ParentNumber = $issue.parent.number
            ParentType  = $parentType
            Expected    = if ($allowed) { $allowed -join "/" } else { "(cannot have children)" }
        }
    }
}

# --- Hierarchy depth calculation ---

function Get-Depth {
    param([object]$Issue, [hashtable]$IssueMap, [int]$CurrentDepth)

    $maxDepth = $CurrentDepth
    if ($Issue.subIssues -and $Issue.subIssues.nodes) {
        foreach ($child in $Issue.subIssues.nodes) {
            $childIssue = $IssueMap[$child.number]
            if ($childIssue) {
                $childDepth = Get-Depth -Issue $childIssue -IssueMap $IssueMap -CurrentDepth ($CurrentDepth + 1)
                if ($childDepth -gt $maxDepth) { $maxDepth = $childDepth }
            } else {
                if (($CurrentDepth + 1) -gt $maxDepth) { $maxDepth = $CurrentDepth + 1 }
            }
        }
    }
    return $maxDepth
}

$issueMap = @{}
foreach ($issue in $allIssues) {
    $issueMap[$issue.number] = $issue
}

$maxDepth = 0
$roots = $allIssues | Where-Object { -not $_.parent }
foreach ($root in $roots) {
    $depth = Get-Depth -Issue $root -IssueMap $issueMap -CurrentDepth 1
    if ($depth -gt $maxDepth) { $maxDepth = $depth }
}
if ($maxDepth -eq 0 -and $totalIssues -gt 0) { $maxDepth = 1 }

# --- Health score (0-100) ---

$score = 100

# Deduct for orphans (non-Epic issues without parents)
$orphanRatio = if ($totalIssues -gt 0) { $orphans.Count / $totalIssues } else { 0 }
$score -= [math]::Min(30, [math]::Floor($orphanRatio * 100))

# Deduct for type mismatches
$score -= [math]::Min(25, $typeMismatches.Count * 10)

# Deduct for excessive depth (>3 is unusual)
if ($maxDepth -gt 3) { $score -= ($maxDepth - 3) * 5 }

# Deduct for unknown types
if ($typeCounts["Unknown"] -gt 0) {
    $score -= [math]::Min(15, $typeCounts["Unknown"] * 5)
}

$score = [math]::Max(0, $score)

# Depth label
$depthLabel = switch ($maxDepth) {
    1 { "flat (issues only)" }
    2 { "Epic → Task" }
    3 { "Epic → Feature → Task" }
    default { "$maxDepth levels (deep)" }
}

# --- Build result ---

$healthReport = [PSCustomObject]@{
    Owner          = $Owner
    Repo           = $Repo
    TotalIssues    = $totalIssues
    TypeCounts     = [PSCustomObject]$typeCounts
    Orphans        = $orphans
    OrphanCount    = $orphans.Count
    TypeMismatches = $typeMismatches
    MismatchCount  = $typeMismatches.Count
    MaxDepth       = $maxDepth
    DepthLabel     = $depthLabel
    HealthScore    = $score
}

# --- Display ---

if ($Brief) {
    $orphanIcon = if ($orphans.Count -eq 0) { "✅" } else { "⚠️" }
    $mismatchIcon = if ($typeMismatches.Count -eq 0) { "✅" } else { "❌" }
    $summary = "${Owner}/${Repo}: ${totalIssues} issues | ${orphanIcon} $($orphans.Count) orphans | ${mismatchIcon} $($typeMismatches.Count) mismatches | Score: ${score}/100"
    Write-Host $summary -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "🏥 Hierarchy Health: $Owner/$Repo" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📊 Issues: $totalIssues open" -ForegroundColor White
    Write-Host "   Epic: $($typeCounts.Epic) │ Feature: $($typeCounts.Feature) │ Task: $($typeCounts.Task) │ Bug: $($typeCounts.Bug)" -ForegroundColor Gray
    if ($typeCounts.Unknown -gt 0) {
        Write-Host "   ⚠️ Unknown type: $($typeCounts.Unknown)" -ForegroundColor Yellow
    }

    # Orphans
    if ($orphans.Count -eq 0) {
        Write-Host "✅ No orphans — all non-Epic issues have parents" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Orphans (no parent): $($orphans.Count)" -ForegroundColor Yellow
        foreach ($o in $orphans | Select-Object -First 10) {
            Write-Host "   #$($o.Number) $($o.Type): $($o.Title)" -ForegroundColor DarkGray
        }
        if ($orphans.Count -gt 10) {
            Write-Host "   ... and $($orphans.Count - 10) more" -ForegroundColor DarkGray
        }
    }

    # Type mismatches
    if ($typeMismatches.Count -eq 0) {
        Write-Host "✅ No type mismatches" -ForegroundColor Green
    } else {
        Write-Host "❌ Type mismatches: $($typeMismatches.Count)" -ForegroundColor Red
        foreach ($m in $typeMismatches | Select-Object -First 10) {
            Write-Host "   #$($m.ChildNumber) $($m.ChildType) is child of #$($m.ParentNumber) $($m.ParentType) (expected: $($m.Expected))" -ForegroundColor DarkGray
        }
    }

    # Depth
    $depthIcon = if ($maxDepth -le 3) { "✅" } else { "⚠️" }
    Write-Host "🏗️ Max depth: $maxDepth ($depthLabel) $depthIcon" -ForegroundColor White

    # Score
    $scoreColor = if ($score -ge 80) { "Green" } elseif ($score -ge 50) { "Yellow" } else { "Red" }
    Write-Host "💯 Health score: $score/100" -ForegroundColor $scoreColor
    Write-Host ""
}

# Emit structured object to pipeline
Write-Output $healthReport
