<#
.SYNOPSIS
    Find issues that exist outside any hierarchy.

.DESCRIPTION
    Queries all open issues and identifies orphans — issues without a parent
    Epic or Feature. Epics are considered roots (not orphans). Optionally
    suggests parent assignment based on issue labels and context.

    This script is part of the Sankofa patrol system for maintaining clean
    issue hierarchies.

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER Brief
    If set, returns compact summary.

.PARAMETER SuggestParents
    If set, suggests potential parent issues for orphans based on labels and title patterns.

.EXAMPLE
    .\Get-OrphanedIssues.ps1 -Owner anokye-labs -Repo akwaaba

.EXAMPLE
    .\Get-OrphanedIssues.ps1 -Owner anokye-labs -Repo akwaaba -Brief

.EXAMPLE
    .\Get-OrphanedIssues.ps1 -Owner anokye-labs -Repo akwaaba -SuggestParents
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [switch]$Brief,
    [switch]$SuggestParents
)

$ErrorActionPreference = "Stop"

# --- Constants for parent suggestion logic ---
$MinWordLength = 3    # Minimum word length to consider for keyword matching
$MaxKeywords = 5      # Maximum number of keywords to extract from orphan titles

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
        labels(first: 10) {
          nodes {
            name
          }
        }
        parentIssue {
          number
          issueType { name }
          title
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

# --- Orphan detection (issues with no parent that aren't Epics) ---

$orphans = @()
foreach ($issue in $allIssues) {
    $typeName = if ($issue.issueType) { $issue.issueType.name } else { "Unknown" }
    # Epics are roots — not orphans. Everything else needs a parentIssue.
    if ($typeName -ne "Epic" -and -not $issue.parentIssue) {
        $labels = @()
        if ($issue.labels -and $issue.labels.nodes) {
            $labels = $issue.labels.nodes | ForEach-Object { $_.name }
        }
        
        $orphans += [PSCustomObject]@{
            Number = $issue.number
            Title  = $issue.title
            Type   = $typeName
            Labels = $labels
            SuggestedParent = $null
        }
    }
}

# --- Suggest parent assignments if requested ---

if ($SuggestParents -and $orphans.Count -gt 0) {
    # Get all potential parents (Epics and Features)
    $potentialParents = $allIssues | Where-Object {
        $type = if ($_.issueType) { $_.issueType.name } else { "Unknown" }
        $type -in @("Epic", "Feature")
    }
    
    foreach ($orphan in $orphans) {
        $suggestions = @()
        
        # Try to match by labels
        if ($orphan.Labels.Count -gt 0) {
            foreach ($parent in $potentialParents) {
                $parentLabels = @()
                if ($parent.labels -and $parent.labels.nodes) {
                    $parentLabels = $parent.labels.nodes | ForEach-Object { $_.name }
                }
                
                # Count label overlap
                $overlap = 0
                foreach ($label in $orphan.Labels) {
                    if ($label -in $parentLabels) {
                        $overlap++
                    }
                }
                
                if ($overlap -gt 0) {
                    $suggestions += [PSCustomObject]@{
                        Number = $parent.number
                        Title  = $parent.title
                        Type   = if ($parent.issueType) { $parent.issueType.name } else { "Unknown" }
                        Score  = $overlap
                        Reason = "$overlap shared label(s)"
                    }
                }
            }
        }
        
        # Try to match by title keywords
        $orphanWords = ($orphan.Title -split '\s+' | Where-Object { $_.Length -gt $MinWordLength }) | Select-Object -First $MaxKeywords
        foreach ($parent in $potentialParents) {
            $parentWords = ($parent.title -split '\s+' | Where-Object { $_.Length -gt $MinWordLength })
            $wordMatches = 0
            foreach ($word in $orphanWords) {
                if ($word -in $parentWords) {
                    $wordMatches++
                }
            }
            
            if ($wordMatches -gt 0) {
                # Check if already suggested via labels
                $existing = $suggestions | Where-Object { $_.Number -eq $parent.number }
                if ($existing) {
                    $existing.Score += $wordMatches
                    $existing.Reason += ", $wordMatches keyword match(es)"
                } else {
                    $suggestions += [PSCustomObject]@{
                        Number = $parent.number
                        Title  = $parent.title
                        Type   = if ($parent.issueType) { $parent.issueType.name } else { "Unknown" }
                        Score  = $wordMatches
                        Reason = "$wordMatches keyword match(es)"
                    }
                }
            }
        }
        
        # Sort by score and take top suggestion
        if ($suggestions.Count -gt 0) {
            $topSuggestion = $suggestions | Sort-Object -Property Score -Descending | Select-Object -First 1
            $orphan.SuggestedParent = $topSuggestion
        }
    }
}

# --- Build result ---

$orphanReport = [PSCustomObject]@{
    Owner           = $Owner
    Repo            = $Repo
    TotalIssues     = $totalIssues
    Orphans         = $orphans
    OrphanCount     = $orphans.Count
    SuggestionsEnabled = $SuggestParents.IsPresent
}

# --- Display ---

if ($Brief) {
    $icon = if ($orphans.Count -eq 0) { "✅" } else { "⚠️" }
    $summary = "${Owner}/${Repo}: $($orphans.Count) orphaned issue(s) out of ${totalIssues} total"
    Write-Host "$icon $summary" -ForegroundColor $(if ($orphans.Count -eq 0) { "Green" } else { "Yellow" })
} else {
    Write-Host ""
    Write-Host "🔍 Orphaned Issues Report: $Owner/$Repo" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📊 Total open issues: $totalIssues" -ForegroundColor White
    
    if ($orphans.Count -eq 0) {
        Write-Host "✅ No orphans — all non-Epic issues have parents" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Orphaned issues (no parent): $($orphans.Count)" -ForegroundColor Yellow
        Write-Host ""
        
        foreach ($o in $orphans) {
            $labelStr = if ($o.Labels.Count -gt 0) { " [" + ($o.Labels -join ", ") + "]" } else { "" }
            Write-Host "   #$($o.Number) [$($o.Type)] $($o.Title)$labelStr" -ForegroundColor White
            
            if ($SuggestParents -and $o.SuggestedParent) {
                $suggestion = $o.SuggestedParent
                Write-Host "      → Suggested parent: #$($suggestion.Number) [$($suggestion.Type)] $($suggestion.Title)" -ForegroundColor Gray
                Write-Host "        Reason: $($suggestion.Reason)" -ForegroundColor DarkGray
            }
            Write-Host ""
        }
        
        if (-not $SuggestParents) {
            Write-Host "💡 Tip: Use -SuggestParents to get parent assignment suggestions" -ForegroundColor Cyan
        }
    }
    Write-Host ""
}

# Emit structured object to pipeline
Write-Output $orphanReport
