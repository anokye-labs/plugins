# Copilot Instructions

This document defines how GitHub Copilot agents work within this repository. These rules ensure consistent behavior across all agent sessions.

## Core Workflow Rules

### 1. Never Make Local File Changes

**Always create GitHub issues with detailed specifications and assign to @copilot.** Work flows through issues and pull requests, not local edits.

- When you identify work to be done, create a GitHub issue
- Include detailed specifications, acceptance criteria, and context
- Assign the issue to @copilot
- Let the PR workflow handle implementation
- Your role is to orchestrate via issues, not to write code locally

### 2. No Prefixes in Issue Titles

**Use issue types (Task, Feature, Epic, Bug) for structure.** Never use prefixes like `[TASK]`, `[BUG]`, or `[FEATURE]` in issue titles.

- Issue types provide proper categorization
- Use parent-child sub-issues for relationships
- Use blocked/blocked-by for dependencies
- Clean titles without prefixes improve readability

### 3. Use GraphQL API for All GitHub Write Operations

**The GitHub CLI REST API is insufficient for issue types, sub-issues, and other structured operations.** Always use GraphQL for GitHub write operations.

- GraphQL provides access to organization-level issue types
- Sub-issues API is only available via GraphQL
- Relationship management requires GraphQL mutations
- REST API lacks support for modern GitHub project features

### 4. Use Organization-Level Issue Types

**Never use labels or title prefixes for structure.** The organization provides proper issue types:

- **Epic** — Large initiatives spanning multiple features
- **Feature** — User-facing capabilities or system components
- **Task** — Concrete, actionable work items
- **Bug** — Defects and fixes

Labels are for tags and metadata, not for work item categorization.

### 5. Hierarchy: Epic → Feature → Task

**Use three levels when grouping exists, two levels when tasks are standalone:**

- **3-level hierarchy:** Epic → Feature → Task
  - Use when work naturally groups into features
  - Epics contain Features, Features contain Tasks
  
- **2-level hierarchy:** Feature → Task OR Epic → Task
  - Use when tasks are standalone under a feature
  - Use when work doesn't require feature grouping

Maximum nesting depth is 8 levels, maximum 100 sub-issues per parent.

### 6. PRs Are Typically Associated with a Task

**Pull requests represent concrete implementation work:**

- Each PR should link to a Task issue
- Tasks are the actionable units of work
- PRs close their associated Task upon merge
- Features and Epics are completed when all child Tasks are done

### 7. Higher-Level Work Items Represent Both Plan and Conversation

**Features and Epics are living documents:**

- They represent the initial plan
- They capture iterative conversation about the plan
- Comments discuss approach, architecture, and decisions
- They evolve as understanding improves
- They serve as the historical record of "why"

## Summary

These rules ensure the Anokye System operates as designed:

1. **Orchestrate, don't implement** — Create issues, don't edit files
2. **Use proper structure** — Issue types, not labels or prefixes
3. **Use GraphQL** — REST is insufficient for modern GitHub features
4. **Organize with hierarchy** — Epic → Feature → Task
5. **PRs close Tasks** — Keep work items atomic
6. **Epics/Features are conversations** — Living plans, not static specs

This workflow creates a clear, AI-orchestrated development environment where work flows naturally from planning to implementation to completion.
