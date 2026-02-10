# Anokye Labs Plugins

**Deploy the Anokye System to any GitHub repository** — turning your repo into an AI-orchestrated project management environment with multi-agent automation.

## Available Plugins

| Plugin | Role | Description | Status |
|--------|------|-------------|--------|
| [okyeame](okyeame/) | Linguist | The voice of the system — status updates, blocker reports, clarity requests | ✅ Ready |
| [omanfo](omanfo/) | The People | Community toolkit — orchestration, documents, product management, automation | ✅ Ready |

## The Anokye System: Three Layers Working in Harmony

The Anokye System is a multi-agent orchestration architecture that transforms how software gets built. Instead of manually creating issues, tracking status, and coordinating work, you install a plugin and your repository becomes an AI-orchestrated environment.

### The Three Layers

| Layer | Role | Where It Lives | How It's Installed |
|-------|------|---------------|-------------------|
| **Okyeame** (linguist) | CLI agent. Guides developers through Socratic dialog. Creates issues, reports status, automates repo setup. | Copilot CLI plugin | `/plugin install` |
| **Okyerema** (master drummer) | Repo skill. Keeps cloud agents in rhythm. Scripts, references, workflow automation. | Target repo `.github/skills/okyerema/` | `Install-Anokye.ps1` (automated by Okyeame) |
| **Asafo** (warriors) | Implementation agents. @copilot, specialist agents. Execute Tasks. | Cloud (GitHub Actions) | Deployed by Okyerema workflows |

### The Flow: From Plugin to Fully Orchestrated Repo

1. **Developer installs the plugin** → gets Okyeame in their CLI
2. **Okyeame detects an unconfigured repo** → guides setup through Socratic dialog
3. **Okyeame runs Install-Anokye.ps1** → deploys Okyerema skill, docs, scripts into the repo
4. **Repo is now Anokye-System-enabled** → cloud agents can use Okyerema
5. **Developer tells Okyeame to plan work** → Okyeame uses Okyerema to create typed issues with hierarchy
6. **Asafo (@copilot) picks up Tasks** → writes code, opens PRs
7. **Okyeame monitors progress** → reports status, surfaces blockers

### Okyeame's Socratic Dialog

Okyeame doesn't just execute commands — it guides you through decisions:

- *"I see this repo has no issue types configured. What kind of work does your team do?"*
- *"You mentioned notifications. Should I break that into separate features?"*
- *"I have created 6 tasks. Should I assign them all to @copilot, or do some need human review?"*

This conversational approach means you're never alone in setting up the system. Okyeame walks you through it, asks clarifying questions, and helps you make the right decisions for your project.

### Future Extensibility

The Anokye System is designed for growth:

- **Additional Asafo agents** — specialist agents for security, testing, documentation
- **Additional skills beyond Okyerema** — product management, DevOps, analytics
- **Repo analysis for upgrades** — not just greenfield, but brownfield repo improvements
- **Okyeame monitoring of cloud workflows** — real-time orchestration feedback

### Why This Matters

The README is the first thing a developer sees. If it says *"install this plugin and get some scripts,"* they miss the vision. 

**What the Anokye System really does:** It turns your repository into an AI-orchestrated project management environment where work flows from conversation to typed issues to automated implementation to merged code — all with minimal manual intervention.

### Other Anokye System Components

- **Adwoma** — Work. GitHub Issues as the single source of truth.
- **Sankofa** — Return and get it. Automated health patrols.

## Installation

### The Two Ways to Deploy

The Anokye System can be deployed in two ways:

1. **Via Okyeame CLI Plugin** (Recommended) — `/plugin install` in GitHub Copilot CLI
   - Okyeame guides you through Socratic dialog
   - Automatically runs `Install-Anokye.ps1` for you
   - Helps configure issue types and project boards
   - *Currently in development - watch this space*

2. **Manual Deployment** (Available Now) — Run the script directly

### Quick Start: Manual Deployment

Each plugin includes an `Install-Anokye.ps1` script that deploys the full system into your repository:

```powershell
# Deploy the Anokye System to your repository
& S:\anokye-labs\plugins\omanfo\scripts\Install-Anokye.ps1 -TargetRepo .
```

Or manually copy the `.github/skills/<plugin-name>/` directory into your repository.

### What Gets Deployed

When you run `Install-Anokye.ps1`, you get:

- ✅ **Okyerema skill files** — SKILL.md, references, PowerShell scripts
- ✅ **Documentation** — how-we-work guides, glossary, conventions
- ✅ **Agent entry points** — agents.md for cloud agent coordination
- ✅ **Workflow automation** — Scripts for issue types, hierarchy, PR reviews

Your repository becomes Anokye-System-enabled, ready for orchestrated development.

## Plugin Structure

Each plugin follows a standard layout:

```
<plugin-name>/
├── README.md                          # Plugin docs and usage
├── manifest.json                      # Plugin metadata and version
├── .github/skills/<name>/             # The skill (deployed to target repos)
│   ├── <name>.agent.md                # Agent persona (optional)
│   ├── SKILL.md                       # Main skill file (<500 lines)
│   ├── references/                    # On-demand reference guides
│   └── scripts/                       # PowerShell helper scripts
├── how-we-work/                       # Human-facing documentation (optional)
├── evaluations/                       # Test scenarios for validation
└── scripts/
    └── Install-Anokye.ps1             # Deployment script
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
