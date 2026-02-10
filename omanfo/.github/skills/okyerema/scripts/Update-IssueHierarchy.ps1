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

$result = gh api graphql -f query="$parentQuery" | ConvertFrom-Json
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
    
    $childResult = gh api graphql -f query="$childQuery" | ConvertFrom-Json
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
    
    $addResult = gh api graphql -H "GraphQL-Features: sub_issues" -f query="$addMutation" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Added #$($child.Number) - $($child.Title)" -ForegroundColor Gray
        $successCount++
        $successfulNumbers += $child.Number
    } else {
        Write-Host "  ⚠ Failed to add #$($child.Number): $addResult" -ForegroundColor Yellow
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
