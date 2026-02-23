# Update-IssueHierarchy.ps1
# Build parent-child relationships using GitHub's sub-issues API

param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$ParentNumber,
    [Parameter(Mandatory)][int[]]$ChildNumbers
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\_Invoke-GraphQL.ps1"

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

$result = Invoke-GraphQL -Query $parentQuery

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
    
    $childResult = Invoke-GraphQL -Query $childQuery

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
    
    try {
        $addResult = Invoke-GraphQL -Query $addMutation -Headers @{"GraphQL-Features" = "sub_issues"}
        Write-Host "  ✓ Added #$($child.Number) - $($child.Title)" -ForegroundColor Gray
        $successCount++
        $successfulNumbers += $child.Number
    } catch {
        Write-Host "  ⚠ Failed to add #$($child.Number): $_" -ForegroundColor Yellow
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
