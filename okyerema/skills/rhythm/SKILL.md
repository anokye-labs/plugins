---
name: okyerema-rhythm
description: >
  The rhythm skill for the Okyerema plugin. Teaches agents the WIEG state machine
  (Wait → Investigate → Execute → Guard), dispatch patterns, and the rhythm loop
  for coordinating work across agents. Use when creating, managing, or querying
  GitHub issues, projects, hierarchies, and relationships.
---

# Rhythm: The WIEG State Machine

The Okyerema coordinates adwoma (work) across the asafo (team). This skill teaches
agents how to orchestrate GitHub-based project management the Anokye Labs way.

## Core Principles

1. **Use GitHub organization issue types** (Epic, Feature, Task, Bug) — never labels or title prefixes
2. **Use GraphQL API for all write operations** — gh CLI is insufficient
3. **Use sub-issues API for parent-child relationships** — `addSubIssue`/`removeSubIssue` mutations
4. **Use labels only for categorization** — never for structure
5. **Automate issue governance** — propose agentic workflows for repos that lack them
6. **Hierarchy: Epic → Feature → Task** — 3 levels when grouping exists, 2 levels when tasks are standalone
7. **Default assignment policy** — Tasks and Bugs auto-assign to @copilot; Epics and Features to authenticated user

## The WIEG Rhythm Loop

The Okyerema operates in a continuous **WIEG** cycle:

### W — Wait
Monitor for signals: new issues, completed PRs, stalled work, schedule triggers.

**Scripts:**
- `scripts/rhythm/Get-ReadyIssues.ps1` — Find issues with all dependencies met
- `scripts/rhythm/Get-BlockedIssues.ps1` — Find issues blocked by open dependencies
- `scripts/rhythm/Get-StalledWork.ps1` — Find issues with no recent activity

### I — Investigate
Analyze the current state: DAG status, hierarchy health, PR readiness.

**Scripts:**
- `scripts/rhythm/Get-DagStatus.ps1` — Recursive hierarchy status
- `scripts/rhythm/Get-DagCompletionReport.ps1` — Completion percentage
- `scripts/rhythm/Invoke-DagHealthCheck.ps1` — Comprehensive DAG health
- `scripts/health/Get-HierarchyHealth.ps1` — Structural validation
- `scripts/health/Get-Sitrep.ps1` — Tactical status dashboard

### E — Execute
Dispatch work: create issues, build hierarchies, assign agents, materialize plans.

**Scripts:**
- `scripts/dispatch/New-IssueWithType.ps1` — Create issue with proper type
- `scripts/dispatch/New-IssueBatch.ps1` — Batch create multiple issues
- `scripts/dispatch/New-IssueHierarchy.ps1` — Build full hierarchy
- `scripts/dispatch/Update-IssueHierarchy.ps1` — Modify parent-child relationships
- `scripts/dispatch/Set-IssueDependency.ps1` — Establish dependency relationships
- `scripts/dispatch/Add-IssuesToProject.ps1` — Add issues to Projects board
- `scripts/dispatch/Invoke-PlanMaterialization.ps1` — Convert plans into issue DAGs
- `scripts/dispatch/Sync-PlanToIssues.ps1` — Sync plan updates

### G — Guard
Verify results: check PR status, resolve threads, confirm completion.

**Scripts:**
- `scripts/verify/Get-PRStatus.ps1` — PR status (approvals, checks, merge readiness)
- `scripts/verify/Get-PRHealth.ps1` — Deep PR health check
- `scripts/verify/Get-UnresolvedThreads.ps1` — List unresolved threads
- `scripts/verify/Resolve-ReviewThreads.ps1` — Bulk resolve/unresolve threads
- `scripts/verify/Submit-PRReview.ps1` — Submit structured reviews
- `scripts/rhythm/Invoke-PRCompletion.ps1` — PR completion workflow

## When to Use This Skill

- Creating Epics, Features, or Tasks
- Setting up issue hierarchies
- **Converting markdown plans into issue DAGs** — Use `scripts/dispatch/Invoke-PlanMaterialization.ps1`
- Querying or manipulating GitHub Projects
- Checking issue relationships and dependencies
- Finding ready or blocked work items for agent self-selection
- Automating issue governance with agentic workflows
- Assigning work to @copilot coding agent
- Understanding how work is structured
- Tracking DAG status and dependency chains
- **Auditing a repo for automation readiness** — Use `scripts/health/Get-RepoReadiness.ps1`
- **Onboarding a new repository** — Use `scripts/health/Initialize-RepoAutomation.ps1`

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

## Default Assignment Policy

| Issue Type | Default Assignee | Reasoning |
|------------|------------------|-----------|
| **Epic** | Authenticated user | Strategic oversight — requires human judgment |
| **Feature** | Authenticated user | Review scope — human coordination needed |
| **Task** | `@copilot` | Execution scope — well-defined agent work |
| **Bug** | `@copilot` | Fix scope — debugging is agent-friendly |

## What NOT To Do

- `gh issue create --label "epic"` — Labels are not types
- `gh issue create --title "[Epic] Phase 2"` — Prefixes are not types
- Use tasklists for hierarchy — Use sub-issues API instead
- Use gh CLI for project field manipulation — Use GraphQL
- Use labels for structure — Labels are for categorization only

## Known Limitations & API Exceptions

### Copilot Bot Assignment Requires REST API

While the core principle states "Use GraphQL API for all write operations,"
**Copilot bot assignment is a documented exception** that requires the REST API.

```bash
# Assign Copilot using REST API
gh api repos/{owner}/{repo}/issues/{number}/assignees \
  --method POST -f 'assignees[]=Copilot'

# Or using gh CLI (@ prefix required)
gh issue edit {number} --add-assignee "@copilot"
```

## References (Load When Needed)

For detailed GraphQL examples and workflows, reference these guides:

- **[Issue Types](references/issue-types.md)** — Creating, updating, verifying types
- **[Relationships](references/relationships.md)** — Parent-child, hierarchy queries, orphan detection
- **[Plan Materialization](references/plan-materialization.md)** — Convert markdown plans into issue DAGs
- **[Projects](references/projects.md)** — GitHub Projects V2 GraphQL API
- **[PR Reviews](references/pr-reviews.md)** — PR intelligence suite
- **[Labels](references/labels.md)** — When and how to use labels properly
- **[Status Commands](references/status-commands.md)** — Slash command reference
- **[Agentic Workflows](references/agentic-workflows.md)** — gh-aw, @copilot, automated governance
- **[Errors & Fixes](references/errors.md)** — Common mistakes and solutions

## Glossary: The Anokye System

| Akan Term | Meaning | Role |
|-----------|---------|------|
| **Okyeame** | Linguist | The voice — status, blockers, clarity |
| **Okyerema** | Master drummer | Rhythm engine — workflows, patrols, CI/CD |
| **Asafo** | Warrior company | Implementation agents — @copilot, coding agents |
| **Adwoma** | Work | GitHub Issues as external memory |
| **Ananse** | Spider | The agentic runtime — @copilot, gh-aw, Actions |
| **Sankofa** | Return and get it | Health patrols — stale, orphaned, stuck work |
| **Akwaaba** | Welcome | Reference repository — conventions, onboarding |
