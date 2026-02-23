# Test-Hierarchy.ps1
# Verify issue relationships via GraphQL using sub-issues API

param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$IssueNumber,
    [int]$Depth = 2
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\_Invoke-GraphQL.ps1"

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
    
    $result = Invoke-GraphQL -Query $query -Headers @{"GraphQL-Features" = "sub_issues"}

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
