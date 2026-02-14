# Research Insights Summary

This document consolidates findings from 4 comprehensive research analyses conducted via Perplexity AI, totaling approximately **25,000 words** of best practices, patterns, and real-world insights.

---

## Research #1: Image Manipulation Techniques

**Source:** Perplexity AI research on common image manipulation techniques for AI workflows  
**Word Count:** ~6,000 words  
**Date:** 2026-02-06

### Key Findings

#### Tier 1: Universal Operations (Used in Nearly Every Pipeline)
- **Resizing & Scaling**: Most common operation; models require consistent input dimensions
  - YOLO: 640×640
  - Vision transformers: 224×224 or 384×384
  - Methods: Bilinear (smooth), bicubic (quality), nearest-neighbor (fast, blocky)
- **Normalization**: Critical for training stability
  - Min-max scaling: [0, 1]
  - Z-score: Mean and std deviation
- **Format Conversion**: Daily operation
  - WebP: 20-80% space savings over JPEG/PNG
  - AVIF: Even better compression, 3-5× slower encoding
  - 95% browser support for WebP, 75% for AVIF (2026)
- **Cropping**: Remove unwanted regions or focus on subject
  - Fixed-region, center, random (augmentation), smart/content-aware

#### Tier 2: High-Frequency Operations (Used in Most Pipelines)
- **Color Space Conversion**: RGB, BGR, grayscale, HSV, LAB, CMYK
  - OpenCV loads as BGR by default → RGB conversion is one-liner
- **Data Augmentation**: Expand datasets, reduce overfitting
  - Geometric: Flips, rotations, affine transforms, random crops
  - Photometric: Brightness, contrast, saturation, hue jitter
  - Advanced: CutMix, Mixup, mosaic
- **Background Removal**: AI-powered, bulk operations
  - E-commerce: 20,000-30,000 images/month processed
- **Quality/Compression Optimization**: Balance size vs quality
  - Lossy (JPEG quality), lossless (PNG optimization), modern codecs

#### Tier 3: Common Specialized Operations
- **Masking**: Binary/grayscale regions of interest
  - Selective editing, segmentation, inpainting, compositing
  - Alpha channels for per-pixel transparency
- **Compositing & Blending**: Combine multiple layers
  - Alpha blending: α×A + (1-α)×B
  - Watermarks, lifestyle images, AI + real photo combination
- **Sharpening & Noise Reduction**: Post-processing
  - Gaussian blur, median filtering, AI-powered (Topaz Gigapixel)
  - Unsharp masking for programmatic sharpening
- **Color Correction & Grading**: Consistent look
  - Exposure, white balance, contrast curves, saturation
  - Histogram equalization, CLAHE

#### Tier 4: Advanced/AI-Specific Operations
- **Upscaling & Super-Resolution**: AI-powered detail prediction
  - 2×-4× resolution increase
  - Real-ESRGAN, Magic Image Refiner
  - 1024px → 2048px+ in production
- **Inpainting**: Fill missing/damaged regions
  - Fix AI artifacts (e.g., malformed hands)
  - Object removal, reconstruction
  - NVIDIA partial convolution, diffusion-based
- **Outpainting (Uncropping)**: Extend beyond borders
  - Generate matching context
  - Vertical ↔ horizontal conversion
  - Diffusion models for contextual extension
- **Style Transfer & Domain Adaptation**: Modify surface characteristics
  - Color, texture preservation of structure
  - Day-to-night, synthetic-to-real
  - Histogram matching, intensity standardization

### Priority by Workflow

| Workflow | Top Techniques |
|----------|---------------|
| AI model pre-processing | Resize, normalize, color space conversion, augmentation, dataset splitting |
| Post-processing AI output | Upscaling, inpainting, sharpening, color correction, noise reduction, outpainting |
| Platform/format preparation | Format conversion, compression optimization, responsive resizing, cropping, metadata stripping |
| Batch automation | Background removal, auto-crop, recolor, format conversion, watermarking, padding/centering |

### Key Libraries
- **Pillow (PIL)**: Python - Simple API for basics
- **OpenCV**: Python/C++ - Full CV toolkit
- **Albumentations**: Python - Fast augmentation pipeline
- **Sharp**: Node.js - High-performance web pipelines
- **Cloudinary**: API/CDN - Cloud-based auto-processing
- **torchvision.transforms**: PyTorch - Model-training transforms

### Application to Project
- **Focus on Tier 1-2 first**: Cover 80%+ of use cases
- **Tier 3-4 as advanced features**: Differentiation and power-user capabilities
- **Document by tier**: Organize ImageSorcery skill references this way
- **Integration with fal.ai**: Pre-processing before generation, post-processing after

---

## Research #2: Claude Plugin/Skill Best Practices

**Source:** Perplexity AI research on Claude AI plugins, skills, and MCP servers  
**Word Count:** ~8,000 words  
**Date:** 2026-02-06

### Key Findings

#### Token Budget Reality
- **Pre-Tool Search**: 73 MCP tools = 40k tokens before any work
- **With Tool Search**: 85% reduction (77k → 8.7k tokens) via lazy-loading
- **Target**: Keep tool descriptions <10-15% of context window
- **Skill Frontmatter**: 30-50 tokens per skill (metadata only)
- **Full SKILL.md**: Loaded only when triggered
- **Recommended Limits**:
  - Main SKILL.md: **<500 lines** (ideally 300-500)
  - Total skill content: **<5,000 words** (~800 lines)
  - Beyond 500 lines: Apply progressive disclosure pattern

#### Progressive Disclosure Architecture (Three-Tier Loading)
1. **Metadata Phase** (Always loaded): 30-50 tokens
   ```yaml
   ---
   name: systematic-debugger
   description: Use when user asks to fix bugs. Enforces root-cause analysis before code.
   ---
   ```

2. **Instruction Phase** (Loaded on trigger): Core SKILL.md content
   - Quick start guide
   - Essential workflows

3. **Reference Phase** (Loaded on-demand): Detailed documentation in `references/`
   - Supporting scripts
   - Examples and edge cases

#### Token Optimization Techniques
1. **Consolidate related operations**: Don't expose `get_team_members`, `get_team_projects` separately
2. **Eliminate verbose schemas**: Reduce oneOf descriptions
3. **Reduce example arrays**: One representative example sufficient
4. **Use dynamic toolsets**: `search_tools` → `describe_tools` → `execute_tool` for 96% reduction

#### YAML Frontmatter Best Practices
```yaml
---
name: skill-name  # lowercase, hyphens only, max 64 chars
description: Third-person with trigger phrases. Maximum 1024 characters.
             Be specific about WHEN to use.
license: Complete terms in LICENSE.txt  # optional
---
```
- **Name**: Lowercase only, hyphens for separators
- **Description**:
  - Write in **third person** ("Use this skill when...")
  - Include **trigger phrases** matching user language
  - **Specific about context** (when vs. what)
  - Bad: "Helps with documents"
  - Good: "Use when user requests financial modeling for SaaS companies. Generates revenue projections, CAC/LTV calculations."

#### Content Structure
- **No preamble**: Start Quick Start immediately
- **Imperative language**: "Analyze..." not "This skill can analyze..."
- **Concrete input/output pairs**: Show don't tell
- **Consistent terminology**: Same terms throughout
- **Keep main SKILL.md <500 lines**: Move lengthy content to references/

#### Tool Parameter Design Best Practices
**Think top-down from workflows, not bottom-up from APIs**

❌ **Don't**: Expose raw API endpoints (requires 5 tool calls)
✅ **Do**: Combine into workflow-oriented tools (single call)

**Parameter Guidelines**:
1. Use Pydantic models for complex parameters
2. Optimize descriptions - treat as prompts for LLM
3. Include examples in descriptions
4. Keep names short (long names waste tokens)
5. Use action-oriented tool names: `fetch_data` not `data_fetcher`

**Tool Response Design**:
> "Every tool response is an opportunity to guide the model"

❌ **Bad**: `{"error": "Unauthorized"}`  
✅ **Good**: `{"error": "project_id 'abc123' not found", "suggestion": "Call list_projects()", "available_actions": [...]}`

#### Common Pitfalls to Avoid
1. **Oversized skills** (>500 lines in SKILL.md)
2. **Vague trigger descriptions**
3. **Nested references** (references/sub/deep/file.md)
4. **Noun-based tool names** (data_fetcher)
5. **Generic error messages** without guidance
6. **Mixing read and write** operations in same tool
7. **Hot path integration** (MCP on production-critical path)
8. **Loading all tool schemas** upfront
9. **Enabling too many skills** (<20-50 recommended simultaneously)

### Application to Project
- **Strict 500-line limit** on all SKILL.md files
- **Rich frontmatter descriptions** with trigger phrases
- **Progressive disclosure** with references/ directory
- **Workflow-oriented scripts**: Consolidate operations
- **Error responses guide next steps**: Actionable suggestions
- **Token budget tracking**: Audit before release

---

## Research #3: GitHub Copilot Plugin Architecture

**Source:** Perplexity AI research on GitHub Copilot plugins  
**Word Count:** ~5,000 words  
**Date:** 2026-02-06

### Key Findings

#### Core Architecture
**GitHub Copilot Extensions** = GitHub App + Agent Endpoint + Optional MCP Integration

**Directory Structure** (from official examples):
```
copilot-extension/
├── src/
│   ├── agent.js (or agent.go)     # Main agent endpoint handler
│   ├── verification.js             # Request verification logic
│   ├── models/                     # Schema definitions
│   ├── handlers/                   # Event and API handlers
│   └── skills/                     # Optional skill implementations
├── tests/ (unit/, integration/)
├── .github/
│   ├── copilot-instructions.md     # Repository-wide instructions
│   └── instructions/               # Path-specific instructions
├── app.manifest.json               # GitHub App manifest
└── README.md
```

#### Skills vs MCP Servers

| Aspect | **MCP Servers** | **Copilot Skills** |
|--------|-----------------|-------------------|
| **Definition** | External tools following MCP standard | Embedded functions within extension |
| **Scope** | Broad, reusable across AI tools | Specific to your extension |
| **Configuration** | `mcp.json` or `.github/mcp.json` | Defined within extension code |
| **When to Use** | Databases, APIs, external services | Extension-specific logic, custom rules |
| **Examples** | GitHub MCP (issues/PRs), Playwright, Figma | Random data, custom calculations, internal workflows |
| **Support** | ✅ Tools only (not resources/prompts yet) | ✅ Full support |

#### MCP Server Configuration
```json
{
  "servers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    },
    "custom-server": {
      "type": "stdio",
      "command": "node",
      "args": ["./mcp-servers/custom-server.js"],
      "env": {
        "API_KEY": "${secrets.API_KEY}"
      }
    }
  }
}
```

**Default MCP Servers** (auto-configured):
- GitHub MCP Server: Issues, PRs, repository data
- Playwright MCP Server: Web interaction (localhost only by default)

#### When to Build MCP vs Extension
**Build MCP Server when**:
- Want reusability across AI tools (Claude, Cursor, Windsurf)
- Providing general-purpose tools (DB queries, API calls)
- Users configure once, use everywhere
- Example: Database connector, Slack integration

**Build Copilot Extension when**:
- Need GitHub-specific integration
- Want branded, user-facing agent experience
- Need complex multi-turn conversations
- Want GitHub Marketplace presence
- Example: Code review agent, documentation generator

#### Testing Strategies
1. **Local Testing**: `gh extension install copilot-extensions/gh-debug-cli`
   ```bash
   gh debug-copilot --agent-url http://localhost:3000/agent
   ```

2. **Unit Testing**: Request verification, handler logic
3. **Integration Testing**: Multi-step tasks with MCP servers
4. **E2E Testing**: Complete workflows (triage → branch → implement → PR)
5. **Custom Instructions Testing**: Verify repository coding standards

#### Agentic Design Patterns
1. **Multi-Step Reasoning with Checkpoints**: User review at critical points
2. **Context Engineering**: `.github/copilot-instructions.md` for repository standards
3. **Self-Correcting Loops**: Validate → adjust → retry (max attempts)
4. **Decomposition Strategy**: Break complex tasks into subtasks
5. **Model Selection**: Choose based on task complexity (o1-preview, gpt-4o, gpt-4o-mini)

### Application to Project
- **Use MCP for ImageSorcery**: Reusable across platforms
- **Use Skills for fal.ai**: Plugin-specific business logic
- **Repository instructions**: `.github/copilot-instructions.md` for agent context
- **Testing strategy**: gh-debug-cli + unit + integration + E2E
- **Agentic patterns**: Checkpoints, self-correction, decomposition

---

## Research #4: Agentic AI Workflows & CI/CD

**Source:** Perplexity AI research on agentic AI workflows in GitHub Actions  
**Word Count:** ~6,000 words  
**Date:** 2026-02-06

### Key Findings

#### Continuous AI Pattern
**Dominant Model**: Fleets of small, specialized agents (not one general-purpose agent)

**Common Agent Archetypes**:
- **Doc-sync agent**: Reads docstrings, compares to implementation, opens PRs with fixes
- **Report-generation agent**: Summarizes activity, highlights trends
- **Performance regression agent**: Flags regressions in critical paths
- **Semantic regression agent**: Detects user flow regressions impossible to express as rules

**Philosophy**: Shift chores from "when someone remembers" to "every commit" or "every day"

#### Actions-First Design
**GitHub's `gh aw` Prototype Pattern**:
1. YAML frontmatter: Triggers, permissions, available tools
2. Markdown instructions: Plain-language prompts
3. Compilation to standard GitHub Action via `gh aw compile`
4. Standard Actions execution: Logs, security, triggers

```markdown
---
on: daily
permissions: read
safe-outputs:
  create-issue:
    title-prefix: "[report] "
---
Analyze recent repository activity and create upbeat
daily status report. Create an issue with the report.
```

#### Reliability Principles
- **Containerized execution**: Isolated environments for reproducibility
- **Read-only by default**: Write operations gated via safe-output processing
- **Transparent logs**: All runs visible in standard Actions logs
- **Pull requests as primary output**: Agents create PRs, not direct commits
- **Debuggability wins over complexity**: Transparent, auditable, diff-based

#### Queue Management
**Why Agents Need Task Queues**: Single request fans out to multiple LLM calls, DB writes, API requests. Without queue: race conditions, duplicate processing, no visibility.

**Essential Queue Features**:
- **Priority levels**: High (user-facing) → Normal → Low (background)
- **Rate-limit tracking**: Monitor requests/min and tokens/min
- **Context carriage**: Each task stores full conversation history
- **Deduplication**: Hash context before enqueueing
- **Dead-letter queues**: Failed tasks preserved with full context

**Context Loss is Most Expensive Failure**: Rebuilding context costs tokens and time; reconstructed context may not match → inconsistent decisions. Queue becomes source of truth.

#### Error Handling & Retry Strategies

**Error Classification**:
| Error Type | Examples | Strategy |
|------------|----------|----------|
| Transient | 429 rate limits, network timeouts, 503 | Retry with exponential backoff |
| Permanent | 401 invalid key, 400 malformed request | Log, alert, fail fast |
| Logical | Valid but wrong output, infinite loops | Circuit breaker + human escalation |

**Exponential Backoff with Jitter**:
- Start: 1 second delay
- Double each retry: 1s → 2s → 4s → 8s
- Add jitter: Randomize ±25% to prevent thundering herd
- Cap max delay: 30-60 seconds
- Limit attempts: 3-5 tries

**Circuit Breaker**:
- **Closed**: Requests pass through, failures counted
- **Open**: Immediate rejection, service gets breathing room
- **Half-open**: After timeout, test recovery with single request

**Additional Patterns**:
- **Idempotency**: Every step safely re-runnable with idempotency keys
- **Correlation IDs**: Single ID across all workflow steps for traceability
- **Human escalation**: Review when confidence low or operation destructive
- **Checkpointing**: Persist state at each step; partial failures don't restart entire workflow

#### Monitoring & Observability

**Five Pillars** (Azure Agent Factory Model):
1. **Continuous monitoring**: Track actions, decisions, interactions in real-time
2. **Tracing**: Capture execution flows including reasoning, tool selection, collaboration
3. **Logging**: Record decisions, tool calls, state changes
4. **Evaluation**: Assess outputs for quality, safety, compliance, alignment
5. **Governance**: Enforce policies ensuring ethical, safe, regulatory compliance

**Implementation Practices**:
- **Adopt OpenTelemetry**: Portable across Datadog, Grafana, Langfuse
- **Tag agent-specific metadata**: Model version, token count, tool used, agent/session ID
- **Trace multi-agent workflows**: Capture every handoff, retry, branch
- **Log prompts, responses, tool calls**: Replay failures, spot regressions
- **Add monitoring to CI/CD**: Catch drift/broken prompts before production
- **Set up real-time alerts**: Slack/PagerDuty integration
- **Test observability in staging**: Validate telemetry under realistic workloads

**What to Log Per Agent Step**:
- Timestamp, trace ID, agent ID
- Step name and tool call with inputs/outputs
- Token count and model version
- Latency and retry count
- Status (success/failure) with error details
- Reasoning path or decision rationale

**Detecting Silent Failures**:
- **Infinite loops**: Same tool called repeatedly with no progress
- **Context abandonment**: Agent forgets original goal mid-task
- **Drift**: Gradual degradation in output quality over time
- **Runaway costs**: Token usage spiraling from repetitive behavior

### Application to Project
- **Fleet of specialized agents**: doc-sync, test-plugin, performance-check, media-workflow
- **Actions-first compilation**: Markdown prompts → GitHub Actions YAML
- **Queue management**: Priority levels, context carriage, DLQ
- **Error handling**: Exponential backoff, circuit breakers, human escalation
- **OpenTelemetry instrumentation**: Trace all agent operations
- **Structured logging**: Every tool call, token usage, reasoning path

---

## Cross-Research Synthesis

### Unified Design Principles

1. **Progressive Disclosure** (Research #2 + #3)
   - Metadata (30-50 tokens) → Instructions (<500 lines) → References (on-demand)
   - Applies to: Skills, documentation, tool descriptions

2. **Workflow-Oriented Design** (Research #2 + #3)
   - Think top-down from user workflows, not APIs
   - Consolidate related operations
   - Applies to: PowerShell scripts, tool design, agent tasks

3. **Observable from Day One** (Research #4)
   - Don't bolt monitoring on later
   - OpenTelemetry, structured logging, tracing
   - Applies to: All scripts, agents, workflows

4. **Error Responses as Prompts** (Research #2 + #4)
   - Guide next steps with specific suggestions
   - Include available actions
   - Applies to: PowerShell scripts, tool responses, agent outputs

5. **Token Consciousness** (Research #2)
   - Every design decision considers token cost
   - Aggressive extraction to references
   - Applies to: Skills, documentation, tool descriptions

6. **Reliability Patterns** (Research #4)
   - Exponential backoff, circuit breakers, idempotency
   - Queue management with DLQ
   - Applies to: All async operations, agent workflows

### Priority Matrix

| Component | Research Foundation | Priority | Token Budget | Testing Strategy |
|-----------|-------------------|----------|--------------|------------------|
| fal.ai Skill | #2, #3 | High | <500 lines | Unit + Integration |
| ImageSorcery Skill | #1, #2, #3 | High | <500 lines | Integration + E2E |
| Workflow Builder | #2, #3 | Medium | <500 lines | Unit + E2E |
| Agentic Capabilities | #3, #4 | High | <500 lines | E2E + Observability |
| PowerShell Scripts | #2, #4 | High | N/A | Unit + Integration |
| GitHub Actions | #4 | Medium | N/A | Integration + E2E |

---

## Research Application Checklist

### For Every Skill
- [ ] YAML frontmatter <1024 chars with trigger phrases
- [ ] Main SKILL.md <500 lines
- [ ] Progressive disclosure with references/
- [ ] Imperative language throughout
- [ ] Concrete input/output examples
- [ ] No nested references

### For Every PowerShell Script
- [ ] Workflow-oriented (consolidates operations)
- [ ] Error responses guide next steps
- [ ] Action-oriented naming (Verb-Noun pattern)
- [ ] Exponential backoff for retries
- [ ] Structured error output
- [ ] Help comments with examples

### For Every Agent
- [ ] Specialized (single chore/check/rule)
- [ ] Outputs PRs (not direct commits)
- [ ] Read-only by default
- [ ] Transparent logging
- [ ] Circuit breakers for failures
- [ ] Queue with DLQ
- [ ] OpenTelemetry instrumentation

### For Documentation
- [ ] Quick Start has no preamble
- [ ] Consistent terminology
- [ ] Links to references instead of inlining
- [ ] Spell-checked and grammar-reviewed
- [ ] All links validated

---

## Research Credits

All research conducted via **Perplexity AI** on **2026-02-06**

### Sources Cited Across Researches
- Official GitHub Documentation
- Anthropic Claude Documentation
- Microsoft Azure Agent Factory
- Block's MCP Playbook
- Speakeasy Dynamic Toolsets
- GitHub Next (Continuous AI)
- Various technical blogs and papers

**Total Research Investment**: ~4 hours of research + analysis  
**Total Word Count**: ~25,000 words  
**Application Impact**: Every design decision in this project

---

*Last Updated: 2026-02-06*  
*For implementation details, see the [project README](../README.md)*
