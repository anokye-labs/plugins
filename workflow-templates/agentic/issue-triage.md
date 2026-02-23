---
name: Issue Triage

on:
  issues:
    types: [opened, reopened]
  workflow_dispatch:

permissions:
  issues: read
  contents: read

safe-outputs:
  add-labels:
    allowed: [bug, feature, task, enhancement, question, documentation, needs-triage]
  add-comment:
    max: 5

---

# Issue Triage Agent

Analyze the newly opened issue in ${{ github.repository }}.

## Instructions

1. Read the issue title and body carefully.
2. Apply the most appropriate label from the allowed set based on the content:
   - `bug` — describes a defect or broken behavior
   - `feature` — requests new functionality
   - `task` — concrete actionable work item (refactor, chore, docs update)
   - `enhancement` — improvement to existing functionality
   - `question` — asks for clarification or information
   - `documentation` — documentation-only change
   - `needs-triage` — unclear or requires human judgment
3. If the description is unclear or missing key details, post a comment asking for clarification. Be concise and specific about what is missing.
4. If the issue is actionable and well-scoped, add a comment suggesting it for assignment to @copilot.
5. Do NOT add `needs-triage` if the issue is already clear.
