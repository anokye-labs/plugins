# Anokye Labs Plugins

Installable GitHub Copilot skills and agent plugins for the Anokye Labs ecosystem — the **Anokye System**.

## Available Plugins

| Plugin | Role | Description | Status |
|--------|------|-------------|--------|
| [okyeame](okyeame/) | Linguist | The voice of the system — status updates, blocker reports, clarity requests | ✅ Ready |
| [omanfo](omanfo/) | The People | Community toolkit — orchestration, documents, product management, automation | ✅ Ready |

## The Anokye System

A multi-agent orchestration architecture for software development using Akan naming:

- **Okyeame** — The linguist. The voice you interact with. Status updates, blockers, clarity.
- **Okyerema** — The master drummer. Keeps the asafo in rhythm through automation.
- **Asafo** — Warriors. Implementation agents (@copilot) that execute Tasks.
- **Adwoma** — Work. GitHub Issues as the single source of truth.
- **Sankofa** — Return and get it. Automated health patrols.

## Installation

Each plugin includes an `Install-Plugin.ps1` script that copies the skill files into your repository:

```powershell
# Install the plugin
& S:\anokye-labs\plugins\omanfo\scripts\Install-Plugin.ps1 -TargetRepo .
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
- **Okyeame** (ɔkyeame) — The linguist who gives voice to the system
- **Okyerema** (ɔkyerɛma) — The master drummer who keeps the asafo in rhythm
- See each plugin's glossary for full terminology
