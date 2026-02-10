# Agentic Workflows Reference

Okyerema leverages GitHub Agentic Workflows and the Copilot Coding Agent to
automate issue governance and accelerate development. This reference covers
the systems, patterns, and workflows Okyerema should understand, propose, and
manage.

## Overview: Three Automation Layers

Okyerema operates across three automation layers, each with increasing autonomy:

| Layer | Mechanism | What It Does | Human Role |
|-------|-----------|--------------|------------|
| **Interactive** | Copilot CLI / Agent mode | Okyerema creates issues, reports status, asks for clarity | Direct collaboration |
| **Assign-to-Copilot** | `@copilot` issue assignment | Copilot coding agent creates branch + PR from issue | Review PR |
| **Agentic Workflows** | `gh-aw` markdown → Actions | Event-driven automation (triage, governance, health) | Monitor + override |

The goal: in interactive mode, Okyerema mostly creates issues and reports
status. Everything else is automated.

## Layer 1: Interactive Communication

Okyerema's core role. It creates well-specified issues, builds hierarchies,
and monitors progress. Human intervention only for:
- Resolving ambiguity in requirements
- Making scope/priority decisions
- Approving destructive operations (closing epics, reassigning work)

## Layer 2: Assign-to-Copilot (@copilot)

### How It Works
1. Okyerema creates a fully-specified issue with acceptance criteria
2. Issue is assigned to `@copilot`
3. Copilot coding agent reads the issue, plans work, creates a `copilot/*` branch
4. Agent writes code, runs tests, pushes commits
5. Agent opens a draft PR referencing the issue
6. Human reviews and merges

### When Okyerema Should Propose @copilot Assignment
- Well-scoped Tasks (not Epics or Features)
- Clear acceptance criteria exist
- Low-to-medium complexity (bug fixes, test coverage, docs, refactoring)
- No security-sensitive changes
- Repository has CI/CD configured

### Issue Format for @copilot
Issues assigned to @copilot should be written as AI-readable prompts:
```markdown
## Task
[Clear, actionable description of what to do]

## Acceptance Criteria
- [ ] Specific testable criterion 1
- [ ] Specific testable criterion 2
- [ ] Tests pass

## Context
- Related files: `path/to/file1.ts`, `path/to/file2.ts`
- Related issue: #parent-issue
- Constraints: [any technical constraints]

## Out of Scope
- [What NOT to change]
```

### Assigning Issues to Copilot Bot

**Important:** Copilot bot assignment is an exception to the "GraphQL for all writes" rule. Use REST API for reliable bot assignment.

```bash
# Assign Copilot to an issue using REST API (RECOMMENDED)
gh api repos/{owner}/{repo}/issues/{num}/assignees \
  --method POST \
  -f 'assignees[]=Copilot'

# Or using gh CLI wrapper (also uses REST internally)
# NOTE: @ prefix is REQUIRED for CLI (casing doesn't matter: @copilot or @Copilot)
gh issue edit {num} --add-assignee "@copilot"
```

**Prerequisites:**
- Copilot coding agent must be enabled at the organization level before assignment will work
- Copilot does NOT appear in standard `/assignees` or `/collaborators` API endpoints (org-level enablement is required)

**Why REST is Required:**
- Copilot's node ID (e.g., `BOT_kgDOC9w8XQ`) is a BOT type, not a User type
- GraphQL `addAssigneesToAssignable` mutation returns `NOT_FOUND` for BOT IDs
- REST API `/repos/{owner}/{repo}/issues/{number}/assignees` properly handles bot assignees

## Layer 3: Agentic Workflows (gh-aw)

### What Are Agentic Workflows?
Natural language automation files (`.md`) that compile into GitHub Actions
YAML (`.lock.yml`). They use AI agents (Copilot, Claude, Codex) to make
context-aware decisions, but all write operations go through a validated
`safe-outputs` pipeline.

### File Format
```markdown
---
timeout-minutes: 10

on:
  issues:
    types: [opened, reopened]

permissions:
  issues: read

tools:
  github:
    toolsets: [issues, labels]

safe-outputs:
  add-labels:
    allowed: [bug, feature, task, needs-triage]
  add-comment: {}
---

# Issue Triage Agent

Analyze the newly opened issue in ${{ github.repository }}.
[Natural language instructions for the AI agent...]
```

### Key Concepts

**Triggers (`on:`)** — Same as GitHub Actions events:
- `issues: [opened, reopened, labeled, assigned]`
- `pull_request: [opened, synchronize, review_requested]`
- `schedule: daily` (cron-based)
- `issue_comment: [created]`
- `workflow_dispatch:` (manual)

**Permissions** — Least-privilege, read-only for the agent job:
- `issues: read`, `pull-requests: read`, `contents: read`
- Write permissions only on the safe-output jobs

**Safe Outputs** — The ONLY way agents perform writes:
- `add-comment: {}` — post a comment
- `add-labels: { allowed: [...] }` — add from allowlist
- `create-issue: {}` — create a new issue
- `create-pull-request: {}` — create a PR
- `close-issue: {}` — close an issue
- `update-issue: {}` — update issue fields

Agent runs read-only → emits structured JSONL of intended outputs →
separate downstream Actions jobs execute writes with narrow permissions.

**Compilation:**
```powershell
# Install the CLI extension
gh extension install github/gh-aw

# Compile markdown to Actions YAML
gh aw compile

# Strict mode with security scanning
gh aw compile --strict --actionlint --zizmor --poutine
```

Both `.md` source and `.lock.yml` compiled output are committed to the repo.
Markdown body can be edited on GitHub.com without recompilation.

### Workflows Okyerema Should Propose

When Okyerema detects a repository lacks automation, it should propose
creating these agentic workflows (as issues with accompanying workflow files):

#### 1. Issue Triage (`issue-triage.md`)
**Trigger:** `issues: [opened]`
**Purpose:** Auto-label, ask clarifying questions, suggest assignment
```markdown
Analyze the newly opened issue. Based on title, body, and repository context:
1. Apply the most appropriate label from the allowed set
2. If the description is unclear, post a comment asking for clarification
3. If the issue is actionable, suggest it for assignment to @copilot
```

#### 2. Stale Issue Patrol (`stale-patrol.md`)
**Trigger:** `schedule: daily`
**Purpose:** Find and flag stale issues, close abandoned ones
```markdown
Find issues that have been open with no activity for 14+ days.
- Post a comment asking for an update
- If already warned 7+ days ago with no response, close with explanation
- Skip issues labeled "long-running" or "blocked"
```

#### 3. PR Health Monitor (`pr-health.md`)
**Trigger:** `schedule: every 6 hours` or `pull_request: [review_requested]`
**Purpose:** Check PR readiness, nudge reviewers
```markdown
For each open pull request:
- Check if CI has passed
- Check if reviews are complete
- If PR has been waiting for review for 48+ hours, comment tagging reviewers
- If all checks pass and approved, comment that PR is ready to merge
```

#### 4. Issue Lifecycle Governance (`issue-lifecycle.md`)
**Trigger:** `issues: [closed, reopened, assigned]`
**Purpose:** Enforce lifecycle rules
```markdown
When an issue is closed:
- Verify all sub-issues are also closed (warn if not)
- Update parent issue progress comment
- If part of a project, update board status

When an issue is assigned:
- If no type is set, apply best-guess type based on title/body
- If no parent, flag as orphan in a comment
```

#### 5. Sub-Issue Progress Tracker (`progress-tracker.md`)
**Trigger:** `issues: [closed, opened]`
**Purpose:** Auto-update parent issues with progress
```markdown
When a sub-issue is closed or opened:
- Find its parent issue
- Count closed vs total sub-issues
- Update or create a progress comment on the parent:
  "Progress: 3/5 sub-issues complete (60%)"
```

#### 6. Release Notes Generator (`release-notes.md`)
**Trigger:** `release: [published]` or `workflow_dispatch:`
**Purpose:** Generate release notes from closed issues and merged PRs
```markdown
Collect all issues closed and PRs merged since the last release.
Group by type (Feature, Bug, Task). Generate markdown release notes.
```

## Design Patterns: The Anokye System

The Anokye System is our multi-agent orchestration architecture for
software development, built natively on GitHub's platform using Akan
naming conventions.

### Architecture: Roles and Their Akan Names

| Anokye Role | Akan Meaning | Mechanism |
|-------------|-------------|-----------|
| **Okyeame** | Linguist | The voice — gives status updates, reports on blocked issues, asks for clarity when needed. |
| **Okyerema** | Master drummer | The master drummer of the asafo — keeps the warriors in rhythm through workflow automation, patrols, and CI/CD. Invoked by Okyeame. |
| **Ananse** | Spider (folklore) | The agentic runtime — `@copilot` coding agent and gh-aw workflows |
| **Asafo** | Warrior company | Implementation agents — pick up Tasks, create branches, write code, open PRs |
| **Adwoma** | Work | GitHub Issues as external memory — every task, decision, and status recorded |
| **Sankofa** | Return and get it | Scheduled health checks — stale patrol, orphan detection, progress tracking |

### Core Principles

1. **Okyeame speaks, Asafo implements.** The linguist gives voice;
   the warriors execute. Okyeame never writes code — it creates the issues
   that Asafo agents (including `@copilot`) pick up and deliver.

2. **Okyerema keeps the rhythm.** The master drummer of the asafo keeps
   the warriors in cadence. When Okyeame
   identifies a pattern that should be automated, it invokes Okyerema to
   configure the appropriate workflow (gh-aw, GitHub Actions, Temporal, etc.).

3. **Adwoma is the single source of truth.** GitHub Issues are the external
   memory. Not markdown plans, not session state, not local files. If it's
   not in an issue, it doesn't exist for coordination purposes. We use
   GitHub's native issue graph as the single source of truth.

4. **Zero-Footprint Computing.** Agents derive state by querying the API,
   not from local memory. This eliminates stale state and makes agents
   resilient to restarts, context loss, and session boundaries.

5. **Sankofa patrols keep the system healthy.** Scheduled agentic workflows
   (configured by Okyerema) run continuously to detect stale issues, orphaned
   work, unresolved PR threads, and lifecycle violations. The `/health` command
   is the interactive version; Sankofa workflows are the automated version.

6. **Automate the predictable, ask about the ambiguous.** If a governance
   pattern repeats, Okyeame invokes Okyerema to make it an agentic workflow.
   Interactive involvement should shrink over time as more patterns get
   automated. Human attention is reserved for decisions that require
   judgment, creativity, or domain knowledge.

### How Work Flows Through the Anokye System

```
Human Request
    │
    ▼
┌─────────────┐
│   Okyeame   │ ← Linguist: status updates, blockers, asks for clarity
│ (Linguist)  │
└──────┬──────┘
       │ Creates well-specified Tasks
       │ Invokes Okyerema for automation config
       ▼
┌─────────────┐     ┌──────────────┐
│  Okyerema   │     │    Asafo     │ ← Worker agents pick up Tasks
│  (Drummer)  │     │  (Warriors)  │   @copilot creates branch + PR
└──────┬──────┘     └──────┬───────┘
       │ Configures         │ Opens draft PR
       │ workflows          ▼
       ▼              ┌──────────────┐
┌─────────────┐       │    Human     │ ← Reviews via PR UI
│  Sankofa    │       │   Review     │
│  (Patrols)  │       └──────────────┘
└─────────────┘
  Automated
  governance
```

### Lifecycle: How Issues Move Through Stages

```
Created → Triaged → Assigned → In Progress → In Review → Done
   │         │         │           │              │
   │    [auto-label]  [assign    [branch      [PR opened,
   │    [ask for      @copilot]  created,     CI checks,
   │    clarity]                 commits]     review]
   │
   └─ Sankofa patrol catches if stuck at any stage
```

Each transition can be:
- **Automated** via agentic workflow (preferred)
- **Interactive** via Okyerema in a session (fallback)
- **Manual** via human directly (escape hatch)

## Okyerema's Decision Tree

When asked to move work forward, Okyerema follows this priority order:

```
1. Does an agentic workflow exist for this? → Let it handle it
2. Can this be assigned to @copilot? → Create issue, assign, monitor
3. Does this need human decision? → Ask the specific question
4. Is this a communication task? → Do it directly (status, blockers, clarity)
5. None of the above? → Create an issue proposing a new workflow
```

### Proposing New Workflows
When Okyerema identifies a pattern that should be automated:

1. Create a Feature issue: "Add {workflow-name} agentic workflow"
2. Include the proposed `.md` workflow file in the issue body
3. Specify the trigger, permissions, and safe-outputs
4. Link to related issues that would benefit
5. If approved, the implementation agent creates the actual workflow file

## Copilot Instructions Integration

Repositories should have `.github/copilot-instructions.md` with:
- Coding standards and conventions
- Tech stack details
- Testing requirements
- File organization patterns
- Known gotchas

These instructions are read by both Copilot agent mode (interactive)
and the Copilot coding agent (@copilot issue assignment). Okyerema
should check for this file and propose creating one if missing.

## References

- [GitHub Agentic Workflows](https://githubnext.com/projects/agentic-workflows/)
- [gh-aw CLI](https://github.com/github/gh-aw)
- [Agentic Workflows Markdown Reference](https://github.github.io/gh-aw/reference/markdown/)
- [Safe Outputs Reference](https://github.github.io/gh-aw/reference/safe-outputs/)
- [Copilot Coding Agent Best Practices](https://docs.github.com/copilot/how-tos/agents/copilot-coding-agent/best-practices-for-using-copilot-to-work-on-tasks)
