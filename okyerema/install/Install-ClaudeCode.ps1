<#
.SYNOPSIS
    Sets up Claude Code integration for the Okyerema plugin in a target repository.

.DESCRIPTION
    Creates AGENTS.md and .claude/commands/ slash commands in the target repository
    so that Claude Code can discover and invoke Okyerema skills and scripts.

.PARAMETER TargetRepo
    Path to the target repository root.

.PARAMETER Force
    If set, overwrites existing files.

.EXAMPLE
    .\Install-ClaudeCode.ps1 -TargetRepo C:\src\my-project
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TargetRepo,

    [switch]$Force
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $PSScriptRoot  # okyerema/ directory

# Resolve target path
$targetPath = Resolve-Path $TargetRepo -ErrorAction Stop

Write-Host "`nInstalling Claude Code integration to: $targetPath" -ForegroundColor Cyan

# Create AGENTS.md
$agentsFile = Join-Path $targetPath "AGENTS.md"
if ((Test-Path $agentsFile) -and -not $Force) {
    Write-Host "  AGENTS.md already exists, skipping" -ForegroundColor Yellow
} else {
    $agentsContent = @"
# Agents

This repository uses the Anokye System. The Okyerema (master drummer) provides
workflow automation and project orchestration.

## Okyerema — Rhythm Engine

The Okyerema plugin provides scripts for:
- **Rhythm**: DAG status, work selection, dependency tracking
- **Dispatch**: Issue creation, hierarchy, plan materialization
- **Verify**: PR intelligence, reviews, thread management
- **Health**: Hierarchy health, orphans, sitrep, repo readiness

See the [Okyerema plugin](https://github.com/anokye-labs/plugins/tree/main/okyerema)
for full documentation.
"@
    Set-Content -Path $agentsFile -Value $agentsContent
    Write-Host "  Created AGENTS.md" -ForegroundColor Green
}

# Create .claude/commands/ directory and slash commands
$claudeDir = Join-Path $targetPath ".claude/commands"
if (-not (Test-Path $claudeDir)) {
    New-Item -Path $claudeDir -ItemType Directory -Force | Out-Null
    Write-Host "  Created .claude/commands/" -ForegroundColor Gray
}

$commands = @{
    "sitrep.md" = @"
# /sitrep — Tactical Status Dashboard

Run the Okyerema sitrep script to get a tactical status dashboard for this repository.

```bash
pwsh -File okyerema/scripts/health/Get-Sitrep.ps1 -Owner {owner} -Repo {repo}
```

Replace {owner} and {repo} with the actual repository owner and name.
"@
    "prcheck.md" = @"
# /prcheck — PR Health Check

Run the Okyerema PR health script to check all open PRs for readiness.

```bash
pwsh -File okyerema/scripts/verify/Get-PRHealth.ps1 -Owner {owner} -Repo {repo}
```

Replace {owner} and {repo} with the actual repository owner and name.
"@
    "health.md" = @"
# /health — Repository Health Check

Run the Okyerema health scripts to check for systemic issues.

```bash
pwsh -File okyerema/scripts/health/Get-HierarchyHealth.ps1 -Owner {owner} -Repo {repo}
pwsh -File okyerema/scripts/health/Get-OrphanedIssues.ps1 -Owner {owner} -Repo {repo}
```

Replace {owner} and {repo} with the actual repository owner and name.
"@
    "whatsleft.md" = @"
# /whatsleft — Remaining Work

Run the Okyerema DAG status script to see what work remains.

```bash
pwsh -File okyerema/scripts/rhythm/Get-DagStatus.ps1 -Owner {owner} -Repo {repo}
pwsh -File okyerema/scripts/rhythm/Get-ReadyIssues.ps1 -Owner {owner} -Repo {repo}
```

Replace {owner} and {repo} with the actual repository owner and name.
"@
}

$created = 0
foreach ($name in $commands.Keys) {
    $cmdFile = Join-Path $claudeDir $name
    if ((Test-Path $cmdFile) -and -not $Force) {
        Write-Host "  Skipping (exists): .claude/commands/$name" -ForegroundColor Yellow
    } else {
        Set-Content -Path $cmdFile -Value $commands[$name]
        $created++
        Write-Host "  Created: .claude/commands/$name" -ForegroundColor Green
    }
}

Write-Host "`n  $created slash command(s) installed" -ForegroundColor Cyan
Write-Host "`nClaude Code integration complete." -ForegroundColor Green
