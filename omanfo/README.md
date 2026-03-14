# Omanfo Plugin

**The community toolkit for GitHub Copilot** — the Okyeame linguist agent, document processing, product management, and productivity skills. All the ancillary skills the asafo needs.

## What It Does

When installed, Omanfo gives GitHub Copilot the ability to:

- **Manage issues** — Create typed issues, build hierarchies, handle PR reviews (via Okyerema scripts)
- **Document decisions** — ADR templates and guidance for architectural decisions
- **Run helper scripts** — PowerShell tools for issue types, hierarchy, PR threads
- **Generate documents** — DOCX, PDF, PPTX, XLSX creation and manipulation
- **Product management** — Product management workflows and templates

## Role in the Anokye System

Omanfo ("the people") is the shared toolkit of the asafo. It provides the **Okyeame** (linguist) agent and ancillary skills for documents, product management, and productivity.

For workflow automation, CI/CD, and the rhythm engine, see **[Okyerema](../okyerema/)** (standalone plugin).
See **[Okyeame](okyeame.agent.md)** for the linguist agent.

## Installation

### Quick Install

```powershell
# Deploy the Anokye System to your target repo
& ./omanfo/scripts/Install-Anokye.ps1 -TargetRepo .
```

### Manual Install

Copy these directories into your repository:
1. `how-we-work/` and `how-we-work.md` — Human documentation (optional)
2. `agents.md` — Agent entry point (optional)

For the Okyerema rhythm engine (workflow automation, CI/CD), install the **[Okyerema plugin](../okyerema/)** separately.

### Prerequisites

- GitHub CLI (`gh`) authenticated
- PowerShell 7+
- Organization with issue types configured (Epic, Feature, Task, Bug)

## Plugin Structure

```
omanfo/
├── okyeame.agent.md                # Okyeame agent persona
├── .github/plugin/plugin.json      # Plugin metadata
├── skills/                         # Copilot skills
│   ├── okyeame/                    # Okyeame skill
│   ├── doc-coauthoring/            # Document co-authoring
│   ├── docx/                       # DOCX generation
│   ├── github-issue-creator/       # Issue creation
│   ├── internal-comms/             # Internal communications
│   ├── pdf/                        # PDF generation
│   ├── pptx/                       # PPTX presentations
│   ├── product-management/         # Product management
│   ├── productivity/               # Productivity workflows
│   ├── skill-creator/              # Skill authoring
│   └── xlsx/                       # XLSX spreadsheets
├── archetypes/                     # Reusable agent templates
├── how-we-work/                    # Human-facing documentation
├── how-we-work.md                  # Coordination overview
├── agents.md                       # Agent entry point
├── evaluations/                    # Test scenarios
└── scripts/                        # Deployment and validation
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
