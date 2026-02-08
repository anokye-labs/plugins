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

## When to Use This Skill

- Creating Epics, Features, or Tasks
- Setting up issue hierarchies
- Querying or manipulating GitHub Projects
- Checking issue relationships
- Automating issue governance with agentic workflows
- Assigning work to @copilot coding agent
- Understanding how work is structured

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

Use the sub-issues API (tasklists are retired as of April 2025):

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
❌ Use tasklists for hierarchy — Tasklists are retired; use sub-issues API
❌ Use gh CLI for project field manipulation — Use GraphQL
❌ Use labels for structure — Labels are for categorization only

## References (Load When Needed)

For detailed GraphQL examples and workflows, reference these guides:

- **[Issue Types](references/issue-types.md)** — Creating, updating, verifying types
- **[Relationships](references/relationships.md)** — Parent-child, hierarchy queries, orphan detection
- **[Projects](references/projects.md)** — GitHub Projects V2 GraphQL API
- **[PR Reviews](references/pr-reviews.md)** — Reply to, resolve, and find unresolved review threads
- **[Labels](references/labels.md)** — When and how to use labels properly
- **[Status Commands](references/status-commands.md)** — Slash command reference (/sitrep, /prcheck, /health, etc.)
- **[Agentic Workflows](references/agentic-workflows.md)** — gh-aw, @copilot assignment, automated governance
- **[Errors & Fixes](references/errors.md)** — Common mistakes and solutions

## Helper Scripts

Invoke these scripts for common operations:

- **[scripts/Get-IssueTypeIds.ps1](scripts/Get-IssueTypeIds.ps1)** — Retrieve type IDs for an organization
- **[scripts/New-IssueWithType.ps1](scripts/New-IssueWithType.ps1)** — Create issue with proper type
- **[scripts/Update-IssueHierarchy.ps1](scripts/Update-IssueHierarchy.ps1)** — Build tasklist relationships
- **[scripts/Test-Hierarchy.ps1](scripts/Test-Hierarchy.ps1)** — Verify relationships via GraphQL
- **[scripts/Get-Sitrep.ps1](scripts/Get-Sitrep.ps1)** — Tactical status report (/sitrep)
- **[scripts/Get-PRHealth.ps1](scripts/Get-PRHealth.ps1)** — Deep PR health check (/prcheck)
- **[scripts/Get-HierarchyHealth.ps1](scripts/Get-HierarchyHealth.ps1)** — Structural validation (/health)

## Labels: Use Sparingly

Labels are for **filtering and categorization only**:

✅ **Good uses:** `documentation`, `security`, `typescript`, `good-first-issue`, `breaking-change`
❌ **Bad uses:** `epic`, `task`, `blocked-by-7`, `in-progress`, `parent:14`

If you're tempted to create a label for structure, you're using the wrong tool. Use issue types, tasklists, or project fields instead.

## Glossary: The Anokye System

The Anokye System is our multi-agent orchestration architecture for software
development. Each role has an Akan name reflecting its function.

| Akan Term | Meaning | Role in the Anokye System |
|-----------|---------|--------------------------|
| **Okyeame** | Spokesperson | The coordinator — the face you interact with. Creates issues, builds hierarchies, reports status, coordinates agents. |
| **Okyerema** | Master drummer | The automation specialist — configures agentic workflows, sets up patrols, scaffolds CI/CD. Invoked by Okyeame. |
| **Asafo** | Warrior company | Implementation agents — `@copilot` and other agents that pick up Tasks, write code, open PRs |
| **Adwoma** | Work | GitHub Issues as external memory — every task, decision, status change. The single source of truth. |
| **Ananse** | Spider (folklore) | The agentic runtime — `@copilot` coding agent, `gh-aw` workflows, GitHub Actions |
| **Sankofa** | Return and get it | Automated health patrols — scheduled workflows that detect stale, orphaned, or stuck work |
| **Akwaaba** | Welcome | The reference repository — conventions, onboarding, team knowledge |

### Principle Summary

1. **Okyeame coordinates, Asafo implements** — the spokesperson sets direction, warriors execute
2. **Okyerema automates the rhythm** — the master drummer configures the workflows that keep the beat
3. **Adwoma is the single source of truth** — if it's not in an issue, it doesn't exist
4. **Zero-footprint computing** — agents query the API, never rely on local memory
5. **Sankofa keeps the system healthy** — automated patrols catch what humans miss
6. **Automate the predictable, ask about the ambiguous** — human attention for judgment only
