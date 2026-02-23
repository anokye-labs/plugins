---
name: Issue Lifecycle Governance

on:
  issues:
    types: [closed, reopened, assigned]
  workflow_dispatch:

permissions:
  issues: read
  contents: read

safe-outputs:
  add-comment:
    max: 20
  add-labels:
    allowed: [orphan, needs-type, lifecycle/complete]
  update-issue:
    max: 10

---

# Issue Lifecycle Governance Agent

Enforce lifecycle rules for issues in ${{ github.repository }}.

## Instructions

### When an issue is closed

1. Check whether the issue has open sub-issues. If any sub-issues are still open, post a warning comment listing them.
2. If the issue is part of a parent issue hierarchy, post a progress update on the parent issue: count closed vs total sub-issues.
3. Add the `lifecycle/complete` label if all sub-issues are also closed.

### When an issue is assigned

1. If the issue has no type set (not labeled with a type label and has no issue type), apply a best-guess type based on the title and body. Use `add-labels` to apply it.
2. If the issue has no parent issue and no project, add the `orphan` label and post a comment noting it is not linked to any parent or project.

### When an issue is reopened

1. Remove the `lifecycle/complete` label if present.
2. Post a brief comment noting the issue has been reopened.

## Important Rules

- Never modify issues labeled `wont-fix` or `locked`.
- Keep all comments brief and informational.
