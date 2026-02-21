# Gas Town: Steve Yegge's Multi-Agent Orchestration Framework

> **Published**: January 1, 2026 | **Author**: Steve Yegge | **Status**: Open-source, v0.3+
> **Source**: [Welcome to Gas Town](https://steve-yegge.medium.com/welcome-to-gas-town-4f25ee16dd04)

---

## Overview

Gas Town is a multi-agent AI workspace orchestration system built by Steve Yegge (ex-Amazon, ex-Google, ex-Sourcegraph) that manages 20-30 parallel AI coding agents (primarily Claude Code instances) through a structured hierarchy of roles, workflows, and persistent state management. Written in Go (~189k LOC) and built on top of the [Beads](https://github.com/steveyegge/beads) issue-tracking system, Gas Town represents the most ambitious publicly documented attempt at what Yegge calls **Stage 8** of the developer-agent evolution: building your own orchestrator.

Gas Town is Yegge's fourth complete orchestrator of 2025. It is 100% vibe-coded (Yegge has never read the code), uses tmux as its primary UI, and is explicitly designed for developers already comfortable running 10+ agents in parallel.

## Yegge's 8 Stages of Developer-Agent Evolution

A foundational framework introduced in the Gas Town article:

| Stage | Description | Human Role |
|-------|-------------|------------|
| 1 | Zero or near-zero AI; maybe code completions | Traditional developer |
| 2 | Coding agent in IDE, permissions turned on | Approver |
| 3 | Agent in IDE, YOLO mode; trust goes up | Occasional reviewer |
| 4 | In IDE, wide agent; code is just for diffs | Diff reviewer |
| 5 | CLI, single agent, YOLO; diffs scroll by | Monitor |
| 6 | CLI, multi-agent, YOLO; 3-5 parallel instances | Coordinator |
| 7 | 10+ agents, hand-managed; pushing limits | Overwhelmed coordinator |
| **8** | **Building your own orchestrator** | **Factory operator** |

Gas Town targets Stage 8 developers. See [Stage 8 Deep-Dive](./stage-8-approaches.md) for cross-system analysis.

## Architecture

Gas Town operates as a two-tier system with town-level coordination and rig-level operations, comparable in spirit to Kubernetes (container orchestration) and Temporal (durable workflow execution), but specialized for AI agent management.

### Environment Hierarchy

- **Town** (`~/gt/`): The management headquarters coordinating all workers across multiple Rigs. Houses town-level agents (Mayor, Deacon).
- **Rig**: A project-specific Git repository under Gas Town management. Each Rig has its own Polecats, Refinery, Witness, and Crew members. This is where actual development work happens.

### Agent Roles

#### Town-Level Agents

| Role | Function |
|------|----------|
| **Mayor** | Chief-of-staff agent. Initiates Convoys, coordinates cross-rig work distribution, dispatches work via `gt sling`, and notifies users of important events. Global visibility across all Rigs. |
| **Deacon** | Daemon beacon running continuous Patrol cycles. Ensures worker activity, monitors system health, triggers recovery when agents become unresponsive. The system's watchdog. |
| **Dogs** | The Deacon's crew of maintenance agents for automated housekeeping tasks. |

#### Rig-Level Agents

| Role | Function |
|------|----------|
| **Polecats** | Ephemeral worker agents on feature branches. Execute individual tasks. Spawned with worktrees, destroyed after work completes. |
| **Crew** | Persistent worker agents with independent clones for long-running work that survives restarts. |
| **Witness** | Oversight agent monitoring Polecats within a rig. Checks for stuck work, crashes, self-cleaning failures. Nudges stuck polecats or escalates to Mayor. |
| **Refinery** | Manages the merge queue for each rig. Validates and merges branches sequentially, rebasing polecat work to main. The quality gate. |

### Core Operational Principles

- **GUPP** (Gas Town Universal Propulsion Principle): "If you have work on your hook, YOU RUN IT." Agents immediately execute assigned work without waiting for confirmation. The heartbeat of autonomous operation.
- **MEOW** (Molecular Expression of Work): Breaking large goals into detailed instructions through Beads, Epics, Formulas, and Molecules. Ensures work decomposition into trackable atomic units.
- **NDI** (Nondeterministic Idempotence): Ensuring useful outcomes through orchestration of potentially unreliable processes. Persistent Beads and oversight agents guarantee eventual workflow completion.
- **ZFC** (Zero-Footprint Computing): State is derived from authoritative sources (tmux sessions, beads databases, git worktrees) rather than maintained in separate state files.

### Work Tracking Primitives

| Primitive | Persistence | Description |
|-----------|-------------|-------------|
| **Beads** | Persistent | Git-backed atomic work units stored in JSONL format. Statuses: `open` -> `hooked` -> `in_progress` -> `closed`. The fundamental unit of work. |
| **Hooks** | Persistent | Special pinned Beads for each agent. The primary work queue. GUPP dictates: if work appears on your Hook, you must run it. |
| **Formulas** | Persistent | TOML-based workflow source templates defining reusable patterns for common operations. |
| **Molecules** | Durable | Chained Bead workflows representing multi-step processes. Survive agent restarts. |
| **Wisps** | Ephemeral | Transient Beads destroyed after runs. Used for patrol cycles and one-off operations. |
| **Convoys** | Persistent | Work-order bundles wrapping related Beads. Group related tasks for assignment to multiple workers. |

### Interaction Flow

```
Human -> Mayor (gt sling) -> Polecat spawned with hooked work
                                |
                           Polecat executes (GUPP)
                                |
                           Polecat completes (gt done)
                                |
                           Witness detects merge-request
                                |
                           Refinery processes merge queue
                                |
                           Work lands on main
```

### Health Monitoring

Four-layer system:

1. **Mechanical daemon checks** - Low-level process monitoring
2. **AI-based Boot triage** - Intelligent failure classification
3. **Deacon town-level patrol** - Cross-rig health assessment
4. **Witness rig-level patrol** - Per-project agent monitoring

### Git Architecture

Gas Town uses a shared bare repository architecture per rig:

- **Mayor**: Independent clone for reading code
- **Refinery**: Worktree on main branch for merging
- **Polecats**: Ephemeral worktrees on feature branches
- **Crew**: Independent clones for persistent work

## Communication Mechanisms

- **Slinging** (`gt sling`): Dispatching work to agents by placing it on their Hook
- **Nudging** (`gt nudge`): Real-time messages between agents for immediate communication
- **Mail** (`gt mail`): Asynchronous communication and instruction handoff
- **Beads**: Persistent, git-backed state that all agents can query

Gas Town adopted Jeffrey Emanuel's discovery (author of MCP Agent Mail) that combining Mail with Beads creates an "agent village" where agents naturally collaborate, divide up work, and farm it out without explicit training.

## Economics and Scale

- Gas Town is "expensive as hell" - requires multiple Claude Code accounts
- Yegge merged 100+ PRs from ~50 contributors in 12 days, adding 44k lines of code no human looked at
- Total codebase grew to 189k lines of Go in 2,684 commits since Dec 15, 2025
- Throughput-focused: "Some bugs get fixed 2 or 3 times, someone has to pick the winner"
- The human role shifts to Product Manager; Gas Town is an "Idea Compiler"

## Critical Analysis

### Strengths

- Most ambitious publicly documented multi-agent orchestration attempt
- Demonstrates that Stage 8 is achievable today
- Novel primitives (GUPP, MEOW, NDI) for autonomous agent coordination
- Git-backed persistent state solves the "50 First Dates" memory problem
- Hierarchical supervision (Mayor > Witness > Polecats) prevents runaway agents

### Weaknesses (per Maggie Appleton and community feedback)

- "Vibe designed" - no upfront design, concepts accumulated ad-hoc
- Overwhelming number of overlapping concepts and metaphors
- Expensive: thousands of dollars/month in API costs
- Requires Stage 7+ proficiency to even begin using
- Tmux-based UI is a high barrier to entry
- Core insights may be extracted into simpler tools rather than Gas Town being adopted wholesale

## Relevance to Omanfo

Gas Town's architecture mirrors several Omanfo patterns:

| Gas Town | Omanfo | Pattern |
|----------|--------|---------|
| Beads (JSONL in git) | GitHub Issues as Adwoma | Git-backed work tracking as source of truth |
| GUPP (auto-execute hooked work) | Agent self-selection via `Get-ReadyIssues` | Autonomous work pickup |
| Witness oversight | `Invoke-DagHealthCheck` / Sankofa patrols | Automated health monitoring |
| Refinery merge queue | `Invoke-PRCompletion` | Quality-gated merging |
| Mayor work dispatch | Okyeame guided planning | Hierarchical task decomposition |
| ZFC (zero-footprint) | Zero-footprint computing via live API queries | No local state maintenance |

## Related Reports

- [Stage 8 Approaches Deep-Dive](./stage-8-approaches.md)
- [StrongDM Software Factory](./strongdm-software-factory.md) - Alternative "Dark Factory" approach
- [Claude Agent Teams](./claude-agent-teams.md) - Platform-native multi-agent
- [GitHub Copilot Fleet Mode](./copilot-fleet-mode.md) - IDE-integrated parallelism
- [OpenAI Codex App](./openai-codex-app.md) - Desktop multi-agent orchestration
- [Executive Summary](./README.md)

## Sources

1. [Welcome to Gas Town](https://steve-yegge.medium.com/welcome-to-gas-town-4f25ee16dd04) - Steve Yegge, Jan 1, 2026
2. [The Future of Coding Agents](https://steve-yegge.medium.com/the-future-of-coding-agents-e9451a84207c) - Steve Yegge, Jan 5, 2026
3. [Gas Town Emergency User Manual](https://steve-yegge.medium.com/gas-town-emergency-user-manual-cf0e4556d74b) - Steve Yegge, Jan 13, 2026
4. [Gas Town's Agent Patterns, Design Bottlenecks, and Vibecoding at Scale](https://maggieappleton.com/gastown) - Maggie Appleton, Jan 23, 2026
5. [Yegge's Developer-Agent Evolution Model](https://justin.abrah.ms/blog/2026-01-08-yegge-s-developer-agent-evolution-model.html) - Justin Abrahms, Jan 8, 2026
6. [Gas Town Glossary](https://docs.gastownhall.ai/glossary/) - Gas Town Docs
7. [AI Coding Agents in 2026: Coherence Through Orchestration](https://mikemason.ca/writing/ai-coding-agents-jan-2026/) - Mike Mason, Jan 22, 2026
8. DeepWiki analysis of [steveyegge/gastown](https://deepwiki.com/steveyegge/gastown)
