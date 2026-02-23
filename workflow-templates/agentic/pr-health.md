---
name: PR Health Monitor

on:
  schedule: every 6 hours
  pull_request:
    types: [review_requested]
  workflow_dispatch:

permissions:
  pull-requests: read
  contents: read

safe-outputs:
  add-comment:
    max: 20
  add-labels:
    allowed: [pr/needs-review, pr/ready-to-merge, pr/blocked]

---

# PR Health Monitor Agent

Monitor open pull requests in ${{ github.repository }} for review and merge readiness.

## Instructions

For each open pull request:

1. Check whether all required CI checks have passed.
2. Check whether the PR has the required number of approving reviews.
3. Check whether there are any unresolved review threads.

Based on the findings:

- If the PR has been waiting for a reviewer response for 48 or more hours after `review_requested`, post a comment tagging the requested reviewers with a gentle nudge.
- If all checks pass, all reviews are approved, and no unresolved threads exist: add the `pr/ready-to-merge` label and post a comment noting the PR is ready.
- If CI is failing or there are blocking unresolved threads: add `pr/blocked` label.

## Important Rules

- Do not post duplicate comments. Check for an existing nudge comment before posting.
- Only tag reviewers if they were explicitly requested.
- Skip draft PRs.
