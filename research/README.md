# Agentic Orchestration Systems: Research Report

> **Date**: February 12, 2026 | **Author**: Research compiled for Anokye Labs
> **Scope**: Multi-agent coding orchestration systems announced January-February 2026

---

## Executive Summary

The first six weeks of 2026 have produced a Cambrian explosion in multi-agent coding orchestration. What was theoretical in late 2025 is now shipping in production: Anthropic launched [Agent Teams](./claude-agent-teams.md) with Opus 4.6 (Feb 5), GitHub shipped [Fleet Mode](./copilot-fleet-mode.md) for Copilot CLI (Feb 5), OpenAI released the [Codex App](./openai-codex-app.md) desktop command center (Feb 2), StrongDM published their [Software Factory](./strongdm-software-factory.md) manifesto (Feb 6), and Steve Yegge's [Gas Town](./gastown.md) has catalyzed the entire conversation since January 1.

The common thread: **the single-agent paradigm is over**. Every major platform now supports parallel agent execution. The differentiation is in *how* they coordinate, *what* the human controls, and *where* the quality gates live.

### The Stage 8 Moment

Steve Yegge's [8-stage model](./gastown.md#yegges-8-stages-of-developer-agent-evolution) of developer-agent evolution has become the de facto framework for this conversation. Stage 8 - "Building your own orchestrator" - is where the frontier teams now operate. Six distinct approaches have emerged, each making different bets on the human-agent boundary:

| Approach | System | Human Role | Coordination Model |
|----------|--------|------------|-------------------|
| Custom hierarchical orchestrator | [Gas Town](./gastown.md) | Product manager, factory operator | Named agent hierarchy (Mayor > Witness > Polecats) |
| Platform-native agent teams | [Claude Agent Teams](./claude-agent-teams.md) | Team architect, lead reviewer | Peer-to-peer messaging + shared task list |
| Non-interactive software factory | [StrongDM Factory](./strongdm-software-factory.md) | Spec author, scenario curator | No coordination (isolated pipeline stages) |
| Desktop multi-agent command center | [OpenAI Codex App](./openai-codex-app.md) | Project manager in GUI | Per-project parallelism + Skills |
| IDE-integrated parallel dispatch | [Copilot Fleet Mode](./copilot-fleet-mode.md) | Developer in CLI | SQLite dependency-aware dispatch |
| Autonomous agent-as-service | [Devin](./emerging-systems.md#devin-cognition) | Task submitter, PR reviewer | Black box (single autonomous agent) |

See the [Stage 8 Approaches Deep-Dive](./stage-8-approaches.md) for detailed analysis.

### The Key Insight: Specification Is the New Bottleneck

Every Stage 8 system converges on the same discovery: **when execution is automated, specification quality becomes the limiting factor**. Maggie Appleton, analyzing Gas Town: "Design becomes the limiting factor: imagining what you want to create and then figuring out all the gnarly little details." StrongDM codified this by eliminating code from the human workflow entirely, leaving only specs and scenarios.

This has direct implications for Omanfo's architecture, which already treats specification (issue hierarchies, plan materialization, SKILL.md) as the primary human contribution.

### The Validation Revolution

The most consequential shift across these systems is in how quality is ensured:

| Era | Validation | Success Metric |
|-----|-----------|----------------|
| Pre-agent | Human code review | Subjective judgment |
| Early agent | Automated tests + human review | Boolean pass/fail |
| **Stage 8** | **Scenarios + satisfaction scoring + digital twins** | **Probabilistic satisfaction** |

StrongDM's move from tests to scenarios, from pass/fail to satisfaction scoring, and from live services to Digital Twin Universes represents the furthest evolution. But every system is moving in this direction - Claude Agent Teams uses hooks for quality gates, Gas Town has a Refinery merge queue, and Copilot Fleet leverages cross-agent memory to accumulate validation knowledge.

### Universal Design Patterns

Five patterns appear in every Stage 8 system surveyed:

1. **Work decomposition as DAG**: All systems model tasks as dependency-aware directed acyclic graphs (Beads, SQLite, JSON, DOT syntax, GitHub sub-issues)

2. **Autonomous work pickup**: Agents query for ready work and self-assign (Gas Town's GUPP, Claude Agent Teams' TaskList, Omanfo's `Get-ReadyIssues`)

3. **Git as coordination backbone**: Branch-per-task isolation, merge queues as serialization points, git-backed state for persistence

4. **Layered quality gates**: Multiple validation layers catching different failure modes (monitoring > merge queue > main branch)

5. **Progressive trust delegation**: Systems allow varying levels of human oversight, from full plan approval to zero code review

### The Two Paths Forward

Futurum Group analyst Mitch Ashley identifies two parallel paths forming in agent-driven development:

1. **Multi-agent execution** (Gas Town, Claude Agent Teams, Copilot Fleet): Coordination and parallelism are primary. Communication between agents matters. Human orchestrates.

2. **Intent-first structuring** (StrongDM Factory): Specifications and constraints shape how agents act. Coordination is implicit in the spec, not explicit between agents. Human specifies.

These paths are not mutually exclusive. The most mature systems will likely combine both - structured specifications driving coordinated multi-agent execution.

## Report Index

### System-Specific Reports

| Report | System | Key Innovation |
|--------|--------|---------------|
| [Gas Town](./gastown.md) | Steve Yegge's orchestrator | Two-tier agent hierarchy, GUPP, Beads, 20-30 agent management |
| [Claude Agent Teams](./claude-agent-teams.md) | Anthropic's Opus 4.6 feature | Peer-to-peer teams, 16-agent C compiler, shared task list |
| [Copilot Fleet Mode](./copilot-fleet-mode.md) | GitHub's parallel dispatch | SQLite task DB, ACP protocol, cross-agent memory |
| [StrongDM Software Factory](./strongdm-software-factory.md) | StrongDM's Dark Factory | NLSpecs, Digital Twin Universe, zero human code review |
| [OpenAI Codex App](./openai-codex-app.md) | OpenAI's desktop app | GUI command center, Skills, worktree isolation, scheduling |
| [Emerging Systems](./emerging-systems.md) | Devin, Amp, AOrchestra, MegaFlow, etc. | Diverse approaches from autonomous agents to research frameworks |

### Cross-Cutting Analysis

| Report | Focus |
|--------|-------|
| [Stage 8 Approaches Deep-Dive](./stage-8-approaches.md) | In-depth comparison of all six Stage 8 approaches, design patterns, implications for Omanfo |

## Relevance to Omanfo / Anokye Labs

Omanfo's architecture already implements several Stage 8 patterns at a mature level:

| Capability | Omanfo Status | Stage 8 Comparison |
|-----------|--------------|-------------------|
| Work decomposition DAG | Mature (Epic > Feature > Task + blocking refs) | On par with all systems |
| Autonomous work pickup | Mature (`Get-ReadyIssues` + self-selection) | Matches Gas Town GUPP pattern |
| Quality gates | Mature (thread severity + PR completion + health) | Comparable to all systems |
| Git-backed coordination | Mature (GitHub Issues + GraphQL-first) | On par, with stronger API integration |
| Agent dispatch/parallelism | Gap | Not yet implemented |
| Cross-session memory | Different (zero-footprint) | Trade-off: simplicity vs. accumulation |
| Scenario-based validation | Partial (10 evaluations) | Below StrongDM's level |
| Digital Twin Universe | Gap | High-value opportunity |

### Recommended Next Steps

1. **Evaluate Copilot Fleet + ACP integration**: The Agent Client Protocol could enable Omanfo scripts to orchestrate parallel Copilot agents, bridging the dispatch gap.

2. **Expand scenario-based validation**: Adopt StrongDM's scenario + satisfaction pattern to move Omanfo's evaluation framework from 10 scenarios toward comprehensive coverage.

3. **Investigate cross-agent memory**: Copilot's memory system or a Beads-like approach could complement Omanfo's zero-footprint design.

4. **Consider Digital Twin Universe**: Building behavioral clones of the GitHub API for high-volume E2E testing would dramatically improve test coverage.

5. **Track Claude Agent Teams maturity**: As the feature moves from experimental to stable, it could become a natural execution layer for Omanfo-planned work.

## Taxonomy: Yegge's 8 Stages vs. Shapiro's 5 Levels

Two complementary frameworks for understanding the evolution:

| Yegge Stage | Shapiro Level | Description |
|-------------|--------------|-------------|
| 1-2 | 0: Spicy Autocomplete | Basic completions, copy-paste |
| 3 | 1: Coding Intern | AI writes boilerplate, full review |
| 4 | 2: Junior Developer | Pair programming, reviewing every line |
| 5 | 3: Developer | Most code AI-generated, human reviews |
| 6-7 | 4: Engineering Team | Human as manager, agents work |
| **8** | **5: Dark Factory** | **Custom orchestrator / specs-only** |

## Methodology

Research conducted February 12, 2026 using:

- **Web search**: Exa API for article discovery and content retrieval
- **DeepWiki**: AI-powered analysis of [steveyegge/gastown](https://deepwiki.com/steveyegge/gastown) and [strongdm/attractor](https://deepwiki.com/strongdm/attractor) repositories
- **Primary sources**: Original blog posts, documentation, and announcements
- **Secondary analysis**: Community reviews (Maggie Appleton, Simon Willison, Mike Mason, Stanford CodeX)
- **Academic sources**: arXiv papers (AOrchestra, MegaFlow, Orchestral AI)
