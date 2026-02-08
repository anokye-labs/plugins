# Okyerema Plugin

**Workflow automation skill for GitHub Copilot** — configures agentic workflows, CI/CD pipelines, patrol schedules, and automation scaffolding. The master drummer sets the rhythm.

## What It Does

When installed, Okyerema gives GitHub Copilot the ability to:

- **Configure agentic workflows** — create gh-aw definitions, GitHub Actions, Temporal workflows
- **Scaffold automation** — audit repos for missing infrastructure, propose and create it
- **Set up patrols** — Sankofa health checks for stale issues, orphans, stuck work
- **Manage issues** — Create typed issues, build hierarchies, handle PR reviews
- **Run helper scripts** — PowerShell tools for issue types, hierarchy, PR threads

## Role in the Anokye System

Okyerema is the automation specialist invoked by the **Okyeame** (spokesperson/coordinator) when workflow configuration is needed. It can also operate independently as a modular agent for security-sensitive workflow operations.

See **[Okyeame](../okyeame/)** for the top-level coordination agent.

## Installation

### Quick Install

```powershell
# From your target repo root
& S:\anokye-labs\plugins\okyerema\scripts\Install-Plugin.ps1 -TargetRepo .
```

### Manual Install

Copy these directories into your repository:
1. `.github/skills/okyerema/` — The Copilot skill (SKILL.md + references + scripts)
2. `how-we-work/` and `how-we-work.md` — Human documentation (optional)
3. `agents.md` — Agent entry point (optional)

### Prerequisites

- GitHub CLI (`gh`) authenticated
- PowerShell 7+
- Organization with issue types configured (Epic, Feature, Task, Bug)

## What Gets Installed

```
your-repo/
├── .github/skills/okyerema/
│   ├── SKILL.md                    # Main skill (~165 lines)
│   ├── references/
│   │   ├── issue-types.md          # Issue type GraphQL operations
│   │   ├── relationships.md        # Hierarchy via tasklists
│   │   ├── projects.md             # Projects V2 API
│   │   ├── pr-reviews.md           # PR review thread management
│   │   ├── labels.md               # Label best practices
│   │   └── errors.md               # Common errors & fixes
│   └── scripts/
│       ├── Get-IssueTypeIds.ps1    # Get org type IDs
│       ├── New-IssueWithType.ps1   # Create typed issues
│       ├── Update-IssueHierarchy.ps1  # Build tasklist relationships
│       ├── Test-Hierarchy.ps1      # Verify hierarchy trees
│       ├── Get-UnresolvedThreads.ps1  # List PR review threads
│       ├── Reply-ReviewThread.ps1  # Reply to review threads
│       └── Resolve-ReviewThreads.ps1  # Bulk resolve threads
├── how-we-work.md                  # Coordination overview
├── how-we-work/
│   ├── getting-started.md          # Newcomer guide
│   ├── our-way.md                  # Opinionated workflow
│   └── glossary.md                 # Akan terminology
└── agents.md                       # Agent entry point
```

## Evaluations

See [evaluations/](evaluations/) for test scenarios that validate the plugin after installation. Run these to confirm everything works in your environment.

## Version

See [manifest.json](manifest.json) for current version and compatibility information.
