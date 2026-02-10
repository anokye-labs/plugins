# Anokye System — Repository Rules

This repository uses the Anokye System for project orchestration. All agents working in this repo must follow these conventions.

## Core Principles

### 1. Work through issues, not local edits

**Create GitHub issues with detailed specs and assign to agents.** All work flows through issues and PRs. Never make local file changes without an associated issue and PR.

### 2. No prefixes in issue titles

**Use issue types (Task, Feature, Epic, Bug) for structure.** Never use prefixes like `[FEATURE]` or `TASK:` in titles. Use parent-child sub-issues and blocked/blocked-by relationships for organizing work.

### 3. Use GraphQL API for GitHub write operations

**Use GraphQL for issue types, sub-issues, and project mutations.** The GitHub CLI (`gh`) is insufficient for operations involving:
- Issue types (`issueTypeId` field)
- Sub-issues (`addSubIssue`/`removeSubIssue` mutations)
- Project v2 mutations

Always use `gh api graphql` with the appropriate queries/mutations.

### 4. Use org-level issue types

**Use organization issue types (Epic, Feature, Task, Bug) — never labels or title prefixes for structure.** Labels are for categorization only, not hierarchy. Issue types are defined at the organization level and applied via the `issueTypeId` field.

### 5. Hierarchy: Epic → Feature → Task

**PRs are associated with Tasks.** The standard hierarchy is:
- **Epic**: Large multi-feature initiatives (weeks/months)
- **Feature**: User-facing capabilities (days/weeks)
- **Task**: Individual units of work tied to PRs (hours/days)

Tasks have PRs. Features group related Tasks. Epics group related Features.

### 6. Higher-level work items represent the plan AND the conversation

**Features and Epics represent both the plan AND iterative conversation about the plan.** They are living documents where:
- The description contains the current plan/spec
- Comments contain decisions, clarifications, and evolution of the plan
- Sub-issues track the actual implementation work

Keep the Feature/Epic description updated as the plan evolves through conversation.

## References

For detailed information on using these conventions:

- **Issue Types**: `.github/skills/okyerema/references/issue-types.md`
- **Relationships**: `.github/skills/okyerema/references/relationships.md`
- **Projects**: `.github/skills/okyerema/references/projects.md`
- **PR Reviews**: `.github/skills/okyerema/references/pr-reviews.md`

---

*This file is managed by the Okyerema skill. See `.github/skills/okyerema/SKILL.md` for the full orchestration guide.*
