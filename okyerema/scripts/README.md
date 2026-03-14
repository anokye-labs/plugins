# Okyerema Scripts

PowerShell scripts for the Okyerema rhythm engine. Organized by domain.

## Directories

| Directory | Purpose | Scripts |
|-----------|---------|---------|
| `dispatch/` | Issue creation, hierarchy, and project management | `New-IssueWithType.ps1`, `New-IssueBatch.ps1`, `New-IssueHierarchy.ps1`, `Update-IssueHierarchy.ps1`, `Test-Hierarchy.ps1`, `Get-IssueTypeIds.ps1`, `Add-IssuesToProject.ps1`, `Invoke-PlanMaterialization.ps1`, `Set-IssueDependency.ps1`, `Sync-PlanToIssues.ps1` |
| `health/` | Status reporting and health checks | `Get-Sitrep.ps1`, `Get-HierarchyHealth.ps1`, `Get-OrphanedIssues.ps1`, `Get-RepoReadiness.ps1`, `Initialize-RepoAutomation.ps1` |
| `rhythm/` | Workflow state and progress tracking | `Get-ReadyIssues.ps1`, `Get-BlockedIssues.ps1`, `Get-StalledWork.ps1`, `Get-DagStatus.ps1`, `Get-DagCompletionReport.ps1`, `Invoke-DagHealthCheck.ps1`, `Invoke-PRCompletion.ps1` |
| `verify/` | PR verification and thread management | `Get-PRHealth.ps1`, `Get-PRStatus.ps1`, `Get-PRTimeline.ps1`, `Get-UnresolvedThreads.ps1`, `Get-ThreadSeverity.ps1`, `Reply-ReviewThread.ps1`, `Resolve-ReviewThreads.ps1`, `Submit-PRReview.ps1`, `Find-IssueByPR.ps1` |

## Requirements

- PowerShell 7.0+
- GitHub CLI (`gh`) authenticated
