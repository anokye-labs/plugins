---
name: health-patrol
description: Evaluate sankofa health patrol scripts
---

# Health Patrol Evaluation

## Scenario
Test health patrol detection of systemic issues.

## Setup
- Repository with intentional health issues:
  - Orphaned issues (Task/Feature with no parent)
  - Stale issues (no activity in 14+ days)
  - Broken hierarchy (child references non-existent parent)

## Steps

1. Run `Get-OrphanedIssues.ps1` — should detect orphans
2. Run `Get-HierarchyHealth.ps1` — should detect broken relationships
3. Run `Get-StalledWork.ps1` — should detect stale issues
4. Run `Get-RepoReadiness.ps1` — should identify missing automation

## Success Criteria
- All orphaned issues detected and reported with correct counts
- Hierarchy violations flagged with specific issue references
- Stale issues identified with last activity timestamps
- Repo readiness report identifies specific gaps
