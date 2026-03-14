# Okyerema Workflow Templates

Distributable GitHub Actions workflow templates for the Anokye System. Copy these
to your target repository's `.github/workflows/` directory.

## Installation

```powershell
# Automated installation
../install/Install-Okyerema.ps1 -TargetRepo /path/to/repo

# Or manually copy individual workflows
cp okyerema/workflows/issue-dispatch.yml /path/to/repo/.github/workflows/
```

## Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `issue-dispatch.yml` | `issues: [opened, labeled]` | Auto-assign Task/Bug issues to @copilot |
| `copilot-checks.yml` | `pull_request_target`, `workflow_dispatch` | Run required checks for Copilot-authored PRs |
| `auto-approve.yml` | `pull_request: [opened, ...]` | Auto-approve PRs from trusted actors |
| `auto-enqueue.yml` | `workflow_run`, `schedule`, `workflow_dispatch` | Sweep and enqueue ready PRs |
| `post-merge.yml` | `pull_request: [closed]` | Update linked issues, check parent completion |
| `sankofa-patrol.yml` | `schedule` (weekly), `workflow_dispatch` | Health checks: orphans, stale, PR debt |
| `auto-assign-unblocked.yml` | `issues: [closed]` | Cascade dispatch: unblocked issues get auto-assigned |

## Configuration

### Required Repository Secrets

| Secret | Purpose |
|--------|---------|
| `COPILOT_DISPATCH_PAT` | PAT with `issues:write` scope for Copilot assignment via GraphQL |

### Optional Repository Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| Trusted actors list | Edit `auto-approve.yml` directly | See workflow file |
| Schedule cron | Edit `sankofa-patrol.yml` directly | `0 9 * * 1` (Monday 9 AM) |

## Customization

Each workflow is self-contained and can be customized independently:

1. **Trusted actors** — Edit the `trustedActors` array in `auto-approve.yml`
2. **Dispatchable types** — Edit `dispatchableTypes` in `issue-dispatch.yml` (default: Task, Bug)
3. **Bot thread resolution** — Edit `botLogins` in `copilot-checks.yml` and `auto-enqueue.yml`
4. **Patrol schedule** — Edit the cron expression in `sankofa-patrol.yml`
5. **Required checks** — Edit `requiredChecks` in `auto-approve.yml` and `auto-enqueue.yml`
