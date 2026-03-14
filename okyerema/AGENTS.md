# Okyerema — Rhythm Engine for the Anokye System

This is the Okyerema plugin, the multi-context rhythm engine for the Anokye System.
One drummer, many instruments: the same PowerShell scripts run across Claude Code,
Copilot, GitHub Actions, and local `act` runners.

## Agent

The Okyerema agent persona is defined in [`okyerema.agent.md`](okyerema.agent.md).

## Skills

- **[Rhythm](skills/rhythm/SKILL.md)** — WIEG state machine, dispatch patterns, rhythm loop, DAG management
- **[Sankofa](skills/sankofa/SKILL.md)** — Health patrols: orphans, stale work, hierarchy integrity

## Scripts

Scripts are the shared core — all contexts invoke the same PowerShell files:

| Directory | Purpose | Scripts |
|-----------|---------|---------|
| `scripts/rhythm/` | DAG status, work selection, dependency tracking | 7 |
| `scripts/dispatch/` | Issue creation, hierarchy, plan materialization | 10 |
| `scripts/verify/` | PR intelligence, reviews, thread management | 9 |
| `scripts/health/` | Hierarchy health, orphans, sitrep, repo readiness | 5 |

## Workflow Templates

Distributable GitHub Actions templates in `workflows/`. Copy to a target repo's
`.github/workflows/` and configure via repository variables (`vars.*`).

## Installation

```powershell
# Install Okyerema plugin for Copilot
copilot plugin install anokye-labs/plugins:okyerema

# Install workflow templates to a target repo
./install/Install-Okyerema.ps1 -TargetRepo /path/to/repo

# Set up Claude Code integration
./install/Install-ClaudeCode.ps1 -TargetRepo /path/to/repo

# Verify installation
./install/Verify-Installation.ps1 -TargetRepo /path/to/repo
```

## References

Detailed API guides in `skills/rhythm/references/`:
- Issue types, relationships, projects, PR reviews, agentic workflows, labels, errors, status commands, plan materialization
