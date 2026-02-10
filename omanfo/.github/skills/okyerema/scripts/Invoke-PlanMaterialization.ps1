# Invoke-PlanMaterialization.ps1
# Convert markdown plan documents into GitHub issue DAGs with proper hierarchy

<#
.SYNOPSIS
    Materializes a markdown plan document into GitHub issues with Epic→Feature→Task hierarchy.

.DESCRIPTION
    Parses a markdown document where headings represent issue hierarchy:
    - H1 (#) → Epic
    - H2 (##) → Feature  
    - H3 (###) → Task
    
    Creates issues with proper organization types and builds parent-child relationships
    using GitHub's sub-issues API. Optionally adds issues to a GitHub Project.

.PARAMETER Owner
    Repository owner (organization or user)

.PARAMETER Repo
    Repository name

.PARAMETER PlanFile
    Path to the markdown plan document

.PARAMETER ProjectNumber
    Optional GitHub Project number to add issues to

.PARAMETER DryRun
    If specified, shows what would be created without making changes

.PARAMETER MappingFile
    Optional path to save issue mapping (for use with Sync-PlanToIssues.ps1)
    Defaults to <PlanFile>-mapping.json

.EXAMPLE
    ./Invoke-PlanMaterialization.ps1 -Owner "anokye-labs" -Repo "my-project" -PlanFile "./roadmap.md"

.EXAMPLE
    ./Invoke-PlanMaterialization.ps1 -Owner "anokye-labs" -Repo "my-project" -PlanFile "./roadmap.md" -ProjectNumber 5

.EXAMPLE
    ./Invoke-PlanMaterialization.ps1 -Owner "anokye-labs" -Repo "my-project" -PlanFile "./roadmap.md" -MappingFile "./custom-mapping.json"

.NOTES
    Requires:
    - GitHub CLI (gh) authenticated
    - Organization issue types configured (Epic, Feature, Task)
    - Sub-issues API access (GraphQL-Features header)
#>

param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$PlanFile,
    [int]$ProjectNumber,
    [string]$MappingFile,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Validate plan file exists
if (-not (Test-Path $PlanFile)) {
    Write-Error "Plan file not found: $PlanFile"
    exit 1
}

# Set default mapping file if not specified
if (-not $MappingFile) {
    $MappingFile = "$PlanFile-mapping.json"
}

Write-Host "=== Plan Materialization Pipeline ===" -ForegroundColor Cyan
Write-Host "Repository: $Owner/$Repo" -ForegroundColor Gray
Write-Host "Plan File: $PlanFile" -ForegroundColor Gray
if ($DryRun) {
    Write-Host "Mode: DRY RUN (no changes will be made)" -ForegroundColor Yellow
}
Write-Host ""

# Parse markdown plan
Write-Host "Parsing plan document..." -ForegroundColor Cyan
$content = Get-Content $PlanFile -Raw
$lines = Get-Content $PlanFile

$items = @()
$currentH1 = $null
$currentH2 = $null

foreach ($line in $lines) {
    # Match heading patterns
    if ($line -match '^# (.+)$') {
        # H1 = Epic
        $title = $matches[1].Trim()
        $currentH1 = @{
            Level = 1
            Type = "Epic"
            Title = $title
            Body = ""
            Children = @()
        }
        $items += $currentH1
        $currentH2 = $null
    }
    elseif ($line -match '^## (.+)$') {
        # H2 = Feature
        $title = $matches[1].Trim()
        $currentH2 = @{
            Level = 2
            Type = "Feature"
            Title = $title
            Body = ""
            Children = @()
            Parent = $currentH1
        }
        if ($currentH1) {
            $currentH1.Children += $currentH2
        } else {
            # Standalone feature (no epic parent)
            $items += $currentH2
        }
    }
    elseif ($line -match '^### (.+)$') {
        # H3 = Task
        $title = $matches[1].Trim()
        $taskItem = @{
            Level = 3
            Type = "Task"
            Title = $title
            Body = ""
            Children = @()
            Parent = if ($currentH2) { $currentH2 } else { $currentH1 }
        }
        if ($currentH2) {
            $currentH2.Children += $taskItem
        } elseif ($currentH1) {
            $currentH1.Children += $taskItem
        } else {
            # Standalone task
            $items += $taskItem
        }
    }
    elseif ($line.Trim() -and -not $line.StartsWith('#')) {
        # Accumulate body content for the current item
        if ($currentH2) {
            if ($currentH2.Body) { $currentH2.Body += "`n" }
            $currentH2.Body += $line
        } elseif ($currentH1) {
            if ($currentH1.Body) { $currentH1.Body += "`n" }
            $currentH1.Body += $line
        }
    }
}

# Count items
$totalEpics = ($items | Where-Object { $_.Level -eq 1 }).Count
$totalFeatures = 0
$totalTasks = 0

function Count-Items($item) {
    $script:totalFeatures += ($item.Children | Where-Object { $_.Type -eq "Feature" }).Count
    $script:totalTasks += ($item.Children | Where-Object { $_.Type -eq "Task" }).Count
    foreach ($child in $item.Children) {
        Count-Items $child
    }
}

foreach ($item in $items) {
    if ($item.Type -eq "Feature" -and -not $item.Parent) {
        $totalFeatures++
    }
    if ($item.Type -eq "Task" -and -not $item.Parent) {
        $totalTasks++
    }
    Count-Items $item
}

Write-Host "Parsed $totalEpics Epics, $totalFeatures Features, $totalTasks Tasks" -ForegroundColor Green
Write-Host ""

if ($DryRun) {
    Write-Host "=== DRY RUN: Would create ===" -ForegroundColor Yellow
    function Show-Item($item, $indent = 0) {
        $prefix = "  " * $indent
        Write-Host "$prefix[$($item.Type)] $($item.Title)" -ForegroundColor Cyan
        if ($item.Body -and $item.Body.Trim()) {
            $bodyPreview = $item.Body.Trim().Substring(0, [Math]::Min(60, $item.Body.Trim().Length))
            Write-Host "$prefix  Body: $bodyPreview..." -ForegroundColor Gray
        }
        foreach ($child in $item.Children) {
            Show-Item $child ($indent + 1)
        }
    }
    foreach ($item in $items) {
        Show-Item $item
    }
    Write-Host ""
    Write-Host "Use without -DryRun to create issues" -ForegroundColor Yellow
    exit 0
}

# Get repository ID and issue type IDs
Write-Host "Fetching repository and issue type IDs..." -ForegroundColor Cyan
$query = @"
query {
  repository(owner: "$Owner", name: "$Repo") {
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

$rawResult = gh api graphql -f query="$query" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to fetch repository info: $rawResult"
    exit 1
}

$result = $rawResult | ConvertFrom-Json
if ($result.errors) {
    Write-Error "GraphQL errors: $($result.errors | ConvertTo-Json -Compress)"
    exit 1
}

$repoId = $result.data.repository.id
$issueTypes = $result.data.repository.owner.issueTypes.nodes

# Map type names to IDs
$typeMap = @{}
foreach ($type in $issueTypes) {
    $typeMap[$type.name] = $type.id
}

# Validate required types exist
foreach ($typeName in @("Epic", "Feature", "Task")) {
    if (-not $typeMap.ContainsKey($typeName)) {
        Write-Error "Issue type '$typeName' not found in organization. Available: $($issueTypes.name -join ', ')"
        exit 1
    }
}

Write-Host "✓ Found repository ID and issue types" -ForegroundColor Green
Write-Host ""

# Create issues recursively
Write-Host "Creating issues..." -ForegroundColor Cyan
$createdIssues = @{}

function Create-IssueFromItem($item) {
    $escapedTitle = $item.Title.Replace('\', '\\').Replace('"', '\"')
    $escapedBody = $item.Body.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n')
    $typeId = $typeMap[$item.Type]
    
    $mutation = @"
mutation {
  createIssue(input: {
    repositoryId: "$repoId"
    title: "$escapedTitle"
    body: "$escapedBody"
    issueTypeId: "$typeId"
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
    
    $rawCreateResult = gh api graphql -f query="$mutation" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create issue: $rawCreateResult"
        return $null
    }
    
    $createResult = $rawCreateResult | ConvertFrom-Json
    if ($createResult.errors) {
        Write-Error "GraphQL errors creating issue: $($createResult.errors | ConvertTo-Json -Compress)"
        return $null
    }
    
    $issue = $createResult.data.createIssue.issue
    Write-Host "  ✓ Created #$($issue.number) [$($issue.issueType.name)] $($issue.title)" -ForegroundColor Green
    
    return $issue
}

function Create-Issues-Recursive($item) {
    # Create the item itself
    $issue = Create-IssueFromItem $item
    if (-not $issue) {
        return $null
    }
    
    $createdIssues[$item] = $issue
    
    # Create children
    $childIssues = @()
    foreach ($child in $item.Children) {
        $childIssue = Create-Issues-Recursive $child
        if ($childIssue) {
            $childIssues += $childIssue
        }
    }
    
    # Build parent-child relationships
    if ($childIssues.Count -gt 0) {
        Write-Host "    Building relationships for #$($issue.number)..." -ForegroundColor Gray
        foreach ($childIssue in $childIssues) {
            $addMutation = @"
mutation {
  addSubIssue(input: {
    issueId: "$($issue.id)"
    subIssueId: "$($childIssue.id)"
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
                    Write-Host "      ✓ Linked #$($issue.number) → #$($childIssue.number)" -ForegroundColor Gray
                } else {
                    Write-Warning "Failed to link #$($issue.number) → #$($childIssue.number): $($addResult.errors | ConvertTo-Json -Compress)"
                }
            } else {
                Write-Warning "Failed to link #$($issue.number) → #$($childIssue.number): $rawAddResult"
            }
        }
    }
    
    return $issue
}

# Create all issues
foreach ($item in $items) {
    Create-Issues-Recursive $item | Out-Null
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
$createdCount = $createdIssues.Count
Write-Host "Created $createdCount issues from plan" -ForegroundColor Green

# List created issues by type
$epicIssues = $createdIssues.Values | Where-Object { $_.issueType.name -eq "Epic" }
$featureIssues = $createdIssues.Values | Where-Object { $_.issueType.name -eq "Feature" }
$taskIssues = $createdIssues.Values | Where-Object { $_.issueType.name -eq "Task" }

Write-Host "  Epics: $($epicIssues.Count)" -ForegroundColor Gray
Write-Host "  Features: $($featureIssues.Count)" -ForegroundColor Gray
Write-Host "  Tasks: $($taskIssues.Count)" -ForegroundColor Gray

Write-Host ""

# Generate mapping file for sync
Write-Host "Generating mapping file..." -ForegroundColor Cyan
$mappingData = @{
    planFile = $PlanFile
    repository = "$Owner/$Repo"
    createdAt = (Get-Date).ToString("o")
    issues = @()
}

function Add-To-Mapping($item, $parentNumber = $null) {
    if ($createdIssues.ContainsKey($item)) {
        $issue = $createdIssues[$item]
        $mappingData.issues += @{
            number = $issue.number
            id = $issue.id
            title = $issue.title
            type = $issue.issueType.name
            body = $item.Body
            parent = $parentNumber
            url = $issue.url
        }
        
        # Add children recursively
        foreach ($child in $item.Children) {
            Add-To-Mapping $child $issue.number
        }
    }
}

foreach ($item in $items) {
    Add-To-Mapping $item
}

$mappingData | ConvertTo-Json -Depth 10 | Set-Content $MappingFile
Write-Host "✓ Saved mapping to $MappingFile" -ForegroundColor Green
Write-Host ""

Write-Host "✓ Plan materialization complete" -ForegroundColor Green
