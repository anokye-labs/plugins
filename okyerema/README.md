# Okyerema Plugin

**Project orchestration skill for GitHub Copilot** — coordinates issues, hierarchies, projects, and PR reviews using organization issue types and GraphQL.

## What It Does

When installed, Okyerema gives GitHub Copilot the ability to:

- **Create typed issues** — Epic, Feature, Task, Bug with proper organization issue types
- **Build hierarchies** — 3-level (Epic → Feature → Task) or 2-level structures via tasklists
- **Manage projects** — Add items to GitHub Projects V2, update custom fields
- **Handle PR reviews** — Find unresolved threads, reply, bulk resolve/unresolve
- **Apply labels** — Sparingly and correctly, following org conventions

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
