# GitHub Copilot Fleet Mode: IDE-Integrated Parallel Agent Dispatch

> **Announced**: February 5, 2026 | **Status**: Experimental (`/experimental` mode in Copilot CLI)
> **Source**: [Evan Boyle LinkedIn announcement](https://www.linkedin.com/posts/evan-boyle-107a1445_new-in-experimental-mode-in-copilot-cli-activity-7425264653586403328-DarZ)

---

## Overview

Fleet Mode (internally "Fleets") is GitHub Copilot CLI's experimental multi-agent feature, announced February 5, 2026. It enables developers to dispatch parallel subagents to implement a plan, using a SQLite database per session to model dependency-aware tasks and TODOs. Fleet Mode sits within GitHub's broader **Agent HQ** vision - making agents native to the GitHub development flow.

Fleet Mode is accessed via the `/fleet` slash command in Copilot CLI's experimental mode, positioning it as the GitHub ecosystem's answer to [Claude Agent Teams](./claude-agent-teams.md) and [Gas Town](./gastown.md).

## Context: GitHub Agent HQ

Fleet Mode is part of GitHub's larger **Agent HQ** initiative announced at Universe 2025 (October 28, 2025), which transforms GitHub into an open ecosystem uniting every agent on a single platform:

- **Coding agents** from Anthropic, OpenAI, Google, Cognition, xAI available directly in GitHub
- **Agent Client Protocol (ACP)** support in Copilot CLI (public preview, January 28, 2026) - industry-standard protocol for agent-client communication
- **Cross-agent memory** - Agents remember and learn across coding, code review, and security workflows
- **Copilot SDK** (technical preview, January 22, 2026) - Embed the Copilot agentic core into any application

## Architecture

### Core Mechanism

```
Developer -> /fleet command -> Plan generation
                                    |
                            SQLite task database
                                    |
                     Dependency-aware parallel dispatch
                            /       |       \
                     Subagent   Subagent   Subagent
                        |          |          |
                     Complete   Complete   Complete
                        \          |          /
                         Merge results back
```

### Key Components

| Component | Function |
|-----------|----------|
| **Plan Generator** | Decomposes the user's intent into dependency-aware tasks |
| **SQLite Task DB** | Per-session database tracking todos with dependencies, status, and ownership |
| **Parallel Subagents** | Independent Copilot instances executing non-blocking tasks simultaneously |
| **Dependency Resolver** | Ensures tasks execute in correct order based on dependency graph |

### SQLite-Based Coordination

The "secret sauce" per Evan Boyle: a SQLite database per session that models:

- Task definitions with natural language descriptions
- Dependency relationships between tasks (DAG structure)
- Task status (pending, in_progress, completed, failed)
- Agent assignment and completion tracking

This approach contrasts with [Gas Town's](./gastown.md) git-backed JSONL (Beads) and [Claude Agent Teams'](./claude-agent-teams.md) JSON file-locking, offering:

- **ACID transactions** for task state changes
- **Efficient querying** for ready tasks (no file system scanning)
- **Single-file portability** of session state

## ACP: Agent Client Protocol

Fleet Mode benefits from Copilot CLI's ACP support (public preview January 28, 2026):

```bash
# Start in ACP mode via stdio
copilot --acp

# Connect via TCP
copilot --acp --port 8080
```

ACP clients can:
- Initialize connections and discover agent capabilities
- Create isolated sessions with custom working directories
- Send prompts with text, images, and context resources
- Receive streaming updates as the agent works
- Respond to permission requests for tool execution
- Cancel operations and manage session lifecycle

This enables Fleet Mode to be orchestrated by external systems, positioning it as both a standalone feature and a building block for [Stage 8 orchestrators](./stage-8-approaches.md).

## Cross-Agent Memory System

A key differentiator in GitHub's approach (public preview, January 15, 2026):

- **Learning across workflows**: If Copilot coding agent learns how a repo handles database connections while fixing a security vulnerability, Copilot code review can use that knowledge to spot inconsistent patterns in future PRs
- **Synchronized files**: If code review notices certain files must stay synchronized, coding agent will automatically update them together
- **Progressive accumulation**: Each interaction teaches Copilot more about codebase conventions

This persistent memory addresses the same "50 First Dates" problem that [Gas Town's Beads](./gastown.md) and [StrongDM's cxdb](./strongdm-software-factory.md) solve, but at the platform level.

## Copilot SDK: Programmable Agent Core

The Copilot SDK (technical preview, January 22, 2026) allows embedding the same agentic loop that powers Fleet Mode into any application:

- **Languages**: Node.js, Python, Go, .NET
- **Capabilities**: Multi-model support, custom tool definitions, MCP server integration, GitHub authentication, real-time streaming
- **Use case**: Build custom orchestrators on top of the production-tested Copilot execution loop

This is significant for [Stage 8](./stage-8-approaches.md) because it offers a middle ground: instead of building an orchestrator from scratch like [Gas Town](./gastown.md), developers can compose one from the Copilot SDK.

## Comparison to Other Multi-Agent Systems

| Dimension | Copilot Fleet | [Claude Agent Teams](./claude-agent-teams.md) | [Gas Town](./gastown.md) |
|-----------|--------------|-------------------|----------|
| **Task Tracking** | SQLite per session | JSON files with file-locking | Git-backed JSONL (Beads) |
| **Coordination** | Dependency-aware dispatch | Peer messaging + shared queue | Mail + nudge + beads |
| **Agent Identity** | Anonymous subagents | Named teammates with roles | Named roles (Polecat, Crew) |
| **Persistence** | Session-scoped | Session-scoped | Cross-session (git-backed) |
| **Platform Integration** | Native GitHub (PRs, Issues, Actions) | Claude Code ecosystem | Standalone + Beads |
| **Memory** | Cross-agent memory system | Per-session context | Beads + Formulas |
| **External Orchestration** | ACP protocol | N/A (native only) | CLI commands (gt) |
| **Human Oversight** | PR review, permissions | Plan approval, delegate mode | Witness, Refinery |

## Relevance to Omanfo

GitHub Copilot Fleet Mode aligns with several Omanfo architectural patterns:

| Fleet Mode | Omanfo | Pattern |
|------------|--------|---------|
| SQLite task DB with dependencies | DAG-based issue hierarchy | Dependency-aware task management |
| `/fleet` plan dispatch | Plan Materialization via `Invoke-PlanMaterialization` | Intent-to-tasks decomposition |
| Cross-agent memory | Zero-footprint computing via live API queries | Accumulated knowledge |
| ACP protocol | GraphQL-first operations | Standardized agent communication |
| Copilot SDK | Copilot CLI + Skills framework | Programmable agent composition |

The ACP protocol is particularly relevant: it could enable Omanfo's scripts to orchestrate Copilot agents programmatically, creating a bridge between Omanfo's issue-driven workflow and Fleet Mode's parallel execution.

## Related Reports

- [Claude Agent Teams](./claude-agent-teams.md) - Anthropic's competing approach
- [Gas Town](./gastown.md) - Custom-built orchestrator comparison
- [OpenAI Codex App](./openai-codex-app.md) - OpenAI's desktop alternative
- [Stage 8 Approaches Deep-Dive](./stage-8-approaches.md)
- [Executive Summary](./README.md)

## Sources

1. [Introducing Fleets in Copilot CLI](https://www.linkedin.com/posts/evan-boyle-107a1445_new-in-experimental-mode-in-copilot-cli-activity-7425264653586403328-DarZ) - Evan Boyle, Feb 5, 2026
2. [Introducing Agent HQ](https://github.blog/news-insights/company-news/welcome-home-agents/) - GitHub Blog, Oct 28, 2025
3. [ACP support in Copilot CLI](https://github.blog/changelog/2026-01-28-acp-support-in-copilot-cli-is-now-in-public-preview) - GitHub Changelog, Jan 28, 2026
4. [Building an agentic memory system for GitHub Copilot](https://github.blog/2026-01-09-building-an-agentic-memory-system-for-github-copilot) - GitHub Blog, Jan 15, 2026
5. [Build an agent into any app with the GitHub Copilot SDK](https://github.blog/news-insights/company-news/build-an-agent-into-any-app-with-the-github-copilot-sdk/) - GitHub Blog, Jan 22, 2026
6. [Managing Copilot coding agents](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/manage-agents) - GitHub Docs
7. [Building AI agents with the GitHub Copilot SDK](https://www.infoworld.com/article/4125776/building-ai-agents-with-the-github-copilot-sdk.html) - InfoWorld, Feb 3, 2026
