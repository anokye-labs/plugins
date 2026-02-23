# New-IssueWithType.ps1
# Create a GitHub issue with proper organization issue type
# Implements default assignment policy: Task/Bug → @copilot, Epic/Feature → authenticated user

param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$TypeName,  # Epic, Feature, Task, Bug
    [string]$Body = "",
    [string[]]$Labels = @(),
    [string]$Assignee = "auto"  # "auto" = use policy, "username", "@copilot", or "" = none
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\_Invoke-GraphQL.ps1"
. "$PSScriptRoot\_Get-RepoContext.ps1"

# Get repo ID, owner info, and type IDs
$ctx = Get-RepoContext -Owner $Owner -Repo $Repo
$repoId = $ctx.RepoId
$repoOwnerLogin = $ctx.OwnerLogin
$ownerType = $ctx.OwnerType
$authenticatedUser = $ctx.ViewerLogin

# Check if organization has issue types
if ($ownerType -eq "Organization") {
    $typeId = ($ctx.IssueTypes | Where-Object { $_.name -eq $TypeName }).id
    
    if (-not $typeId) {
        Write-Error "Issue type '$TypeName' not found. Available: $($ctx.IssueTypes.name -join ', ')"
        return
    }
} else {
    Write-Error "Issue types are only supported for organization-owned repositories. This repository is owned by a user account."
    return
}

# Create issue
$escapedTitle = $Title.Replace('\', '\\').Replace('"', '\"')
$escapedBody = $Body.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n')

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

$result = Invoke-GraphQL -Query $mutation
$issue = $result.data.createIssue.issue

Write-Host "✓ Created #$($issue.number) [$($issue.issueType.name)] $($issue.title)" -ForegroundColor Green

# Add labels if provided (via GraphQL, not gh CLI)
if ($Labels.Count -gt 0) {
    # Get label IDs
    $labelQuery = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    labels(first: 100) {
      nodes { id name }
    }
  }
}
"@
    $labelResult = Invoke-GraphQL -Query $labelQuery
    $labelIds = $Labels | ForEach-Object {
        $name = $_
        ($labelResult.data.repository.labels.nodes | Where-Object { $_.name -eq $name }).id
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
        $allLabelNodes = $labelResult.data.repository.labels.nodes
        $appliedLabels = $allLabelNodes | Where-Object { $_.id -in $labelIds } | ForEach-Object { $_.name }
        $missing = $Labels | Where-Object { $_ -notin ($allLabelNodes.name) }
        Write-Host "  + Labels: $($appliedLabels -join ', ')" -ForegroundColor Gray
        if ($missing) { Write-Warning "Labels not found (skipped): $($missing -join ', ')" }
    }
}

# Determine assignee based on policy
$targetAssignee = $null
if ($Assignee -eq "auto") {
    # Apply default assignment policy
    if ($TypeName -eq "Task" -or $TypeName -eq "Bug") {
        $targetAssignee = "@copilot"
        Write-Host "  → Applying default policy: $TypeName → @copilot" -ForegroundColor Gray
    } elseif ($TypeName -eq "Epic" -or $TypeName -eq "Feature") {
        # For Epics/Features, assign to authenticated user (orgs can't be assignees)
        # Note: Owner is guaranteed to be an org at this point (checked earlier)
        $targetAssignee = $authenticatedUser
        Write-Host "  → Applying default policy: $TypeName → $authenticatedUser (authenticated user)" -ForegroundColor Gray
    }
} elseif ($Assignee -ne "") {
    $targetAssignee = $Assignee
}

# Assign issue if target assignee is specified
if ($targetAssignee) {
    try {
        # Use REST API for bot assignment (GraphQL doesn't work for @copilot)
        # Strip @ prefix if present for REST API
        $assigneeLogin = $targetAssignee -replace '^@', ''
        
        $assignResult = gh api "repos/$Owner/$Repo/issues/$($issue.number)/assignees" `
            --method POST `
            -f "assignees[]=$assigneeLogin" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  + Assigned to: $targetAssignee" -ForegroundColor Gray
        } else {
            Write-Warning "Failed to assign to $targetAssignee : $assignResult"
        }
    } catch {
        Write-Warning "Failed to assign to $targetAssignee : $_"
    }
}

# Return issue object
$issue
