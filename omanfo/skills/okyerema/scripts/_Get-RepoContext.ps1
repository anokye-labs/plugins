#Requires -Version 5.1
<#
.SYNOPSIS
    Shared helper to retrieve and cache repository context.

.DESCRIPTION
    Queries the GitHub GraphQL API for repository metadata (node ID, owner type,
    issue types) and caches the result for the session.

.PARAMETER Owner
    Repository owner (organization or user).

.PARAMETER Repo
    Repository name.
#>

$script:_RepoContextCache = @{}

function Get-RepoContext {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo
    )

    $ErrorActionPreference = "Stop"

    $cacheKey = "$Owner/$Repo"
    if ($script:_RepoContextCache.ContainsKey($cacheKey)) {
        return $script:_RepoContextCache[$cacheKey]
    }

    $query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    id
    owner {
      __typename
      ... on Organization {
        login
        issueTypes(first: 25) {
          nodes { id name }
        }
      }
      ... on User {
        login
      }
    }
  }
  viewer {
    login
  }
}
"@

    $result = Invoke-GraphQL -Query $query
    $ctx = [PSCustomObject]@{
        Owner       = $Owner
        Repo        = $Repo
        RepoId      = $result.data.repository.id
        OwnerType   = $result.data.repository.owner.__typename
        OwnerLogin  = $result.data.repository.owner.login
        IssueTypes  = $result.data.repository.owner.issueTypes.nodes
        ViewerLogin = $result.data.viewer.login
    }
    $script:_RepoContextCache[$cacheKey] = $ctx
    return $ctx
}
