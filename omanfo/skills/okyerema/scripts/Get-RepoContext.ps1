#Requires -Version 5.1
<#
.SYNOPSIS
    Resolve and cache repository context (owner, repo, node_id).

.DESCRIPTION
    Resolves repository owner, name, and node_id via the GitHub API and caches
    the result within the current session to avoid repeated API calls.

    Supports explicit owner/repo parameters or auto-detection from the git
    remote URL. On the first call the GitHub GraphQL API is queried; subsequent
    calls return the cached result unless -Force is specified.

.PARAMETER Owner
    Repository owner (organization or user). If omitted, auto-detected from
    the origin git remote URL.

.PARAMETER Repo
    Repository name. If omitted, auto-detected from the origin git remote URL.

.PARAMETER Force
    Clear the cached context and re-resolve via the API even if a cached
    result already exists.

.EXAMPLE
    .\Get-RepoContext.ps1 -Owner anokye-labs -Repo plugins

.EXAMPLE
    .\Get-RepoContext.ps1

.EXAMPLE
    $ctx = .\Get-RepoContext.ps1 -Owner anokye-labs -Repo plugins
    Write-Host "Node ID: $($ctx.NodeId)"
#>
[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter()][string]$Owner,
    [Parameter()][string]$Repo,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Get-RepoContext {
    <#
    .SYNOPSIS
        Resolve and cache repository context (owner, repo, node_id).
    #>
    [CmdletBinding()]
    param(
        [Parameter()][string]$Owner,
        [Parameter()][string]$Repo,
        [switch]$Force
    )

    if ($script:_repoContextCache -and -not $Force) {
        return $script:_repoContextCache
    }

    # Auto-detect owner/repo from the origin git remote when not provided
    if (-not $Owner -or -not $Repo) {
        $remote = git remote get-url origin 2>$null
        if ($remote -match 'github\.com[:/]([^/]+)/([^/.]+)') {
            if (-not $Owner) { $Owner = $Matches[1] }
            if (-not $Repo)  { $Repo  = $Matches[2] -replace '\.git$', '' }
        }
    }

    if (-not $Owner -or -not $Repo) {
        throw "Could not determine Owner and Repo. Provide them explicitly or run from within a git repository with a GitHub origin remote."
    }

    $query = @"
query {
  repository(owner: "$Owner", name: "$Repo") {
    id
    name
    owner { login }
  }
}
"@

    $rawResult = gh api graphql -f query="$query" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "GraphQL query failed: $rawResult"
    }
    $result = $rawResult | ConvertFrom-Json

    if ($result.errors) {
        throw "GraphQL errors: $($result.errors | ConvertTo-Json -Compress)"
    }

    $repoData = $result.data.repository

    $context = [PSCustomObject]@{
        Owner  = $repoData.owner.login
        Repo   = $repoData.name
        NodeId = $repoData.id
    }

    $script:_repoContextCache = $context

    return $context
}

# When invoked directly as a script (not dot-sourced), call the function and emit the result
if ($MyInvocation.InvocationName -ne '.') {
    $invokeParams = @{}
    if ($Owner) { $invokeParams['Owner'] = $Owner }
    if ($Repo)  { $invokeParams['Repo']  = $Repo  }
    if ($Force) { $invokeParams['Force'] = $Force }

    Get-RepoContext @invokeParams
}
