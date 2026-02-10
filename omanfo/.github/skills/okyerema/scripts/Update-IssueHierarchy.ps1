# Update-IssueHierarchy.ps1
# Build parent-child relationships using GitHub's sub-issues API

param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$ParentNumber,
    [Parameter(Mandatory)][int[]]$ChildNumbers
)

$ErrorActionPreference = "Stop"

# Get parent issue ID
$parentQuery = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    issue(number: $ParentNumber) {
      id
      title
    }
  }
}
"@

$rawResult = gh api graphql -f query="$parentQuery" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "GraphQL query failed for parent issue #${ParentNumber}: $rawResult"
    exit 1
}

$result = $rawResult | ConvertFrom-Json
if ($result.errors) {
    Write-Error "GraphQL errors querying parent issue #${ParentNumber}: $($result.errors | ConvertTo-Json -Compress)"
    exit 1
}

$parentId = $result.data.repository.issue.id
$parentTitle = $result.data.repository.issue.title

Write-Host "Parent: #$ParentNumber - $parentTitle" -ForegroundColor Cyan

# Get child issue IDs
$childIds = @()
foreach ($num in $ChildNumbers) {
    $childQuery = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    issue(number: $num) {
      id
      title
    }
  }
}
"@
    
    $rawChildResult = gh api graphql -f query="$childQuery" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "GraphQL query failed for child issue #${num}: $rawChildResult"
        exit 1
    }
    
    $childResult = $rawChildResult | ConvertFrom-Json
    if ($childResult.errors) {
        Write-Error "GraphQL errors querying child issue #${num}: $($childResult.errors | ConvertTo-Json -Compress)"
        exit 1
    }
    
    $childIds += [PSCustomObject]@{
        Number = $num
        Id = $childResult.data.repository.issue.id
        Title = $childResult.data.repository.issue.title
    }
}

# Add each child as a sub-issue
$successCount = 0
$failedCount = 0
$successfulNumbers = @()
foreach ($child in $childIds) {
    $addMutation = @"
mutation {
  addSubIssue(input: {
    issueId: `"$parentId`"
    subIssueId: `"$($child.Id)`"
  }) {
    issue { id }
    subIssue { id }
  }
}
"@
    
    $rawAddResult = gh api graphql -H "GraphQL-Features: sub_issues" -f query="$addMutation" 2>&1
    if ($LASTEXITCODE -eq 0) {
        $addResult = $rawAddResult | ConvertFrom-Json
        if ($addResult.errors) {
            Write-Host "  ⚠ Failed to add #$($child.Number): $($addResult.errors | ConvertTo-Json -Compress)" -ForegroundColor Yellow
            $failedCount++
        } else {
            Write-Host "  ✓ Added #$($child.Number) - $($child.Title)" -ForegroundColor Gray
            $successCount++
            $successfulNumbers += $child.Number
        }
    } else {
        Write-Host "  ⚠ Failed to add #$($child.Number): $rawAddResult" -ForegroundColor Yellow
        $failedCount++
    }
}

if ($failedCount -gt 0) {
    Write-Host "✓ Updated #$ParentNumber with $successCount sub-issues ($failedCount failed)" -ForegroundColor Yellow
    if ($successfulNumbers.Count -gt 0) {
        Write-Host "  Successful: #$($successfulNumbers -join ', #')" -ForegroundColor Gray
    }
    exit 1
} else {
    Write-Host "✓ Updated #$ParentNumber with $successCount sub-issues" -ForegroundColor Green
    Write-Host "  Children: #$($ChildNumbers -join ', #')" -ForegroundColor Gray
}
