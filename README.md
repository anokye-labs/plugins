# Anokye Labs Plugins

Installable GitHub Copilot skills and agent plugins for the Anokye Labs ecosystem — the **Anokye System**.

## Available Plugins

| Plugin | Role | Description | Status |
|--------|------|-------------|--------|
| [okyeame](okyeame/) | Spokesperson (Mayor) | Project coordination agent — issues, hierarchy, status, agent coordination | ✅ Ready |
| [okyerema](okyerema/) | Master Drummer (Deacon) | Workflow automation skill — agentic workflows, CI/CD, patrols, scripts | ✅ Ready |

## The Anokye System

A multi-agent orchestration architecture for software development using Akan naming:

- **Okyeame** — The spokesperson. The face you interact with. Coordinates all work.
- **Okyerema** — The master drummer. Configures automation. Invoked by Okyeame.
- **Asafo** — Warriors. Implementation agents (@copilot) that execute Tasks.
- **Adwoma** — Work. GitHub Issues as the single source of truth.
- **Sankofa** — Return and get it. Automated health patrols.

## Installation

Each plugin includes an `Install-Plugin.ps1` script that copies the skill files into your repository:

```powershell
# Install both plugins
& S:\anokye-labs\plugins\okyerema\scripts\Install-Plugin.ps1 -TargetRepo .
```

Or manually copy the `.github/skills/<plugin-name>/` directory into your repository.

## Plugin Structure

Each plugin follows a standard layout:

```
<plugin-name>/
├── README.md                          # Plugin docs and usage
├── manifest.json                      # Plugin metadata and version
├── .github/skills/<name>/             # The skill (copied to target repos)
│   ├── <name>.agent.md                # Agent persona (optional)
│   ├── SKILL.md                       # Main skill file (<500 lines)
│   ├── references/                    # On-demand reference guides
│   └── scripts/                       # PowerShell helper scripts
├── how-we-work/                       # Human-facing documentation (optional)
├── evaluations/                       # Test scenarios for validation
└── scripts/
    └── Install-Plugin.ps1             # Installation script
```

## Design Principles

- **Skills < 500 lines** — Progressive disclosure via `references/` directory
- **GraphQL-first** — All structured GitHub operations use GraphQL, not REST
- **PowerShell** — All scripts are PowerShell 7+ compatible
- **Organization issue types** — Never labels for structure (Epic/Feature/Task/Bug)
- **Sub-issues for hierarchy** — Parent-child relationships via sub-issues API

## Naming

Plugins use Akan naming conventions from the Anokye System:
- **Okyeame** (ɔkyeame) — The spokesperson who coordinates the ensemble
- **Okyerema** (ɔkyerɛma) — The master drummer who sets the rhythm
- See each plugin's glossary for full terminology
