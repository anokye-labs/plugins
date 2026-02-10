# Test-Hierarchy.ps1
# Verify issue relationships via GraphQL using sub-issues API

param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$IssueNumber,
    [int]$Depth = 2
)

$ErrorActionPreference = "Stop"

function Get-IssueTree {
    param([string]$Owner, [string]$Repo, [int]$Number, [int]$Level = 0)
    
    $indent = "  " * $Level
    
    $query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    issue(number: $Number) {
      number
      title
      state
      issueType { name }
      subIssues(first: 50) {
        totalCount
        nodes {
          number
          title
          state
          issueType { name }
        }
      }
      parentIssue {
        number
        issueType { name }
      }
    }
  }
}
"@
    
    $rawResult = gh api graphql -H "GraphQL-Features: sub_issues" -f query="$query" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "GraphQL query failed. Ensure the sub-issues API is available and the GraphQL-Features header is supported: $rawResult"
        exit 1
    }
    
    $result = $rawResult | ConvertFrom-Json
    if ($result.errors) {
        Write-Error "GraphQL errors: $($result.errors | ConvertTo-Json -Compress)"
        exit 1
    }
    
    $issue = $result.data.repository.issue
    
    $typeColor = switch ($issue.issueType.name) {
        "Epic" { "Cyan" }
        "Feature" { "Green" }
        "Task" { "White" }
        "Bug" { "Red" }
        default { "Gray" }
    }
    
    $stateIcon = if ($issue.state -eq "CLOSED") { "✓" } else { "○" }
    
    Write-Host "${indent}${stateIcon} #$($issue.number) [$($issue.issueType.name)] $($issue.title)" -ForegroundColor $typeColor
    
    if ($issue.parentIssue -and $Level -eq 0) {
        Write-Host "${indent}  ↑ Parent: #$($issue.parentIssue.number) [$($issue.parentIssue.issueType.name)]" -ForegroundColor Gray
    }
    
    if ($issue.subIssues.totalCount -gt 0) {
        Write-Host "${indent}  ↓ Has $($issue.subIssues.totalCount) sub-issues:" -ForegroundColor Gray
        
        foreach ($child in $issue.subIssues.nodes) {
            if ($Level -lt $Depth) {
                Get-IssueTree -Owner $Owner -Repo $Repo -Number $child.number -Level ($Level + 1)
            } else {
                $childStateIcon = if ($child.state -eq "CLOSED") { "✓" } else { "○" }
                $childIndent = "  " * ($Level + 1)
                Write-Host "${childIndent}${childStateIcon} #$($child.number) [$($child.issueType.name)] $($child.title)" -ForegroundColor Gray
            }
        }
    }
    
    return $issue
}

Write-Host "`nHierarchy for #${IssueNumber}:" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Get-IssueTree -Owner $Owner -Repo $Repo -Number $IssueNumber | Out-Null
Write-Host ""
