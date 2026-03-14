---
name: rhythm-loop
description: Evaluate the WIEG rhythm loop — Wait, Investigate, Execute, Guard
---

# Rhythm Loop Evaluation

## Scenario
Test the full WIEG cycle in a repository with mixed issue states.

## Setup
- Repository with 10+ issues: mix of open, closed, blocked, and ready
- At least one Epic with Feature and Task children
- At least one issue with "Blocked by #N" reference

## Steps

1. **Wait** — Run `Get-ReadyIssues.ps1` and verify it identifies issues with all dependencies met
2. **Investigate** — Run `Get-DagStatus.ps1` and verify hierarchy visualization is accurate
3. **Execute** — Run `New-IssueWithType.ps1` to create a new Task, then `Update-IssueHierarchy.ps1` to attach it
4. **Guard** — Run `Get-PRHealth.ps1` to check any open PRs, then `Get-DagCompletionReport.ps1`

## Success Criteria
- Ready issues list only contains issues with no open blockers or children
- DAG status shows correct hierarchy and completion percentages
- New issue is created with correct type and hierarchy relationship
- Health checks return structured output without errors
