# Okyerema Scripts

PowerShell scripts for GitHub issue and PR management using GraphQL API.

## Issue Creation Scripts

### New-IssueWithType.ps1

Create a single GitHub issue with proper organization issue type.

**Usage:**
```powershell
# Create a single Task issue
./New-IssueWithType.ps1 `
    -Owner "anokye-labs" `
    -Repo "plugins" `
    -Title "Implement authentication" `
    -TypeName "Task" `
    -Body "Add OAuth2 support" `
    -Labels @("enhancement", "P1")
```

**Parameters:**
- `Owner` (required) - Repository owner
- `Repo` (required) - Repository name
- `Title` (required) - Issue title
- `TypeName` (required) - Issue type: Epic, Feature, Task, or Bug
- `Body` (optional) - Issue description
- `Labels` (optional) - Array of label names

**Returns:** Issue object with id, number, title, type, and url

---

### New-IssueBatch.ps1

Batch create multiple GitHub issues with proper organization issue types.

**Usage:**
```powershell
# Create multiple issues at once
$issues = @(
    @{
        Title = "Setup CI pipeline"
        TypeName = "Task"
        Body = "Configure GitHub Actions"
        Labels = @("infrastructure")
    },
    @{
        Title = "Add unit tests"
        TypeName = "Task"
        Body = "Write tests for core modules"
        Labels = @("testing", "P0")
    },
    @{
        Title = "Update documentation"
        TypeName = "Task"
        Body = "Add API reference docs"
    }
)

./New-IssueBatch.ps1 `
    -Owner "anokye-labs" `
    -Repo "plugins" `
    -Issues $issues
```

**Parameters:**
- `Owner` (required) - Repository owner
- `Repo` (required) - Repository name
- `Issues` (required) - Array of hashtables, each with:
  - `Title` (required) - Issue title
  - `TypeName` (required) - Issue type: Epic, Feature, Task, or Bug
  - `Body` (optional) - Issue description
  - `Labels` (optional) - Array of label names

**Returns:** Array of created issue objects

**Features:**
- Single GraphQL query to fetch repo metadata (optimized for batch operations)
- Validates issue types before creation
- Applies labels to created issues
- Reports success/failure for each issue
- Returns array of successfully created issues

---

### New-IssueHierarchy.ps1

Create full Epic-Feature-Task trees from structured definitions using sub-issues API.

**Usage:**

**Example 1: Epic → Feature → Task (3-level hierarchy)**
```powershell
$hierarchy = @{
    Title = "Improve Performance"
    Type = "Epic"
    Body = "Optimize application performance across all modules"
    Features = @(
        @{
            Title = "Database Optimization"
            Type = "Feature"
            Body = "Improve database query performance"
            Tasks = @(
                @{ Title = "Add query indexes"; Type = "Task"; Body = "Index frequently queried columns" }
                @{ Title = "Optimize slow queries"; Type = "Task"; Body = "Refactor N+1 queries" }
                @{ Title = "Implement query caching"; Type = "Task"; Body = "Add Redis cache layer" }
            )
        },
        @{
            Title = "Frontend Optimization"
            Type = "Feature"
            Body = "Reduce frontend bundle size and improve load times"
            Tasks = @(
                @{ Title = "Code splitting"; Type = "Task"; Body = "Implement route-based code splitting" }
                @{ Title = "Image optimization"; Type = "Task"; Body = "Add lazy loading for images" }
            )
        }
    )
}

./New-IssueHierarchy.ps1 `
    -Owner "anokye-labs" `
    -Repo "plugins" `
    -Hierarchy $hierarchy
```

**Example 2: Feature → Task (2-level hierarchy)**
```powershell
$hierarchy = @{
    Title = "Authentication System"
    Type = "Feature"
    Body = "Implement user authentication and authorization"
    Tasks = @(
        @{ Title = "OAuth2 provider setup"; Type = "Task"; Body = "Configure GitHub OAuth" }
        @{ Title = "Session management"; Type = "Task"; Body = "Implement secure sessions" }
        @{ Title = "Permission middleware"; Type = "Task"; Body = "Add role-based access control" }
    )
}

./New-IssueHierarchy.ps1 `
    -Owner "anokye-labs" `
    -Repo "plugins" `
    -Hierarchy $hierarchy
```

**Parameters:**
- `Owner` (required) - Repository owner
- `Repo` (required) - Repository name
- `Hierarchy` (required) - Hashtable with hierarchical structure:
  
  **For Epic hierarchy:**
  - `Title` - Epic title
  - `Type` - "Epic"
  - `Body` - Epic description
  - `Features` - Array of feature hashtables, each with:
    - `Title` - Feature title
    - `Type` - "Feature"
    - `Body` - Feature description
    - `Tasks` - Array of task hashtables
  
  **For Feature hierarchy:**
  - `Title` - Feature title
  - `Type` - "Feature"
  - `Body` - Feature description
  - `Tasks` - Array of task hashtables, each with:
    - `Title` - Task title
    - `Type` - "Task"
    - `Body` - Task description

**Returns:** 
- For Epic: `@{ Epic = <issue>; FeatureCount = <int> }`
- For Feature: `@{ Feature = <issue>; TaskCount = <int> }`

**Features:**
- Creates parent issues before children (proper ordering)
- Automatically establishes sub-issue relationships using GitHub's sub-issues API
- Supports 3-level (Epic→Feature→Task) and 2-level (Feature→Task) hierarchies
- Uses GraphQL mutations with `GraphQL-Features: sub_issues` header
- Reports creation progress with indentation for hierarchy visualization

---

### Update-IssueHierarchy.ps1

Build parent-child relationships using GitHub's sub-issues API.

**Usage:**
```powershell
# Link issues #45, #46, #47 as sub-issues of #44
./Update-IssueHierarchy.ps1 `
    -Owner "anokye-labs" `
    -Repo "plugins" `
    -ParentNumber 44 `
    -ChildNumbers @(45, 46, 47)
```

**Parameters:**
- `Owner` (required) - Repository owner
- `Repo` (required) - Repository name
- `ParentNumber` (required) - Parent issue number
- `ChildNumbers` (required) - Array of child issue numbers

**Features:**
- Uses GitHub's native sub-issues API
- Validates parent and child issues exist
- Reports success/failure for each relationship
- Requires `GraphQL-Features: sub_issues` header

---

## Other Scripts

### Test-Hierarchy.ps1
Validate issue hierarchy structure and relationships.

### Get-DagCompletionReport.ps1

Generate a DAG progress completion report for issue hierarchies.

**Usage:**
```powershell
# Report on all roots
./Get-DagCompletionReport.ps1 -Owner "anokye-labs" -Repo "plugins"

# Focus on a specific root
./Get-DagCompletionReport.ps1 -Owner "anokye-labs" -Repo "plugins" -RootNumber 10 -Brief
```

**Parameters:**
- `Owner` (required) - Repository owner
- `Repo` (required) - Repository name
- `RootNumber` (optional) - Focus on a specific root issue number; defaults to all roots
- `Brief` (optional switch) - Compact single-line output

**Returns:**
PSCustomObject with `TotalIssues`, `OpenCount`, `ClosedCount`, `PercentComplete`,
`RootCount`, `RootReports` (per-root stats), `BlockedPaths` (all-open dependency chains),
`BlockedPathCount`, `CriticalPath` (longest all-open chain), and `CriticalPathLength`.

---

### Get-HierarchyHealth.ps1
Analyze health of issue hierarchies in a repository.

### Get-Sitrep.ps1
Generate situation report for repository status.

### Get-PRHealth.ps1
Analyze pull request health and review status.

### Get-UnresolvedThreads.ps1
List unresolved review threads in pull requests.

### Reply-ReviewThread.ps1
Reply to a review thread in a pull request.

### Resolve-ReviewThreads.ps1
Resolve review threads in a pull request.

---

## Requirements

- PowerShell 7+
- GitHub CLI (`gh`) installed and authenticated
- Organization-level issue types configured (Epic, Feature, Task, Bug)
- For sub-issues: Repository must have sub-issues feature enabled

## Notes

- All scripts use GraphQL API via `gh api graphql`
- GraphQL injection is prevented via proper escaping of backslashes and quotes
- Sub-issues API requires the `GraphQL-Features: sub_issues` header
- Issue types are organization-level, not repository-level
