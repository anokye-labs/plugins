---
name: productivity
description: "Use this skill for task management and memory/knowledge management. Triggers: tracking tasks, managing TODOs, creating task lists, remembering information across sessions, maintaining project context, glossaries, people directories, and session memory. Complements Okyerema's DAG tracking and Okyeame's status reporting."
---

# Productivity

Task tracking and persistent memory management for development workflows.

## Task Management

### TASKS.md Format

Maintain a `TASKS.md` file at the project root:

```markdown
# Tasks

## In Progress
- [ ] Implement auth module @alice
- [ ] Fix pagination bug @bob #high

## Blocked
- [ ] Deploy to staging — waiting on DB migration
  - Blocker: Need DBA approval (asked 2025-01-15)

## Done
- [x] Set up CI pipeline @alice
- [x] Write API docs @bob
```

### Rules
- One task per line, checkbox format
- `@mention` for assignment
- `#high`, `#medium`, `#low` for priority
- Move between sections as status changes
- Add sub-bullets for context, blockers, or notes
- Date-stamp blockers and decisions

### Task Lifecycle
```
New → In Progress → [Blocked ↔ In Progress] → Done
```

## Memory Management

### Two-Tier System

**Tier 1: CLAUDE.md** (root-level, always loaded)
- Project conventions and rules
- Key architectural decisions
- Current sprint goals
- Links to Tier 2 files

**Tier 2: memory/ directory** (loaded on demand)
- `memory/glossary.md` — Project-specific terms
- `memory/people.md` — Team members, roles, preferences
- `memory/projects.md` — Active projects and status
- `memory/decisions.md` — Decision log with rationale

### Glossary Format

```markdown
# Glossary

| Term | Definition |
|------|-----------|
| Asafo | Implementation agents (warriors) |
| Okyeame | Linguist agent — status, reporting, coordination |
| Okyerema | Master drummer — keeps the rhythm, shared skills |
| Adwoma | Work items — GitHub Issues as external memory |
```

### People Directory

```markdown
# People

## [Name]
- **Role**: [Title/Function]
- **Handles**: @github, @slack
- **Expertise**: [Key areas]
- **Preferences**: [Communication style, review expectations]
- **Current focus**: [What they're working on]
```

### Decision Log

```markdown
# Decisions

## [YYYY-MM-DD] [Decision Title]
**Context**: [Why this came up]
**Decision**: [What was decided]
**Alternatives considered**: [What else was evaluated]
**Rationale**: [Why this option won]
**Revisit if**: [Conditions that would change this]
```

## Integration with Anokye System

- **Okyeame** uses task data for `/sitrep` and `/recap` commands
- **Okyerema** maintains rhythm across tasks via DAG tracking
- **Adwoma** (GitHub Issues) is the canonical source of truth — TASKS.md is a local working copy
- Sync pattern: Issues → TASKS.md for local work, push status back to Issues

## Attribution

Consolidated from [anthropics/knowledge-work-plugins](https://github.com/anthropics/knowledge-work-plugins) `productivity` plugin (source-available license).
