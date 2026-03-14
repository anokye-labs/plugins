---
name: verification
description: Evaluate PR intelligence and thread management
---

# Verification Evaluation

## Scenario
Test PR health checking, thread management, and review submission.

## Setup
- Repository with at least one open PR with review threads

## Steps

1. Run `Get-PRStatus.ps1` — verify comprehensive status output
2. Run `Get-PRHealth.ps1` — verify health assessment
3. Run `Get-UnresolvedThreads.ps1` — verify thread listing
4. Run `Get-ThreadSeverity.ps1` — verify comment categorization
5. Run `Get-PRTimeline.ps1` — verify timeline view
6. Run `Find-IssueByPR.ps1` — verify issue-PR linkage

## Success Criteria
- PR status includes approvals, checks, merge readiness
- Health assessment identifies specific issues
- Unresolved threads listed with author and context
- Thread severity categories match expected patterns
- Timeline shows chronological review activity
