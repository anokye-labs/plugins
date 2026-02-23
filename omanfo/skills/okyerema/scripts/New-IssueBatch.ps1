# New-IssueBatch.ps1
# Batch create multiple GitHub issues with proper organization issue types

param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][array]$Issues  # Array of hashtables with Title, TypeName, Body, Labels
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\_Invoke-GraphQL.ps1"

# Get repo ID and type IDs once (optimization)
$query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    id
    owner {
      ... on Organization {
        issueTypes(first: 25) {
          nodes { id name }
        }
      }
    }
    labels(first: 100) {
      nodes { id name }
    }
  }
}
"@

$result = Invoke-GraphQL -Query $query

$repoId = $result.data.repository.id
$issueTypes = $result.data.repository.owner.issueTypes.nodes
$availableLabels = $result.data.repository.labels.nodes

Write-Host "Repository: $Owner/$Repo (ID: $repoId)" -ForegroundColor Cyan
Write-Host "Available issue types: $($issueTypes.name -join ', ')" -ForegroundColor Gray

# Create issues
$createdIssues = @()
$successCount = 0
$failedCount = 0

foreach ($issueSpec in $Issues) {
    $title = $issueSpec.Title
    $typeName = $issueSpec.TypeName
    $body = if ($issueSpec.Body) { $issueSpec.Body } else { "" }
    $labels = if ($issueSpec.Labels) { $issueSpec.Labels } else { @() }
    
    # Validate type
    $typeId = ($issueTypes | Where-Object { $_.name -eq $typeName }).id
    if (-not $typeId) {
        Write-Host "  ✗ Failed to create issue '$title': Type '$typeName' not found" -ForegroundColor Red
        $failedCount++
        continue
    }
    
    # Escape title and body for GraphQL
    $escapedTitle = $title.Replace('\', '\\').Replace('"', '\"')
    $escapedBody = $body.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n')
    
    # Create issue mutation
    $mutation = @"
mutation {
  createIssue(input: {
    repositoryId: `"$repoId`"
    title: `"$escapedTitle`"
    body: `"$escapedBody`"
    issueTypeId: `"$typeId`"
  }) {
    issue {
      id
      number
      title
      issueType { name }
      url
    }
  }
}
"@
    
    try {
        $createResult = Invoke-GraphQL -Query $mutation
        $issue = $createResult.data.createIssue.issue
        
        Write-Host "  ✓ Created #$($issue.number) [$($issue.issueType.name)] $($issue.title)" -ForegroundColor Green
        
        # Add labels if provided
        if ($labels.Count -gt 0) {
            $labelIds = $labels | ForEach-Object {
                $name = $_
                ($availableLabels | Where-Object { $_.name -eq $name }).id
            } | Where-Object { $_ }
            
            if ($labelIds.Count -gt 0) {
                $labelIdList = ($labelIds | ForEach-Object { "`"$_`"" }) -join ', '
                $labelMutation = @"
mutation {
  addLabelsToLabelable(input: {
    labelableId: `"$($issue.id)`"
    labelIds: [$labelIdList]
  }) {
    labelable {
      ... on Issue { number }
    }
  }
}
"@
                Invoke-GraphQL -Query $labelMutation | Out-Null
                $appliedLabels = $availableLabels | Where-Object { $_.id -in $labelIds } | ForEach-Object { $_.name }
                Write-Host "    + Labels: $($appliedLabels -join ', ')" -ForegroundColor Gray
            }
        }
        
        $createdIssues += $issue
        $successCount++
    }
    catch {
        Write-Host "  ✗ Failed to create issue '$title' [$typeName]: $_" -ForegroundColor Red
        if ($_.Exception.Message -match "rate limit") {
            Write-Host "    Hint: Rate limit exceeded. Wait before retrying." -ForegroundColor Yellow
        } elseif ($_.Exception.Message -match "permission|unauthorized|forbidden") {
            Write-Host "    Hint: Check repository permissions and authentication." -ForegroundColor Yellow
        }
        $failedCount++
    }
}

# Summary
Write-Host ""
if ($failedCount -eq 0) {
    Write-Host "✓ Successfully created $successCount issues" -ForegroundColor Green
} else {
    Write-Host "⚠ Created $successCount issues, $failedCount failed" -ForegroundColor Yellow
}

# Return created issues
$createdIssues
