# Status & Slash Commands

**[← Back to SKILL.md](../SKILL.md)**

Quick-access commands that surface project state. Scripts return structured data; agents format the output.

---

## Command Reference

### `/sitrep` — Tactical Status

| | |
|---|---|
| **Priority** | P0 |
| **Trigger** | `/sitrep`, "what's the status", "where are we" |
| **Queries** | Open issues, recent commits, unresolved PR threads, git status |
| **Script** | `scripts/Get-Sitrep.ps1` |

**Output format:**
```
🎯 Focus: <current issue or PR>
📊 Done: 4 │ Pending: 3 │ Blocked: 1
🔀 PR #12: 2 unresolved threads │ CI: ✅ passing
⚠️  Blockers: #8 waiting on API design
```

**Emoji indicators:**
- 🎯 Current focus
- ✅ Healthy / passing / done
- ⚠️ Warning / needs attention
- 🔴 Blocked / failing
- 📊 Counts summary

---

### `/context` — Session Recovery

| | |
|---|---|
| **Priority** | P0 |
| **Trigger** | `/context`, "catch me up", "what repo is this" |
| **Queries** | Git remote, current branch, open issues, PR state, project conventions |
| **Script** | Manual (git + gh CLI introspection) |

**Output format:**
```
📂 Repo: anokye-labs/akwaaba (branch: feature/slash-commands)
🎫 Active issues: #14 (Epic), #106 (Feature), #15 (Task — in progress)
🔀 Open PR: #12 → main (3 commits ahead)
🏷️ Issue types: Epic, Feature, Task, Bug
📐 Conventions: tasklists for hierarchy, no label-as-type
```

---

### `/recap` — Narrative Session Summary

| | |
|---|---|
| **Priority** | P1 |
| **Trigger** | `/recap`, "what did we do", "summarize this session" |
| **Queries** | Recent commits, closed issues, PR activity, conversation history |
| **Script** | Manual (agent synthesizes from session + git log) |

**Output format:**
```
📝 Session Recap (last 2 hours)

1. Created Feature #106 under Epic #14
2. Implemented Get-Sitrep.ps1 — queries issues + PR threads
3. Fixed GraphQL escaping bug (commit abc1234)
4. ⚠️ Decided: use sub-issues API instead of tasklists for new hierarchy queries
5. PR #12: pushed 3 commits, 1 thread resolved, 2 remaining
```

---

### `/whatsleft` — Remaining Work

| | |
|---|---|
| **Priority** | P1 |
| **Trigger** | `/whatsleft`, "what's remaining", "what's next" |
| **Queries** | Open issues with hierarchy, dependency order, blocked items |
| **Script** | Manual (filters open issues from hierarchy) |

**Output format:**
```
📋 Remaining (5 items)

1. 🔴 #8  Task: API schema design (blocked — needs decision)
2. ⬜ #15 Task: Create SKILL.md (ready — no dependencies)
3. ⬜ #16 Task: Convert scripts (ready — no dependencies)
4. ⏳ #17 Task: Integration tests (waiting on #15, #16)
5. ⏳ #18 Task: Documentation (waiting on #17)
```

---

### `/prcheck [owner/repo#number]` — Deep PR Health

| | |
|---|---|
| **Priority** | P0 |
| **Trigger** | `/prcheck`, `/prcheck owner/repo#12`, "is this PR ready" |
| **Queries** | Mergeable state, review threads, checks, approvals, reviewer categorization |
| **Script** | `scripts/Get-PRHealth.ps1` |

**Output format:**
```
🔀 PR #12: feature/slash-commands → main

📊 Threads: 5 total │ 3 resolved │ 2 unresolved
   🤖 Copilot: 2 threads (1 resolved)
   🧑 Human: 3 threads (2 resolved, 1 unresolved)
✅ Checks: 4/4 passing
👤 Approvals: 1 approved, 0 changes requested
🔀 Mergeable: MERGEABLE
📋 Recommendation: Address 1 human thread, then merge
```

**Reviewer categories:**
- 🤖 `copilot` — GitHub Copilot reviews
- 🤖 `devin` — Devin AI reviews
- 🧑 Human — all other reviewers

---

### `/health` — Structural Validation

| | |
|---|---|
| **Priority** | P1 |
| **Trigger** | `/health`, "check hierarchy health", "any orphans" |
| **Queries** | All open issues, type distribution, orphan detection, hierarchy depth |
| **Script** | `scripts/Get-HierarchyHealth.ps1` |

**Output format:**
```
🏥 Hierarchy Health: anokye-labs/akwaaba

📊 Issues: 12 open
   Epic: 2 │ Feature: 4 │ Task: 5 │ Bug: 1
⚠️ Orphans (no parent): 2
   #19 Task: Stray cleanup task
   #21 Bug: Login regression
❌ Type mismatches: 1
   #106 Feature is child of #15 Task (should be child of Epic)
🏗️ Max depth: 3 (Epic → Feature → Task) ✅
💯 Health score: 78/100
```

---

### `/board [project]` — Project Board Summary

| | |
|---|---|
| **Priority** | P2 |
| **Trigger** | `/board`, `/board "Phase 2"`, "show me the board" |
| **Queries** | GitHub Project V2 items, status field values |
| **Script** | Manual (uses projects.md reference queries) |

**Output format:**
```
📋 Board: Phase 2

Todo        │ In Progress │ Done
────────────┼─────────────┼──────
#15 Task    │ #16 Task    │ #10 Task ✓
#17 Task    │             │ #11 Task ✓
#18 Task    │             │ #12 Task ✓
(3 items)   │ (1 item)    │ (3 items)
```

---

### `/watch [resource]` — Async Monitoring

| | |
|---|---|
| **Priority** | P2 |
| **Trigger** | `/watch pr#12`, `/watch ci`, "watch this PR" |
| **Queries** | Polls resource state at intervals |
| **Script** | Manual (agent loop with sleep) |

**Output format:**
```
👁️ Watching PR #12 (polling every 60s)

[14:32] CI: ⏳ running (2/4 checks)
[14:33] CI: ✅ all checks passed
[14:33] Threads: 2 unresolved → 1 unresolved (thread on line 42 resolved)
[14:33] Status: ready for review
```

---

### `/diff-since [checkpoint]` — Changes Since Checkpoint

| | |
|---|---|
| **Priority** | P2 |
| **Trigger** | `/diff-since abc1234`, `/diff-since "last session"` |
| **Queries** | Git log, issue state changes, PR activity since checkpoint |
| **Script** | Manual (git log + gh API) |

**Output format:**
```
📝 Changes since abc1234 (3 hours ago)

Commits (4):
  def5678 Fix escaping in GraphQL queries
  ghi9012 Add Get-Sitrep.ps1 script
  jkl3456 Update SKILL.md with command references
  mno7890 Add status-commands.md reference

Issues:
  #15 Task: OPEN → CLOSED
  #19 Task: created (orphan — needs parent)

PR #12:
  +2 commits, 1 thread resolved
```

---

## Script Inventory

| Script | Command | Priority | Status |
|--------|---------|----------|--------|
| `Get-Sitrep.ps1` | `/sitrep` | P0 | ✅ Implemented |
| `Get-PRHealth.ps1` | `/prcheck` | P0 | ✅ Implemented |
| `Get-HierarchyHealth.ps1` | `/health` | P1 | ✅ Implemented |
| *(agent-driven)* | `/context` | P0 | Agent introspection |
| *(agent-driven)* | `/recap` | P1 | Agent synthesis |
| *(agent-driven)* | `/whatsleft` | P1 | Agent + hierarchy query |
| *(agent-driven)* | `/board` | P2 | Agent + projects API |
| *(agent-driven)* | `/watch` | P2 | Agent polling loop |
| *(agent-driven)* | `/diff-since` | P2 | Agent + git log |

## Design Principles

1. **Scripts return PSCustomObject/JSON** — agents format output with emoji
2. **All GitHub queries use `gh api graphql`** — consistent auth and error handling
3. **Include `-Brief` switch** — compact output for inline use
4. **Handle pagination** — large repos may exceed single-page results
5. **Graceful errors** — missing repos, no permissions, empty results

**[← Back to SKILL.md](../SKILL.md)**
