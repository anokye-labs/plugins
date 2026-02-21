# Omanfo Plugin

**The community toolkit for GitHub Copilot** — project orchestration, document processing, product management, and workflow automation. All the skills the asafo needs.

## What It Does

When installed, Omanfo gives GitHub Copilot the ability to:

- **Configure agentic workflows** — create gh-aw definitions, GitHub Actions, Temporal workflows
- **Scaffold automation** — audit repos for missing infrastructure, propose and create it
- **Set up patrols** — Sankofa health checks for stale issues, orphans, stuck work
- **Manage issues** — Create typed issues, build hierarchies, handle PR reviews
- **Document decisions** — ADR templates and guidance for architectural decisions
- **Run helper scripts** — PowerShell tools for issue types, hierarchy, PR threads

## Role in the Anokye System

Omanfo ("the people") is the shared toolkit of the asafo. It bundles the **Okyerema** (master drummer) agent alongside shared skills for documents, product management, and productivity — everything the warriors need to do their work.

See **[Okyeame](../okyeame/)** for the linguist agent.

## Installation

### Quick Install

```powershell
# Deploy the Anokye System to your target repo
& S:\anokye-labs\plugins\omanfo\scripts\Install-Anokye.ps1 -TargetRepo .
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
│   │   ├── relationships.md        # Hierarchy via sub-issues API
│   │   ├── projects.md             # Projects V2 API
│   │   ├── pr-reviews.md           # PR review thread management
│   │   ├── labels.md               # Label best practices
│   │   └── errors.md               # Common errors & fixes
│   └── scripts/
│       ├── Get-IssueTypeIds.ps1    # Get org type IDs
│       ├── New-IssueWithType.ps1   # Create typed issues
│       ├── Update-IssueHierarchy.ps1  # Build parent-child relationships
│       ├── Test-Hierarchy.ps1      # Verify hierarchy trees
│       ├── Get-UnresolvedThreads.ps1  # List PR review threads
│       ├── Reply-ReviewThread.ps1  # Reply to review threads
│       └── Resolve-ReviewThreads.ps1  # Bulk resolve threads
├── how-we-work.md                  # Coordination overview
├── how-we-work/
│   ├── getting-started.md          # Newcomer guide
│   ├── our-way.md                  # Opinionated workflow
│   ├── adr-process.md              # ADR process guidance
│   ├── adr-template.md             # Architecture Decision Record template
│   └── glossary.md                 # Akan terminology
└── agents.md                       # Agent entry point
```

## Agent Archetypes

The [archetypes/](archetypes/) directory contains reusable `.agent.md` templates for common automation patterns:

| Archetype | Purpose | Related Issues |
|-----------|---------|----------------|
| [doc-sync](archetypes/doc-sync.agent.md) | Documentation synchronization — detects when code changes but docs don't | anokye-labs/akwaaba#226-#232 |
| [issue-labeler](archetypes/issue-labeler.agent.md) | Automatic issue classification with type, priority, and phase labels | anokye-labs/akwaaba#233-#241 |
| [pr-reviewer](archetypes/pr-reviewer.agent.md) | Automated PR reviews with validation and auto-approve for agent PRs | anokye-labs/akwaaba#243-#253 |

See [archetypes/README.md](archetypes/README.md) for deployment guide and customization instructions.

## Evaluations

See [evaluations/](evaluations/) for test scenarios that validate the plugin after installation. Run these to confirm everything works in your environment.

## Version

See [.github/plugin/plugin.json](.github/plugin/plugin.json) for current version and compatibility information.
