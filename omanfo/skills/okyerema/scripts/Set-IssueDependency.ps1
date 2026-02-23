<#
.SYNOPSIS
    Establish dependency relationships between issues (blocks/blocked-by).

.DESCRIPTION
    Creates or removes dependency relationships independent of parent-child hierarchy.
    Dependencies are tracked via structured comments in issue bodies/comments.
    Supports querying dependencies in both directions for DAG readiness checks.

.PARAMETER Owner
    Repository owner (organization or user).

.PARAMETER Repo
    Repository name.

.PARAMETER IssueNumber
    The issue number to set dependencies for.

.PARAMETER Blocks
    Array of issue numbers that this issue blocks (this issue must be completed first).

.PARAMETER BlockedBy
    Array of issue numbers that block this issue (these must be completed first).

.PARAMETER Action
    Action to perform: Add (default), Remove, Query.

.EXAMPLE
    .\Set-IssueDependency.ps1 -Owner anokye-labs -Repo plugins -IssueNumber 22 -BlockedBy 4,53

.EXAMPLE
    .\Set-IssueDependency.ps1 -Owner anokye-labs -Repo plugins -IssueNumber 4 -Blocks 22 -Action Add

.EXAMPLE
    .\Set-IssueDependency.ps1 -Owner anokye-labs -Repo plugins -IssueNumber 22 -Action Query
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$IssueNumber,
    [int[]]$Blocks = @(),
    [int[]]$BlockedBy = @(),
    [ValidateSet('Add', 'Remove', 'Query')]
    [string]$Action = 'Add'
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\_Invoke-GraphQL.ps1"

# Helper function to escape strings for GraphQL
function Escape-GraphQLString {
    param([string]$text)
    return $text.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n')
}

# Helper function to parse dependencies from issue body/comments
function Get-IssueDependencies {
    param(
        [string]$Owner,
        [string]$Repo,
        [int]$IssueNumber
    )
    
    $query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    issue(number: $IssueNumber) {
      number
      title
      body
      comments(first: 100) {
        nodes {
          body
          author { login }
        }
      }
    }
  }
}
"@
    
    $result = Invoke-GraphQL -Query $query
    $issue = $result.data.repository.issue
    
    $dependencies = @{
        Blocks = @()
        BlockedBy = @()
    }
    
    # Parse body and comments for dependency markers
    $allText = @($issue.body)
    if ($issue.comments.nodes) {
        $allText += $issue.comments.nodes | ForEach-Object { $_.body }
    }
    
    foreach ($text in $allText) {
        if (-not $text) { continue }
        
        # Match "Blocked by #N" or "Blocked by: #N" or "Blocked by anokye-labs/repo#N"
        $blockedByMatches = [regex]::Matches($text, '(?i)blocked\s*by:?\s*(?:[\w-]+/[\w-]+)?#(\d+)')
        foreach ($match in $blockedByMatches) {
            $num = [int]$match.Groups[1].Value
            if ($num -notin $dependencies.BlockedBy) {
                $dependencies.BlockedBy += $num
            }
        }
        
        # Match "Blocks #N" or "Blocks: #N"
        $blocksMatches = [regex]::Matches($text, '(?i)blocks:?\s*(?:[\w-]+/[\w-]+)?#(\d+)')
        foreach ($match in $blocksMatches) {
            $num = [int]$match.Groups[1].Value
            if ($num -notin $dependencies.Blocks) {
                $dependencies.Blocks += $num
            }
        }
        
        # Match "Depends on #N" (equivalent to blocked by)
        $dependsMatches = [regex]::Matches($text, '(?i)depends\s*on:?\s*(?:[\w-]+/[\w-]+)?#(\d+)')
        foreach ($match in $dependsMatches) {
            $num = [int]$match.Groups[1].Value
            if ($num -notin $dependencies.BlockedBy) {
                $dependencies.BlockedBy += $num
            }
        }
    }
    
    return $dependencies
}

# Get issue ID for mutations
function Get-IssueId {
    param(
        [string]$Owner,
        [string]$Repo,
        [int]$Number
    )
    
    $query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    issue(number: $Number) {
      id
      number
      title
      state
    }
  }
}
"@
    
    $result = Invoke-GraphQL -Query $query
    return $result.data.repository.issue
}

# Main logic
switch ($Action) {
    'Query' {
        Write-Host "Querying dependencies for #${IssueNumber}..." -ForegroundColor Cyan
        $deps = Get-IssueDependencies -Owner $Owner -Repo $Repo -IssueNumber $IssueNumber
        
        Write-Host "`nIssue #${IssueNumber} dependencies:" -ForegroundColor White
        
        if ($deps.BlockedBy.Count -gt 0) {
            Write-Host "  Blocked by: #$($deps.BlockedBy -join ', #')" -ForegroundColor Yellow
        } else {
            Write-Host "  Blocked by: (none)" -ForegroundColor Gray
        }
        
        if ($deps.Blocks.Count -gt 0) {
            Write-Host "  Blocks: #$($deps.Blocks -join ', #')" -ForegroundColor Yellow
        } else {
            Write-Host "  Blocks: (none)" -ForegroundColor Gray
        }
        
        # Return object for programmatic use
        return [PSCustomObject]@{
            IssueNumber = $IssueNumber
            BlockedBy = $deps.BlockedBy
            Blocks = $deps.Blocks
        }
    }
    
    'Add' {
        # Verify issue exists
        $issue = Get-IssueId -Owner $Owner -Repo $Repo -Number $IssueNumber
        if (-not $issue) {
            Write-Error "Issue #${IssueNumber} not found"
            return
        }
        
        if ($issue.state -eq 'CLOSED') {
            Write-Warning "Issue #${IssueNumber} is closed. Dependencies may not be relevant."
        }
        
        # Get current dependencies to avoid duplicates
        $currentDeps = Get-IssueDependencies -Owner $Owner -Repo $Repo -IssueNumber $IssueNumber
        
        # Filter out dependencies that already exist
        $newBlocks = $Blocks | Where-Object { $_ -notin $currentDeps.Blocks }
        $newBlockedBy = $BlockedBy | Where-Object { $_ -notin $currentDeps.BlockedBy }
        
        if ($newBlocks.Count -eq 0 -and $newBlockedBy.Count -eq 0) {
            Write-Host "✓ No new dependencies to add (all already exist)" -ForegroundColor Green
            return
        }
        
        # Build comment body
        $commentParts = @()
        
        if ($newBlockedBy.Count -gt 0) {
            $blockedByList = $newBlockedBy | ForEach-Object { "#$_" }
            $commentParts += "**Blocked by** " + ($blockedByList -join ', ')
        }
        
        if ($newBlocks.Count -gt 0) {
            $blocksList = $newBlocks | ForEach-Object { "#$_" }
            $commentParts += "**Blocks** " + ($blocksList -join ', ')
        }
        
        $commentBody = ($commentParts -join ' — ')
        $escapedBody = Escape-GraphQLString -text $commentBody
        
        # Add comment with dependency markers
        $mutation = @"
mutation {
  addComment(input: {
    subjectId: `"$($issue.id)`"
    body: `"$escapedBody`"
  }) {
    commentEdge {
      node {
        id
        body
      }
    }
  }
}
"@
        
        $result = Invoke-GraphQL -Query $mutation

        Write-Host "✓ Added dependencies to #${IssueNumber}" -ForegroundColor Green
        if ($newBlockedBy.Count -gt 0) {
            Write-Host "  Blocked by: #$($newBlockedBy -join ', #')" -ForegroundColor Gray
        }
        if ($newBlocks.Count -gt 0) {
            Write-Host "  Blocks: #$($newBlocks -join ', #')" -ForegroundColor Gray
        }
        
        # Verify and display all dependencies
        Write-Host "`nAll dependencies for #${IssueNumber}:" -ForegroundColor Cyan
        $allDeps = Get-IssueDependencies -Owner $Owner -Repo $Repo -IssueNumber $IssueNumber
        if ($allDeps.BlockedBy.Count -gt 0) {
            Write-Host "  Blocked by: #$($allDeps.BlockedBy -join ', #')" -ForegroundColor Gray
        } else {
            Write-Host "  Blocked by: (none)" -ForegroundColor Gray
        }
        if ($allDeps.Blocks.Count -gt 0) {
            Write-Host "  Blocks: #$($allDeps.Blocks -join ', #')" -ForegroundColor Gray
        } else {
            Write-Host "  Blocks: (none)" -ForegroundColor Gray
        }
    }
    
    'Remove' {
        Write-Warning "Remove action not yet implemented. To remove dependencies:"
        Write-Host "  1. Edit the issue body or delete the comment containing the dependency marker"
        Write-Host "  2. Or manually edit the comment to remove the 'Blocked by #N' or 'Blocks #N' text"
        Write-Host "`nNote: This is by design - dependency removal requires human review to avoid breaking DAG consistency."
    }
}
