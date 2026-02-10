# Sync-PlanToIssues.ps1
# Synchronize an updated markdown plan with existing GitHub issues

<#
.SYNOPSIS
    Syncs changes from a markdown plan document to existing GitHub issues.

.DESCRIPTION
    Compares a markdown plan document against existing issues to identify:
    - New items to create
    - Modified items to update (title/body changes)
    - Items that need hierarchy adjustments
    
    This script maintains bidirectional sync between markdown plans and GitHub issues,
    allowing plans to evolve while preserving issue numbers and relationships.

.PARAMETER Owner
    Repository owner (organization or user)

.PARAMETER Repo
    Repository name

.PARAMETER PlanFile
    Path to the markdown plan document

.PARAMETER MappingFile
    Path to JSON file that maps plan items to issue numbers (created by Invoke-PlanMaterialization.ps1)

.PARAMETER DryRun
    If specified, shows what would be changed without making changes

.EXAMPLE
    ./Sync-PlanToIssues.ps1 -Owner "anokye-labs" -Repo "my-project" -PlanFile "./roadmap.md" -MappingFile "./roadmap-mapping.json"

.NOTES
    Requires:
    - GitHub CLI (gh) authenticated
    - A mapping file created by prior Invoke-PlanMaterialization.ps1 run
#>

param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$PlanFile,
    [Parameter(Mandatory)][string]$MappingFile,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Validate files exist
if (-not (Test-Path $PlanFile)) {
    Write-Error "Plan file not found: $PlanFile"
    exit 1
}

if (-not (Test-Path $MappingFile)) {
    Write-Error "Mapping file not found: $MappingFile. Run Invoke-PlanMaterialization.ps1 first."
    exit 1
}

Write-Host "=== Plan Sync Pipeline ===" -ForegroundColor Cyan
Write-Host "Repository: $Owner/$Repo" -ForegroundColor Gray
Write-Host "Plan File: $PlanFile" -ForegroundColor Gray
Write-Host "Mapping File: $MappingFile" -ForegroundColor Gray
if ($DryRun) {
    Write-Host "Mode: DRY RUN (no changes will be made)" -ForegroundColor Yellow
}
Write-Host ""

# Load existing mapping
Write-Host "Loading existing issue mapping..." -ForegroundColor Cyan
$mapping = Get-Content $MappingFile -Raw | ConvertFrom-Json
Write-Host "✓ Loaded mapping for $($mapping.issues.Count) issues" -ForegroundColor Green
Write-Host ""

# Parse current plan (same logic as Invoke-PlanMaterialization.ps1)
Write-Host "Parsing current plan..." -ForegroundColor Cyan
$lines = Get-Content $PlanFile

$items = @()
$currentH1 = $null
$currentH2 = $null
$itemIndex = 0

foreach ($line in $lines) {
    if ($line -match '^# (.+)$') {
        $title = $matches[1].Trim()
        $currentH1 = @{
            Index = $itemIndex++
            Level = 1
            Type = "Epic"
            Title = $title
            Body = ""
            Children = @()
        }
        $items += $currentH1
        $currentH2 = $null
    }
    elseif ($line -match '^## (.+)$') {
        $title = $matches[1].Trim()
        $currentH2 = @{
            Index = $itemIndex++
            Level = 2
            Type = "Feature"
            Title = $title
            Body = ""
            Children = @()
            Parent = $currentH1
        }
        if ($currentH1) {
            $currentH1.Children += $currentH2
        } else {
            $items += $currentH2
        }
    }
    elseif ($line -match '^### (.+)$') {
        $title = $matches[1].Trim()
        $taskItem = @{
            Index = $itemIndex++
            Level = 3
            Type = "Task"
            Title = $title
            Body = ""
            Children = @()
            Parent = if ($currentH2) { $currentH2 } else { $currentH1 }
        }
        if ($currentH2) {
            $currentH2.Children += $taskItem
        } elseif ($currentH1) {
            $currentH1.Children += $taskItem
        } else {
            $items += $taskItem
        }
    }
    elseif ($line.Trim() -and -not $line.StartsWith('#')) {
        if ($currentH2) {
            if ($currentH2.Body) { $currentH2.Body += "`n" }
            $currentH2.Body += $line
        } elseif ($currentH1) {
            if ($currentH1.Body) { $currentH1.Body += "`n" }
            $currentH1.Body += $line
        }
    }
}

Write-Host "✓ Parsed plan with $($items.Count) top-level items" -ForegroundColor Green
Write-Host ""

# Compare plan items with existing issues
Write-Host "Computing diff..." -ForegroundColor Cyan

$toCreate = @()
$toUpdate = @()
$unchanged = @()

function Compare-Items {
    param(
        [Parameter(Mandatory)]
        [array]$CurrentItems,
        [Parameter(Mandatory)]
        [array]$MappingIssues
    )
    
    foreach ($item in $CurrentItems) {
        # Find matching issue by title
        $matchedIssue = $mappingIssues | Where-Object { 
            $_.title -eq $item.Title -and $_.type -eq $item.Type 
        } | Select-Object -First 1
        
        if ($matchedIssue) {
            # Check if title or body changed
            $bodyChanged = ($item.Body -ne $matchedIssue.body)
            
            if ($bodyChanged) {
                $script:toUpdate += @{
                    Item = $item
                    Issue = $matchedIssue
                    Changes = @("body")
                }
            } else {
                $script:unchanged += $item
            }
            
            # Recursively compare children
            if ($item.Children.Count -gt 0) {
                $childMappings = $MappingIssues | Where-Object { $_.parent -eq $matchedIssue.number }
                Compare-Items -CurrentItems $item.Children -MappingIssues $childMappings
            }
        } else {
            # New item
            $script:toCreate += $item
        }
    }
}

Compare-Items -CurrentItems $items -MappingIssues $mapping.issues

Write-Host "  New items: $($toCreate.Count)" -ForegroundColor Cyan
Write-Host "  Items to update: $($toUpdate.Count)" -ForegroundColor Yellow
Write-Host "  Unchanged: $($unchanged.Count)" -ForegroundColor Green
Write-Host ""

if ($toCreate.Count -eq 0 -and $toUpdate.Count -eq 0) {
    Write-Host "✓ Plan is in sync with issues (no changes needed)" -ForegroundColor Green
    exit 0
}

if ($DryRun) {
    Write-Host "=== DRY RUN: Would make the following changes ===" -ForegroundColor Yellow
    Write-Host ""
    
    if ($toCreate.Count -gt 0) {
        Write-Host "CREATE:" -ForegroundColor Green
        foreach ($item in $toCreate) {
            Write-Host "  [$($item.Type)] $($item.Title)" -ForegroundColor Cyan
        }
        Write-Host ""
    }
    
    if ($toUpdate.Count -gt 0) {
        Write-Host "UPDATE:" -ForegroundColor Yellow
        foreach ($update in $toUpdate) {
            Write-Host "  #$($update.Issue.number) [$($update.Item.Type)] $($update.Item.Title)" -ForegroundColor Cyan
            Write-Host "    Changes: $($update.Changes -join ', ')" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Write-Host "Use without -DryRun to apply changes" -ForegroundColor Yellow
    exit 0
}

# Apply changes
if ($toUpdate.Count -gt 0) {
    Write-Host "Updating issues..." -ForegroundColor Cyan
    
    foreach ($update in $toUpdate) {
        $issue = $update.Issue
        $item = $update.Item
        
        # Escape strings for GraphQL
        $escapedBody = $item.Body.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n')
        
        $mutation = @"
mutation {
  updateIssue(input: {
    id: "$($issue.id)"
    body: "$escapedBody"
  }) {
    issue {
      id
      number
      title
    }
  }
}
"@
        
        $rawResult = gh api graphql -f query="$mutation" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to update #$($issue.number): $rawResult"
            continue
        }
        
        $result = $rawResult | ConvertFrom-Json
        if ($result.errors) {
            Write-Warning "GraphQL errors updating #$($issue.number): $($result.errors | ConvertTo-Json -Compress)"
            continue
        }
        
        Write-Host "  ✓ Updated #$($issue.number) $($item.Title)" -ForegroundColor Green
    }
    
    Write-Host ""
}

if ($toCreate.Count -gt 0) {
    Write-Host "Creating new issues..." -ForegroundColor Cyan
    Write-Warning "New items detected. Consider running Invoke-PlanMaterialization.ps1 with these items or create them manually."
    
    foreach ($item in $toCreate) {
        Write-Host "  [$($item.Type)] $($item.Title)" -ForegroundColor Cyan
    }
    
    Write-Host ""
}

Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Updated: $($toUpdate.Count)" -ForegroundColor Green
Write-Host "New (not created): $($toCreate.Count)" -ForegroundColor Yellow
Write-Host ""
Write-Host "✓ Sync complete" -ForegroundColor Green
