---
name: okyerema-sankofa
description: >
  Health patrol skill for the Okyerema plugin. Sankofa (return and get it) teaches
  agents to detect and remediate systemic issues: orphaned issues, stale work,
  hierarchy integrity violations, and repo readiness gaps.
---

# Sankofa: Health Patrols

Sankofa means "return and get it" — go back and retrieve what was missed. This skill
teaches agents to run health patrols that detect systemic issues before they become
blockers.

## When to Use This Skill

- Checking for orphaned issues (open, no parent, not an Epic)
- Finding stale issues (no activity in 14+ days)
- Validating hierarchy integrity (broken parent-child relationships)
- Auditing a repo for automation infrastructure gaps
- Onboarding a new repository with missing scaffolding
- Scheduled health checks (via GitHub Actions or cron)

## Health Patrol Scripts

All scripts are in `scripts/health/`:

### Get-HierarchyHealth.ps1
Validates the structural integrity of issue hierarchies.

```powershell
./scripts/health/Get-HierarchyHealth.ps1 -Owner anokye-labs -Repo plugins
```

Checks for:
- Orphaned issues (no parent, not an Epic)
- Broken parent-child relationships
- Circular dependencies
- Type violations (e.g., Task as parent of Epic)

### Get-OrphanedIssues.ps1
Finds open issues with no parent that aren't Epics.

```powershell
./scripts/health/Get-OrphanedIssues.ps1 -Owner anokye-labs -Repo plugins
```

### Get-Sitrep.ps1
Tactical status dashboard — shows active work, blockers, and health metrics.

```powershell
./scripts/health/Get-Sitrep.ps1 -Owner anokye-labs -Repo plugins
```

### Get-RepoReadiness.ps1
Audits a repository for automation infrastructure gaps.

```powershell
./scripts/health/Get-RepoReadiness.ps1 -Owner anokye-labs -Repo plugins
```

Checks for:
- `.github/copilot-instructions.md` — agent context
- `.github/aw/` — agentic workflow definitions
- `.github/workflows/` — GitHub Actions
- Branch protection rules
- Required status checks
- Issue type configuration

### Initialize-RepoAutomation.ps1
Generates GitHub issues for each readiness gap found by `Get-RepoReadiness.ps1`.

```powershell
./scripts/health/Initialize-RepoAutomation.ps1 -Owner anokye-labs -Repo plugins
```

## Patrol Patterns

### Scheduled Patrol (via GitHub Actions)
Use the `sankofa-patrol.yml` workflow template to run health checks on a schedule:

```yaml
# In target repo's .github/workflows/sankofa-patrol.yml
on:
  schedule:
    - cron: '0 9 * * 1'  # Every Monday at 9 AM
```

### On-Demand Patrol
Invoke health scripts directly from any context (Claude Code, Copilot, terminal):

```powershell
# Full health check
./scripts/health/Get-HierarchyHealth.ps1 -Owner myorg -Repo myrepo
./scripts/health/Get-OrphanedIssues.ps1 -Owner myorg -Repo myrepo
./scripts/health/Get-Sitrep.ps1 -Owner myorg -Repo myrepo
```

### Remediation Actions

When patrols find issues:

1. **Orphans** → Create parent issues or attach to existing Epics/Features
2. **Stale work** → Comment to request status update, or close if abandoned
3. **Broken hierarchies** → Repair with `scripts/dispatch/Update-IssueHierarchy.ps1`
4. **Missing automation** → Scaffold with `scripts/health/Initialize-RepoAutomation.ps1`

## Health Output Format

```
Health — {repo}
   Orphans: {count} issues with no parent
   Stale: {count} issues idle 14+ days
   PR debt: {count} PRs with unresolved threads
   CI: default branch green | {details}
   Untyped: {count} issues missing type
```
