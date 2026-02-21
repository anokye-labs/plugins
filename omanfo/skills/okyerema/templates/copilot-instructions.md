# Copilot Instructions

<!-- TEMPLATE: Copy this file to .github/copilot-instructions.md and fill in
     the sections marked with [FILL IN]. Remove this comment when done. -->

This document defines how GitHub Copilot agents work within this repository.
All Copilot sessions — both interactive (VS Code agent mode) and automated
(`@copilot` issue assignment) — load these rules automatically.

## Repository Overview

**Repository:** [FILL IN: owner/repo]  
**Description:** [FILL IN: brief description of what this repo does]  
**Tech Stack:** [FILL IN: e.g., TypeScript, Node.js, PostgreSQL]  
**Primary Language:** [FILL IN: e.g., TypeScript]

## Anokye System Rules

This repository uses the Anokye System for AI-orchestrated project management.

### 1. Use Organization Issue Types — Never Labels as Types

Work is structured using GitHub organization issue types:
- **Epic** — Large initiatives spanning multiple features
- **Feature** — User-facing capabilities or system components
- **Task** — Concrete, actionable work items assigned to `@copilot`
- **Bug** — Defects and fixes assigned to `@copilot`

❌ Never use labels like `epic`, `task`, `feature` as type substitutes.  
❌ Never use title prefixes like `[Epic]` or `[Bug]`.  
✅ Use the `New-IssueWithType.ps1` script or GraphQL API to create typed issues.

### 2. Use GraphQL API for All GitHub Write Operations

The `gh` CLI REST API is insufficient for issue types, sub-issues, and
project fields. Always use `gh api graphql` for write operations.

```powershell
# Correct: GraphQL for issue creation with type
gh api graphql -f query='mutation { createIssue(input: { ... issueTypeId: "IT_xxx" }) { issue { id } } }'

# Wrong: gh CLI creates issues without type
gh issue create --title "..." --body "..."
```

### 3. Issue Hierarchy: Epic → Feature → Task

Use parent-child relationships (not tasklists) via the sub-issues API:

```
Epic: Initiative or phase
├─ Feature: Logical grouping of tasks
│  ├─ Task: Concrete work item (@copilot)
│  └─ Task: Concrete work item (@copilot)
└─ Feature: Another grouping
   └─ Task: Concrete work item (@copilot)
```

Link with: `addSubIssue` / `removeSubIssue` GraphQL mutations.  
Require header: `GraphQL-Features: sub_issues`.

### 4. Default Assignment Policy

| Issue Type | Assignee | Reason |
|------------|----------|--------|
| Epic | Authenticated user | Strategic oversight |
| Feature | Authenticated user | Coordination scope |
| Task | `@copilot` | Execution scope |
| Bug | `@copilot` | Fix scope |

### 5. PRs Are Linked to Tasks

Each PR should close a Task issue. Use `Closes #N` in the PR body or
commits. Tasks are the atomic units of implementation.

## Tech Stack Conventions

[FILL IN: List your tech stack conventions, e.g.:]

### [FILL IN: Language/Framework Name]

- [FILL IN: e.g., "Use TypeScript strict mode — no `any` types"]
- [FILL IN: e.g., "Follow the Google TypeScript Style Guide"]
- [FILL IN: e.g., "Prefer async/await over raw Promises"]

### Testing

- [FILL IN: e.g., "Use Jest for unit tests, Playwright for E2E"]
- [FILL IN: e.g., "Minimum 80% test coverage for new code"]
- [FILL IN: e.g., "Test file naming: *.test.ts alongside source"]

### File Organization

```
[FILL IN: your project structure, e.g.:]
src/
  api/          ← API routes and handlers
  services/     ← Business logic
  models/       ← Data models
  utils/        ← Shared utilities
tests/
  unit/         ← Unit tests
  integration/  ← Integration tests
```

## Coding Conventions

[FILL IN: Your specific conventions, e.g.:]

- [FILL IN: e.g., "Use single quotes for strings"]
- [FILL IN: e.g., "Always handle errors — never silent catch blocks"]
- [FILL IN: e.g., "Prefer composition over inheritance"]
- [FILL IN: e.g., "All public APIs must have JSDoc comments"]

## Known Gotchas

[FILL IN: Common pitfalls specific to this repo, e.g.:]

- [FILL IN: e.g., "The config loader is loaded once at startup — changes require restart"]
- [FILL IN: e.g., "Database migrations must be backward-compatible for zero-downtime deploys"]

## Helper Scripts

The following scripts are available in `.github/skills/okyerema/scripts/`:

| Script | Purpose |
|--------|---------|
| `Get-RepoReadiness.ps1` | Audit this repo for automation gaps |
| `Initialize-RepoAutomation.ps1` | Create issues for readiness gaps |
| `New-IssueWithType.ps1` | Create GitHub issues with proper type |
| `Get-Sitrep.ps1` | Get tactical status report (`/sitrep`) |
| `Get-HierarchyHealth.ps1` | Validate issue hierarchy (`/health`) |
| `Invoke-PlanMaterialization.ps1` | Convert markdown plans into issue DAGs |

## Agent Behaviour Rules

1. **Orchestrate via issues** — When you identify work to do, create a GitHub
   issue with detailed acceptance criteria and assign to `@copilot`.
   Do not make local file changes unless explicitly asked.

2. **Ask about the ambiguous** — If requirements are unclear, ask a specific
   question rather than guessing. Human attention is for judgment calls only.

3. **Zero-footprint computing** — Query the GitHub API for state. Do not rely
   on local memory or files for coordination state.

4. **Propose automation** — When a governance pattern repeats, propose an
   agentic workflow (gh-aw) to automate it instead of repeating manually.

## References

- [SKILL.md](.github/skills/okyerema/SKILL.md) — Full Okyerema skill documentation
- [how-we-work/getting-started.md](how-we-work/getting-started.md) — Team onboarding
- [how-we-work/agent-conventions.md](how-we-work/agent-conventions.md) — Agent rules
