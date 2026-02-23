<#
.SYNOPSIS
    Get timeline view of review activity on a PR.

.DESCRIPTION
    Displays a chronological timeline of PR review activity including:
    - Review submissions (approved, changes requested, commented)
    - Review thread creation and resolution
    - Commits
    - Status check updates
    
    Provides a narrative view of what happened when.

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER PullNumber
    Pull request number.

.PARAMETER Limit
    Maximum number of timeline events to retrieve (default: 50).

.PARAMETER EventTypes
    Specific event types to include. If not specified, shows all review-related events.

.EXAMPLE
    .\Get-PRTimeline.ps1 -Owner anokye-labs -Repo plugins -PullNumber 50

.EXAMPLE
    .\Get-PRTimeline.ps1 -Owner anokye-labs -Repo plugins -PullNumber 50 -Limit 100
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$PullNumber,
    [int]$Limit = 50
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\_Invoke-GraphQL.ps1"

$query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    pullRequest(number: $PullNumber) {
      number
      title
      createdAt
      author { login }
      timelineItems(first: $Limit, itemTypes: [
        PULL_REQUEST_COMMIT,
        PULL_REQUEST_REVIEW,
        PULL_REQUEST_REVIEW_THREAD,
        REVIEW_DISMISSED_EVENT,
        HEAD_REF_FORCE_PUSHED_EVENT
      ]) {
        nodes {
          __typename
          ... on PullRequestCommit {
            commit {
              oid
              abbreviatedOid
              message
              committedDate
              author {
                user { login }
                name
              }
            }
          }
          ... on PullRequestReview {
            author { login }
            state
            body
            submittedAt
          }
          ... on PullRequestReviewThread {
            comments(first: 1) {
              nodes {
                author { login }
                body
                createdAt
              }
            }
            path
            line
            isResolved
          }
          ... on ReviewDismissedEvent {
            createdAt
            actor { login }
            dismissalMessage
            review {
              author { login }
              state
            }
          }
          ... on HeadRefForcePushedEvent {
            createdAt
            actor { login }
            beforeCommit { abbreviatedOid }
            afterCommit { abbreviatedOid }
          }
        }
      }
    }
  }
}
"@

$result = Invoke-GraphQL -Query $query
$pr = $result.data.repository.pullRequest

# Build timeline
$timeline = @()

foreach ($item in $pr.timelineItems.nodes) {
    $entry = $null
    
    switch ($item.__typename) {
        "PullRequestCommit" {
            $commit = $item.commit
            $authorLogin = $commit.author.user.login ?? $commit.author.name
            $entry = [PSCustomObject]@{
                Timestamp = [DateTime]$commit.committedDate
                Type = "COMMIT"
                Actor = $authorLogin
                Description = "$($commit.abbreviatedOid): $($commit.message -split "`n" | Select-Object -First 1)"
                Icon = "📝"
            }
        }
        "PullRequestReview" {
            $stateText = switch ($item.state) {
                "APPROVED" { "approved" }
                "CHANGES_REQUESTED" { "requested changes" }
                "COMMENTED" { "commented" }
                "DISMISSED" { "dismissed" }
                default { $item.state.ToLower() }
            }
            
            $icon = switch ($item.state) {
                "APPROVED" { "✅" }
                "CHANGES_REQUESTED" { "❌" }
                "COMMENTED" { "💬" }
                default { "📋" }
            }
            
            $desc = "@$($item.author.login) $stateText"
            if ($item.body) {
                $preview = ($item.body -split "`n" | Select-Object -First 1)
                if ($preview.Length -gt 60) { $preview = $preview.Substring(0, 57) + "..." }
                $desc += ": $preview"
            }
            
            $entry = [PSCustomObject]@{
                Timestamp = [DateTime]$item.submittedAt
                Type = "REVIEW"
                Actor = $item.author.login
                Description = $desc
                Icon = $icon
                ReviewState = $item.state
            }
        }
        "PullRequestReviewThread" {
            if ($item.comments.nodes.Count -gt 0) {
                $comment = $item.comments.nodes[0]
                $preview = ($comment.body -split "`n" | Select-Object -First 1)
                if ($preview.Length -gt 60) { $preview = $preview.Substring(0, 57) + "..." }
                
                $entry = [PSCustomObject]@{
                    Timestamp = [DateTime]$comment.createdAt
                    Type = "THREAD"
                    Actor = $comment.author.login
                    Description = "@$($comment.author.login) started thread on $($item.path):$($item.line): $preview"
                    Icon = "🧵"
                    IsResolved = $item.isResolved
                }
            }
        }
        "ReviewDismissedEvent" {
            $entry = [PSCustomObject]@{
                Timestamp = [DateTime]$item.createdAt
                Type = "REVIEW_DISMISSED"
                Actor = $item.actor.login
                Description = "@$($item.actor.login) dismissed review from @$($item.review.author.login)"
                Icon = "🚫"
            }
        }
        "HeadRefForcePushedEvent" {
            $entry = [PSCustomObject]@{
                Timestamp = [DateTime]$item.createdAt
                Type = "FORCE_PUSH"
                Actor = $item.actor.login
                Description = "@$($item.actor.login) force-pushed $($item.beforeCommit.abbreviatedOid)..$($item.afterCommit.abbreviatedOid)"
                Icon = "⚡"
            }
        }
    }
    
    if ($entry) {
        $timeline += $entry
    }
}

# Sort by timestamp
$timeline = $timeline | Sort-Object -Property Timestamp

# Display timeline
Write-Host "`n━━━ PR #$($pr.number): $($pr.title) ━━━" -ForegroundColor Cyan
Write-Host "Created: $($pr.createdAt) by @$($pr.author.login)" -ForegroundColor Gray
Write-Host ""

foreach ($event in $timeline) {
    $timeStr = $event.Timestamp.ToString("yyyy-MM-dd HH:mm")
    Write-Host "$timeStr " -ForegroundColor DarkGray -NoNewline
    Write-Host "$($event.Icon) " -NoNewline
    
    $typeColor = switch ($event.Type) {
        "COMMIT" { "White" }
        "REVIEW" {
            switch ($event.ReviewState) {
                "APPROVED" { "Green" }
                "CHANGES_REQUESTED" { "Red" }
                default { "Yellow" }
            }
        }
        "THREAD" { "Cyan" }
        "REVIEW_DISMISSED" { "Magenta" }
        "FORCE_PUSH" { "Yellow" }
        default { "White" }
    }
    
    Write-Host $event.Description -ForegroundColor $typeColor
}

Write-Host "`nTotal events: $($timeline.Count)" -ForegroundColor Gray
Write-Host ""

# Output to pipeline
$timeline | ForEach-Object { Write-Output $_ }
