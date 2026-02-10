<#
.SYNOPSIS
    Submit structured PR review programmatically.

.DESCRIPTION
    Submits a pull request review with comments and an overall decision.
    Supports:
    - Review comments on specific lines
    - Overall review state (APPROVE, REQUEST_CHANGES, COMMENT)
    - Review body/summary
    
    This enables programmatic review submission from automation or agents.

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER PullNumber
    Pull request number.

.PARAMETER CommitId
    The commit SHA to review. If not specified, uses the latest commit.

.PARAMETER Event
    Review action: APPROVE, REQUEST_CHANGES, or COMMENT.

.PARAMETER Body
    Overall review comment/summary.

.PARAMETER Comments
    Array of review comments. Each comment should be a hashtable with:
    - Path: File path
    - Line: Line number (or Position for diff position)
    - Body: Comment text

.EXAMPLE
    .\Submit-PRReview.ps1 -Owner anokye-labs -Repo plugins -PullNumber 50 -Event APPROVE -Body "LGTM!"

.EXAMPLE
    $comments = @(
        @{ Path = "src/main.ps1"; Line = 42; Body = "Consider using -ErrorAction Stop here" }
        @{ Path = "README.md"; Line = 10; Body = "Typo: 'recieve' should be 'receive'" }
    )
    .\Submit-PRReview.ps1 -Owner anokye-labs -Repo plugins -PullNumber 50 `
        -Event REQUEST_CHANGES -Body "Found a few issues" -Comments $comments
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$PullNumber,
    [string]$CommitId,
    [Parameter(Mandatory)]
    [ValidateSet("APPROVE", "REQUEST_CHANGES", "COMMENT")]
    [string]$Event,
    [string]$Body = "",
    [hashtable[]]$Comments = @()
)

$ErrorActionPreference = "Stop"

# Get latest commit if not specified
if (-not $CommitId) {
    $query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    pullRequest(number: $PullNumber) {
      commits(last: 1) {
        nodes {
          commit { oid }
        }
      }
    }
  }
}
"@
    $result = gh api graphql -f query="$query" | ConvertFrom-Json
    $CommitId = $result.data.repository.pullRequest.commits.nodes[0].commit.oid
    Write-Host "Using latest commit: $CommitId" -ForegroundColor Gray
}

# Prepare review comments
$reviewComments = @()
foreach ($comment in $Comments) {
    if (-not $comment.Path -or -not $comment.Body) {
        Write-Error "Each comment must have 'Path' and 'Body' properties"
        return
    }
    
    $escapedBody = $comment.Body.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n')
    $escapedPath = $comment.Path.Replace('\', '\\').Replace('"', '\"')
    
    # Determine if using line or position
    if ($comment.Line) {
        $reviewComments += @"
{
  path: `"$escapedPath`"
  line: $($comment.Line)
  body: `"$escapedBody`"
}
"@
    } elseif ($comment.Position) {
        $reviewComments += @"
{
  path: `"$escapedPath`"
  position: $($comment.Position)
  body: `"$escapedBody`"
}
"@
    } else {
        Write-Error "Each comment must have either 'Line' or 'Position' property"
        return
    }
}

$commentsField = ""
if ($reviewComments.Count -gt 0) {
    $commentsField = "comments: [" + ($reviewComments -join ", ") + "]"
}

# Escape review body
$escapedReviewBody = $Body.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n')

# Submit review using GraphQL mutation
$mutation = @"
mutation {
  addPullRequestReview(input: {
    pullRequestId: `"`"
    commitOID: `"$CommitId`"
    event: $Event
    body: `"$escapedReviewBody`"
    $commentsField
  }) {
    pullRequestReview {
      id
      author { login }
      state
      body
      submittedAt
    }
  }
}
"@

# First, get the PR node ID
$prQuery = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    pullRequest(number: $PullNumber) {
      id
    }
  }
}
"@

$prResult = gh api graphql -f query="$prQuery" | ConvertFrom-Json
$prId = $prResult.data.repository.pullRequest.id

# Update mutation with PR ID
$mutation = $mutation.Replace('pullRequestId: ""', "pullRequestId: `"$prId`"")

# Execute mutation
try {
    $result = gh api graphql -f query="$mutation" | ConvertFrom-Json
    $review = $result.data.addPullRequestReview.pullRequestReview
    
    Write-Host "`n✓ Review submitted successfully" -ForegroundColor Green
    Write-Host "  Reviewer: @$($review.author.login)" -ForegroundColor White
    Write-Host "  State: $($review.state)" -ForegroundColor $(
        switch ($review.state) {
            "APPROVED" { "Green" }
            "CHANGES_REQUESTED" { "Yellow" }
            default { "White" }
        }
    )
    Write-Host "  Submitted: $($review.submittedAt)" -ForegroundColor Gray
    
    if ($Comments.Count -gt 0) {
        Write-Host "  Comments: $($Comments.Count)" -ForegroundColor Gray
    }
    
    if ($review.body) {
        Write-Host "  Body: $($review.body)" -ForegroundColor DarkGray
    }
    Write-Host ""
    
    # Output review object
    Write-Output $review
} catch {
    Write-Error "Failed to submit review: $_"
    
    # If it's a line number issue, provide helpful error
    if ($_ -match "line") {
        Write-Host "`nNote: Line numbers must refer to lines in the diff, not absolute file lines." -ForegroundColor Yellow
        Write-Host "Consider using 'position' (diff position) instead of 'line' for older commits." -ForegroundColor Yellow
    }
    
    throw
}
