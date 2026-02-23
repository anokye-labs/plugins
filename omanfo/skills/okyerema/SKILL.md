---
name: okyerema
description: >
  Project orchestration skill for Anokye Labs. Use when creating, managing, or
  querying GitHub issues, projects, hierarchies, and relationships. The Okyerema
  (talking drummer) keeps agents in rhythm — coordinating adwoma (work) through
  the asafo (the team). Invoke this skill for any issue creation, hierarchy
  setup, project board manipulation, or when you need to understand how we
  structure work.
---

# Okyerema: The Talking Drummer

The Okyerema coordinates adwoma (work) across the asafo (team). This skill teaches agents how to orchestrate GitHub-based project management the Anokye Labs way.

## Core Principles

1. **Use GitHub organization issue types** (Epic, Feature, Task, Bug) — never labels or title prefixes
2. **Use GraphQL API for all write operations** — gh CLI is insufficient
3. **Use sub-issues API for parent-child relationships** — `addSubIssue`/`removeSubIssue` mutations
4. **Use labels only for categorization** — never for structure
5. **Automate issue governance** — propose agentic workflows for repos that lack them
6. **Hierarchy: Epic → Feature → Task** — 3 levels when grouping exists, 2 levels when tasks are standalone
7. **Default assignment policy** — Tasks and Bugs auto-assign to @copilot; Epics and Features to authenticated user

## When to Use This Skill

- Creating Epics, Features, or Tasks
- Setting up issue hierarchies
- **Converting markdown plans into issue DAGs** — Use Invoke-PlanMaterialization.ps1 to materialize roadmaps
- Querying or manipulating GitHub Projects
- Checking issue relationships and dependencies
- Finding ready or blocked work items for agent self-selection
- Automating issue governance with agentic workflows
- Assigning work to @copilot coding agent
- Understanding how work is structured
- Tracking DAG status and dependency chains
- **Auditing a repo for automation readiness** — Use Get-RepoReadiness.ps1 to check for gaps
- **Onboarding a new repository** — Use Initialize-RepoAutomation.ps1 to scaffold missing pieces

## Deployment

When the Anokye System is deployed to a target repository (via `scripts/Install-Anokye.ps1`), it creates:

- **`.github/skills/okyerema/`** — The Okyerema skill files, scripts, and references
- **`.github/copilot-instructions.md`** — Repository-level rules that all Copilot sessions automatically pick up
- **`how-we-work/`** — Team documentation and conventions (optional)
- **`agents.md`** — Agent entry point (optional)

The `.github/copilot-instructions.md` file establishes the standard rules for how agents operate in an Anokye-managed repository. Without it, agents won't know the conventions. This is how Okyerema "sets the rhythm" — by configuring the rules that all agents follow.

## Quick Operations

### Get Organization Issue Type IDs

```graphql
query {
  organization(login: "anokye-labs") {
    issueTypes(first: 25) {
      nodes { id name }
    }
  }
}
```

### Create Issue with Correct Type

```graphql
mutation {
  createIssue(input: {
    repositoryId: "R_xxx"
    title: "Your Title"
    body: "Description"
    issueTypeId: "IT_xxx"
  }) {
    issue { id number title issueType { name } }
  }
}
```

### Create Parent-Child Relationship

Use the sub-issues API:

```graphql
mutation {
  addSubIssue(input: {
    issueId: "I_parent_node_id"
    subIssueId: "I_child_node_id"
  }) {
    issue { id }
    subIssue { id }
  }
}
```

### Verify Relationships

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 14) {
      issueType { name }
      subIssues(first: 50) {
        nodes { number title state issueType { name } }
      }
      parentIssue { number title }
    }
  }
}
```

Note: Sub-issues queries require the `GraphQL-Features: sub_issues` header:
```powershell
gh api graphql -H "GraphQL-Features: sub_issues" -f query='...'
```

## Hierarchy Patterns

### Pattern A: Epic → Feature → Task

Use when tasks group naturally into features:

```
Epic #14: Phase 2
├─ Feature #106: Core Skill Creation
│  ├─ Task #15: Analyze scripts
│  └─ Task #16: Create SKILL.md
└─ Feature #107: Script Conversion
   ├─ Task #17: Convert generate.sh
   └─ Task #18: Convert search.sh
```

### Pattern B: Epic → Task

Use when tasks are standalone:

```
Epic #1: Phase 0 Setup
├─ Task #2: Init repo
├─ Task #3: Create structure
└─ Task #4: Write .gitignore
```

## What NOT To Do

❌ `gh issue create --label "epic"` — Labels are not types
❌ `gh issue create --title "[Epic] Phase 2"` — Prefixes are not types
❌ Use tasklists for hierarchy — Use sub-issues API instead
❌ Use gh CLI for project field manipulation — Use GraphQL
❌ Use labels for structure — Labels are for categorization only

## Default Assignment Policy

The Anokye System follows a **humans opt-in, not opt-out** philosophy for task assignment. Issue types determine default assignees based on their nature and scope:

| Issue Type | Default Assignee | Reasoning |
|------------|------------------|-----------|
| **Epic** | Authenticated user | Strategic oversight and planning — requires human judgment |
| **Feature** | Authenticated user | Review and approval scope — human coordination needed |
| **Task** | `@copilot` | Execution scope — well-defined work suitable for agent automation |
| **Bug** | `@copilot` | Fix scope — debugging and patching is agent-friendly work |

### Rationale

When issues are created in bulk (e.g., via plan materialization or batch scripts), assigning all issues to humans creates busywork. The human then has to manually unassign themselves and assign `@copilot` for every task. This policy inverts that:

- **Tasks and Bugs** are execution work — assign to `@copilot` by default
- **Epics and Features** are coordination work — assign to the authenticated user by default
- Humans can always reassign when needed, but the defaults minimize manual work

**Note:** Epics and Features are assigned to the **authenticated user** (the person running the script), not the repository owner. This is because organization accounts cannot be assigned to issues — only user accounts can be assignees.

### Implementation

The `New-IssueWithType.ps1` script implements this policy automatically:
- Pass `-Assignee "auto"` (or omit the parameter) to use the default policy
- Pass `-Assignee "username"` to assign to a specific user
- Pass `-Assignee "@copilot"` to explicitly assign to Copilot (regardless of type)
- Pass `-Assignee ""` to create unassigned issues

```powershell
# Uses default policy: Task → @copilot, Epic → authenticated user
./New-IssueWithType.ps1 -Owner "anokye-labs" -Repo "plugins" -Title "Add tests" -TypeName "Task"

# Explicit assignment overrides default
./New-IssueWithType.ps1 -Owner "anokye-labs" -Repo "plugins" -Title "Add tests" -TypeName "Task" -Assignee "alice"

# No assignment
./New-IssueWithType.ps1 -Owner "anokye-labs" -Repo "plugins" -Title "Add tests" -TypeName "Task" -Assignee ""
```
```

**Important:** This policy applies to **bulk creation workflows**. For interactive issue creation in the GitHub UI, humans choose assignees as usual.

## Known Limitations & API Exceptions

### Copilot Bot Assignment Requires REST API

**The Exception:** While the core principle states "Use GraphQL API for all write operations," **Copilot bot assignment is a documented exception** that requires the REST API.

**Prerequisites:**
- Copilot coding agent must be enabled at the organization level before assignment will work
- Standard `/assignees` and `/collaborators` API endpoints do NOT list Copilot (org-level enablement is verified separately)

**Why REST is Required:**
- Copilot's node ID (e.g., `BOT_kgDOC9w8XQ`) is a BOT type, not a User type
- The GraphQL `addAssigneesToAssignable` mutation returns `NOT_FOUND` error for BOT-type node IDs
- GitHub's REST API `/repos/{owner}/{repo}/issues/{number}/assignees` endpoint properly handles bot assignees

**Working Pattern (REST API):**
```bash
# Assign Copilot to an issue using REST API
gh api repos/{owner}/{repo}/issues/{number}/assignees \
  --method POST \
  -f 'assignees[]=Copilot'
```

**Alternative (gh CLI):**
```bash
# Using gh issue edit command (wraps REST API)
# NOTE: @ prefix is REQUIRED for CLI (casing doesn't matter: @copilot or @Copilot)
gh issue edit {number} --add-assignee "@copilot"
```

**What Does NOT Work:**
```graphql
# ❌ This mutation fails for BOT-type assignees
mutation {
  addAssigneesToAssignable(input: {
    assignableId: "I_issue_node_id"
    assigneeIds: ["BOT_kgDOC9w8XQ"]  # Example BOT node ID
  }) {
    assignable { id }
  }
}
# Returns: NOT_FOUND error
```

**Note:** The `updateIssue` mutation with `assigneeIds` field may work in some contexts, but REST API is the officially documented and reliable method for bot assignment. Always use REST for @copilot assignments.

## References (Load When Needed)

For detailed GraphQL examples and workflows, reference these guides:

- **[Issue Types](references/issue-types.md)** — Creating, updating, verifying types
- **[Relationships](references/relationships.md)** — Parent-child, hierarchy queries, orphan detection
- **[Plan Materialization](references/plan-materialization.md)** — Convert markdown plans into issue DAGs
- **[Projects](references/projects.md)** — GitHub Projects V2 GraphQL API
- **[PR Reviews](references/pr-reviews.md)** — PR intelligence suite: status, timeline, comment analysis, review submission, thread management
- **[Labels](references/labels.md)** — When and how to use labels properly
- **[Status Commands](references/status-commands.md)** — Slash command reference (/sitrep, /prcheck, /health, etc.)
- **[Agentic Workflows](references/agentic-workflows.md)** — gh-aw, @copilot assignment, automated governance
- **[Errors & Fixes](references/errors.md)** — Common mistakes and solutions

## Helper Scripts

Invoke these scripts for common operations:

### Issue Creation & Hierarchy Management
- **[scripts/Get-IssueTypeIds.ps1](scripts/Get-IssueTypeIds.ps1)** — Retrieve type IDs for an organization
- **[scripts/New-IssueWithType.ps1](scripts/New-IssueWithType.ps1)** — Create issue with proper type
- **[scripts/Update-IssueHierarchy.ps1](scripts/Update-IssueHierarchy.ps1)** — Build parent-child relationships using sub-issues API
- **[scripts/Set-IssueDependency.ps1](scripts/Set-IssueDependency.ps1)** — Establish blocks/blocked-by dependency relationships
- **[scripts/Test-Hierarchy.ps1](scripts/Test-Hierarchy.ps1)** — Verify relationships via GraphQL

### Plan Materialization
- **[scripts/Invoke-PlanMaterialization.ps1](scripts/Invoke-PlanMaterialization.ps1)** — Convert markdown plans into issue DAGs
- **[scripts/Sync-PlanToIssues.ps1](scripts/Sync-PlanToIssues.ps1)** — Sync plan updates with existing issues

### Status & Health Reporting- **[scripts/Get-Sitrep.ps1](scripts/Get-Sitrep.ps1)** — Tactical status report (/sitrep)
- **[scripts/Get-PRHealth.ps1](scripts/Get-PRHealth.ps1)** — Deep PR health check (/prcheck)
- **[scripts/Get-HierarchyHealth.ps1](scripts/Get-HierarchyHealth.ps1)** — Structural validation (/health)

### Repo Onboarding
- **[scripts/Get-RepoReadiness.ps1](scripts/Get-RepoReadiness.ps1)** — Audit a repo for automation infrastructure gaps (/readiness)
- **[scripts/Initialize-RepoAutomation.ps1](scripts/Initialize-RepoAutomation.ps1)** — Generate GitHub issues for each readiness gap

### PR Intelligence
- **[scripts/Get-PRStatus.ps1](scripts/Get-PRStatus.ps1)** — Comprehensive PR status (approvals, checks, merge readiness)
- **[scripts/Get-ThreadSeverity.ps1](scripts/Get-ThreadSeverity.ps1)** — Categorize review comments by actionability
- **[scripts/Find-IssueByPR.ps1](scripts/Find-IssueByPR.ps1)** — Discover PRs linked to issues
- **[scripts/Get-PRTimeline.ps1](scripts/Get-PRTimeline.ps1)** — Timeline view of review activity
- **[scripts/Submit-PRReview.ps1](scripts/Submit-PRReview.ps1)** — Submit structured reviews programmatically

### Thread Management
- **[scripts/Get-UnresolvedThreads.ps1](scripts/Get-UnresolvedThreads.ps1)** — List unresolved threads
- **[scripts/Reply-ReviewThread.ps1](scripts/Reply-ReviewThread.ps1)** — Reply to threads, optionally resolve
- **[scripts/Resolve-ReviewThreads.ps1](scripts/Resolve-ReviewThreads.ps1)** — Bulk resolve/unresolve threads

### Dependency & Work Selection (DAG Queries)
- **[scripts/Get-DagStatus.ps1](scripts/Get-DagStatus.ps1)** — Recursive issue hierarchy status with readiness tracking
- **[scripts/Get-ReadyIssues.ps1](scripts/Get-ReadyIssues.ps1)** — Find issues ready to work on (all dependencies met)
- **[scripts/Get-BlockedIssues.ps1](scripts/Get-BlockedIssues.ps1)** — Find issues blocked by open dependencies

The DAG query scripts enable agent self-selection of work by tracking:
1. **Hierarchy-based dependencies** — Issues with open child sub-issues are waiting
2. **Cross-reference dependencies** — Issues blocked by other issues (via "Blocked by #N" in body/comments)

Use these scripts to understand which work is ready, which is blocked, and what the dependency chain looks like.

## Labels: Use Sparingly

Labels are for **filtering and categorization only**:

✅ **Good uses:** `documentation`, `security`, `typescript`, `good-first-issue`, `breaking-change`
❌ **Bad uses:** `epic`, `task`, `blocked-by-7`, `in-progress`, `parent:14`

If you're tempted to create a label for structure, you're using the wrong tool. Use issue types, sub-issues API, or project fields instead.

## Glossary

See **[references/glossary.md](../../references/glossary.md)** for the full Anokye System glossary and principle summary.
