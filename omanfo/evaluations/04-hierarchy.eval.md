# Evaluation 4: Hierarchy Building

**Priority:** 🔴 Critical  
**Time:** 15 minutes  
**Prerequisites:** Installed plugin, can create issues in test repo

## Objective

Verify the plugin can build parent-child hierarchies using sub-issues API and verify them.

## Setup

Create a set of test issues for hierarchy testing:

```powershell
$owner = "anokye-labs"
$repo = "plugins"

# Create parent Epic
$epic = & .github\skills\okyerema\scripts\New-IssueWithType.ps1 `
    -Owner $owner -Repo $repo `
    -Title "Eval 4: Test Epic" -TypeName "Epic" `
    -Body "Hierarchy evaluation parent."

# Create child Features
$feat1 = & .github\skills\okyerema\scripts\New-IssueWithType.ps1 `
    -Owner $owner -Repo $repo `
    -Title "Eval 4: Feature A" -TypeName "Feature" -Body "First feature."

$feat2 = & .github\skills\okyerema\scripts\New-IssueWithType.ps1 `
    -Owner $owner -Repo $repo `
    -Title "Eval 4: Feature B" -TypeName "Feature" -Body "Second feature."

# Create child Tasks under Feature A
$task1 = & .github\skills\okyerema\scripts\New-IssueWithType.ps1 `
    -Owner $owner -Repo $repo `
    -Title "Eval 4: Task A.1" -TypeName "Task" -Body "First task."

$task2 = & .github\skills\okyerema\scripts\New-IssueWithType.ps1 `
    -Owner $owner -Repo $repo `
    -Title "Eval 4: Task A.2" -TypeName "Task" -Body "Second task."
```

## Test Steps

### 4.1 Create 2-Level Hierarchy (Epic → Features)

**Action:** Link features to epic.

```powershell
# Get issue numbers from the creation output
& .github\skills\okyerema\scripts\Update-IssueHierarchy.ps1 `
    -Owner $owner -Repo $repo `
    -ParentNumber <epic-number> `
    -ChildNumbers @(<feat1-number>, <feat2-number>)
```

**Expected:**
- [ ] Epic and Features are linked via sub-issues API
- [ ] Both features appear as sub-issues of the epic
- [ ] Script completes without error

### 4.2 Verify Relationships

**Action:** Verify the relationships immediately (no waiting required).

```powershell
& .github\skills\okyerema\scripts\Test-Hierarchy.ps1 `
    -Owner $owner -Repo $repo `
    -IssueNumber <epic-number> `
    -Depth 2
```

**Expected:**
- [ ] GitHub UI shows parent-child relationships
- [ ] GraphQL query returns correct structure
- [ ] No delay needed for verification

### 4.3 Create 3-Level Hierarchy (Epic → Feature → Tasks)

**Action:** Link tasks to Feature A.

```powershell
& .github\skills\okyerema\scripts\Update-IssueHierarchy.ps1 `
    -Owner $owner -Repo $repo `
    -ParentNumber <feat1-number> `
    -ChildNumbers @(<task1-number>, <task2-number>)
```

**Expected:**
- [ ] Feature A has both tasks as sub-issues
- [ ] Relationships are created via sub-issues API
- [ ] No body modification needed

### 4.4 Verify Hierarchy Tree

**Action:** Use the hierarchy verification script.

```powershell
& .github\skills\okyerema\scripts\Test-Hierarchy.ps1 `
    -Owner $owner -Repo $repo `
    -IssueNumber <epic-number> `
    -Depth 3
```

**Expected:**
- [ ] Tree output shows 3 levels: Epic → Features → Tasks
- [ ] All issue titles are correct
- [ ] States (open/closed) are shown
- [ ] Types are displayed

### 4.5 Idempotent Updates

**Action:** Run the same hierarchy update again.

```powershell
& .github\skills\okyerema\scripts\Update-IssueHierarchy.ps1 `
    -Owner $owner -Repo $repo `
    -ParentNumber <epic-number> `
    -ChildNumbers @(<feat1-number>, <feat2-number>)
```

**Expected:**
- [ ] Existing relationships are maintained
- [ ] Script handles existing entries gracefully
- [ ] No errors or duplicate relationships

### 4.6 Copilot Builds Hierarchy

**Action:** In Copilot chat, ask:

> "Create a Feature issue titled 'Eval 4.6 Feature' and two Task children titled 'Task C.1' and 'Task C.2' in anokye-labs/plugins. Link them as parent-child."

**Expected:**
- [ ] Copilot creates all 3 issues with correct types
- [ ] Builds the hierarchy correctly
- [ ] Reports the created structure

## Cleanup

Close all evaluation issues:

```powershell
gh issue list -R "$owner/$repo" --search "Eval 4" --json number | ConvertFrom-Json | ForEach-Object { gh issue close $_.number -R "$owner/$repo" }
```

## Pass/Fail

- **PASS:** Steps 4.1, 4.3, 4.4, and 4.6 succeed
- **FAIL:** Any critical step fails
