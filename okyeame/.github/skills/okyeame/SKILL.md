---
name: okyeame
description: >
  Project coordination for Anokye Labs. The Okyeame (spokesperson) coordinates
  adwoma (work) — creating issues with proper types and hierarchy, monitoring PR
  health, reporting status via /sitrep /prcheck /health /whatsleft, and tracking
  progress across GitHub Projects. Invoke for issue management, project boards,
  status reporting, and coordination of Asafo implementation agents.
tools:
  - powershell
  - github-cli
---

# Okyeame — Project Coordination Skill

The Okyeame (spokesperson) is the top-level coordinator in the Anokye System.
This skill provides project coordination capabilities for Anokye Labs.

## Quick Start

```
/sitrep          → Dashboard of current work state
/context         → Load project context for session
/prcheck         → PR health across repo
/whatsleft       → Prioritized remaining work
/recap           → Narrative summary of progress
/health          → Repository health check
/board           → Project board snapshot
/watch #42       → Monitor an issue or PR
```

See `references/status-commands.md` for full command documentation.

## Core Capabilities

### Issue Management
- Create issues with organization-level types (Epic, Feature, Task, Bug)
- Build parent-child hierarchies via sub-issues API
- Track progress through DAG queries

### Project Board Management
- Add items to GitHub Projects V2
- Update status fields via GraphQL
- Generate board snapshots

### Status Reporting
- Structured dashboards (/sitrep, /board)
- Narrative summaries (/recap)
- Health checks (/health)
- PR monitoring (/prcheck)

### Agent Coordination
- Create fully-specified issues for @copilot assignment
- Monitor implementation agent progress
- Invoke Okyerema skill for workflow automation needs

## Related Skills

| Skill | When to Invoke |
|-------|---------------|
| **Okyerema** | Workflow automation config, gh-aw templates, repo automation scaffolding, patrol setup |

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

## Labels: Use Sparingly

Labels are for **filtering and categorization only**:

✅ **Good uses:** `documentation`, `security`, `typescript`, `good-first-issue`, `breaking-change`
❌ **Bad uses:** `epic`, `task`, `blocked-by-7`, `in-progress`, `parent:14`

If you're tempted to create a label for structure, you're using the wrong tool.
Use issue types, sub-issues, or project fields instead.
