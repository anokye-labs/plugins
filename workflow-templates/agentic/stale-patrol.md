---
name: Stale Issue Patrol

on:
  schedule: daily
  workflow_dispatch:

permissions:
  issues: read
  contents: read

safe-outputs:
  add-comment:
    max: 50
  add-labels:
    allowed: [stale, wont-fix]
  close-issue:
    max: 20

---

# Stale Issue Patrol Agent

Patrol open issues in ${{ github.repository }} for staleness.

## Instructions

Find issues that have been open with no activity for 14 or more days.

For each stale issue found:
1. Check if the issue has already been warned (look for a previous comment from this agent mentioning staleness).
2. Skip issues with labels `long-running`, `blocked`, `wont-fix`, or `pinned`.
3. If no prior warning exists: post a comment asking for an update and add the `stale` label. Be polite and constructive.
4. If a stale warning was already posted 7 or more days ago and there has been no response since: close the issue with an explanatory comment. Remove the `stale` label after closing.

## Important Rules

- Never close issues labeled `long-running` or `blocked`.
- Do not warn the same issue twice in the same patrol run.
- Keep comments brief and actionable.
