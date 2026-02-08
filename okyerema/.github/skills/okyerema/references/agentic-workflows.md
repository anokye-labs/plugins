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

## Layer 1: Interactive Coordination

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

### Discovering the Copilot Bot Node ID
Standard CLI can't assign to the bot. Use GraphQL:
```powershell
# Find bot ID from an issue where Copilot is already assigned
gh api repos/{owner}/{repo}/issues/{num} --jq '.assignees[] | select(.login=="Copilot") | .node_id'
# Returns: BOT_kgDO...

# Assign via GraphQL
gh api graphql -f query='mutation {
  updateIssue(input: {
    id: "{ISSUE_NODE_ID}"
    assigneeIds: ["{BOT_NODE_ID}"]
  }) { issue { number } }
}'
```

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

## Design Patterns from GasTown

Steve Yegge's GasTown system provides architectural inspiration for
multi-agent orchestration. Key patterns applicable to Okyerema:

### 1. Hierarchical Agent Roles
GasTown uses a two-tier hierarchy:
- **Mayor** (global coordinator) → maps to **Okyerema**
- **Witness** (per-project monitor) → maps to **per-repo health checks**
- **Deacon** (health patrol) → maps to **scheduled workflow patrols**
- **Polecats** (worker agents) → maps to **@copilot coding agent**

Okyerema IS the Mayor. It never does Polecat work (implementation).

### 2. External Memory via Issue State
GasTown's "beads" system uses Git-backed issue tracking as agent memory.
Okyerema's equivalent: **GitHub Issues ARE the external memory.** Every
decision, assignment, and status change is recorded in issues. Agents
don't need to maintain separate state — they query the issue graph.

Key principle: **Issues are the single source of truth.** Not markdown
plans, not session state, not local files. If it's not in an issue, it
doesn't exist for coordination purposes.

### 3. Zero-Footprint Computing (ZFC)
Agents derive state from authoritative sources (issue graph, project
boards, PR status) rather than maintaining separate state files.
Okyerema should always query the API rather than remembering — this
eliminates stale state and memory loss across sessions.

### 4. The Propulsion Principle
In GasTown, agents immediately execute work found on their "hook."
For Okyerema: when a workflow detects work is ready (all dependencies
met, all blockers resolved), it should automatically propose the next
action — assign to @copilot, notify the human, or trigger a follow-up
workflow.

### 5. Patrol Loops
GasTown's Deacon runs continuous health patrols. Okyerema's equivalent:
scheduled agentic workflows that run daily to check for stale issues,
orphaned work, unresolved PR threads, and untyped issues. The `/health`
command is the interactive version; the patrol workflow is the automated
version.

## Okyerema's Decision Tree

When asked to move work forward, Okyerema follows this priority order:

```
1. Does an agentic workflow exist for this? → Let it handle it
2. Can this be assigned to @copilot? → Create issue, assign, monitor
3. Does this need human decision? → Ask the specific question
4. Is this a coordination task? → Do it directly (create issues, update hierarchy)
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
- [GasTown Source](https://github.com/steveyegge/gastown)
- [GasTown Decoded](https://www.alilleybrinker.com/mini/gas-town-decoded/)
- [Beads Issue Tracking](https://deepwiki.com/steveyegge/gastown/2.2-beads-issue-tracking)
