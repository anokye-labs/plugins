---
name: PR Triage

on:
  pull_request_review:
    types: [submitted]
  pull_request_review_comment:
    types: [created]
  pull_request:
    types: [synchronize]
  schedule: every 15 minutes
  workflow_dispatch:

permissions:
  contents: read
  issues: read
  pull-requests: read

safe-outputs:
  add-comment:
    max: 20
  create-issue:
    max: 10
  add-labels:
    allowed: [triage/active, triage/escalated]
  create-agent-session:

---

# PR Triage Agent

Triage unresolved review threads on open pull requests in ${{ github.repository }}.

## Instructions

### Step 1: Find PRs with unresolved review threads

List open PRs and identify those with unresolved review threads. Skip PRs labeled `triage/escalated`.

### Step 2: Classify each unresolved thread

Apply the following rules in order (first match wins):

- **resolve**: Bot comment with no actionable pattern, nit or style preference, optional suggestion, low/medium severity bot comment.
- **fix**: Security issue, functional bug, or a `suggestion` code block in the comment.
- **create-issue**: Comment requests test coverage or mentions a missing test.
- **needs-human**: Comment from a human (no `[bot]` suffix), architectural discussion, or backward-compatibility concern.

### Step 3: Execute dispositions

- **resolve**: Reply "Triage: Acknowledged — resolved as informational." then resolve the thread.
- **fix**: Post a single PR comment tagging `@copilot` with a list of all fix threads.
- **create-issue**: Create a follow-up issue titled "Follow-up: [description]" and resolve the thread.
- **needs-human**: Add `triage/escalated` label and post an escalation comment.

### Step 4: Update triage state

After processing, add or update the `triage/active` label. If all threads are resolved, remove it.

## Important Rules

- Never resolve security-related threads without a fix.
- Never resolve threads from human reviewers.
- When in doubt, classify as `needs-human`.
