# Anokye Labs Plugins

**Deploy the Anokye System to any GitHub repository** — turning your repo into an AI-orchestrated project management environment with multi-agent automation.

## Plugins

| Plugin | Description | Skills | Status |
|--------|-------------|--------|--------|
| [omanfo](omanfo/) | The Omanfo plugin containing Okyeame (agent) and Okyerema (orchestration skill) for the Anokye System | Okyeame, Okyerema | ✅ Ready |
| [ahuofe](ahuofe/) | The Ahuofe plugin for media generation and manipulation using fal.ai and ImageSorcery | fal-ai, fal-workflow, image-sorcery, media-agents | ✅ Ready |

**Omanfo** ("The People") is the project-management plugin that contains:
- **Okyeame** — The agent persona (linguist) for project management, status reporting, and coordination
- **Okyerema** — The orchestration skill (master drummer) with scripts, references, and workflow automation
- **Agent Archetypes** — Reusable templates for doc-sync, issue-labeler, and pr-reviewer automation

## Agent Archetypes

| Archetype | Purpose | Related Issues |
|-----------|---------|----------------|
| [doc-sync](omanfo/archetypes/doc-sync.agent.md) | Keep docs in sync with code changes | anokye-labs/akwaaba#226-#232 |
| [issue-labeler](omanfo/archetypes/issue-labeler.agent.md) | Automatic issue classification | anokye-labs/akwaaba#233-#241 |
| [pr-reviewer](omanfo/archetypes/pr-reviewer.agent.md) | Automated PR reviews | anokye-labs/akwaaba#243-#253 |

See [archetypes documentation](omanfo/archetypes/README.md) for deployment and customization.

## Shared Modules

| Module | Purpose | Description | Status |
|--------|---------|-------------|--------|
| [OkyeremanAgentRunner](shared/OkyeremanAgentRunner/) | Runtime Foundation | Common functions for logging, error handling, issue context, PR management, safe output processing, correlation tracking | ✅ Ready |

## Governance Workflow Templates

| Template | Purpose | Description | Status |
|----------|---------|-------------|--------|
| [workflow-templates](workflow-templates/) | Repository Governance | Reusable GitHub Actions workflows for commit validation, agent authentication, and branch protection rulesets | ✅ Ready |

**Enforce agent-only commits and issue-driven development** — Copy these templates into any repository to require that all commits reference issues and come from approved agents (like Copilot).

## The Anokye System: Three Layers Working in Harmony

The Anokye System is a multi-agent orchestration architecture that transforms how software gets built. Instead of manually creating issues, tracking status, and coordinating work, you install a plugin and your repository becomes an AI-orchestrated environment.

### The Three Layers

| Layer | Role | Where It Lives | How It's Installed |
|-------|------|---------------|-------------------|
| **Okyeame** (linguist) | CLI agent. Guides developers through Socratic dialog. Creates issues, reports status, automates repo setup. | Copilot CLI plugin | `copilot plugin install omanfo@anokye-plugins` |
| **Okyerema** (master drummer) | Repo skill. Keeps cloud agents in rhythm. Scripts, references, workflow automation. | Target repo `.github/skills/okyerema/` | Auto-deployed from Omanfo plugin |
| **Asafo** (warriors) | Implementation agents. @copilot, specialist agents. Execute Tasks. | Cloud (GitHub Actions) | Deployed by Okyerema workflows |

### The Flow: From Plugin to Fully Orchestrated Repo

1. **Developer registers the marketplace** → `copilot plugin marketplace add anokye-labs/plugins`
2. **Developer installs the plugin** → `copilot plugin install omanfo@anokye-plugins`
3. **Okyeame detects an unconfigured repo** → guides setup through Socratic dialog
4. **Okyeame deploys Okyerema skill** → copies `.github/skills/okyerema/` into the target repo
5. **Repo is now Anokye-System-enabled** → cloud agents can use Okyerema
6. **Developer tells Okyeame to plan work** → Okyeame uses Okyerema to create typed issues with hierarchy
7. **Asafo (@copilot) picks up Tasks** → writes code, opens PRs
8. **Okyeame monitors progress** → reports status, surfaces blockers

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

### Quick Start: Marketplace Installation (Recommended)

The Omanfo plugin is distributed through the Anokye Plugins marketplace. Install it in three steps:

```bash
# Step 1: Register the Anokye Plugins marketplace (one-time setup)
copilot plugin marketplace add anokye-labs/plugins

# Step 2: Browse available plugins
copilot plugin marketplace browse anokye-plugins

# Step 3: Install the Omanfo plugin
copilot plugin install omanfo@anokye-plugins
```

Once installed, Okyeame is available in your Copilot CLI and will guide you through deploying the Okyerema skill to your repositories.

### Manual / Advanced Deployment

For advanced users or automated deployment scenarios, the Omanfo plugin includes an `Install-Anokye.ps1` script that directly deploys skill files into a target repository:

```powershell
# Deploy Okyerema skill files directly to your repository
& /path/to/plugins/omanfo/scripts/Install-Anokye.ps1 -TargetRepo .
```

Or manually copy the `.github/skills/` directory from the plugin into your repository.

**Note:** This approach bypasses Okyeame's Socratic dialog and is intended for automation pipelines or situations where you need fine-grained control over the deployment process.

### What Gets Deployed

When you run `Install-Anokye.ps1`, you get:

- ✅ **Okyerema skill files** — SKILL.md, references, PowerShell scripts
- ✅ **Documentation** — how-we-work guides, glossary, conventions
- ✅ **Agent entry points** — agents.md for cloud agent coordination
- ✅ **Workflow automation** — Scripts for issue types, hierarchy, PR reviews

Your repository becomes Anokye-System-enabled, ready for orchestrated development.

## Plugin Structure

The Omanfo plugin contains multiple skills and follows this structure:

```
omanfo/
├── README.md                          # Plugin docs and usage
├── manifest.json                      # Plugin metadata with skills array
├── okyeame.agent.md                   # Okyeame agent persona file
├── .github/skills/
│   ├── okyeame/                       # Okyeame skill
│   │   └── SKILL.md                   # Main skill file (<500 lines)
│   └── okyerema/                      # Okyerema skill  
│       ├── SKILL.md                   # Main skill file (<500 lines)
│       ├── references/                # On-demand reference guides
│       └── scripts/                   # PowerShell helper scripts
├── how-we-work/                       # Human-facing documentation
├── evaluations/                       # Test scenarios for validation
└── scripts/
    ├── Install-Anokye.ps1             # Deployment script
    └── Verify-Installation.ps1        # Verification script
```

## Design Principles

- **Skills < 500 lines** — Progressive disclosure via `references/` directory
- **GraphQL-first** — All structured GitHub operations use GraphQL, not REST
- **PowerShell** — All scripts are PowerShell 7+ compatible
- **Organization issue types** — Never labels for structure (Epic/Feature/Task/Bug)
- **Sub-issues for hierarchy** — Parent-child relationships via sub-issues API

## Naming

The Anokye System uses Akan naming conventions:
- **Omanfo** (ɔmanfoɔ) — "The people" - the unified plugin containing all components
- **Okyeame** (ɔkyeame) — The linguist who gives voice to the system (agent persona)
- **Okyerema** (ɔkyerɛma) — The master drummer who keeps the asafo in rhythm (orchestration skill)
- See the plugin's glossary for full terminology
