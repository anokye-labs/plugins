# New-IssueHierarchy.ps1
# Create full Epic-Feature-Task trees from structured definitions
# Uses sub-issues API to establish parent-child relationships

param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][hashtable]$Hierarchy  # Structured definition of Epic/Feature/Task tree
)

$ErrorActionPreference = "Stop"

# Get repo ID and type IDs
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
  }
}
"@

$result = gh api graphql -f query="$query" | ConvertFrom-Json
$repoId = $result.data.repository.id
$issueTypes = $result.data.repository.owner.issueTypes.nodes

Write-Host "Repository: $Owner/$Repo" -ForegroundColor Cyan
Write-Host "Available issue types: $($issueTypes.name -join ', ')" -ForegroundColor Gray
Write-Host ""

# Helper function to create a single issue
function New-SingleIssue {
    param($Title, $TypeName, $Body = "", $Indent = "")
    
    $typeId = ($issueTypes | Where-Object { $_.name -eq $TypeName }).id
    if (-not $typeId) {
        Write-Error "Issue type '$TypeName' not found"
        return $null
    }
    
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
    
    $createResult = gh api graphql -f query="$mutation" | ConvertFrom-Json
    $issue = $createResult.data.createIssue.issue
    
    Write-Host "${Indent}✓ Created #$($issue.number) [$($issue.issueType.name)] $($issue.title)" -ForegroundColor Green
    
    return $issue
}

# Helper function to add sub-issues
function Add-SubIssues {
    param($ParentId, $ParentNumber, $ChildNumbers, $Indent = "")
    
    foreach ($childNum in $ChildNumbers) {
        # Get child issue ID
        $childQuery = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    issue(number: $childNum) {
      id
    }
  }
}
"@
        $childResult = gh api graphql -f query="$childQuery" | ConvertFrom-Json
        $childId = $childResult.data.repository.issue.id
        
        # Add as sub-issue
        $addMutation = @"
mutation {
  addSubIssue(input: {
    issueId: `"$ParentId`"
    subIssueId: `"$childId`"
  }) {
    issue { id }
    subIssue { id }
  }
}
"@
        
        $rawAddResult = gh api graphql -H "GraphQL-Features: sub_issues" -f query="$addMutation" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $addResult = $rawAddResult | ConvertFrom-Json
            if (-not $addResult.errors) {
                Write-Host "${Indent}  → Linked #$childNum as sub-issue" -ForegroundColor Gray
            }
        }
    }
}

# Process hierarchy structure
# Expected format:
# @{
#   Title = "Epic Title"
#   Type = "Epic"
#   Body = "Description"
#   Features = @(
#     @{
#       Title = "Feature Title"
#       Type = "Feature"
#       Body = "Description"
#       Tasks = @(
#         @{ Title = "Task 1"; Type = "Task"; Body = "..." }
#         @{ Title = "Task 2"; Type = "Task"; Body = "..." }
#       )
#     }
#   )
# }

$root = $Hierarchy

# Detect hierarchy level
$isEpic = $root.Type -eq "Epic" -and $root.Features
$isFeature = $root.Type -eq "Feature" -and $root.Tasks
$isSimple = $root.Tasks -and -not $root.Type

if ($isEpic) {
    # 3-level hierarchy: Epic → Feature → Task
    Write-Host "Creating Epic hierarchy..." -ForegroundColor Cyan
    
    # Create Epic
    $epic = New-SingleIssue -Title $root.Title -TypeName "Epic" -Body $root.Body
    if (-not $epic) { return }
    
    $featureNumbers = @()
    
    # Create Features
    foreach ($feature in $root.Features) {
        $featureObj = New-SingleIssue -Title $feature.Title -TypeName "Feature" -Body $feature.Body -Indent "  "
        if (-not $featureObj) { continue }
        
        $featureNumbers += $featureObj.number
        $taskNumbers = @()
        
        # Create Tasks
        if ($feature.Tasks) {
            foreach ($task in $feature.Tasks) {
                $taskObj = New-SingleIssue -Title $task.Title -TypeName "Task" -Body $task.Body -Indent "    "
                if ($taskObj) {
                    $taskNumbers += $taskObj.number
                }
            }
            
            # Link Tasks to Feature
            if ($taskNumbers.Count -gt 0) {
                Add-SubIssues -ParentId $featureObj.id -ParentNumber $featureObj.number -ChildNumbers $taskNumbers -Indent "    "
            }
        }
    }
    
    # Link Features to Epic
    if ($featureNumbers.Count -gt 0) {
        Add-SubIssues -ParentId $epic.id -ParentNumber $epic.number -ChildNumbers $featureNumbers -Indent "  "
    }
    
    Write-Host ""
    Write-Host "✓ Created Epic hierarchy: #$($epic.number) with $($featureNumbers.Count) features" -ForegroundColor Green
    
    return @{
        Epic = $epic
        FeatureCount = $featureNumbers.Count
    }
}
elseif ($isFeature) {
    # 2-level hierarchy: Feature → Task
    Write-Host "Creating Feature hierarchy..." -ForegroundColor Cyan
    
    # Create Feature
    $feature = New-SingleIssue -Title $root.Title -TypeName "Feature" -Body $root.Body
    if (-not $feature) { return }
    
    $taskNumbers = @()
    
    # Create Tasks
    foreach ($task in $root.Tasks) {
        $taskObj = New-SingleIssue -Title $task.Title -TypeName "Task" -Body $task.Body -Indent "  "
        if ($taskObj) {
            $taskNumbers += $taskObj.number
        }
    }
    
    # Link Tasks to Feature
    if ($taskNumbers.Count -gt 0) {
        Add-SubIssues -ParentId $feature.id -ParentNumber $feature.number -ChildNumbers $taskNumbers -Indent "  "
    }
    
    Write-Host ""
    Write-Host "✓ Created Feature hierarchy: #$($feature.number) with $($taskNumbers.Count) tasks" -ForegroundColor Green
    
    return @{
        Feature = $feature
        TaskCount = $taskNumbers.Count
    }
}
elseif ($isSimple) {
    # Simple task list (backwards compatibility)
    Write-Host "Creating task list..." -ForegroundColor Cyan
    
    $taskNumbers = @()
    foreach ($task in $root.Tasks) {
        $taskObj = New-SingleIssue -Title $task.Title -TypeName "Task" -Body $task.Body
        if ($taskObj) {
            $taskNumbers += $taskObj.number
        }
    }
    
    Write-Host ""
    Write-Host "✓ Created $($taskNumbers.Count) tasks" -ForegroundColor Green
    
    return @{
        TaskCount = $taskNumbers.Count
    }
}
else {
    Write-Error "Invalid hierarchy structure. Must have Epic with Features, Feature with Tasks, or Tasks array."
}
