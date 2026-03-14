# Anokye Labs Plugins

**Deploy the Anokye System to any GitHub repository** — turning your repo into an AI-orchestrated project management environment with multi-agent automation.

## Plugins

| Plugin | Description | Skills | Status |
|--------|-------------|--------|--------|
| [omanfo](omanfo/) | Community toolkit — Okyeame agent, document processing, product management, and productivity skills | okyeame, doc-coauthoring, docx, pdf, pptx, xlsx, github-issue-creator, internal-comms, product-management, productivity, skill-creator | ✅ Ready |
| [okyerema](okyerema/) | Rhythm Engine — multi-context workflow automation, CI/CD, health patrols, and dispatch | rhythm, sankofa | ✅ Ready |
| [ahuofe](ahuofe/) | Media generation and manipulation using fal.ai and ImageSorcery | fal-ai, fal-workflow, image-sorcery, media-agents | ✅ Ready |

**Omanfo** ("The People") is the community toolkit plugin that contains:
- **Okyeame** — The agent persona (linguist) for project management, status reporting, and coordination
- **Agent Archetypes** — Reusable templates for doc-sync, issue-labeler, and pr-reviewer automation
- **Ancillary skills** — Document generation (DOCX/PDF/PPTX/XLSX), product management, productivity

**Okyerema** ("Master Drummer") is the rhythm engine plugin that contains:
- **Workflow automation** — GitHub Actions templates for dispatch, auto-approve, post-merge, and health patrols
- **Scripts** — PowerShell tools for issue management, hierarchy, PR health, and status reporting
- **Skills** — rhythm (WIEG state machine) and sankofa (health patrol patterns)

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
| [CLITestHarness](shared/CLITestHarness/) | Test Infrastructure | PowerShell module for testing Copilot CLI plugin interactions | ✅ Ready |

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
| **Okyerema** (master drummer) | Rhythm engine. Keeps cloud agents in rhythm. Scripts, workflows, health patrols. | Standalone plugin | `copilot plugin install okyerema@anokye-plugins` |
| **Asafo** (warriors) | Implementation agents. @copilot, specialist agents. Execute Tasks. | Cloud (GitHub Actions) | Deployed by Okyerema workflows |

### The Flow: From Plugin to Fully Orchestrated Repo

1. **Developer registers the marketplace** → `copilot plugin marketplace add anokye-labs/plugins`
2. **Developer installs plugins** → `copilot plugin install omanfo@anokye-plugins` and `okyerema@anokye-plugins`
3. **Okyeame detects an unconfigured repo** → guides setup through Socratic dialog
4. **Okyerema deploys workflows** → installs GitHub Actions, scripts, and skill files into the target repo
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

**What the Anokye System really does:** It turns your repository into an AI-orchestrated project management environment where work flows from conversation to typed issues to automated implementation to merged code — all with minimal manual intervention.

### Other Anokye System Components

- **Adwoma** — Work. GitHub Issues as the single source of truth.
- **Sankofa** — Return and get it. Automated health patrols.

## Installation

### Quick Start: Marketplace Installation (Recommended)

```bash
# Step 1: Register the Anokye Plugins marketplace (one-time setup)
copilot plugin marketplace add anokye-labs/plugins

# Step 2: Browse available plugins
copilot plugin marketplace browse anokye-plugins

# Step 3: Install plugins
copilot plugin install omanfo@anokye-plugins
copilot plugin install okyerema@anokye-plugins
```

Once installed, Okyeame is available in your Copilot CLI and will guide you through deploying Okyerema workflows to your repositories.

### Manual / Advanced Deployment

For advanced users or automated deployment scenarios:

```powershell
# Deploy Okyerema workflows and scripts to your repository
& ./okyerema/install/Install-Okyerema.ps1 -TargetRepo .

# Deploy Omanfo documentation and agent config
& ./omanfo/scripts/Install-Anokye.ps1 -TargetRepo .
```

**Note:** This approach bypasses Okyeame's Socratic dialog and is intended for automation pipelines or situations where you need fine-grained control over the deployment process.

## Repository Structure

```
plugins/
├── omanfo/                        # Community toolkit plugin
│   ├── okyeame.agent.md           # Okyeame agent persona
│   ├── skills/                    # 11 Copilot skills
│   ├── archetypes/                # Agent templates
│   ├── how-we-work/               # Human documentation
│   └── scripts/                   # Deployment & validation
├── okyerema/                      # Rhythm Engine plugin
│   ├── okyerema.agent.md          # Okyerema agent persona
│   ├── skills/                    # rhythm, sankofa skills
│   ├── workflows/                 # GitHub Actions templates
│   ├── scripts/                   # PowerShell tools
│   └── install/                   # Deployment scripts
├── ahuofe/                        # Media generation plugin
│   └── skills/                    # fal-ai, image-sorcery skills
├── shared/                        # Shared modules
│   ├── OkyeremanAgentRunner/      # Agent runtime foundation
│   └── CLITestHarness/            # Test infrastructure
├── tests/                         # Test suites
│   ├── omanfo/                    # Omanfo tests
│   └── okyerema/                  # Okyerema tests
├── workflow-templates/            # Governance workflows
└── .github/plugin/marketplace.json # Marketplace registry
```

## Design Principles

- **Skills < 500 lines** — Progressive disclosure via `references/` directory
- **GraphQL-first** — All structured GitHub operations use GraphQL, not REST
- **PowerShell** — All scripts are PowerShell 7+ compatible
- **Organization issue types** — Never labels for structure (Epic/Feature/Task/Bug)
- **Sub-issues for hierarchy** — Parent-child relationships via sub-issues API

## Naming

The Anokye System uses Akan naming conventions:
- **Omanfo** (ɔmanfoɔ) — "The people" — the community toolkit plugin
- **Okyeame** (ɔkyeame) — The linguist who gives voice to the system (agent persona)
- **Okyerema** (ɔkyerɛma) — The master drummer who keeps the asafo in rhythm (orchestration plugin)
- **Ahuofe** (ahúofe) — "Beauty" — the media generation plugin
- See the [glossary](omanfo/how-we-work/glossary.md) for full terminology
