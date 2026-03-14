# Okyerema — Rhythm Engine

The Okyerema (master drummer) plugin is the multi-context rhythm engine for the
[Anokye System](../anokye-system-vision.md). One drummer, many instruments: the
same PowerShell scripts run across Claude Code, Copilot, GitHub Actions, and
local `act` runners.

## Architecture

```
okyerema/
  .github/plugin/plugin.json      # Copilot plugin manifest
  AGENTS.md                        # Claude Code agent entry point
  okyerema.agent.md               # Agent persona (drummer)
  skills/
    rhythm/SKILL.md + references/  # WIEG state machine, dispatch, rhythm loop
    sankofa/SKILL.md               # Health patrols
  scripts/
    rhythm/                        # 7 scripts: DAG status, ready issues, stalled work
    dispatch/                      # 10 scripts: issue creation, hierarchy, plan materialization
    verify/                        # 9 scripts: PR status, reviews, thread mgmt
    health/                        # 5 scripts: hierarchy health, orphans, sitrep, repo readiness
  workflows/                       # Distributable GitHub Actions templates
  install/                         # Installation scripts
  evaluations/                     # Evaluation scenarios
```

## Multi-Context Execution

| Context | Entry Point | How Scripts Run |
|---------|-------------|-----------------|
| **Claude Code** | `AGENTS.md` → `skills/rhythm/SKILL.md` | `pwsh -File scripts/rhythm/Get-ReadyIssues.ps1` |
| **Copilot** | `plugin.json` → `skills/rhythm/SKILL.md` | PowerShell execution in Copilot session |
| **GitHub Actions** | `workflows/*.yml` | `steps:` with `shell: pwsh` |
| **Local (act)** | Same workflow YAML | `act` runner invokes identical steps |

## Installation

### As a Copilot Plugin

```powershell
copilot plugin install anokye-labs/plugins:okyerema
```

### Workflow Templates

Copy distributable workflow templates to your repo:

```powershell
./install/Install-Okyerema.ps1 -TargetRepo /path/to/repo
```

### Claude Code Integration

```powershell
./install/Install-ClaudeCode.ps1 -TargetRepo /path/to/repo
```

### Verify

```powershell
./install/Verify-Installation.ps1 -TargetRepo /path/to/repo
```

## Scripts

### Rhythm (`scripts/rhythm/`)
- `Get-ReadyIssues.ps1` — Find issues with all dependencies met
- `Get-BlockedIssues.ps1` — Find issues blocked by open dependencies
- `Get-DagStatus.ps1` — Recursive hierarchy status with readiness tracking
- `Get-DagCompletionReport.ps1` — DAG completion percentage and summary
- `Get-StalledWork.ps1` — Find issues with no recent activity
- `Invoke-DagHealthCheck.ps1` — Comprehensive DAG health analysis
- `Invoke-PRCompletion.ps1` — PR completion workflow orchestration

### Dispatch (`scripts/dispatch/`)
- `Get-IssueTypeIds.ps1` — Retrieve org issue type IDs
- `New-IssueWithType.ps1` — Create issue with proper type
- `New-IssueBatch.ps1` — Batch create multiple issues
- `New-IssueHierarchy.ps1` — Build full hierarchy
- `Update-IssueHierarchy.ps1` — Modify parent-child relationships
- `Set-IssueDependency.ps1` — Establish dependency relationships
- `Test-Hierarchy.ps1` — Verify relationships via GraphQL
- `Add-IssuesToProject.ps1` — Add issues to Projects board
- `Invoke-PlanMaterialization.ps1` — Convert plans into issue DAGs
- `Sync-PlanToIssues.ps1` — Sync plan updates with existing issues

### Verify (`scripts/verify/`)
- `Get-PRStatus.ps1` — PR status (approvals, checks, merge readiness)
- `Get-PRHealth.ps1` — Deep PR health check
- `Get-PRTimeline.ps1` — Timeline view of review activity
- `Get-ThreadSeverity.ps1` — Categorize review comments
- `Get-UnresolvedThreads.ps1` — List unresolved PR threads
- `Reply-ReviewThread.ps1` — Reply to threads
- `Resolve-ReviewThreads.ps1` — Bulk resolve/unresolve threads
- `Submit-PRReview.ps1` — Submit structured reviews
- `Find-IssueByPR.ps1` — Discover PRs linked to issues

### Health (`scripts/health/`)
- `Get-HierarchyHealth.ps1` — Hierarchy validation
- `Get-OrphanedIssues.ps1` — Find orphaned issues
- `Get-Sitrep.ps1` — Tactical status dashboard
- `Get-RepoReadiness.ps1` — Audit repo for automation gaps
- `Initialize-RepoAutomation.ps1` — Scaffold missing automation

## Related

- **[omanfo](../omanfo/)** — Okyeame linguist agent and project management skills
- **[shared/OkyeremanAgentRunner](../shared/OkyeremanAgentRunner/)** — Shared PowerShell module (logging, retry, issue context)
