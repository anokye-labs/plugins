# Agents

AI agents working in Anokye Labs repositories should follow the **agent behavior conventions** and use the **Okyerema** skill for all project management operations.

## Agent Behavior Conventions

**Location:** [how-we-work/agent-conventions.md](how-we-work/agent-conventions.md)

All agents must follow these core principles:
- **Action-first** — Do the work, don't suggest it
- **Branch-awareness** — Verify correct branch before making changes
- **Read-docs-before-debug** — Consult documentation before trial-and-error
- **OODA loop** — Observe → Orient → Decide → Act
- **Issue references** — Every commit must reference the issue being worked on
- **Structured logging** — Use consistent, parseable log formats
- **GitHub Issues as coordination** — Issues are external memory and contracts
- **Sub-issues for hierarchy** — Use the sub-issues API (synchronous, replaced tasklists April 2025)
- **Agent assignment** — Assign work via GraphQL `updateIssue` mutation with bot node ID

See the full [agent conventions document](how-we-work/agent-conventions.md) for details and anti-patterns.

## The Okyerema Plugin

**Location:** [okyerema/](../okyerema/)

The Okyerema (talking drummer) plugin teaches agents how to:
- Create issues with proper organization types (Epic, Feature, Task, Bug)
- Build parent-child hierarchies using GitHub's sub-issues API
- Manipulate GitHub Projects via GraphQL
- Use labels appropriately (sparingly, for categorization only)
- Verify relationships and troubleshoot issues

## Quick Rules

1. **Use GraphQL for all structured operations** — gh CLI is insufficient
2. **Use organization issue types** — never labels or title prefixes
3. **Use sub-issues API for relationships** — `addSubIssue`/`removeSubIssue` mutations
4. **Use labels sparingly** — categorization only, never structure

## Session Context

Every agent session should operate in the context of a specific GitHub issue. Before starting work:

1. Identify the issue you're working on
2. Check its dependencies (are blocking issues resolved?)
3. Understand where it sits in the hierarchy
4. Do the work
5. Update and close the issue when done

## Human Documentation

For the human-readable version of how we work, see [how-we-work.md](./how-we-work.md).

