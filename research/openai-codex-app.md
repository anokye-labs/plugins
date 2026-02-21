# OpenAI Codex App: Desktop Multi-Agent Command Center

> **Released**: February 2, 2026 | **Status**: Generally available (macOS; Windows coming soon)
> **Source**: [Introducing the Codex app](https://openai.com/index/introducing-the-codex-app/)

---

## Overview

OpenAI's Codex App is a macOS desktop application that serves as a "command center for agents," allowing developers to manage parallel AI workflows across projects, review automated changes, and run long-running tasks in the background. Launched February 2, 2026 and given a Super Bowl ad slot, the Codex App centralizes the multi-agent experience that previously required juggling terminal sessions - directly addressing [Stage 6-7](./gastown.md#yegges-8-stages-of-developer-agent-evolution) workflow pain points.

Key adoption metrics since the GPT-5.2-Codex model release (December 2025):
- Overall Codex usage doubled
- 1,000,000+ developers used it in the past month
- Initially available across all ChatGPT tiers (Free through Enterprise)

OpenAI's Dominik Kundel: "I've completely migrated to the Codex app and now do 99.9% of my work with the Codex app."

## Architecture

### The Agent Loop

OpenAI published a detailed technical breakdown of the [Codex agent loop](https://openai.com/index/unrolling-the-codex-agent-loop/) (January 23, 2026), the core logic orchestrating interaction between user, model, and tools:

```
User prompt -> System prompt assembly -> Model inference
                                              |
                                     Tool call detected?
                                        /          \
                                      Yes           No
                                       |             |
                                  Execute tool    Return response
                                       |
                                  Tool result
                                       |
                              Append to context
                                       |
                              Loop (next inference)
```

The agent loop uses the **Responses API** (replacing the older Completions/Chat APIs) for:
- Streaming tool calls and responses
- Managing conversation state across turns
- Handling parallel tool execution
- Built-in safety boundaries

### Multi-Project Management

The Codex App introduces a project-centric model:

| Feature | Description |
|---------|-------------|
| **Project sidebar** | List of all active projects with concurrent agent sessions |
| **Worktree version control** | Git worktree-based isolation for parallel changes |
| **Background tasks** | Long-running agent work continues without blocking the UI |
| **Diff review** | Inline diff viewer for reviewing agent-generated changes |
| **Branch management** | Create branches, commit, and manage PRs from the app |

### Skills System

Skills are reusable, configurable agent capabilities:

| Skill Type | Description |
|------------|-------------|
| **Built-in** | Pre-packaged capabilities (code generation, testing, documentation) |
| **Custom** | User-defined skills with specific instructions and tool access |
| **Scheduled** | Automated execution by day of week, time, and interval |
| **Shared** | Skills published for team reuse |

Skills can be composed into pipelines, enabling a form of workflow orchestration within the app.

### Worktree-Based Isolation

The Codex App uses Git worktrees to enable parallel agent work on the same repository:

- Each agent task gets its own worktree (separate working directory, shared .git)
- No merge conflicts between concurrent agent sessions
- Changes can be reviewed, committed, or discarded independently
- Multiple agents can work on different features simultaneously

This mirrors [Gas Town's](./gastown.md) rig-level git architecture (Polecats get ephemeral worktrees on feature branches) but packages it in a GUI.

## Multi-Agent Orchestration

### Current Capabilities

The Codex App supports:
- Running agents across multiple projects simultaneously
- Background execution with progress monitoring
- Per-project agent configuration
- Voice input for natural language task assignment

### Codex CLI Integration

The desktop app shares infrastructure with the Codex CLI, which has its own multi-agent capabilities:

- **Multi-agent/collab mode**: Orchestrator dispatches work to sub-agents
- **Known issues**: Orchestrator frequently interrupts sub-agents, reducing effectiveness (see [GitHub issue #9723](https://github.com/openai/codex/issues/9723))
- **Active development**: Plans for improved orchestrator prompts and better sub-agent autonomy

### Codex Cloud

For headless/background execution:
- Sandboxed environments for agent work
- No local resource consumption
- Integration with GitHub for PR creation

## Comparison to Other Systems

| Dimension | Codex App | [Claude Agent Teams](./claude-agent-teams.md) | [Gas Town](./gastown.md) | [Copilot Fleet](./copilot-fleet-mode.md) |
|-----------|-----------|-------------------|----------|---------------|
| **Interface** | GUI desktop app | CLI terminal | tmux terminal | CLI (`/fleet`) |
| **Multi-agent** | Per-project parallelism | Peer-to-peer teams | 20-30 managed agents | Parallel subagents |
| **Isolation** | Git worktrees | Separate sessions | Bare repo + worktrees | Dependency-aware dispatch |
| **Task tracking** | Project sidebar | Shared task list | Beads (JSONL) | SQLite per session |
| **Scheduling** | Built-in cron-like Skills | Manual | GUPP (auto-execute) | Manual |
| **Model** | GPT-5.2-Codex | Opus 4.6 | Model-agnostic (primarily Claude) | Multi-model |
| **Voice input** | Yes | No | No | No |
| **Cost model** | ChatGPT subscription tiers | Per-token | Per-token (multiple accounts) | GitHub Copilot subscription |

## The Two Paths of Agent Development

Futurum Group analyst Mitch Ashley ([February 5, 2026](https://futurumgroup.com/insights/agent-driven-development-two-paths-one-future/)) identifies the Codex App as establishing a baseline along two emerging paths:

1. **Multi-agent execution** (Codex App, Claude Agent Teams, Gas Town): Coordination and parallelism are primary. Agents work concurrently, communication between them matters.

2. **Intent-first structuring** ([StrongDM Factory](./strongdm-software-factory.md)): Specifications and constraints shape how agents act. Coordination is implicit in the spec, not explicit between agents.

The Codex App currently emphasizes path 1 but its Skills system hints at path 2 convergence.

## Relevance to Omanfo

| Codex App | Omanfo | Pattern |
|-----------|--------|---------|
| Git worktree isolation | Copilot agents in cloud sandboxes | Parallel work without conflicts |
| Skills system | Okyerema skill with 28 scripts | Reusable, composable agent capabilities |
| Scheduled Skills | Sankofa health patrols (GitHub Actions) | Automated recurring agent work |
| Project-centric model | Repository-centric workflow | Repo as unit of agent management |
| Diff review UI | PR review via `Get-ThreadSeverity` | Change verification before merge |

## Related Reports

- [Claude Agent Teams](./claude-agent-teams.md) - CLI-based alternative
- [GitHub Copilot Fleet Mode](./copilot-fleet-mode.md) - GitHub ecosystem approach
- [Gas Town](./gastown.md) - Custom orchestrator approach
- [StrongDM Software Factory](./strongdm-software-factory.md) - Non-interactive alternative
- [Stage 8 Approaches Deep-Dive](./stage-8-approaches.md)
- [Executive Summary](./README.md)

## Sources

1. [Introducing the Codex app](https://openai.com/index/introducing-the-codex-app/) - OpenAI, Feb 2, 2026
2. [Unrolling the Codex agent loop](https://openai.com/index/unrolling-the-codex-agent-loop/) - OpenAI Engineering, Jan 23, 2026
3. [OpenAI Codex App: A Guide to Multi-Agent AI Coding](https://intuitionlabs.ai/articles/openai-codex-app-ai-coding-agents) - IntuitionLabs, Feb 11, 2026
4. [Agent-Driven Development: Two Paths, One Future](https://futurumgroup.com/insights/agent-driven-development-two-paths-one-future/) - Futurum Group, Feb 5, 2026
5. [AI This Week: Multi-Agent Orchestration Becomes Reality](https://trewknowledge.com/2026/02/06/ai-this-week-multi-agent-orchestration-becomes-reality/) - Trew Knowledge, Feb 6, 2026
6. [OpenAI Codex CLI GitHub](https://github.com/openai/codex) - Open source repository
