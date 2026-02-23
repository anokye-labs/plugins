<#
.SYNOPSIS
    Find PRs linked to specific issues.

.DESCRIPTION
    Discovers which PRs are associated with specific issues through:
    - Development timeline events (closing references)
    - PR body/comments mentioning the issue
    - Issue timeline events showing linked PRs
    
    Returns PR numbers and their link types.

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER IssueNumber
    Issue number to find PRs for.

.PARAMETER IncludeClosed
    If set, includes closed/merged PRs in results.

.EXAMPLE
    .\Find-IssueByPR.ps1 -Owner anokye-labs -Repo plugins -IssueNumber 42

.EXAMPLE
    .\Find-IssueByPR.ps1 -Owner anokye-labs -Repo plugins -IssueNumber 42 -IncludeClosed
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$IssueNumber,
    [switch]$IncludeClosed
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\_Invoke-GraphQL.ps1"

# Query for issue timeline and linked PRs
$query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    issue(number: $IssueNumber) {
      number
      title
      state
      timelineItems(first: 100, itemTypes: [CONNECTED_EVENT, CROSS_REFERENCED_EVENT, CLOSED_EVENT]) {
        nodes {
          __typename
          ... on ConnectedEvent {
            createdAt
            subject {
              ... on PullRequest {
                number
                title
                state
                merged
              }
            }
          }
          ... on CrossReferencedEvent {
            createdAt
            source {
              ... on PullRequest {
                number
                title
                state
                merged
                body
              }
            }
          }
          ... on ClosedEvent {
            createdAt
            closer {
              ... on PullRequest {
                number
                title
                state
                merged
              }
            }
          }
        }
      }
    }
  }
}
"@

$result = Invoke-GraphQL -Query $query
$issue = $result.data.repository.issue

# Collect linked PRs
$linkedPRs = @{}

foreach ($event in $issue.timelineItems.nodes) {
    $pr = $null
    $linkType = $null
    
    switch ($event.__typename) {
        "ConnectedEvent" {
            if ($event.subject.number) {
                $pr = $event.subject
                $linkType = "CONNECTED"
            }
        }
        "CrossReferencedEvent" {
            if ($event.source.number) {
                $pr = $event.source
                $linkType = "REFERENCED"
            }
        }
        "ClosedEvent" {
            if ($event.closer.number) {
                $pr = $event.closer
                $linkType = "CLOSES"
            }
        }
    }
    
    if ($pr) {
        $prNumber = $pr.number
        
        # Skip if we already have this PR with a stronger link type
        if ($linkedPRs.ContainsKey($prNumber)) {
            # Priority: CLOSES > CONNECTED > REFERENCED
            $currentType = $linkedPRs[$prNumber].LinkType
            if ($currentType -eq "CLOSES" -or 
                ($currentType -eq "CONNECTED" -and $linkType -eq "REFERENCED")) {
                continue
            }
        }
        
        # Filter by state if needed
        if (-not $IncludeClosed) {
            if ($pr.state -eq "CLOSED" -or $pr.state -eq "MERGED") {
                continue
            }
        }
        
        $linkedPRs[$prNumber] = [PSCustomObject]@{
            PRNumber = $pr.number
            Title = $pr.title
            State = $pr.state
            Merged = $pr.merged ?? $false
            LinkType = $linkType
        }
    }
}

# Sort by PR number
$results = $linkedPRs.Values | Sort-Object -Property PRNumber

# Output
if ($results.Count -eq 0) {
    Write-Host "`nNo PRs linked to issue #$IssueNumber" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "`n━━━ PRs linked to issue #$IssueNumber ━━━" -ForegroundColor Cyan
    Write-Host "Issue: $($issue.title)" -ForegroundColor White
    Write-Host "State: $($issue.state)" -ForegroundColor Gray
    Write-Host ""
    
    foreach ($pr in $results) {
        $linkColor = switch ($pr.LinkType) {
            "CLOSES" { "Green" }
            "CONNECTED" { "Cyan" }
            "REFERENCED" { "Gray" }
            default { "White" }
        }
        
        $stateColor = switch ($pr.State) {
            "OPEN" { "Green" }
            "CLOSED" { "Red" }
            "MERGED" { "Magenta" }
            default { "White" }
        }
        
        Write-Host "  PR #$($pr.PRNumber) " -ForegroundColor White -NoNewline
        Write-Host "[$($pr.LinkType)]" -ForegroundColor $linkColor -NoNewline
        Write-Host " [$($pr.State)]" -ForegroundColor $stateColor
        Write-Host "    $($pr.Title)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Summary
    $byType = $results | Group-Object -Property LinkType
    Write-Host "Summary: $($results.Count) total" -ForegroundColor Gray
    foreach ($group in $byType) {
        Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# Output to pipeline
$results | ForEach-Object { Write-Output $_ }
