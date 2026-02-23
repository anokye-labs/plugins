# _Get-RepoContext.ps1
# Shared helper: retrieve and cache repository context (node ID, owner type, issue types)

$script:_RepoContextCache = @{}

function Get-RepoContext {
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo
    )

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
