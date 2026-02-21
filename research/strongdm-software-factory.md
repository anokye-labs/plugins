# StrongDM Software Factory: The "Dark Factory" Approach

> **Published**: February 6, 2026 | **Authors**: Justin McCarthy, Jay Taylor, Navan Chauhan
> **Source**: [factory.strongdm.ai](https://factory.strongdm.ai/)

---

## Overview

StrongDM's Software Factory is the most radical approach to [Stage 8](./stage-8-approaches.md) agentic engineering: a **non-interactive development** model where specifications and scenarios drive agents that write code, run harnesses, and converge without human review. Their charter contains two foundational rules:

1. **Code must not be written by humans**
2. **Code must not be reviewed by humans**

Founded July 14, 2025, by Justin McCarthy (co-founder, CTO), Jay Taylor, and Navan Chauhan, the three-person AI team at StrongDM (a company that builds access management and *security* infrastructure) demonstrated working prototypes by October 2025. The fact that a security company chose this approach lends particular credibility - and raises particular questions.

StrongDM's practical benchmark: **"If you haven't spent at least $1,000 on tokens today per human engineer, your software factory has room for improvement."**

## Dan Shapiro's Five Levels Context

StrongDM operates at what Dan Shapiro calls **Level 5: The Dark Factory** in his taxonomy of AI-assisted programming:

| Level | Name | Description |
|-------|------|-------------|
| 0 | Spicy Autocomplete | Copy-paste from ChatGPT, basic completions |
| 1 | Coding Intern | AI writes boilerplate, full human review |
| 2 | Junior Developer | Pair programming, reviewing every line |
| 3 | Developer | Most code AI-generated, human is full-time reviewer |
| 4 | Engineering Team | Human as engineering manager, agents do the work |
| **5** | **Dark Factory** | **Specs in, software out. Humans neither needed nor welcome in the code.** |

The term "Dark Factory" borrows from manufacturing - the Fanuc robot factory staffed by robots, where lights are off because robots don't need to see.

## Core Philosophy

### The Koan

> "Why am I doing this?" (implied: the model should be doing this instead)

This is the central question StrongDM trains their team to ask about every manual activity. If a human is performing a task, the default assumption is that an agent should be doing it instead.

### From Tests to Scenarios

StrongDM found traditional testing insufficient for non-interactive development:

| Concept | Traditional | StrongDM's Evolution |
|---------|-------------|---------------------|
| **Validation unit** | Test (code-level) | **Scenario** (end-to-end user story) |
| **Success metric** | Boolean pass/fail | **Satisfaction** (probabilistic, % of trajectories that satisfy users) |
| **Storage** | In codebase (can be reward-hacked) | **Outside codebase** (holdout set, like ML training) |
| **Evaluator** | Deterministic assertion | **LLM-as-judge** (flexible, semantic) |

The word "test" proved insufficient because:
- A test stored in the codebase can be lazily rewritten to match the code
- The code can be rewritten to trivially pass the test (`return true`)
- Boolean pass/fail cannot capture probabilistic agent behavior

**Scenarios** represent end-to-end user stories stored outside the codebase (similar to a holdout set in ML), evaluated by **satisfaction** - the fraction of observed trajectories that would satisfy a real user.

## Architecture

### The Digital Twin Universe (DTU)

The centerpiece innovation: behavioral clones of third-party services that StrongDM's software depends on.

| Service Twin | Purpose |
|-------------|---------|
| Okta | Identity/access management scenarios |
| Jira | Project management integration testing |
| Slack | Communication workflow validation |
| Google Docs | Document integration scenarios |
| Google Drive | File storage integration testing |
| Google Sheets | Spreadsheet integration validation |

The DTU enables:
- **Volume testing**: Thousands of scenarios per hour without rate limits
- **Failure mode testing**: Dangerous/impossible-to-test conditions against live services
- **Cost elimination**: No API costs, abuse detection, or quota consumption
- **Swarm simulation**: Streams of simulated Okta users requesting access via Slack twins

### Open-Source Releases

StrongDM released two key components:

#### 1. Attractor ([github.com/strongdm/attractor](https://github.com/strongdm/attractor))

The core non-interactive coding agent specification. Notably, **the repository contains zero lines of code** - only three Markdown NLSpecs (Natural Language Specifications):

| Spec | Function |
|------|----------|
| **Attractor Pipeline System** | Orchestrates multi-stage AI workflows using directed graphs in Graphviz DOT syntax. Nodes = tasks (LLM calls, human gates, parallel execution), edges = transitions with conditions. |
| **Unified LLM SDK** | Provider-agnostic interface for LLM communication. Uses native APIs to preserve advanced features (reasoning tokens, prompt caching). |
| **Coding Agent Loop** | Autonomous agent implementing the ReAct pattern. Pairs LLM with developer tools through an agentic loop. Manages conversation state, dispatches tool calls, handles event streams. |

The implementation philosophy: hand the specs to any coding agent, and it generates the implementation. The specs ARE the product.

#### 2. cxdb ([github.com/strongdm/cxdb](https://github.com/strongdm/cxdb))

The AI Context Store: 16,000 lines of Rust, 9,500 lines of Go, 6,700 lines of TypeScript. Stores conversation histories and tool outputs in an immutable DAG format. Functions as the memory layer for the factory.

### Three-Tier State Management

| Tier | Scope | Manages |
|------|-------|---------|
| **Pipeline State** (Attractor) | Workflow-level | Handler context, graph traversal position |
| **Session State** (Coding Agent) | Agent-level | Conversation history, tool state |
| **Provider State** (Unified SDK) | Model-level | Conversation threads, token usage |

## The Inflection Points

StrongDM identifies two critical model capability inflection points:

1. **October 2024** (Claude 3.5 Sonnet revision): "Long-horizon agentic coding workflows began to compound correctness rather than error." Prior models accumulated errors; this revision made iterative development viable.

2. **November 2025** (Claude Opus 4.5 + GPT 5.2): The broader community's acknowledgment that coding agents could reliably follow instructions on complex tasks. StrongDM's early bet was validated.

## Economics

StrongDM frames the economics as "deliberate naivete" - removing inherited constraints from pre-agent development:

> Creating a high-fidelity clone of a significant SaaS application was always possible, but never economically feasible. Generations of engineers may have wanted a full in-memory replica of their CRM to test against, but self-censored the proposal. Those of us building software factories must practice a deliberate naivete: finding and removing the habits, conventions, and constraints of Software 1.0.

The DTU is proof that what was unthinkable six months ago is now routine.

## Critical Analysis

### The Stanford Law School Perspective

Stanford CodeX's Eran Kahana ([February 8, 2026](https://law.stanford.edu/2026/02/08/built-by-agents-tested-by-agents-trusted-by-whom/)) raised fundamental questions:

> "A team building *security infrastructure* has decided that human code review is an obstacle, not a safeguard... This inverts how we assign responsibility for software behavior. Existing regulatory frameworks are not prepared for it."

Key concerns:
- Who is responsible when agent-written security code fails?
- How do existing liability frameworks apply?
- Is "satisfaction" scoring sufficient for security-critical software?

### Simon Willison's Analysis

Simon Willison ([February 7, 2026](https://simonwillison.net/2026/Feb/7/software-factory/)):

> "The most interesting of these, without a doubt, is 'Code must not be reviewed by humans'. How could that possibly be a sensible strategy when we all know how prone LLMs are to making inhuman mistakes?"

His answer: the key is that StrongDM's system proves the system works through scenarios and testing, not through code review. The human role shifts from reviewing code to designing the validation system.

## Comparison to Other Approaches

| Dimension | StrongDM Factory | [Gas Town](./gastown.md) | [Claude Agent Teams](./claude-agent-teams.md) |
|-----------|-----------------|----------|-------------------|
| **Human-code interaction** | None (no reading, writing, or reviewing) | Vibe coding (no reading, but human directs) | Active oversight (plan approval, hooks) |
| **Validation model** | Scenarios + satisfaction + DTU | Refinery merge queue | Quality gate hooks |
| **Coordination** | Isolated pipeline stages | Multi-agent messaging | Peer-to-peer teams |
| **State persistence** | cxdb (immutable DAG) | Beads (git-backed JSONL) | Local JSON files |
| **Human role** | Spec author, scenario curator | Product manager, factory operator | Team architect, lead reviewer |
| **Spec format** | NLSpecs (Markdown) | Beads + Formulas (TOML) | Natural language prompts |
| **Open source** | Attractor + cxdb | Gas Town + Beads | Claude Code (proprietary) |

## Relevance to Omanfo

StrongDM's approach offers provocative contrasts with Omanfo's design:

| StrongDM | Omanfo | Tension |
|----------|--------|---------|
| "Code must not be reviewed by humans" | PR review via `Invoke-PRCompletion` with severity classification | StrongDM eliminates review; Omanfo automates it |
| Scenarios stored outside codebase | Evaluations in `omanfo/evaluations/` | Both use holdout-style validation |
| Satisfaction scoring (probabilistic) | Health score 0-100 with letter grades | Both move beyond boolean pass/fail |
| Digital Twin Universe | N/A | Opportunity: DTU for GitHub API testing |
| NLSpecs as product | SKILL.md + references as agent instructions | Both use markdown-as-specification |
| cxdb immutable DAG | Beads as git-backed issue tracking | Both need persistent agent memory |

## Related Reports

- [Gas Town](./gastown.md) - Human-in-the-loop orchestrator alternative
- [Stage 8 Approaches Deep-Dive](./stage-8-approaches.md)
- [Claude Agent Teams](./claude-agent-teams.md) - Platform-native multi-agent
- [OpenAI Codex App](./openai-codex-app.md) - Desktop multi-agent
- [Emerging Systems](./emerging-systems.md) - Other factory approaches
- [Executive Summary](./README.md)

## Sources

1. [Software Factories And The Agentic Moment](https://factory.strongdm.ai/) - Justin McCarthy, Feb 6, 2026
2. [Built by Agents, Tested by Agents, Trusted by Whom?](https://law.stanford.edu/2026/02/08/built-by-agents-tested-by-agents-trusted-by-whom/) - Stanford CodeX, Feb 8, 2026
3. [How StrongDM's AI team build serious software without even looking at the code](https://simonwillison.net/2026/Feb/7/software-factory/) - Simon Willison, Feb 7, 2026
4. [The Five Levels: from Spicy Autocomplete to the Dark Factory](https://simonwillison.net/2026/Jan/28/the-five-levels/) - Dan Shapiro via Simon Willison, Jan 28, 2026
5. DeepWiki analysis of [strongdm/attractor](https://deepwiki.com/strongdm/attractor)
6. [StrongDM's AI Team Builds Software Without Human Code](https://coreiten.com/en/article/strongdms-ai-team-builds-software-without-human-code) - Coreiten, Feb 7, 2026
7. [The "Lights-Out" Era](https://coderlegion.com/11345/the-lights-out-era-why-strongdm-just-banned-humans-from-writing-code) - Coder Legion, Feb 10, 2026
