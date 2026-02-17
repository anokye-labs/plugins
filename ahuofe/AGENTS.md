# Ahuofe Plugin - Agent Operating Model

**Last Updated:** 2026-02-06
**Project:** Ahuofe — Media Generation & Manipulation Plugin for the Anokye System

---

## 🎯 Working in GitHub Issue Context

**CRITICAL:** All agent sessions working on this plugin must be in the context of a specific GitHub issue.

### Issue Context Requirements

When starting work:
1. **Identify the GitHub issue** you're working on
2. **Reference the issue** in your session context
3. **Link commits** to the issue using `Closes #X` or `Fixes #X` in commit messages
4. **Update issue status** as work progresses

### Finding Your Issue

```powershell
# List all open issues
gh issue list --repo anokye-labs/plugins

# View specific issue
gh issue view <number> --repo anokye-labs/plugins
```

### Commit Message Format

```
<type>(<scope>): <short description>

<detailed description>

Closes #<issue-number>
```

**Example:**
```
feat(ahuofe): Add Invoke-FalGenerate.ps1 script

- Implement queue mode with progress monitoring
- Add async mode option
- Include error handling with retry logic

Closes #42
```

---

## 🤖 Continuous AI Operating Model

This plugin follows the **Continuous AI** pattern — a fleet of specialized agents rather than one general-purpose agent.

### Agent Archetypes

#### 1. Media Workflow Agent
- **Purpose:** Orchestrate fal.ai generation + ImageSorcery manipulation workflows
- **Output:** Generated media artifacts
- **Trigger:** On user request via Copilot

#### 2. Doc-Sync Agent
- **Purpose:** Read function docstrings, compare to implementation, detect mismatches
- **Output:** Opens PRs with fixes
- **Trigger:** On commit to main branch

#### 3. Test-Plugin Agent
- **Purpose:** Validate plugin functionality across scenarios
- **Output:** Test results and coverage reports
- **Trigger:** On PR or scheduled

#### 4. Performance Regression Agent
- **Purpose:** Flag regressions in API latency or media quality
- **Output:** Comments on PRs or creates issues
- **Trigger:** On PR or push to main

---

## 🏗️ Actions-First Design

All agents follow the **Actions-first design pattern**:

### Structure
```yaml
---
on: [trigger]
permissions: read
safe-outputs:
  create-issue:
    title-prefix: "[agent-name] "
---
Plain-language instructions telling the agent what to do.
```

### Key Principles
- **Read-only by default** — Write operations gated via safe-output processing
- **PRs as primary output** — Agents don't make autonomous commits
- **Containerized execution** — Reproducibility and safety
- **Transparent logs** — All runs visible in standard Actions logs

---

## 🔄 Error Handling Patterns

### Exponential Backoff with Jitter

For all transient errors (429 rate limits, network timeouts, 503 unavailability):

```
Delay = min(MAX_DELAY, BASE_DELAY * 2^(attempt - 1)) ± jitter

Where:
- BASE_DELAY = 1 second
- MAX_DELAY = 30-60 seconds
- jitter = ±25% randomization
- Max attempts = 3-5
```

### Error Classification

| Error Type | Examples | Strategy |
|------------|----------|----------|
| **Transient** | 429 rate limits, timeouts, 503 | Retry with exponential backoff |
| **Permanent** | 401 invalid API key, 400 malformed | Log, alert, fail fast |
| **Logical** | Valid but wrong output, infinite loops | Circuit breaker + human escalation |

### Additional Patterns

- **Idempotency** — Every step safely re-runnable
- **Correlation IDs** — Single ID across all workflow steps for traceability
- **Human escalation** — Escalate when confidence low or operation destructive
- **Checkpointing** — Persist state at each step; partial failures don't restart entire workflow

---

## 📁 Plugin Structure

```
ahuofe/
├── .github/plugin/plugin.json # Copilot CLI plugin metadata
├── AGENTS.md                  # This file — agent operating model
├── README.md                  # Plugin overview and usage
├── scripts/
│   ├── FalAi.psm1             # Shared module (auth, retry, upload, queue)
│   ├── Invoke-FalGenerate.ps1 # Image generation
│   ├── Invoke-FalVideoGen.ps1 # Video generation
│   └── ...                    # 21 scripts total
├── skills/
│   ├── fal-ai/                # AI generation skill (4 references)
│   ├── fal-workflow/          # Workflow orchestration (5 references)
│   ├── image-sorcery/         # Local image processing (6 references)
│   └── media-agents/          # Fleet-pattern agents (4 references)
├── tests/                     # Pester 5 test suites
└── docs/                      # Project documentation
```

---

## 🔒 Reliability Principles

- **Read-only by default** — Agents operate in read-only mode unless explicitly granted write permissions
- **PRs as primary output** — Human review on all changes
- **Debuggability over complexity** — Choose the more transparent, auditable approach
- **Structured logging** — Every log entry includes model version, token count, tool used, agent ID

---

## 🚀 Getting Started

1. **Review** `README.md` and skill definitions in `skills/`
2. **Find your issue** using `gh issue list`
3. **Follow error handling patterns** documented above
4. **Use `FalAi.psm1`** shared module for all API interactions
5. **Create PRs** not direct commits
6. **Link PRs to issues** with `Closes #X`
