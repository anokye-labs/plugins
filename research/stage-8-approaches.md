# Stage 8 Approaches: Building Your Own Orchestrator

> **Deep-Dive Analysis** | Cross-system comparison of approaches to autonomous agent orchestration
> **Context**: Stage 8 in [Yegge's Developer-Agent Evolution Model](./gastown.md#yegges-8-stages-of-developer-agent-evolution)

---

## What Is Stage 8?

Stage 8 is the frontier of developer-agent interaction: **building your own orchestrator**. At this stage, the developer is no longer using individual agents or even manually managing multiple agents. Instead, they have constructed (or adopted) a system that automates the orchestration of agent workflows - task decomposition, assignment, coordination, quality control, and merging.

The preceding stages provide context:

| Stage | Activity | Bottleneck |
|-------|----------|------------|
| 1-4 | Single agent, increasing trust | Agent capability |
| 5 | CLI single agent, YOLO | Human attention (can only watch one) |
| 6 | 3-5 parallel agents | Human coordination bandwidth |
| 7 | 10+ agents, hand-managed | Human coordination capacity |
| **8** | **Custom orchestrator** | **Design, specification, validation quality** |

The critical insight: at Stage 8, the bottleneck shifts from *execution* to *specification*. Every system surveyed confirms this - when agents can build anything you describe, the quality of your descriptions becomes the limiting factor.

## The Stage 8 Landscape (February 2026)

Six distinct approaches to Stage 8 have emerged, each with a different philosophy about the human-agent boundary:

### Approach 1: Custom Hierarchical Orchestrator ([Gas Town](./gastown.md))

**Philosophy**: Build a Kubernetes-like system specifically for agent management.

**Architecture**:
```
Human (Product Manager)
  |
  Mayor (Chief-of-staff agent)
  |--- Deacon (Health monitoring daemon)
  |--- Rig 1
  |      |--- Witness (Oversight)
  |      |--- Refinery (Merge queue)
  |      |--- Polecats (Ephemeral workers)
  |      |--- Crew (Persistent workers)
  |--- Rig N
         |--- ...
```

**Key Design Decisions**:
- Two-tier hierarchy (town-level coordination, rig-level execution)
- GUPP: Autonomous execution without human approval loops
- Git-backed persistent state (Beads) as single source of truth
- Named agent roles with distinct responsibilities
- Merge queue as quality gate

**Human Role**: Product manager feeding design and plans to the system. Occasional manual intervention when agents get stuck. The human *directs* but does not *implement* or *review code*.

**Strengths**: Maximum flexibility, deep customization, handles 20-30 agents
**Weaknesses**: High complexity, expensive, requires Stage 7+ expertise to adopt

---

### Approach 2: Platform-Native Agent Teams ([Claude Agent Teams](./claude-agent-teams.md))

**Philosophy**: Extend the existing CLI agent with built-in multi-agent primitives.

**Architecture**:
```
Human (Team Architect)
  |
  Team Lead (spawns and synthesizes)
  |--- Teammate A (security reviewer)
  |--- Teammate B (performance reviewer)
  |--- Teammate C (test coverage)
  |
  Shared: Task List + Mailbox
```

**Key Design Decisions**:
- Seven primitives (TeamCreate, TaskCreate, TaskUpdate, TaskList, Task, SendMessage, TeamDelete)
- Peer-to-peer messaging (not hierarchical command)
- File-locking for task claims (prevent double-work)
- Quality gates via hooks (TeammateIdle, TaskCompleted)
- Delegate mode (restrict lead to coordination only)

**Human Role**: Team architect who designs the team composition and reviews synthesized results. Can require plan approval before execution.

**Strengths**: Low setup cost, platform-integrated, proven at scale (16-agent C compiler)
**Weaknesses**: Experimental, session-scoped state, high token costs, no nested teams

---

### Approach 3: Non-Interactive Software Factory ([StrongDM](./strongdm-software-factory.md))

**Philosophy**: Eliminate human-code interaction entirely. Specs in, software out.

**Architecture**:
```
Human (Spec Author + Scenario Curator)
  |
  Attractor Pipeline (DAG-based workflow)
  |--- Stage 1: Parse specs
  |--- Stage 2: Generate code
  |--- Stage 3: Run scenarios against Digital Twin Universe
  |--- Stage 4: Evaluate satisfaction
  |--- Stage 5: Iterate or converge
  |
  No human review. No human code reading.
```

**Key Design Decisions**:
- Code must not be written or reviewed by humans
- Scenarios (not tests) as validation primitive
- Satisfaction scoring (probabilistic, not boolean)
- Digital Twin Universe for safe, high-volume testing
- NLSpecs (Natural Language Specifications) as the product

**Human Role**: Specification author and scenario curator. The human designs what the system should do and how to validate it, but never touches the code. Dan Shapiro calls this "Level 5: The Dark Factory."

**Strengths**: Eliminates human bottleneck entirely, scales infinitely
**Weaknesses**: Requires extremely high-quality specs, raises liability questions, limited to teams with deep testing expertise

---

### Approach 4: Desktop Multi-Agent Command Center ([OpenAI Codex App](./openai-codex-app.md))

**Philosophy**: Provide a polished GUI for managing parallel agent work across projects.

**Architecture**:
```
Human (Project Manager in GUI)
  |
  Codex App (desktop interface)
  |--- Project A: Agent session (worktree A)
  |--- Project B: Agent session (worktree B)
  |--- Project C: Background task (worktree C)
  |
  Skills: Reusable, schedulable agent capabilities
```

**Key Design Decisions**:
- GUI-first (vs. Gas Town's tmux, Claude's terminal)
- Git worktree isolation for parallel work
- Skills system for reusable agent capabilities
- Scheduled execution (cron-like)
- Voice input for natural language tasking

**Human Role**: Project manager using a visual interface to assign work, review diffs, and manage agent sessions. Lower barrier to entry than CLI-based systems.

**Strengths**: Accessible, visual, integrated scheduling, broad model access
**Weaknesses**: Less flexible than custom orchestrators, single-model ecosystem

---

### Approach 5: IDE-Integrated Parallel Dispatch ([Copilot Fleet Mode](./copilot-fleet-mode.md))

**Philosophy**: Embed multi-agent dispatch into the existing developer workflow (CLI + GitHub).

**Architecture**:
```
Human (Developer in CLI)
  |
  /fleet command -> Plan
  |
  SQLite Task DB (dependency-aware)
  |--- Subagent 1 (independent task)
  |--- Subagent 2 (depends on 1)
  |--- Subagent 3 (independent task)
  |
  Cross-agent memory (persistent learning)
```

**Key Design Decisions**:
- SQLite per session (ACID transactions for task state)
- Dependency-aware dispatch (DAG in database)
- ACP protocol for external orchestration
- Cross-agent memory for accumulated knowledge
- Copilot SDK for building custom orchestrators on top

**Human Role**: Developer who invokes `/fleet` and reviews results. The ACP protocol enables building Stage 8 orchestrators on top of Fleet Mode as a building block.

**Strengths**: Native GitHub integration, memory system, SDK for extension
**Weaknesses**: Experimental, limited documentation, GitHub ecosystem lock-in

---

### Approach 6: Autonomous Agent-as-Service ([Devin](./emerging-systems.md#devin-cognition) and similar)

**Philosophy**: Abstract away the orchestration entirely. Submit a task, receive a PR.

**Architecture**:
```
Human (Task Submitter)
  |
  Devin (black box)
  |--- Planning
  |--- Coding
  |--- Debugging
  |--- Testing
  |--- PR creation
  |
  Output: Mergeable PR
```

**Key Design Decisions**:
- Single autonomous agent (not multi-agent)
- Full sandboxed environment (IDE, terminal, browser)
- Enterprise-scale task routing
- PR as the unit of output

**Human Role**: Task submitter and PR reviewer. The human defines what needs doing and evaluates the result, but has no visibility into the process.

**Strengths**: Lowest cognitive overhead, enterprise-ready, proven at scale
**Weaknesses**: Black box, limited customization, high per-seat cost (~$500/mo)

---

## Cross-Cutting Analysis

### The Specification Quality Problem

Every Stage 8 system converges on the same insight: **when execution is automated, specification quality becomes the bottleneck**.

| System | Spec Format | Spec Quality Mechanism |
|--------|-------------|----------------------|
| Gas Town | Beads + Formulas (TOML) | MEOW decomposition principle |
| Claude Agent Teams | Natural language prompts | Plan approval by lead |
| StrongDM | NLSpecs (Markdown) | Scenario holdouts + satisfaction scoring |
| Codex App | Skills (structured prompts) | Diff review UI |
| Copilot Fleet | Natural language + deps | SQLite dependency validation |
| Devin | Issue/task description | Internal planning loop |

Maggie Appleton's analysis of Gas Town identifies this clearly:

> "When you have a fat stack of agents churning through code tasks, development time is no longer the bottleneck... Design becomes the limiting factor: imagining what you want to create and then figuring out all the gnarly little details required to make your imagination into reality."

### The Coordination Spectrum

Systems vary dramatically in how agents coordinate:

```
No coordination          Hierarchical            Peer-to-peer
(StrongDM pipeline)  <-> (Gas Town Mayor)   <-> (Claude Agent Teams)
     |                        |                       |
Isolated stages          Command chain          Self-organization
```

- **No coordination** (StrongDM): Each pipeline stage is independent. No agent-to-agent communication. Coordination is implicit in the spec structure.
- **Hierarchical** (Gas Town): Mayor dispatches to Polecats, Witness monitors, Refinery merges. Clear chain of command.
- **Peer-to-peer** (Claude Agent Teams): Teammates message each other directly, claim tasks from shared queue, challenge each other's reasoning.
- **Hybrid** (Copilot Fleet): Dependency-aware dispatch (hierarchical) with cross-agent memory (shared state).

### The Validation Spectrum

How each system ensures quality:

| System | Validation Approach | When |
|--------|-------------------|------|
| Gas Town | Refinery merge queue + Witness oversight | Before merge |
| Claude Agent Teams | Hooks (TeammateIdle, TaskCompleted) + plan approval | During and after execution |
| StrongDM | Scenarios + satisfaction + Digital Twin Universe | Continuous (no human gate) |
| Codex App | Diff review UI | After generation, before commit |
| Copilot Fleet | Dependency resolution + memory | During dispatch |
| Devin | Internal test loops | Before PR submission |

StrongDM's approach is the most radical: validation is the ONLY quality mechanism. There is no code review. The entire engineering effort goes into making the validation system robust enough to replace human judgment.

### The State Persistence Spectrum

How each system handles agent memory and state:

| System | Persistence | Survives | Format |
|--------|-------------|----------|--------|
| Gas Town | Git-backed (Beads) | Sessions, crashes, restarts | JSONL in git |
| StrongDM | cxdb | Sessions | Immutable DAG (Rust/Go/TS) |
| Copilot | Cross-agent memory | Sessions, agents | Platform-managed |
| Claude Agent Teams | Local files | Current session only | JSON |
| Codex App | Git worktrees | Current session | Git state |
| Copilot Fleet | SQLite per session | Current session | SQLite DB |

Systems with persistent state (Gas Town, StrongDM, Copilot memory) can accumulate knowledge over time. Session-scoped systems (Claude Agent Teams, Fleet Mode) start fresh each time.

### The Human Role Spectrum

```
Full oversight                                              Zero oversight
(Claude Agent Teams)  <->  (Gas Town)  <->  (Devin)  <->  (StrongDM)
      |                        |                |              |
 Plan approval            Vibe coding      PR review     Spec + scenarios
 Delegate mode           Factory operator   Task submitter   only
```

### The Cost Spectrum

| System | Cost Model | Typical Range |
|--------|-----------|---------------|
| Gas Town | Multiple Claude API accounts | $1,000s/month |
| Claude Agent Teams | Per-token (scales with team size) | $20K for large projects |
| StrongDM | $1,000/day per engineer target | $20K+/month per engineer |
| Codex App | ChatGPT subscription + usage | $20-200/month |
| Copilot Fleet | GitHub Copilot subscription | $10-39/month |
| Devin | ~$500/seat/month | $500/month |

## Stage 8 Design Patterns

### Pattern 1: Work Decomposition Graph

All Stage 8 systems decompose work into dependency-aware graphs:

- Gas Town: Beads with blocking/parent-child relationships
- Claude Agent Teams: Tasks with dependency tracking
- Copilot Fleet: SQLite with dependency columns
- StrongDM: Attractor pipeline DAG (Graphviz DOT)
- Omanfo: Issue hierarchy with sub-issues and blocking references

This is the universal primitive. The implementation varies (JSONL, JSON, SQLite, DOT), but the pattern is consistent.

### Pattern 2: Autonomous Work Pickup

Agents should pick up work automatically when it's ready:

- Gas Town: GUPP ("If there is work on your hook, YOU RUN IT")
- Claude Agent Teams: TaskList + TaskUpdate (claim from shared queue)
- Copilot Fleet: Dependency resolver dispatches when prerequisites complete
- Omanfo: `Get-ReadyIssues` (all sub-issues closed + no open blockers)

### Pattern 3: Layered Quality Gates

Multiple validation layers catch different failure modes:

- Gas Town: Witness monitoring -> Refinery merge queue -> main branch
- Claude Agent Teams: TeammateIdle hook -> TaskCompleted hook -> lead synthesis
- StrongDM: Scenario runs -> satisfaction scoring -> convergence check
- Omanfo: `Get-ThreadSeverity` -> `Invoke-PRCompletion` -> merge

### Pattern 4: Git as Coordination Backbone

Git serves as both the artifact store and the coordination mechanism:

- Branch-per-task isolation (Gas Town worktrees, Codex worktrees)
- Merge queue as serialization point (Gas Town Refinery)
- Git-backed state (Gas Town Beads, StrongDM Attractor specs)
- PR as the unit of deliverable output

### Pattern 5: Progressive Trust Delegation

Systems allow varying levels of human oversight:

- Claude Agent Teams: Plan approval mode (read-only until approved)
- Gas Town: Witness oversight (automated monitoring with escalation)
- Codex App: Diff review (inspect before commit)
- StrongDM: No delegation - trust is total from the start

## Implications for Omanfo

Omanfo's architecture already implements several Stage 8 patterns:

| Stage 8 Pattern | Omanfo Implementation | Maturity |
|----------------|----------------------|----------|
| Work decomposition graph | Issue hierarchy (Epic > Feature > Task) + DAG health | Mature |
| Autonomous work pickup | `Get-ReadyIssues` + agent self-selection | Mature |
| Layered quality gates | Thread severity + PR completion + health checks | Mature |
| Git as coordination | GitHub Issues + PRs + GraphQL-first | Mature |
| Progressive trust | Default assignment policy (Tasks -> @copilot) | Early |
| Cross-agent memory | Zero-footprint (live API queries) | Designed differently |
| Multi-agent dispatch | Not yet implemented | Gap |
| Satisfaction scoring | Health score 0-100 | Partial |

### Key Gaps and Opportunities

1. **Multi-agent dispatch**: Omanfo tracks work but doesn't yet orchestrate parallel agent execution. Integrating with Copilot Fleet (via ACP) or Claude Agent Teams could bridge this.

2. **Scenario-based validation**: StrongDM's scenario + satisfaction model could enhance Omanfo's evaluation framework beyond the current 10 eval scenarios.

3. **Digital Twin Universe**: Building behavioral clones of GitHub's API for high-volume testing could dramatically improve Omanfo's E2E test coverage without hitting rate limits.

4. **Cross-session memory**: Gas Town's Beads and Copilot's cross-agent memory solve persistence problems that Omanfo's zero-footprint approach avoids but doesn't benefit from.

5. **Orchestrator integration**: The Copilot SDK and ACP protocol create opportunities to build Omanfo-aware orchestrators that combine issue-driven planning with parallel agent execution.

## Related Reports

- [Gas Town](./gastown.md) - Custom orchestrator (Approach 1)
- [Claude Agent Teams](./claude-agent-teams.md) - Platform-native teams (Approach 2)
- [StrongDM Software Factory](./strongdm-software-factory.md) - Dark Factory (Approach 3)
- [OpenAI Codex App](./openai-codex-app.md) - Desktop command center (Approach 4)
- [GitHub Copilot Fleet Mode](./copilot-fleet-mode.md) - IDE-integrated dispatch (Approach 5)
- [Emerging Systems](./emerging-systems.md) - Devin and other approaches (Approach 6)
- [Executive Summary](./README.md)

## Sources

All sources from individual reports, plus:

1. [The identity shift that unlocked real throughput](https://natesnewsletter.substack.com/p/6-practices-for-when-the-models-got) - Nate's Newsletter, Jan 23, 2026
2. [AI Coding Agents in 2026: Coherence Through Orchestration](https://mikemason.ca/writing/ai-coding-agents-jan-2026/) - Mike Mason, Jan 22, 2026
3. [Building Agentic Control Planes](https://www.shshell.com/blog/multi-agent-orchestration-patterns) - ShShell, Jan 14, 2026
4. [Agent-Driven Development: Two Paths, One Future](https://futurumgroup.com/insights/agent-driven-development-two-paths-one-future/) - Futurum Group, Feb 5, 2026
5. [Agentic AI Engineering Workflows for iOS in 2026](https://blog.jacobstechtavern.com/p/agentic-ai-2026) - Jacob's Tech Tavern, Feb 9, 2026
