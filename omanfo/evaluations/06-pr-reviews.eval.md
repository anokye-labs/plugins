# Evaluation 6: PR Review Management

**Priority:** 🟡 Important  
**Time:** 10 minutes  
**Prerequisites:** Installed plugin, a PR with review comments

## Objective

Verify the PR review thread scripts work for finding, replying to, and resolving threads.

## Setup

Use an existing PR with review comments, or create one:

```powershell
$owner = "anokye-labs"
$repo = "plugins"  # or akwaaba which has PR history
$prNumber = 6       # Use a PR with review threads
```

## Test Steps

### 6.1 List Unresolved Threads

**Action:** Find unresolved review threads.

```powershell
& .github\skills\okyerema\scripts\Get-UnresolvedThreads.ps1 `
    -Owner $owner -Repo $repo -PullNumber $prNumber
```

**Expected:**
- [ ] Returns thread objects with: ThreadId, Index, Author, Body, IsResolved, File, Line
- [ ] Pipeline-compatible output (objects, not strings)
- [ ] Handles PRs with no threads gracefully

### 6.2 List with Brief Mode

**Action:** Get a summary view.

```powershell
& .github\skills\okyerema\scripts\Get-UnresolvedThreads.ps1 `
    -Owner $owner -Repo $repo -PullNumber $prNumber -Brief
```

**Expected:**
- [ ] Compact output suitable for overview
- [ ] Shows thread count and key info

### 6.3 Include Resolved Threads

**Action:** Show all threads including resolved ones.

```powershell
& .github\skills\okyerema\scripts\Get-UnresolvedThreads.ps1 `
    -Owner $owner -Repo $repo -PullNumber $prNumber -IncludeResolved
```

**Expected:**
- [ ] Returns both resolved and unresolved threads
- [ ] IsResolved field distinguishes them

### 6.4 Reply to a Thread

**Action:** Reply to a specific thread.

```powershell
# Get the first thread
$threads = & .github\skills\okyerema\scripts\Get-UnresolvedThreads.ps1 `
    -Owner $owner -Repo $repo -PullNumber $prNumber

if ($threads) {
    & .github\skills\okyerema\scripts\Reply-ReviewThread.ps1 `
        -Owner $owner -Repo $repo -PullNumber $prNumber `
        -ThreadIndex 0 `
        -Body "Evaluation test reply. Safe to ignore."
}
```

**Expected:**
- [ ] Reply is posted to the correct thread
- [ ] Reply appears in GitHub UI
- [ ] Thread is NOT resolved (no -Resolve flag)

### 6.5 Resolve Threads

**Action:** Resolve a specific thread.

```powershell
if ($threads) {
    & .github\skills\okyerema\scripts\Resolve-ReviewThreads.ps1 `
        -Owner $owner -Repo $repo -PullNumber $prNumber `
        -ThreadIds @($threads[0].ThreadId)
}
```

**Expected:**
- [ ] Thread is marked as resolved in GitHub UI
- [ ] Script reports success

### 6.6 Copilot Manages Reviews

**Action:** In Copilot chat:

> "Show me the unresolved review threads on PR #6 in anokye-labs/akwaaba."

**Expected:**
- [ ] Copilot uses the okyerema skill
- [ ] Returns thread details
- [ ] Can follow up to reply or resolve

## Pass/Fail

- **PASS:** Steps 6.1, 6.4, and 6.5 succeed
- **FAIL:** Scripts error out or produce incorrect results
