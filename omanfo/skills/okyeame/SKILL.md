---
name: okyeame
description: >
  The Okyeame (linguist) is the voice of the Anokye System — giving status
  updates, reporting on blocked issues, asking for clarity when needed, and
  tracking progress across GitHub Projects. Invoke for status reporting, issue
  management, blocker surfacing, and invoking the Okyerema to set the rhythm.
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

## Glossary

See **[references/glossary.md](../../references/glossary.md)** for the full Anokye System glossary and principle summary.

## Labels: Use Sparingly

Labels are for **filtering and categorization only**:

✅ **Good uses:** `documentation`, `security`, `typescript`, `good-first-issue`, `breaking-change`
❌ **Bad uses:** `epic`, `task`, `blocked-by-7`, `in-progress`, `parent:14`

If you're tempted to create a label for structure, you're using the wrong tool.
Use issue types, sub-issues, or project fields instead.
