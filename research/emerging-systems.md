# Emerging Agentic Coordination Systems (January-February 2026)

> **Survey Period**: January 1 - February 12, 2026
> **Focus**: Systems beyond the major platforms that represent novel approaches to multi-agent orchestration

---

## Overview

Beyond the major platforms ([Gas Town](./gastown.md), [Claude Agent Teams](./claude-agent-teams.md), [Copilot Fleet](./copilot-fleet-mode.md), [Codex App](./openai-codex-app.md), [StrongDM Factory](./strongdm-software-factory.md)), a constellation of emerging systems, tools, and frameworks are advancing multi-agent coordination. This report catalogs the most significant announcements and patterns from the last six weeks.

## Amp (Sourcegraph)

**Source**: [ampcode.com](https://ampcode.com/) | **Updated**: February 2026

Amp is Sourcegraph's frontier coding agent, notable for:

- **Multi-model architecture**: Uses Opus 4.6, GPT-5.2 Codex, and fast models simultaneously, each for what it's best at
- **Three modes**: `smart` (unconstrained SOTA), `rush` (faster/cheaper for well-defined tasks), `deep` (extended thinking for complex problems)
- **Oracle**: Read-only tool for asking questions about the codebase without making changes
- **Subagents**: Parallel worker agents for dividing tasks (e.g., "Use 3 subagents to convert these CSS files to Tailwind")
- **Shareable Walkthroughs**: Generate interactive annotated diagrams of changes (January 29, 2026)
- **Code Review Agent**: Composable and extensible code review (February 4, 2026)

Steve Yegge (co-author of "Vibe Coding" with Gene Kim) works at Sourcegraph and gave a talk "[Beyond the IDE: Toward Multi-Agent Orchestration](https://www.youtube.com/watch?v=D0cG4GLuzgM)" in October 2025 that previewed many Gas Town concepts.

Amp's approach: provide the best single-agent experience with subagent parallelism, rather than full multi-agent orchestration. Positioned at [Stage 5-6](./gastown.md#yegges-8-stages-of-developer-agent-evolution) on Yegge's scale.

## Devin (Cognition)

**Source**: [cognition.ai](https://cognition.ai) | **Funding**: $175M+ (Founders Fund)

Devin is the first-mover in the "AI software engineer" category:

- **Autonomous execution**: Plans, codes, debugs, and deploys independently in a sandboxed environment (own IDE, terminal, browser)
- **Enterprise scale**: Goldman Sachs, Santander, Nubank, Infosys, Cognizant
- **Performance**: 67% PR merge rate (up from 34% YoY), 4x faster problem solving
- **Pricing**: ~$500/seat/month
- **Best at**: Junior-level tasks at infinite scale - migrations, security fixes, test generation

Devin operates as a **single autonomous agent** rather than a multi-agent system. StrongDM lists Devin among fellow factory builders. The distinction: Devin abstracts away the agent entirely (you assign a task, get a PR), while [Gas Town](./gastown.md) and [Claude Agent Teams](./claude-agent-teams.md) expose the orchestration layer to the developer.

## AOrchestra (Research)

**Source**: [arXiv:2601.02577](https://arxiv.org/abs/2601.02577) | **Published**: February 3, 2026

An orchestrator-centric agentic framework for complex, long-horizon tasks:

- **Dynamic sub-agent creation**: Sub-agents are instantiated on-the-fly, each defined by a unified four-tuple: (Instruction, Context, Tools, Model)
- **Learnable orchestrator**: Improves decomposition, context routing, and capability allocation from past experience
- **Training-free performance**: Outperforms popular agentic systems across GAIA, Terminal-Bench 2.0, and SWE-Bench-Verified benchmarks

Key insight: instead of pre-defining agent roles (like [Gas Town's](./gastown.md) Mayor/Deacon/Witness), AOrchestra creates specialized sub-agents dynamically based on the task at hand.

## MegaFlow (Alibaba)

**Source**: [arXiv:2601.07526](https://arxiv.org/abs/2601.07526) | **Published**: January 12, 2026

A large-scale distributed orchestration system designed for the agentic era:

- **Distributed scheduling**: Efficient resource allocation for agent-environment workloads
- **Fine-grained task management**: Abstracts agent tasks into schedulable units
- **Training + evaluation support**: Designed for both training agents on complex tasks (SWE-bench, computer use) and evaluating them at scale

MegaFlow addresses infrastructure-level orchestration - the layer below systems like Gas Town, handling the actual compute and environment management.

## Orchestral AI (Research)

**Source**: [arXiv:2601.02577](https://arxiv.org/abs/2601.02577) | **Published**: January 5, 2026

A lightweight Python framework for building LLM agents across multiple providers:

- **Unified interface**: Single representation for messages, tools, and LLM usage across providers
- **Type-safe**: Automatic tool schema generation from Python type hints
- **Provider-agnostic**: Eliminates manual format translation
- **Focus**: Scientific computing and production deployment simplicity

Orchestral targets the framework layer rather than the orchestration layer - it provides building blocks for multi-agent systems rather than being one itself.

## AI21 Maestro

**Source**: [ai21.com/blog/test-time-compute-swe-bench](https://www.ai21.com/blog/test-time-compute-swe-bench/) | **Published**: January 7, 2026

A general-purpose agentic framework that automatically scales compute and optimizes orchestration:

- **Test-Time Compute (TTC) orchestration**: Allocates compute efficiently across agent trajectories
- **Horizontal scaling**: Multiple parallel attempts with decision-theoretic optimization
- **SWE-bench performance**: Significant improvements through structured plans and automatic scaling
- **Key insight**: Current strategies treat each agent run as a sealed unit. Maestro coordinates runs as a team.

## Cadence ChipStack AI Super Agent

**Source**: [Cadence press release](https://www.cadence.com/en_US/home/company/newsroom/press-releases/pr/2026/cadence-unleashes-chipstack-ai-super-agent-pioneering-a-new.html) | **Published**: February 10, 2026

The agentic pattern applied to chip design and verification:

- **Multiple virtual engineers**: Orchestrates agents using Cadence's foundational EDA tools
- **10X productivity**: For coding designs, testbenches, test plans, regression testing, debugging
- **Domain-specific**: Proves the orchestration pattern extends beyond software to hardware design

Significant because it demonstrates that [Stage 8](./stage-8-approaches.md) patterns are domain-transferable.

## Community Orchestration Tools

Several open-source tools have emerged to fill gaps in platform-native orchestration:

| Tool | Approach | Link |
|------|----------|------|
| **claude-flow** | Enterprise orchestration platform with distributed swarm intelligence for Claude Code | Community |
| **claude-sneakpeek** | Bypass feature flags to test native swarm mode early | Community |
| **Oh My Claude Code** | Bundled orchestration plugins for Claude Code | Community |
| **Agentic Fleet** (Qredence) | Adaptive AI reasoning using Microsoft Agent Framework | [GitHub](https://github.com/Qredence/agentic-fleet) |
| **Ralph Wiggum Loop** | Persistent agent loop pattern - runs agent until completion criteria met | Geoffrey Huntley |

### The Ralph Wiggum Pattern

Popularized by Geoffrey Huntley in mid-2025, Ralph loops run an AI coding agent in an autonomous loop until pre-defined completion criteria are satisfied. Instead of single-shot prompts, Ralph loops:

1. Send project prompt to agent
2. Intercept agent's attempt to stop
3. Inspect whether success criteria are met
4. If not, re-feed prompt with updated context
5. Loop until tests pass or completion tag detected

This represents a DIY [Stage 7-8](./gastown.md#yegges-8-stages-of-developer-agent-evolution) approach - simpler than Gas Town but achieving sustained autonomous execution.

## Managed Agent Solutions (MAS)

The cloud providers are building platform-level orchestration:

| Platform | Key Feature | Stage |
|----------|-------------|-------|
| **Azure AI Foundry** + Microsoft Agent Framework | Managed agent runtime with enterprise controls | Platform Stage 8 |
| **Google Vertex AI Agent Builder** + ADK | Agent development kit with managed deployment | Platform Stage 8 |
| **Amazon Bedrock AgentCore** | Multi-agent orchestration with guardrails | Platform Stage 8 |
| **OpenAI Agents SDK** | Cross-cloud agent framework | Framework Stage 8 |

These represent the "managed path" to Stage 8 - instead of building your own orchestrator from scratch, use a cloud provider's pre-built orchestration infrastructure.

## Patterns Across Emerging Systems

### Convergent Design Patterns

1. **Git as coordination layer**: Nearly all systems use git for state management, isolation (worktrees), and coordination (branch-per-task)

2. **DAG-based task decomposition**: Dependency-aware task graphs appear in [Copilot Fleet](./copilot-fleet-mode.md) (SQLite), [Claude Agent Teams](./claude-agent-teams.md) (JSON), [Gas Town](./gastown.md) (Beads), and AOrchestra

3. **Scenario-based validation**: Moving from boolean tests to probabilistic satisfaction scoring ([StrongDM](./strongdm-software-factory.md), AI21 Maestro)

4. **Provider-agnostic interfaces**: Orchestral, Amp, and the Copilot SDK all abstract away model-specific APIs

5. **Memory as a first-class concern**: Copilot cross-agent memory, Gas Town Beads, StrongDM cxdb, Amp threads

### Divergent Approaches

1. **Human involvement spectrum**: From full oversight (Claude Agent Teams plan approval) to zero code review (StrongDM Dark Factory)

2. **Orchestration granularity**: From fine-grained (Gas Town's 6+ agent roles per rig) to coarse (Devin's single autonomous agent)

3. **State persistence**: Session-scoped (Claude Agent Teams, Copilot Fleet) vs. persistent across sessions (Gas Town Beads, StrongDM cxdb)

## Related Reports

- [Gas Town](./gastown.md) - Custom orchestrator reference
- [Claude Agent Teams](./claude-agent-teams.md) - Platform-native teams
- [GitHub Copilot Fleet Mode](./copilot-fleet-mode.md) - GitHub ecosystem
- [OpenAI Codex App](./openai-codex-app.md) - Desktop orchestration
- [StrongDM Software Factory](./strongdm-software-factory.md) - Dark Factory
- [Stage 8 Approaches Deep-Dive](./stage-8-approaches.md)
- [Executive Summary](./README.md)

## Sources

1. [Amp Owner's Manual](https://ampcode.com/manual) - Sourcegraph, 2026
2. [Devin (Cognition)](https://rywalker.com/research/devin-cognition) - Ry Walker Research, Feb 9, 2026
3. [AOrchestra: Automating Sub-Agent Creation](https://arxiv.org/abs/2601.02577) - arXiv, Feb 3, 2026
4. [MegaFlow: Large-Scale Distributed Orchestration](https://arxiv.org/abs/2601.07526) - arXiv, Jan 12, 2026
5. [Top AI Coding Trends for 2026](https://beyond.addy.ie/2026-trends/) - Addy Osmani, 2026
6. [The 2026 Guide to Coding CLI Tools: 15 AI Agents Compared](https://www.tembo.io/blog/coding-cli-tools-comparison) - Tembo, Feb 6, 2026
7. [Agent Builders Guide 2026](https://www.ml6.eu/en/blog/agent-builders-guide-2026-managed-vs-custom-ai-agent-solutions) - ML6, Feb 4, 2026
8. [Cadence ChipStack AI Super Agent](https://www.cadence.com/en_US/home/company/newsroom/press-releases/pr/2026/cadence-unleashes-chipstack-ai-super-agent-pioneering-a-new.html) - Feb 10, 2026
