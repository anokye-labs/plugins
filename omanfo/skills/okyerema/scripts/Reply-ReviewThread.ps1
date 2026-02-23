<#
.SYNOPSIS
    Reply to a PR review thread via GraphQL.

.PARAMETER Owner
    Repository owner (org or user).

.PARAMETER Repo
    Repository name.

.PARAMETER PullNumber
    Pull request number.

.PARAMETER ThreadId
    The review thread ID (PRRT_xxx). If not provided, uses -ThreadIndex with Get-UnresolvedThreads.

.PARAMETER ThreadIndex
    Zero-based index into unresolved threads (alternative to ThreadId).

.PARAMETER Body
    Reply text (markdown supported).

.PARAMETER Resolve
    If set, resolves the thread after replying.

.EXAMPLE
    .\Reply-ReviewThread.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -ThreadId "PRRT_xxx" -Body "Fixed in abc123" -Resolve

.EXAMPLE
    .\Reply-ReviewThread.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -ThreadIndex 0 -Body "Fixed" -Resolve
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$PullNumber,
    [string]$ThreadId,
    [int]$ThreadIndex = -1,
    [Parameter(Mandatory)][string]$Body,
    [switch]$Resolve
)

. "$PSScriptRoot\_Invoke-GraphQL.ps1"

# If no ThreadId, look it up by index
if (-not $ThreadId -and $ThreadIndex -ge 0) {
    $lookupQuery = @"
{
  repository(owner: `"$Owner`", name: `"$Repo`") {
    pullRequest(number: $PullNumber) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
        }
      }
    }
  }
}
"@
    $result = Invoke-GraphQL -Query $lookupQuery

    $unresolved = $result.data.repository.pullRequest.reviewThreads.nodes | Where-Object { -not $_.isResolved }
    if ($ThreadIndex -ge $unresolved.Count) {
        Write-Error "ThreadIndex $ThreadIndex out of range. Only $($unresolved.Count) unresolved threads."
        exit 1
    }
    $ThreadId = $unresolved[$ThreadIndex].id
    Write-Host "Resolved index $ThreadIndex to thread: $ThreadId" -ForegroundColor Cyan
}

if (-not $ThreadId) {
    Write-Error "Provide either -ThreadId or -ThreadIndex"
    exit 1
}

# Escape body for GraphQL
$escapedBody = $Body.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n')

# Reply
$replyMutation = @"
mutation {
  addPullRequestReviewThreadReply(input: {
    pullRequestReviewThreadId: `"$ThreadId`"
    body: `"$escapedBody`"
  }) {
    comment {
      url
    }
  }
}
"@
$replyResult = Invoke-GraphQL -Query $replyMutation

$url = $replyResult.data.addPullRequestReviewThreadReply.comment.url
Write-Host "Replied: $url" -ForegroundColor Green

# Optionally resolve
if ($Resolve) {
    $resolveMutation = @"
mutation {
  resolveReviewThread(input: { threadId: `"$ThreadId`" }) {
    thread { isResolved }
  }
}
"@
    Invoke-GraphQL -Query $resolveMutation | Out-Null
    Write-Host "Thread resolved" -ForegroundColor Green
}
