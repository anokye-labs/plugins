---
name: okyeame
description: >
  The Okyeame (linguist) is the voice of the Anokye System — giving status
  updates, reporting on blocked issues, asking for clarity when needed, and
  tracking progress across GitHub Projects. Invoke for status reporting, issue
  management, blocker surfacing, and invoking the Okyerema to set the rhythm.
allowed-tools: "powershell github-cli"
---

# Okyeame — The Linguist

The Okyeame (linguist) is the voice of the Anokye System. It gives status
updates, reports on blocked issues, and asks for clarity when needed.

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

### Status & Communication
- Structured dashboards (/sitrep, /board)
- Narrative summaries (/recap)
- Health checks (/health)
- PR monitoring (/prcheck)
- Blocker reporting and clarity requests

### Asafo Dispatch
- Create fully-specified issues for @copilot assignment
- Monitor implementation agent progress
- Invoke Okyerema skill to set the rhythm when needed

## Related Skills

| Skill | When to Invoke |
|-------|---------------|
| **Okyerema** | Workflow automation, gh-aw templates, repo automation, patrol setup — keeping the asafo in rhythm |

## Glossary: The Anokye System

The Anokye System is our multi-agent orchestration architecture for software
development. Each role has an Akan name reflecting its function.

| Akan Term | Meaning | Role in the Anokye System |
|-----------|---------|--------------------------|
| **Okyeame** | Linguist | The voice — gives status updates, reports on blocked issues, asks for clarity when needed. |
| **Okyerema** | Master drummer | The master drummer of the asafo — keeps the warriors in rhythm through workflow automation, patrols, and CI/CD. |
| **Asafo** | Warrior company | Implementation agents — `@copilot` and other agents that pick up Tasks, write code, open PRs |
| **Adwoma** | Work | GitHub Issues as external memory — every task, decision, status change. The single source of truth. |
| **Ananse** | Spider (folklore) | The agentic runtime — `@copilot` coding agent, `gh-aw` workflows, GitHub Actions |
| **Sankofa** | Return and get it | Automated health patrols — scheduled workflows that detect stale, orphaned, or stuck work |
| **Akwaaba** | Welcome | The reference repository — conventions, onboarding, team knowledge |

### Principle Summary

1. **Okyeame speaks, Asafo implements** — the linguist gives voice, the warriors execute
2. **Okyerema keeps the rhythm** — the master drummer of the asafo keeps the warriors in cadence
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
