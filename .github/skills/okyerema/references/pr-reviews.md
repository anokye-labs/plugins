# PR Review Intelligence

Comprehensive PR review management and intelligence capabilities.

> Back to [SKILL.md](../SKILL.md)

## Overview

The PR review intelligence suite provides tools for:

1. **Status Assessment** — Is the PR ready to merge?
2. **Comment Triage** — Which comments need action vs are optional?
3. **Issue Traceability** — Which PRs address which issues?
4. **Activity Timeline** — What happened when?
5. **Review Submission** — Submit structured reviews programmatically
6. **Thread Management** — Find, reply to, and resolve review threads

## Find Unresolved Threads

```graphql
{
  repository(owner: "ORG", name: "REPO") {
    pullRequest(number: PR_NUM) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          comments(first: 5) {
            nodes {
              author { login }
              body
              createdAt
              url
            }
            totalCount
          }
        }
        totalCount
      }
    }
  }
}
```

Filter in code: `nodes | Where-Object { -not $_.isResolved }`

## Reply to a Thread

```graphql
mutation {
  addPullRequestReviewThreadReply(input: {
    pullRequestReviewThreadId: "PRRT_xxx"
    body: "Fixed in abc123 — added backslash escaping."
  }) {
    comment {
      url
    }
  }
}
```

**Important:** Escape the body properly before embedding:
```powershell
$escaped = $Body.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n')
```

## Resolve a Thread

```graphql
mutation {
  resolveReviewThread(input: {
    threadId: "PRRT_xxx"
  }) {
    thread { isResolved }
  }
}
```

## Unresolve a Thread

```graphql
mutation {
  unresolveReviewThread(input: {
    threadId: "PRRT_xxx"
  }) {
    thread { isResolved }
  }
}
```

## Workflow: Address Review Feedback

1. **Read** unresolved threads → `Get-UnresolvedThreads.ps1`
2. **Fix** the code
3. **Commit & push** to the PR branch
4. **Reply** to each thread explaining the fix → `Reply-ReviewThread.ps1 -Resolve`
5. **Verify** no unresolved threads remain → `Get-UnresolvedThreads.ps1`

## Helper Scripts

### PR Intelligence Scripts

| Script | Purpose |
|--------|---------|
| `Get-PRStatus.ps1` | Comprehensive PR status check (approvals, checks, merge readiness) |
| `Get-ThreadSeverity.ps1` | Categorize review comments by actionability (MUST_FIX, SUGGESTION, QUESTION, NIT, INFO) |
| `Find-IssueByPR.ps1` | Discover PRs associated with specific issues |
| `Get-PRTimeline.ps1` | Timeline view of review activity on a PR |
| `Submit-PRReview.ps1` | Submit structured PR reviews programmatically |

### Thread Management Scripts

| Script | Purpose |
|--------|---------|
| `Get-UnresolvedThreads.ps1` | List unresolved (or all) threads with comment details |
| `Reply-ReviewThread.ps1` | Reply to a thread by ID or index, optionally resolve |
| `Resolve-ReviewThreads.ps1` | Bulk resolve/unresolve threads |

## Common Patterns

### Reply and resolve all unresolved threads with the same message
```powershell
$threads = .\Get-UnresolvedThreads.ps1 -Owner ORG -Repo REPO -PullNumber 6
foreach ($t in $threads) {
    .\Reply-ReviewThread.ps1 -Owner ORG -Repo REPO -PullNumber 6 -ThreadId $t.id -Body "Addressed in commit abc123" -Resolve
}
```

### Bulk resolve all (no reply)
```powershell
.\Resolve-ReviewThreads.ps1 -Owner ORG -Repo REPO -PullNumber 6 -All
```

## PR Status Check

Get comprehensive PR status including approvals, CI checks, and merge readiness:

```powershell
.\Get-PRStatus.ps1 -Owner anokye-labs -Repo plugins -PullNumber 50
```

Returns a structured object with:
- Approval counts (approved, changes requested, commented)
- CI check state and individual check results
- Merge readiness with blocking reasons
- Review decision status

**Use JSON output for programmatic consumption:**
```powershell
.\Get-PRStatus.ps1 -Owner anokye-labs -Repo plugins -PullNumber 50 -Json
```

## Comment Severity Analysis

Categorize review comments by actionability:

```powershell
.\Get-ThreadSeverity.ps1 -Owner anokye-labs -Repo plugins -PullNumber 50 -GroupBySeverity
```

Categories:
- **MUST_FIX**: Critical issues requiring action
- **QUESTION**: Clarifying questions
- **SUGGESTION**: Optional improvements
- **NIT**: Minor style/formatting
- **INFO**: Informational comments

**Use for triage:**
```powershell
$threads = .\Get-ThreadSeverity.ps1 -Owner anokye-labs -Repo plugins -PullNumber 50
$critical = $threads | Where-Object { $_.Severity -eq "MUST_FIX" }
foreach ($t in $critical) {
    Write-Host "Address: $($t.Path):$($t.Line) - $($t.Body)"
}
```

## Find PRs by Issue

Discover which PRs are linked to a specific issue:

```powershell
.\Find-IssueByPR.ps1 -Owner anokye-labs -Repo plugins -IssueNumber 42
```

Link types:
- **CLOSES**: PR closes the issue
- **CONNECTED**: PR is connected via development timeline
- **REFERENCED**: PR references the issue

**Include closed PRs:**
```powershell
.\Find-IssueByPR.ps1 -Owner anokye-labs -Repo plugins -IssueNumber 42 -IncludeClosed
```

## PR Timeline

View chronological review activity:

```powershell
.\Get-PRTimeline.ps1 -Owner anokye-labs -Repo plugins -PullNumber 50
```

Shows:
- 📝 Commits
- ✅/❌/💬 Reviews (approved, changes requested, commented)
- 🧵 Review thread creation
- 🚫 Review dismissals
- ⚡ Force pushes

**Increase event limit:**
```powershell
.\Get-PRTimeline.ps1 -Owner anokye-labs -Repo plugins -PullNumber 50 -Limit 100
```

## Submit PR Review

Programmatically submit reviews with comments:

```powershell
# Approve with summary
.\Submit-PRReview.ps1 -Owner anokye-labs -Repo plugins -PullNumber 50 `
    -Event APPROVE -Body "LGTM! Great work."

# Request changes with line comments
$comments = @(
    @{ Path = "src/main.ps1"; Line = 42; Body = "Add error handling here" }
    @{ Path = "README.md"; Line = 10; Body = "Fix typo: 'recieve' → 'receive'" }
)
.\Submit-PRReview.ps1 -Owner anokye-labs -Repo plugins -PullNumber 50 `
    -Event REQUEST_CHANGES -Body "Found a few issues" -Comments $comments
```

## GraphQL Operations

### Find Unresolved Threads
