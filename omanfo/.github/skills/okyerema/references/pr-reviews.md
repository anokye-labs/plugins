# PR Review Threads

GraphQL operations for managing pull request review conversations.

> Back to [SKILL.md](../SKILL.md)

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

### Manual Workflow

1. **Read** unresolved threads → `Get-UnresolvedThreads.ps1`
2. **Classify** thread severity → `Get-ThreadSeverity.ps1`
3. **Fix** the code
4. **Commit & push** to the PR branch
5. **Reply** to each thread explaining the fix → `Reply-ReviewThread.ps1 -Resolve`
6. **Verify** no unresolved threads remain → `Get-UnresolvedThreads.ps1`

### Automated Workflow

Use `Invoke-PRCompletion.ps1` for automated orchestration of the review-classify-fix-commit-push-reply-resolve cycle:

```powershell
# Run the complete PR completion loop
.\Invoke-PRCompletion.ps1 -Owner ORG -Repo REPO -PullNumber 6

# Dry-run mode to preview actions
.\Invoke-PRCompletion.ps1 -Owner ORG -Repo REPO -PullNumber 6 -DryRun

# With options: max iterations, auto-resolve, min severity filter
.\Invoke-PRCompletion.ps1 -Owner ORG -Repo REPO -PullNumber 6 `
    -MaxIterations 3 -AutoResolve -MinSeverity High
```

## Helper Scripts

| Script | Purpose |
|--------|---------|
| `Get-UnresolvedThreads.ps1` | List unresolved (or all) threads with comment details |
| `Get-ThreadSeverity.ps1` | Classify review threads by severity (Critical, High, Medium, Low, Info) |
| `Reply-ReviewThread.ps1` | Reply to a thread by ID or index, optionally resolve |
| `Resolve-ReviewThreads.ps1` | Bulk resolve/unresolve threads |
| `Invoke-PRCompletion.ps1` | Orchestrate complete review-fix-push-reply-resolve cycle |

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

### Classify threads by severity
```powershell
# Analyze all unresolved threads
.\Get-ThreadSeverity.ps1 -Owner ORG -Repo REPO -PullNumber 6

# Analyze specific thread by index
.\Get-ThreadSeverity.ps1 -Owner ORG -Repo REPO -PullNumber 6 -ThreadIndex 0
```

### Automated PR completion loop
```powershell
# Dry-run mode to preview what would happen
.\Invoke-PRCompletion.ps1 -Owner ORG -Repo REPO -PullNumber 6 -DryRun

# Run with automatic resolution and high-severity filter
.\Invoke-PRCompletion.ps1 -Owner ORG -Repo REPO -PullNumber 6 `
    -AutoResolve -MinSeverity High -MaxIterations 2
```
