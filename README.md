# Anokye Labs Plugins

Installable GitHub Copilot skills and agent plugins for the Anokye Labs ecosystem.

## Available Plugins

| Plugin | Description | Status |
|--------|-------------|--------|
| [okyerema](okyerema/) | Project orchestration — issue types, hierarchy, PR reviews | ✅ Ready |

## Installation

Each plugin includes an `Install-Plugin.ps1` script that copies the skill files into your repository:

```powershell
# From your target repo root
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
│   ├── SKILL.md                       # Main skill file (<500 lines)
│   ├── references/                    # On-demand reference guides
│   └── scripts/                       # PowerShell helper scripts
├── how-we-work/                       # Human-facing documentation (optional)
├── evaluations/                       # Test scenarios for validation
│   ├── README.md                      # Evaluation guide
│   └── *.eval.md                      # Individual test scenarios
└── scripts/
    └── Install-Plugin.ps1             # Installation script
```

## Design Principles

- **Skills < 500 lines** — Progressive disclosure via `references/` directory
- **GraphQL-first** — All structured GitHub operations use GraphQL, not REST
- **PowerShell** — All scripts are PowerShell 7+ compatible
- **Organization issue types** — Never labels for structure (Epic/Feature/Task/Bug)
- **Tasklists for hierarchy** — Parent-child relationships via markdown tasklists

## Naming

Plugins use Akan naming conventions:
- **Okyerema** (ɔkyerɛma) — The master drummer who coordinates the ensemble
- See each plugin's glossary for full terminology
