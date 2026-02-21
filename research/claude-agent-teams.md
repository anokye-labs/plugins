# Claude Code Agent Teams: Anthropic's Multi-Agent Coordination

> **Released**: February 5, 2026 (with Opus 4.6) | **Status**: Experimental, feature-flagged
> **Source**: [Anthropic Opus 4.6 Announcement](https://www.anthropic.com/news/claude-opus-4-6)

---

## Overview

Agent Teams are the third tier of Claude Code's delegation hierarchy, shipped alongside Opus 4.6 on February 5, 2026. Where subagents are isolated workers that report back to a parent, Agent Teams are fully independent Claude Code sessions that coordinate through a shared task list and message each other directly. They represent Anthropic's platform-native answer to the multi-agent orchestration problem, targeting developers at [Stages 6-8](./gastown.md#yegges-8-stages-of-developer-agent-evolution) of Yegge's evolution model.

The landmark proof-of-concept: 16 parallel Opus 4.6 instances built a 100,000-line C compiler in Rust that compiles the Linux 6.9 kernel, achieving a 99% pass rate on GCC torture tests. Cost: $20,000 in API usage over two weeks.

## Claude Code's Delegation Hierarchy

| Tier | Mechanism | Communication | Best For |
|------|-----------|---------------|----------|
| **Direct execution** | Single session | N/A | Simple tasks |
| **Subagents** | Isolated workers within session | Report to parent only | Focused tasks where only result matters |
| **Agent Teams** | Independent sessions | Peer-to-peer messaging + shared task list | Complex work needing discussion and self-organization |

## Architecture

### Core Components

| Component | Role |
|-----------|------|
| **Team Lead** | Main session that spawns teammates, assigns work, synthesizes results |
| **Teammates** | Independent Claude instances with their own full context windows |
| **Task List** | Shared work queue with dependency tracking and file-locking claims |
| **Mailbox** | Peer-to-peer messaging system between all agents |

Configuration stored at `~/.claude/teams/{team-name}/config.json` and `~/.claude/tasks/{team-name}/`.

### Seven Primitives

The entire system runs on these tools:

1. **TeamCreate** - Initialize team namespace and config
2. **TaskCreate** - Define work units as JSON files on disk
3. **TaskUpdate** - Claim tasks, mark complete, set dependencies
4. **TaskList** - Discover available work
5. **Task** (with `team_name`) - Spawn a new teammate into the team
6. **SendMessage** - Direct messages, broadcasts, shutdown requests, plan approvals
7. **TeamDelete** - Cleanup after completion

Tasks flow through three states: `pending` > `in_progress` > `completed`. File locking prevents double-claims when multiple teammates grab work simultaneously.

### Coordination Mechanism

The C compiler proof-of-concept used a surprisingly simple coordination mechanism: **git-based task locking with no orchestration agent**. Key lesson from Anthropic's engineering team:

> "Claude will work autonomously to solve whatever problem I give it. So it's important that the task verifier is nearly perfect, otherwise Claude will solve the wrong problem."

This emphasis on **testing quality over agent sophistication** is a recurring theme across [Stage 8 approaches](./stage-8-approaches.md).

## Enabling Agent Teams

```json
// settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Then describe your team in natural language:

```
Create a team with 3 teammates to review the auth module:
one on security, one on performance, one on test coverage.
```

## Display Modes

- **In-process** (default): All teammates in your terminal. `Shift+Up/Down` to navigate, `Enter` to view, `Escape` to interrupt, `Ctrl+T` for task list.
- **Split panes**: Each teammate gets its own tmux or iTerm2 pane. Requires tmux or iTerm2 with `it2` CLI.

## Coordination Patterns

### Competing Hypotheses
Spawn 5 investigators for a bug, each testing a different theory. Have them actively try to disprove each other. The theory that survives cross-examination is likely the root cause.

### Parallel Review
Security, performance, and test coverage reviewers work the same PR simultaneously through different lenses. Lead synthesizes findings.

### Cross-Layer Features
Frontend, backend, and tests each owned by a different teammate. No file conflicts because each owns distinct paths.

### Plan-Then-Execute
Use plan mode (cheap) to design the approach, then hand the plan to a team for parallel execution (expensive but fast).

## Quality Controls

### Delegate Mode
Press `Shift+Tab` to restrict the lead to coordination-only tools. Prevents the lead from implementing tasks itself instead of delegating.

### Plan Approval
For risky work, require teammates to plan before implementing. Teammate stays read-only until the lead approves. Rejected plans get feedback and resubmission.

### Quality Gates via Hooks
- **TeammateIdle** - Runs when teammate is about to go idle. Exit code 2 sends feedback and keeps them working.
- **TaskCompleted** - Runs when task is being marked complete. Exit code 2 blocks completion with feedback.

## Token Economics

Each teammate requires a full context window:

| Configuration | Approximate Token Usage |
|---------------|------------------------|
| Solo session | ~200k tokens |
| Team of 3 | ~800k tokens |
| Team of 5 | ~1.2M+ tokens |
| C compiler (16 agents) | ~2B input tokens |

Mitigation strategies:
- Use Sonnet for teammates, Opus for the lead
- Plan cheaply first, execute in parallel second
- Size tasks at 5-6 per teammate for optimal throughput
- Kill the team as soon as work completes

## Limitations

- **Experimental** - Disabled by default, breaking changes possible
- **No session resumption** for in-process teammates after `/resume`
- **Task status can lag** - Teammates sometimes forget to mark tasks complete
- **One team per session** - Clean up before starting another
- **No nested teams** - Teammates cannot spawn their own teams
- **Lead is fixed** - Cannot transfer leadership
- **Permissions propagate** - All teammates inherit lead's permission mode at spawn
- **Split panes** need tmux or iTerm2 (not VS Code terminal, Windows Terminal, or Ghostty)

## Comparison to Other Systems

| Dimension | Claude Agent Teams | [Gas Town](./gastown.md) | [StrongDM Factory](./strongdm-software-factory.md) |
|-----------|-------------------|----------|------------------|
| **Orchestration** | Lead agent + task list | Mayor/Deacon hierarchy | Spec-driven pipeline |
| **Coordination** | Peer messaging + shared tasks | Beads + mail + nudge | No coordination (isolated runs) |
| **Human Role** | Team architect, lead reviewer | Product manager, factory operator | Spec author, scenario curator |
| **Agent Count** | 3-16 typical | 20-30 | Unlimited (non-interactive) |
| **State** | Local JSON files | Git-backed JSONL (Beads) | Git-backed specs + scenarios |
| **Quality Gate** | Hooks, plan approval | Refinery merge queue | Scenario satisfaction scoring |
| **Cost Model** | Linear with team size | Multiple API accounts | $1,000/day per engineer target |

## Relevance to Omanfo

Claude Agent Teams' architecture offers direct parallels:

| Agent Teams | Omanfo | Pattern |
|-------------|--------|---------|
| Shared task list with dependencies | DAG-based issue tracking | Dependency-aware work queues |
| File-locking task claims | `Get-ReadyIssues` with blocking refs | Race-condition-free work pickup |
| Quality gate hooks | `Get-ThreadSeverity` + `Invoke-PRCompletion` | Automated quality enforcement |
| Team lead synthesis | `Get-DagStatus` hierarchical view | Aggregated status reporting |
| Plan-then-execute pattern | Plan Materialization pipeline | Structured decomposition |

## Related Reports

- [Gas Town](./gastown.md) - Custom-built orchestrator approach
- [Stage 8 Approaches Deep-Dive](./stage-8-approaches.md)
- [GitHub Copilot Fleet Mode](./copilot-fleet-mode.md) - Microsoft's parallel agent approach
- [OpenAI Codex App](./openai-codex-app.md) - OpenAI's multi-agent desktop
- [StrongDM Software Factory](./strongdm-software-factory.md) - Non-interactive alternative
- [Executive Summary](./README.md)

## Sources

1. [Introducing Claude Opus 4.6](https://www.anthropic.com/news/claude-opus-4-6) - Anthropic, Feb 5, 2026
2. [Anthropic releases Opus 4.6 with new 'agent teams'](https://techcrunch.com/2026/02/05/anthropic-releases-opus-4-6-with-new-agent-teams/) - TechCrunch, Feb 5, 2026
3. [Claude Code Agent Teams](https://prg.sh/notes/Claude-Code-Agent-Teams) - prg.sh, Feb 9, 2026
4. [Claude Code Agent Teams: Run Parallel AI Agents on Your Codebase](https://www.sitepoint.com/anthropic-claude-code-agent-teams/) - SitePoint, Feb 11, 2026
5. [Building a C Compiler with Parallel Claudes](https://www.anthropic.com/engineering/multi-agent-research-system) - Anthropic Engineering
6. [Claude 4.6 Agent Teams: Complete Guide](https://blog.laozhang.ai/en/posts/claude-4-6-agent-teams) - Feb 10, 2026
7. [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) - Anthropic Engineering, Jun 13, 2025
