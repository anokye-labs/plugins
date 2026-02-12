# The Anokye-System: A Vision for AI-Driven Continuous Project Execution

> *"The Okyeame speaks, the Okyerema drums, the Asafo march. The work never stops."*

## 1. What Is the Anokye-System?

The Anokye-System is a framework for building complex projects — not just software — that enables **automated and AI-driven continuous progress**. It is named after Okomfo Anokye, the legendary priest-statesman of the Ashanti Empire who unified disparate groups into a coherent, functioning whole. The Anokye-System aspires to do the same: unify human intent, AI agents, automation infrastructure, and project artifacts into a self-sustaining engine of continuous creation.

Unlike tools that accelerate individual tasks (code completion, PR review, test generation), the Anokye-System operates at the **project level**. It maintains forward momentum on a potentially complex, multi-faceted project by coordinating multiple agents, automating predictable work, and reserving human attention for judgment, strategy, and creative direction.

### The Core Hypothesis

**If you provide a well-structured system of roles, rhythms, and rules, a constellation of AI agents can maintain continuous progress on complex projects with minimal human intervention — and the human's role shifts from doing the work to directing and supervising the system that does the work.**

This is not a hypothesis about replacing humans. It is a hypothesis about **amplifying human agency** through a system that never sleeps, never forgets context, and never loses momentum.

### Beyond Software

While the current implementation targets software development (GitHub Issues, PRs, CI/CD), the Anokye-System's architecture is domain-agnostic. The patterns of hierarchical task decomposition, dependency tracking, agent specialization, checkpoint-based progress, and human-supervised autonomy apply equally to:

- Research programs with multiple workstreams
- Content production pipelines
- Hardware engineering projects with firmware, mechanical, and electrical tracks
- Organizational transformation initiatives
- **Family coordination and scheduling** — managing household logistics, external system integrations, knowledge bases, and planning
- Any complex endeavor requiring sustained coordination across many moving parts

## 2. The Akan Model: Why This Architecture Works

The Anokye-System draws its organizational model from the Akan political structure of West Africa — one of the most sophisticated pre-colonial governance systems ever developed. This is not mere metaphor. The Akan system solved the same fundamental problem the Anokye-System addresses: **How do you coordinate many autonomous actors toward a shared objective while maintaining both cohesion and adaptability?**

### The Roles

| Akan Role | Meaning | System Role | Description |
|-----------|---------|-------------|-------------|
| **Ohene** | Chief/King | Strategic Director | The overarching leadership principle. In the Akan system, the Asantehene is the paramount Ohene. In the Anokye-System, the **Omanhene is the user** — the human who governs a domain of work, resolves stalemates between divisional chiefs, and holds ultimate authority. The Ohene does not do the work — the Ohene decides what work matters. |
| **Ohemaa** | Queen Mother | Governance Daemon | A **persistent daemon agent** that operates its own OODA loop asynchronously, monitoring the system for drift, waste, ethical violations, and misalignment. Unlike encoded policies alone, the Ohemaa has a **persistent identity** — it reasons about governance, interacts directly with other agents, and can escalate or halt work. It is the balancing force with veto power. |
| **Okyeame** | Linguist | Personal User-Agent | **The Okyeame is the equivalent of a browser** — everyone has their own, and each person has exactly **one**. Your single Okyeame can communicate with the Okyeremas of different Oman (domains) — your software project, your family system, your research program. It is your unified personal interface to the entire Anokye-System. Today it lives in the CLI; tomorrow it may be a bespoke application. The Okyeame is a master of natural language, rich interactive visualization, and contextual awareness in a fluid multi-modal interface. |
| **Okyerema** | Master Drummer | Automation & Rhythm Engine | The talking drummer who keeps the warriors in cadence. The Okyerema is the **automation backbone** — responsible for **a domain of work** and ensuring the Asafo stay in rhythm within that domain. It is conceptually **one agent** but may have **multiple implementations** across environments (local, cloud, CI). When these implementations share a common tracking substrate, they are the same Okyerema. When the substrate differs, they are different Okyeremas. Cross-domain dependencies are handled by **inter-domain coordination agents** that pass work requests and messages between Okyeremas. |
| **Ahene** | Sub-chiefs | Domain Coordinators | Specialized coordinating agents modeled on the Akan divisional chief structure. Each Ohene oversees a particular domain and commands their own company of Asafo. (See §2.1 for the full taxonomy of Ohene types.) |
| **Asafo** | Warrior Companies | Implementation Agents | The agents that do the actual work — writing code, generating content, running analyses, producing artifacts. These can be cloud SWE agents (Devin, Copilot, Claude Code), local agents, or agents running on dedicated infrastructure. They are organized into **companies** with specialized capabilities. |
| **Omanfo** | The People | The Plugin/System Package | The unified package that contains the entire system. When you deploy the Omanfo, you deploy the civilization — the roles, the rules, the scripts, the conventions. |
| **Adwoma** | Work | The Source of Truth | GitHub Issues (or equivalent) as the single source of truth. Every task, decision, status change, and artifact is tracked. If it's not in an issue, it doesn't exist. Adwoma is the external memory that makes the whole system stateless and recoverable. |
| **Ananse** | Spider (folklore) | Agentic Runtime | The infrastructure that executes agents — GitHub Actions, local daemon processes, cloud compute. Named after Ananse the spider, the trickster who weaves webs of connection. |
| **Sankofa** | Return and get it | Health Patrols | Automated health checks that look backward to catch what was missed — orphaned issues, stale work, broken dependencies, drift from conventions. Sankofa ensures the system self-heals. |
| **Akwaaba** | Welcome | Reference & Onboarding | The knowledge base — conventions, onboarding guides, architectural decisions. Akwaaba ensures new agents and humans can join the system and be productive immediately. |

### 2.1 The Ahene: A Taxonomy of Domain Chiefs

In the Akan/Ashanti political system, the Asantehene (paramount chief) governed through a sophisticated hierarchy of divisional chiefs, each commanding their own wing of the military and administering their own domain. The Anokye-System draws inspiration from this hierarchy while being respectful of the living cultural institution — the Asantehene remains a historical and conceptual reference point, not a system component.

The system maps the divisional chief roles to agent coordination domains:

| Akan Title | Historical Role | Anokye-System Mapping |
|------------|----------------|----------------------|
| **Omanhene** | Paramount chief of a traditional area, governs a territory | **The user.** The Omanhene is the human who governs a domain of work (an Oman), resolves stalemates between the Ahene council, and holds final authority. Each domain has its own Omanhene. |
| **Krontihene** | Minister of War, Commander-in-Chief in the Asantehene's absence, right wing leader | The **release and deployment coordinator** — takes command of critical execution when the Ohene is unavailable, manages the merge queue and release pipeline |
| **Adontenhene** | Commander of the main body/rear guard, strategic advisor | The **architecture and planning Ohene** — advises on strategy, manages technical debt, ensures structural integrity of the project |
| **Nifahene** | Right wing commander | The **implementation Ohene** — coordinates the primary coding/building Asafo companies, manages feature delivery |
| **Benkumhene** | Left wing commander | The **quality and testing Ohene** — coordinates testing Asafo, manages test suites, enforces coverage and correctness |
| **Kyidomhene** | Rear guard commander, protects retreat | The **security and compliance Ohene** — guards the perimeter, manages vulnerability scanning, dependency auditing, and security policies |
| **Twafohene** | Vanguard/advance guard leader, leads the charge | The **exploration and research Ohene** — scouts ahead, investigates new technologies, prototypes solutions, produces investigation reports |
| **Gyaasehene** | Chief of the palace staff, manages administration | The **DevOps and infrastructure Ohene** — manages the palace (environments, CI/CD, deployment infrastructure, monitoring) |
| **Sanaahene** | War treasury, logistics, and ceremonial protocol | The **resource and cost Ohene** — manages API budgets, compute costs, token spending, and resource allocation across agents |
| **Ankobea Hene** | Palace guard, internal security | The **access control and secrets Ohene** — manages credentials, permissions, and internal security of the agent infrastructure |
| **Nkwankwaahene** | Chief of the young men/commoners, voice of the people | The **feedback and interface Ohene** — represents the voice of anyone interfacing with the system. Provides a channel for the Omanhene to receive feedback from external users, community members, or (in a household) any family member interacting with the system. |

Not every project needs every Ohene. A small project may have only the Ohene (human) and a couple of divisional coordinators. A large enterprise project may instantiate the full council. The architecture scales by **activating roles as complexity demands**.

The key insight from the Akan model is that these roles form a **council** — they advise, check, and coordinate with each other. The Adontenhene's architectural guidance informs the Nifahene's implementation plan. The Benkumhene's test results feed back to the Kyidomhene's security posture. The Sanaahene tracks costs across all wings. This is not a rigid chain of command — it is a **web of accountability**.

### Why the Akan Model Fits

The Akan political system was not a rigid hierarchy — it was a **distributed governance system** with checks and balances:

1. **The Ohene could be destooled** — authority was earned and maintained through results, not inherited permanently. In the Anokye-System, agents that consistently fail are replaced or reconfigured.

2. **The Ohemaa had veto power** — the Queen Mother could override the chief on matters of community welfare. In the system, governance policies can halt agent actions that violate safety or quality constraints.

3. **The Okyeame was not a mere translator** — the linguist was a diplomat, advisor, and protocol expert who shaped how messages were delivered. The Anokye-System's Okyeame is similarly not a thin wrapper over an LLM — it is a sophisticated interface that understands context, adapts communication style, and mediates between human intent and system capabilities.

4. **The Asafo were self-organizing** — warrior companies had their own internal structure and could operate independently within their mission parameters. Asafo agents in the system self-select work, manage their own execution, and report results without constant supervision.

5. **Decisions were made in council** — the Ohene didn't act alone. In the system, complex decisions involve multiple agents contributing analysis before the human (or senior agent) decides.

## 3. The Architecture in Detail

### 3.1 The Okyeame: Your Personal Agent

**The Okyeame is the equivalent of a browser.** Everyone has their own — and each person has exactly **one**. Just as a browser is your window into the web, the Okyeame is your window into the Anokye-System. But unlike a browser that shows you one site at a time, your Okyeame can communicate with the Okyeremas of **multiple Oman** (domains) simultaneously — your software project, your family coordination system, your research program.

This is a critical architectural point: **the Okyeame is the cross-domain unifier for the human**. You don't need a separate interface for each domain. Your single Okyeame understands all your domains and can surface status, translate requests, and coordinate across them. Each person's Okyeame is shaped by their preferences, context, and working style.

**Current State** (as implemented in `anokye-labs/plugins`):
- CLI-based conversational agent within the Copilot CLI tool
- Slash commands (`/sitrep`, `/health`, `/prcheck`, `/whatsleft`, `/recap`)
- Structured dashboard outputs with emoji indicators
- Socratic dialog for project setup and planning
- Issue creation and hierarchy management
- Does NOT implement — only coordinates and communicates

**Vision State**:
- **Personal and customizable**: Each user has their own Okyeame that learns their preferences, communication style, and areas of focus. You make it your own.
- **Evolving form factor**: Today it lives in the CLI. Tomorrow it could be a bespoke standalone application, a browser-based interface, or a mobile companion. The Okyeame is not bound to one medium.
- **Multi-modal interface**: Text, voice, visual dashboards, interactive graphs of project state — the Okyeame adapts its communication modality to the context
- **Context-aware**: Maintains awareness of project state, recent changes, team dynamics, and external events
- **Proactive**: Surfaces information before being asked — "The test suite has been failing for 3 hours. Two Asafo agents have attempted fixes. Here's what they've tried and why it hasn't worked. I recommend escalating."
- **Diplomatic**: Like the Akan linguist, the Okyeame translates between domains — explaining technical blockers to product stakeholders, converting business requirements into technical specifications for agents
- **Rich visualization**: Interactive dependency graphs, burndown charts, agent activity timelines, cost dashboards — all generated dynamically from live project state
- **Embeddable**: The Okyeame can be embedded in a website, a Slack channel, a VS Code sidebar, or a standalone application. It adapts its interface to the medium.
- **Multi-model**: The Okyeame is not locked to a single LLM provider. It can route queries to different models based on the task — fast models for status checks, reasoning models for planning, specialized models for domain-specific analysis.

### 3.2 The Okyerema: The Rhythm Engine

The Okyerema is the automation backbone — **mostly automation and some agentic workflows**. It is the heartbeat of continuous progress. Like the Ohemaa, the Okyerema has a **persistent identity** and operates its own OODA loop asynchronously.

**Current State** (as implemented in `anokye-labs/plugins`):
- 28 PowerShell scripts for issue management, hierarchy building, health checks, and PR workflows
- 9 reference documents for GraphQL patterns, conventions, and workflows
- Dependency-aware work selection (DAG queries)
- Plan materialization (markdown to issue hierarchies)
- PR completion loops with severity classification

**Vision State**:

#### One Agent, Many Implementations

The Okyerema is conceptually **one agent** — the master drummer that keeps the rhythm. But it may have **multiple implementations** running in different environments:

- **Local daemon**: Running on the developer's machine, watching for file changes, running pre-commit checks, coordinating with cloud agents
- **Cloud orchestrator**: Running as GitHub Actions workflows, scheduled Sankofa patrols, CI/CD pipelines
- **Dedicated server**: Running on a dedicated box for heavy orchestration tasks, long-running workflows, or environments that need persistent state

The critical architectural question is the **tracking substrate**:
- When multiple implementations share the same tracking substrate (e.g., the same GitHub Issues, the same project board, the same Adwoma), they are **the same Okyerema** — one drummer playing through different instruments
- When the tracking substrate differs (e.g., a local-only task tracker vs. GitHub Issues), they are **different Okyeremas** — different drummers with different rhythms

This distinction matters because it determines whether agents coordinated by one implementation can see work created by another. A unified substrate means unified rhythm.

#### Domain Scope and Inter-Domain Coordination

Each Okyerema is responsible for **a domain of work** — keeping the Asafo in rhythm within that domain. A software project has its own Okyerema. A family coordination system has its own Okyerema. These are separate drummers with separate rhythms.

When there are **inter-domain dependencies** (e.g., a software deploy that needs to coordinate with a marketing launch, or a household project that requires a vendor booking), the Okyeremas do not merge. Instead, **the user's Okyeame serves as the natural cross-domain bridge** — since each person has one Okyeame that communicates with all their Okyeremas, the Okyeame can relay requests and status between domains on the user's behalf. For automated cross-domain coordination (without human involvement), dedicated **inter-domain coordination agents** pass work requests and messages between Okyeremas.

This preserves the clean boundary: each Okyerema owns its domain's rhythm, and cross-domain coordination flows either through the user's Okyeame (human-mediated) or through explicit inter-domain agents (automated).

#### The Drum Patterns

The Okyerema uses whatever technology best serves the rhythm:
- **GitHub Actions** for cloud-based scheduled workflows
- **Cron jobs** for local periodic tasks
- **File watchers** for reactive automation
- **Webhooks** for event-driven orchestration
- **Message queues** for agent-to-agent coordination
- **Local daemons** for always-on presence on the developer's machine

#### Continuous Rhythm

Like the talking drum, the Okyerema sets a cadence — periodic health checks, scheduled syncs, automated triage, progress tracking. The rhythm never stops.

- **Workflow orchestration**: DAG-based execution of multi-step workflows with dependency resolution, checkpointing, and resume-on-failure (pattern established in `copilot-media-plugins` with `New-FalWorkflow.ps1`)
- **Fleet dispatch**: Parallel execution of independent tasks across multiple agents (pattern established in `copilot-media-plugins` with `media-agents` skill)

### 3.3 The Asafo: Companies of Agentic Warriors

The Asafo are the implementation agents — organized into **companies** with specialized capabilities.

**Current State**:
- Primarily `@copilot` (GitHub's coding agent)
- Task auto-assignment based on issue type
- Agent archetypes: doc-sync, issue-labeler, pr-reviewer
- Cloud-only execution via GitHub Actions

**Vision State**:
- **Multi-provider**: Asafo agents can come from any provider — Devin, Claude Code, Copilot, SWE-Agent, OpenHands, local Ollama instances, or custom agents
- **Cloud and local**: Some agents run in the cloud (for heavy compute or when access to specific services is needed), others run locally (for fast iteration, privacy-sensitive work, or offline capability)
- **Specialized companies**: Like the Akan Asafo companies, each company has a specialty:
  - **Nkwantanan** (pathfinders): Exploration agents that analyze codebases, research solutions, and produce investigation reports
  - **Gyasefo** (palace guard): Security agents that scan for vulnerabilities, audit dependencies, and enforce security policies
  - **Adonten** (vanguard): Primary implementation agents that write code, create PRs, and implement features
  - **Benkum** (left wing): Testing agents that write tests, run test suites, and validate implementations
  - **Nifa** (right wing): Documentation and DevOps agents that maintain docs, configure infrastructure, and manage deployments
- **Self-selection**: Agents query ready work and self-assign based on their capabilities and availability — no central bottleneck
- **Accountability**: Every agent action is traced back to an issue. Every commit references work. The Adwoma (issues) serve as the audit trail.

### 3.4 The Ohene & Ohemaa: Strategic Direction and Governance

The Ohene and Ohemaa represent the human leadership layer and the governance layer respectively.

**The Omanhene** (The User):

The Omanhene is the human who governs a domain of work. In most cases, this is **you** — the person who set up the system and defined the project.

- Sets project vision and priorities
- Makes judgment calls on ambiguous decisions
- Reviews and approves major architectural choices
- **Resolves stalemates** between the Ahene council when they cannot reach consensus
- Shifts from "doing the work" to "directing the system that does the work"
- Activates and deactivates divisional Ohene roles as project complexity demands

**The Ohemaa** (Governance Daemon):

The Ohemaa is not merely encoded rules — it is a **persistent daemon agent** with its own identity and OODA loop. Like the Okyerema, it operates asynchronously and interacts directly with other agents.

- **Persistent identity**: The Ohemaa maintains continuity across sessions. It knows the project's governance history, past violations, patterns of drift, and areas of concern.
- **Asynchronous OODA loop**: Continuously observes agent activity, orients against governance policies, decides whether intervention is needed, and acts (halt, escalate, warn, approve).
- **Direct agent interaction**: The Ohemaa doesn't just set rules — it communicates with the Okyerema, the Okyeame, and individual Asafo agents. It can ask an agent to explain its reasoning. It can instruct the Okyerema to adjust its rhythm.
- **Veto power**: Like the Akan Queen Mother, the Ohemaa can halt or redirect agent activity that violates governance constraints.

In practice, the Ohemaa enforces:
- Quality gates (test coverage, linting, type checking)
- Security policies and dependency audit rules
- Cost budgets and API spending limits
- Required review policies and branch protection
- Escalation rules (when must a human be consulted?)
- Ethical alignment and long-term sustainability constraints

### 3.5 The Ahene Council: Domain Coordination

The divisional Ohene roles (§2.1) are activated as project complexity demands. In a small project, the Ohene (human) may serve all coordination roles personally. In a large project, specialized coordinating agents take on divisional responsibilities:

- The **Krontihene** manages the release pipeline and takes command during critical deployments
- The **Nifahene** coordinates feature implementation across multiple Asafo agents
- The **Benkumhene** orchestrates testing campaigns and quality validation
- The **Twafohene** scouts ahead, researching solutions before the main body commits
- The **Sanaahene** tracks costs and resource allocation across all wings

These Ohene agents form a **council** — they share information, resolve conflicts, and present a unified status view to the Omanhene (user) via the Okyeame. Decisions flow through consensus where possible. **When the council reaches a stalemate, the Omanhene resolves it** — this is the irreducible human judgment that keeps the system aligned with intent.

## 4. The Landscape: Where the Anokye-System Sits

### 4.1 GasTown (Steve Yegge, 2026)

GasTown is a multi-agent workspace manager that coordinates multiple Claude Code instances working in parallel. Its architecture provides valuable lessons:

**What GasTown Does Well:**
- **Mayor agent** as central orchestrator that decomposes plans into atomic tasks
- **Beads** persistence system for crash-resistant task state (JSON in Git)
- **Refinery** merge agent that resolves conflicts and re-imagines implementations when code has shifted
- **Parallel execution** across isolated Git worktrees (20-30+ concurrent agents)
- **Continuous task streams** enabling perpetual forward motion

**Where GasTown and the Anokye-System Diverge:**
- GasTown is **code-centric** — the Anokye-System targets any complex project
- GasTown uses **ad-hoc "vibecoded" design** — the Anokye-System emphasizes structured governance
- GasTown's coordination is **flat** (Mayor → Polecats) — the Anokye-System has **hierarchical governance** (Ohene → Ohemaa → Okyeame → Okyerema → Asafo)
- GasTown's persistence is in **local Git/JSON** — the Anokye-System uses **GitHub Issues as external memory**, making state visible, queryable, and collaborative
- GasTown costs **$100+/hour** in API usage — the Anokye-System's rhythm-based approach (Okyerema) prioritizes efficiency through automation over raw agent throughput

**Key Lesson from GasTown:** Message passing between agents and external state stores (not bloated context windows) are the right patterns. Design and planning become the bottleneck once execution scales.

### 4.2 StrongDM Software Factory (factory.strongdm.ai, 2025-2026)

StrongDM's Software Factory represents the most radical vision: **non-interactive, fully automated development** where AI agents generate, test, and converge on working software driven solely by natural language specifications.

**Key Innovations:**
- **Scenario-based validation**: End-to-end user stories as holdout sets, executed thousands of times per hour
- **Digital Twin Universe (DTU)**: AI-built behavioral clones of services (Okta, Jira, Slack) enabling unlimited testing without rate limits
- **Attractor**: Core coding agent distributed as NLSpecs — you feed specs to your LLM to build the agent itself
- **Gene Transfusion**: Pattern extraction and reuse across codebases
- **Zero human code/review**: Humans set specifications and scenarios only

**Where StrongDM and the Anokye-System Diverge:**
- StrongDM is **zero human involvement in code** — the Anokye-System maintains **human-on-the-loop** for strategic decisions
- StrongDM is **software-only** — the Anokye-System is project-agnostic
- StrongDM's DTU approach is powerful but **specific to API-driven services** — the Anokye-System needs broader applicability
- StrongDM emphasizes **convergence** (agents iterate until tests pass) — the Anokye-System emphasizes **continuous progress** (the work stream never stops)

**Key Lesson from StrongDM:** Scenario-based validation (not boolean test suites) and digital twin environments enable the scale of automated testing needed for autonomous development. The concept of "software that grows" aligns with the Anokye-System's vision of continuous progress.

### 4.3 The Broader Landscape

| System | Approach | Strengths | Limitations vs. Anokye-System Vision |
|--------|----------|-----------|--------------------------------------|
| **GitHub Copilot Workspace** | Task-oriented AI-assisted development | Deep GitHub integration, issue-to-PR workflow | Human-driven, not autonomous; single-session |
| **Devin (Cognition)** | Full-stack autonomous SWE agent | End-to-end task execution, environment access | Single-agent, not multi-agent orchestration |
| **Claude Code** | Terminal-based AI coding with tool use | Hierarchical agent spawning, deep code understanding | Code-specific, requires human prompting |
| **Cursor / Windsurf** | AI-enhanced code editors | Fast iteration, inline suggestions | Editor-bound, not project-level orchestration |
| **SWE-Agent** | Research framework for LLM-based SWE | Systematic approach to code tasks | Academic, focused on benchmarks not production |
| **OpenHands** | Open-source autonomous dev platform | Community-driven, extensible | Early stage, single-agent focus |
| **Aider** | Chat-based pair programming | Lightweight, effective for focused tasks | Single-file focus, not project orchestration |

### 4.4 What's Missing Everywhere

None of these systems fully address the Anokye-System's core concerns:

1. **Continuous progress across sessions**: Most tools operate in sessions. The Anokye-System maintains state and momentum across days, weeks, and months.
2. **Multi-domain coordination**: Software is one domain. Real projects involve design, documentation, testing, deployment, communication, and strategy.
3. **Governance and sustainability**: Most tools optimize for speed. The Anokye-System optimizes for sustained, governed progress.
4. **Human-agent collaboration at scale**: Current tools are either fully autonomous or fully interactive. The Anokye-System creates a **spectrum of autonomy** where different work types get different levels of human involvement.
5. **Agent interoperability**: Current tools lock you into a single provider. The Anokye-System treats agents as interchangeable workers that can come from any provider.

## 5. The Maturity Model: From Plugin to Civilization

### Level 1: Plugin (Current State)

*Where we are today.*

- Omanfo plugin deployed to a GitHub repository
- Okyeame provides conversational project management
- Okyerema provides scripts for issue management and health checks
- Asafo is primarily `@copilot` for task execution
- Adwoma is GitHub Issues as source of truth
- Human is deeply involved in directing every action

**Capabilities**: Issue creation, hierarchy management, status reporting, basic agent dispatch, health monitoring.

### Level 2: Rhythm

*The Okyerema beats steadily.*

- Okyerema runs as scheduled workflows (Sankofa patrols, triage automation, progress tracking)
- Asafo agents self-select work based on dependency analysis
- Plan materialization converts roadmaps into executable issue hierarchies
- PR completion loops handle review thread resolution semi-autonomously
- Human checks in periodically rather than directing continuously

**Capabilities**: Automated triage, self-selecting agents, plan-to-execution pipeline, periodic health enforcement.

### Level 3: Orchestra

*Multiple instruments play in coordination.*

- Multiple Asafo companies with specialized capabilities
- Okyerema coordinates cross-agent workflows (generate → test → review → merge)
- Fleet dispatch pattern for parallel execution of independent work streams
- Checkpoint and resume-on-failure for long-running workflows
- Okyeame provides rich dashboards and proactive alerting

**Capabilities**: Multi-agent coordination, parallel execution, checkpoint-based workflows, proactive status surfacing.

### Level 4: Autonomy

*The system runs. The human supervises.*

- Continuous progress without human prompting — the system identifies what needs to be done next
- Okyeame escalates only when human judgment is genuinely needed
- Okyerema orchestrates complex, multi-day workflows
- Asafo agents from multiple providers work interchangeably
- Ohemaa governance enforces quality, security, and cost constraints automatically
- Human role shifts to strategic direction and exception handling

**Capabilities**: Self-directed work identification, multi-provider agents, automated governance enforcement, exception-based human involvement.

### Level 5: Civilization

*A self-sustaining system that evolves.*

- The system improves its own processes — identifying inefficiencies and proposing workflow improvements
- Cross-project learning — patterns from one project inform automation in others
- New agents and capabilities are integrated without system reconfiguration
- The Okyeame becomes an interactive knowledge interface — not just for the team, but for external stakeholders who want to understand the project
- Sankofa doesn't just detect problems — it predicts them and prevents them
- The system can onboard new team members (human or AI) with minimal friction

**Capabilities**: Self-improving processes, cross-project learning, predictive health, stakeholder-facing interfaces, seamless scaling.

## 6. The Continuous Rhythm: How It All Flows

```
    Omanhene (The User)
        |
        | sets direction, resolves stalemates
        v
    Okyeame (Personal User-Agent / "Browser")
        |
        | translates intent into structured plans
        | surfaces status, asks clarifying questions
        | presents rich visualizations of project state
        | each person has their own Okyeame
        v
    Okyerema (Rhythm Engine)  <------>  Ohemaa (Governance Daemon)
        |                                   |
        | materializes plans into            | monitors all agent activity
        |   issue DAGs                      | enforces quality, cost, security
        | schedules health patrols           | can halt or redirect work
        | dispatches fleet patterns           | interacts with agents directly
        | maintains the cadence              |
        |                                   |
        +------+------+------+------+       |
        |      |      |      |      |       |
        v      v      v      v      v       |
    Ahene Council (Domain Coordinators)     |
    [Nifahene] [Benkumhene] [Twafohene]    |
    [Krontihene] [Gyaasehene] [Sanaahene]  |
        |      |      |      |              |
        v      v      v      v              |
    Asafo Companies (Implementation Agents) |
    [Code] [Test] [Research] [Security]     |
        |      |      |      |              |
        | execute tasks, open PRs            |
        | self-select from ready work        |
        | report results back to Adwoma      |
        v                                   |
    Adwoma (Source of Truth) ---------------+
        |
        | feeds status back to Okyeame
        | informs Okyerema's next beat
        | informs Ohemaa's governance loop
        | maintains the complete audit trail
```

The key insight is the **circular flow**: Adwoma feeds information back to all persistent agents — the Okyeame, the Okyerema, and the Ohemaa each operate their own OODA loops against the shared state. The Okyerema's rhythm ensures the forward cycle never stalls. The Ohemaa's governance loop ensures quality never degrades. The Okyeame keeps the human informed and empowered. Even when individual agents fail or humans are unavailable, the rhythm continues.

### 6.1 Example: Family Coordination Domain

The Anokye-System is not limited to software. Consider a family coordination scenario:

- **Omanhene**: The primary family organizer — the person who sets priorities (vacation planning, school activities, household projects)
- **Okyeame**: Each family member's personal agent — their browser into the family system, accessible via phone, voice assistant, or family dashboard. Everyone has their own.
- **Okyerema**: A daemon that maintains the family rhythm — syncing calendars, tracking recurring tasks, sending reminders, coordinating with external systems (school portals, healthcare providers, utility companies). This is a **separate Okyerema** from any software project — different domain, likely different tracking substrate.
- **Ohemaa**: A governance daemon — budget constraints, scheduling conflict resolution, privacy policies for children's data
- **Nkwankwaahene**: The feedback channel — not just children, but **anyone interfacing with the system** (family members, babysitters, extended family, service providers) can surface needs and concerns back to the Omanhene
- **Asafo**: Leaf-level agents that interface with outside systems — booking appointments, paying bills, ordering supplies, maintaining the family knowledge base
- **Adwoma**: The family's shared task and knowledge system — not GitHub Issues, but perhaps a structured database, a shared calendar, or a custom tracking substrate
- **Inter-domain agents**: If the family Okyerema needs to coordinate with a software project Okyerema (e.g., a parent who needs to block work time), messenger agents pass requests between domains

The same architectural patterns apply: hierarchical task decomposition, dependency tracking, agent specialization, health patrols, and progressive autonomy. The Okyerema beats the rhythm. The Asafo execute. The Adwoma remembers everything.

## 7. Design Principles

### 7.1 External Memory Over Internal Context

Agents are stateless. All state lives in Adwoma (issues), Git (code), and structured artifacts. This means:
- Any agent can pick up any task — no context hoarding
- System survives agent failures, session timeouts, and provider outages
- Complete audit trail for every decision and action
- Human can understand system state at any time by reading the issues

### 7.2 Rhythm Over Throughput

It's better to maintain a steady, sustainable pace than to sprint and stall. The Okyerema ensures:
- Regular health checks catch problems early
- Automated triage prevents work from going stale
- Progress tracking keeps stakeholders informed
- The system recovers gracefully from disruptions

### 7.3 Governance by Default

Every agent action is governed:
- Branch protection prevents unreviewed merges
- Issue references in commits ensure traceability
- Cost monitoring prevents runaway API spend
- Quality gates enforce standards automatically
- Escalation rules ensure humans are consulted on judgment calls

### 7.4 Progressive Autonomy

Not everything needs the same level of oversight:
- **Tasks and Bugs**: High autonomy — agents self-assign, implement, and open PRs
- **Features**: Medium autonomy — agents implement, but humans review and approve
- **Epics**: Low autonomy — humans define scope and strategy, agents execute within bounds
- **Strategic decisions**: No autonomy — always human

### 7.5 Agent Interoperability

The system must not be locked to a single AI provider:
- Asafo agents can be Copilot, Devin, Claude Code, local models, or custom agents
- The Okyeame can use different LLMs for different tasks
- The Okyerema's automation is technology-agnostic
- New providers can be integrated without architectural changes

### 7.6 Domain Agnosticism

The patterns must work beyond software:
- Hierarchical task decomposition works for any project
- Dependency tracking applies to any workflow
- Agent specialization maps to any domain
- The Okyeame's communication role is universal
- The Okyerema's rhythm applies wherever sustained coordination is needed

## 8. What Makes This Different

### From GasTown: Governance

GasTown optimizes for throughput — many agents, many PRs, fast merges. The Anokye-System adds the Ohemaa (governance) and the Sankofa (health patrols) to ensure that speed doesn't come at the cost of quality, security, or sustainability.

### From StrongDM Factory: Human Partnership

StrongDM aims for zero human involvement in code. The Anokye-System recognizes that humans bring judgment, creativity, and strategic thinking that agents cannot replicate. The goal is not to remove humans but to **free them from predictable work** so they can focus on what only humans can do.

### From Copilot/Cursor: Project-Level Thinking

Current AI coding tools operate at the file or task level. The Anokye-System operates at the **project level** — understanding dependencies, tracking progress across workstreams, maintaining momentum over weeks and months.

### From All of Them: The Cultural Model

The Akan organizational model is not decoration — it is a **design philosophy**. It embeds principles of distributed governance, accountability, communication, and self-organizing teams into the architecture itself. These are the same principles that make human organizations effective, applied to agent orchestration.

## 9. The Road Ahead

### Near-Term (Current → Level 2)

1. **Strengthen the Okyerema**: Expand automation scripts, add scheduled Sankofa patrols, implement plan materialization for brownfield repos
2. **Multi-agent dispatch**: Enable the Okyeame to dispatch work to agents beyond `@copilot`
3. **Rich status visualization**: Move beyond text-based dashboards to interactive visualizations
4. **Local Okyerema daemon**: A process running on the developer's machine that maintains rhythm locally

### Medium-Term (Level 2 → Level 3)

5. **Cross-repo orchestration**: Coordinate work across multiple repositories (the system already tracks cross-repo blocking references)
6. **Fleet dispatch for software**: Apply the media-agents fleet pattern to software development workflows
7. **Agent marketplace**: Pluggable Asafo companies from different providers with standardized interfaces
8. **Cost and efficiency tracking**: Monitor and optimize agent spending across providers
9. **Okyeame cross-domain knowledge store**: A personal knowledge graph maintained by the Okyeame that understands relationships across Oman — e.g., "this software project is for client X" and "client X's deadline connects to this family scheduling constraint." Enables the Okyeame to surface cross-domain insights and coordinate more intelligently across the user's Oman.

### Long-Term (Level 3 → Level 5)

10. **Self-directed work identification**:The system analyzes the project and proposes what should be done next
11. **Cross-project learning**: Patterns and solutions from one project inform another
12. **Predictive health**: Sankofa predicts problems before they manifest
13. **Vision repository with interactive Okyeame**: A public-facing site where people can interact with an AI to learn about and adopt the Anokye-System
14. **Beyond software**: Templates and patterns for non-software project domains

## 10. Glossary

| Term | Akan Meaning | System Meaning |
|------|-------------|----------------|
| **Anokye-System** | Named after Okomfo Anokye | The complete framework for AI-driven continuous project execution |
| **Ohene** | Chief/King | The leadership principle — the Omanhene (user) is the primary Ohene |
| **Omanhene** | Paramount chief of a territory (Oman) | The user — governs a domain, resolves stalemates, holds final authority |
| **Oman** | Territory/domain | A domain of work — each Oman has its own Omanhene (user), Okyerema (rhythm), and Adwoma (source of truth) |
| **Ahene** | Sub-chiefs (Krontihene, Nifahene, etc.) | Domain coordinators — specialized agents for implementation, testing, security, DevOps, etc. |
| **Ohemaa** | Queen Mother | Governance daemon agent — persistent identity, asynchronous OODA loop, veto power |
| **Okyeame** | Linguist | Personal user-agent — the equivalent of a browser; everyone has their own |
| **Okyerema** | Master Drummer | Automation and rhythm engine — one agent per domain, multiple implementations, unified by tracking substrate |
| **Nkwankwaahene** | Chief of the young men/commoners | Feedback and interface Ohene — voice of anyone interfacing with the system |
| **Asafo** | Warrior Companies | Implementation agents organized into specialized companies |
| **Omanfo** | The People | The unified plugin/system package |
| **Adwoma** | Work | GitHub Issues as the single source of truth and external memory |
| **Ananse** | Spider (folklore) | The agentic runtime infrastructure |
| **Sankofa** | Return and get it | Automated health patrols and self-healing mechanisms |
| **Akwaaba** | Welcome | Reference repository, onboarding, and knowledge base |

## 11. Invitation to Build

The Anokye-System is an evolving vision. It draws from the wisdom of Akan governance, the lessons of emerging AI orchestration systems, and the practical experience of building multi-agent automation in real repositories.

We believe the future of complex project execution is not a single brilliant AI — it is a **civilization of specialized agents**, governed by clear roles and rules, communicating through well-defined protocols, and driven by an unceasing rhythm that ensures progress never stops.

The question is not whether AI agents will build our software and manage our projects. The question is: **What kind of society will those agents form?**

The Anokye-System answers: one modeled on millennia of human organizational wisdom, adapted for the age of artificial intelligence.

---

*This document is a living artifact. As the system evolves, so will this vision. Contributions, critiques, and conversations are welcome.*

*Refs: #129*
