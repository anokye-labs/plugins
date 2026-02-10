# Evaluation 10: Agent Slash Commands

**Priority:** 🔴 Critical  
**Time:** 15 minutes  
**Prerequisites:** Installed plugin, repository with open issues and PRs, GitHub CLI authenticated

## Objective

Verify the slash command scripts return correct structured data and that the okyerema agent correctly dispatches commands. Tests the 9 commands defined in status-commands.md.

## Setup

Use a repository with active development:

```powershell
$owner = "anokye-labs"
$repo = "plugins"  # or any repo with open issues, PRs, and commits
```

## Test Steps

### 10.1 /sitrep — Tactical Status (P0)

**Action:** Run Get-Sitrep.ps1 to get tactical status.

```powershell
& .github\skills\okyerema\scripts\Get-Sitrep.ps1 `
    -Owner $owner -Repo $repo
```

**Expected:**
- [ ] Returns a PSCustomObject with structured data
- [ ] Contains fields: OpenIssues, CompletedIssues, BlockedIssues
- [ ] Contains fields: RecentCommits (array of commit info)
- [ ] Contains CurrentFocus (inferred issue/PR if available)
- [ ] No errors even if no open issues exist

### 10.2 /sitrep with Focus Issue

**Action:** Run with a specific issue focus.

```powershell
& .github\skills\okyerema\scripts\Get-Sitrep.ps1 `
    -Owner $owner -Repo $repo -IssueNumber 50
```

**Expected:**
- [ ] CurrentFocus field reflects the specified issue
- [ ] Issue details are included in the output
- [ ] Script handles non-existent issue numbers gracefully

### 10.3 /sitrep with PR Health

**Action:** Run with a specific PR to check.

```powershell
& .github\skills\okyerema\scripts\Get-Sitrep.ps1 `
    -Owner $owner -Repo $repo -PullNumber 10
```

**Expected:**
- [ ] PR field contains PR number, state, and thread counts
- [ ] Includes mergeable status and CI check state
- [ ] Shows unresolved thread count if PR has review threads

### 10.4 /sitrep Brief Mode

**Action:** Get compact output.

```powershell
& .github\skills\okyerema\scripts\Get-Sitrep.ps1 `
    -Owner $owner -Repo $repo -Brief
```

**Expected:**
- [ ] Returns a compact, single-object summary
- [ ] Suitable for inline display or agent response
- [ ] Contains key metrics without verbose details

### 10.5 /prcheck — Deep PR Health (P0)

**Action:** Run Get-PRHealth.ps1 for PR health check.

```powershell
& .github\skills\okyerema\scripts\Get-PRHealth.ps1 `
    -Owner $owner -Repo $repo -PullNumber 10
```

**Expected:**
- [ ] Returns PSCustomObject with structured PR health data
- [ ] Contains fields: Number, Title, State, Mergeable
- [ ] Contains ThreadStats with Total, Resolved, Unresolved counts
- [ ] Contains ReviewerCategories: Copilot (🤖), Devin (🤖), Human (🧑)
- [ ] Includes CI check status (passing/failing counts)
- [ ] Includes approval status and mergeable state
- [ ] Contains Recommendation field with actionable guidance

### 10.6 /prcheck Reviewer Categorization

**Action:** Verify reviewer categorization logic.

```powershell
$prHealth = & .github\skills\okyerema\scripts\Get-PRHealth.ps1 `
    -Owner $owner -Repo $repo -PullNumber 10

# Check reviewer categories
$prHealth.ReviewerCategories
```

**Expected:**
- [ ] Copilot reviews are categorized as 🤖 copilot
- [ ] Devin reviews are categorized as 🤖 devin
- [ ] All other reviews are categorized as 🧑 Human
- [ ] Category counts are accurate

### 10.7 /prcheck Brief Mode

**Action:** Get compact PR health summary.

```powershell
& .github\skills\okyerema\scripts\Get-PRHealth.ps1 `
    -Owner $owner -Repo $repo -PullNumber 10 -Brief
```

**Expected:**
- [ ] Returns compact single-line summary
- [ ] Includes critical metrics: threads, checks, mergeable status
- [ ] Suitable for inline agent response

### 10.8 /health — Structural Validation (P1)

**Action:** Run Get-HierarchyHealth.ps1 for hierarchy validation.

```powershell
& .github\skills\okyerema\scripts\Get-HierarchyHealth.ps1 `
    -Owner $owner -Repo $repo
```

**Expected:**
- [ ] Returns PSCustomObject with hierarchy health data
- [ ] Contains fields: TotalIssues, TypeDistribution (Epic, Feature, Task, Bug counts)
- [ ] Contains Orphans array (issues without parents)
- [ ] Contains TypeMismatches array (incorrect hierarchy relationships)
- [ ] Contains MaxDepth (hierarchy depth validation)
- [ ] Contains HealthScore (0-100 calculated score)
- [ ] Correctly identifies orphan issues (Tasks/Bugs without parents)

### 10.9 /health Type Mismatch Detection

**Action:** Verify type hierarchy validation.

```powershell
$health = & .github\skills\okyerema\scripts\Get-HierarchyHealth.ps1 `
    -Owner $owner -Repo $repo

# Check for type mismatches
$health.TypeMismatches
```

**Expected:**
- [ ] Detects Feature as child of Task (invalid)
- [ ] Detects Epic as child of Feature or Task (invalid)
- [ ] Accepts valid patterns: Task under Feature, Feature under Epic
- [ ] Each mismatch includes parent and child issue numbers and types

### 10.10 /health Brief Mode

**Action:** Get compact hierarchy health summary.

```powershell
& .github\skills\okyerema\scripts\Get-HierarchyHealth.ps1 `
    -Owner $owner -Repo $repo -Brief
```

**Expected:**
- [ ] Returns compact summary with key metrics
- [ ] Shows issue counts, orphan count, health score
- [ ] Suitable for quick status checks

### 10.11 /context — Session Recovery (P0, Agent-Driven)

**Action:** In a Copilot chat session, trigger context command.

> "Give me context" or "/context"

**Expected:**
- [ ] Agent identifies current repository and branch
- [ ] Shows active issues with hierarchy (Epic → Feature → Task)
- [ ] Shows open PR state if applicable
- [ ] Lists organization issue types available
- [ ] References repository conventions from copilot-instructions.md
- [ ] No script execution (agent introspection only)

### 10.12 Okyerema Agent Command Dispatch

**Action:** In a Copilot chat with okyerema agent, test command recognition.

> "@okyerema give me a sitrep"

**Expected:**
- [ ] Agent recognizes "sitrep" trigger
- [ ] Executes Get-Sitrep.ps1 script
- [ ] Formats output with emoji indicators (🎯, ✅, ⚠️, 🔴, 📊)
- [ ] Returns structured, readable status report

### 10.13 Okyerema Agent /prcheck Dispatch

**Action:** Test prcheck command dispatch.

> "@okyerema /prcheck #10"

**Expected:**
- [ ] Agent recognizes "/prcheck" trigger
- [ ] Parses PR number from command
- [ ] Executes Get-PRHealth.ps1 with correct parameters
- [ ] Formats output with emoji indicators and categories
- [ ] Provides actionable recommendation

### 10.14 Okyerema Agent /health Dispatch

**Action:** Test health command dispatch.

> "@okyerema /health"

**Expected:**
- [ ] Agent recognizes "/health" trigger
- [ ] Executes Get-HierarchyHealth.ps1 script
- [ ] Formats output with health indicators
- [ ] Highlights orphans and type mismatches if present
- [ ] Shows health score with context

### 10.15 Agent Output Formatting

**Action:** Verify agent formats script output correctly.

**Expected:**
- [ ] Agent adds emoji indicators per status-commands.md:
  - 🎯 Current focus
  - ✅ Healthy / passing / done
  - ⚠️ Warning / needs attention
  - 🔴 Blocked / failing
  - 📊 Counts summary
- [ ] Output is human-readable with proper formatting
- [ ] Raw script data is transformed into narrative format

### 10.16 Error Handling — Missing PR

**Action:** Test error handling with non-existent PR.

```powershell
& .github\skills\okyerema\scripts\Get-PRHealth.ps1 `
    -Owner $owner -Repo $repo -PullNumber 99999
```

**Expected:**
- [ ] Script handles error gracefully
- [ ] Returns meaningful error message
- [ ] Does not crash or show stack trace
- [ ] Error is descriptive about what went wrong

### 10.17 Error Handling — Invalid Repository

**Action:** Test with non-existent repository.

```powershell
& .github\skills\okyerema\scripts\Get-Sitrep.ps1 `
    -Owner "invalid-org" -Repo "nonexistent-repo"
```

**Expected:**
- [ ] Script detects repository doesn't exist
- [ ] Returns graceful error message
- [ ] No stack traces or unclear errors

### 10.18 Pipeline Compatibility

**Action:** Verify scripts work in PowerShell pipelines.

```powershell
$sitrep = & .github\skills\okyerema\scripts\Get-Sitrep.ps1 `
    -Owner $owner -Repo $repo

# Should be able to access properties
$sitrep.OpenIssues
$sitrep.RecentCommits | Select-Object -First 3
```

**Expected:**
- [ ] Scripts return proper PSCustomObject instances
- [ ] Properties are accessible via dot notation
- [ ] Nested objects/arrays are properly structured
- [ ] Compatible with PowerShell pipeline operations

## Additional Command Coverage

The following commands are agent-driven and don't have dedicated scripts. They should be tested in agent sessions:

### 10.19 /recap — Narrative Session Summary (P1)

**Action:** In an agent session with some activity, request:

> "/recap"

**Expected:**
- [ ] Agent synthesizes session activity
- [ ] Shows recent commits, closed issues, PR activity
- [ ] Presents as numbered list of actions taken
- [ ] Notes any important decisions made

### 10.20 /whatsleft — Remaining Work (P1)

**Action:** Request remaining work view.

> "/whatsleft"

**Expected:**
- [ ] Agent queries open issues with hierarchy
- [ ] Shows dependency order (blocked items marked)
- [ ] Indicates ready vs waiting tasks
- [ ] Provides prioritized list

### 10.21 /board — Project Board Summary (P2)

**Action:** Request board view.

> "/board"

**Expected:**
- [ ] Agent queries GitHub Projects V2 if configured
- [ ] Shows status columns (Todo, In Progress, Done)
- [ ] Groups issues by status
- [ ] Provides item counts per column

### 10.22 /watch — Async Monitoring (P2)

**Action:** Request watch on a PR.

> "/watch pr#10"

**Expected:**
- [ ] Agent acknowledges watch command
- [ ] Polls PR state at intervals
- [ ] Reports state changes (CI status, threads, etc.)
- [ ] Continues until stopped or PR is merged

### 10.23 /diff-since — Changes Since Checkpoint (P2)

**Action:** Request diff since a commit.

> "/diff-since abc1234"

**Expected:**
- [ ] Agent queries git log since checkpoint
- [ ] Shows commits with messages
- [ ] Shows issue state changes if available
- [ ] Shows PR activity since checkpoint

## Pass/Fail Criteria

### Critical (Must Pass)
- Steps 10.1-10.4 (/sitrep) must all pass
- Steps 10.5-10.7 (/prcheck) must all pass
- Steps 10.8-10.10 (/health) must all pass
- Step 10.11 (/context) must pass
- Steps 10.12-10.14 (agent dispatch) must pass
- Steps 10.16-10.18 (error handling and pipeline) must pass

### Important (Should Pass)
- Step 10.15 (output formatting) should pass
- Steps 10.19-10.20 (recap, whatsleft) should pass

### Nice-to-Have
- Steps 10.21-10.23 (board, watch, diff-since) are P2 features

## Success Metrics

- **100% pass:** All P0 scripts return structured data correctly
- **Agent dispatch:** Okyerema agent correctly recognizes and dispatches all commands
- **Error handling:** Scripts fail gracefully with meaningful messages
- **Output format:** Agent properly formats script output with emoji indicators
- **Pipeline compatible:** All scripts return proper PSCustomObject instances

## Notes

- All scripts are located in `.github/skills/okyerema/scripts/`
- Command reference is in `.github/skills/okyerema/references/status-commands.md`
- Agent behavior is defined in `.github/skills/okyerema/okyerema.agent.md`
- Scripts should handle pagination for large result sets
- All GitHub queries use `gh api graphql` for consistency
