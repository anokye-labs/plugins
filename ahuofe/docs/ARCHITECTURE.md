# Architecture

This document describes the system architecture of the Copilot Media Plugins extension.

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Copilot                           │
│                      (Chat Interface)                           │
└──────────────────────────┬──────────────────────────────────────┘
                           │ User request
                    ┌──────▼──────┐
                    │ Skill Router │
                    └──┬────┬───┬─┘
         ┌─────────────┘    │   └─────────────┐
         ▼                  ▼                  ▼
┌────────────────┐ ┌────────────────┐ ┌────────────────┐
│   fal-ai Skill │ │ image-sorcery  │ │  media-agents  │
│                │ │    Skill       │ │    Skill       │
│ AI Generation  │ │ Local Image    │ │ Multi-Step     │
│ (cloud)        │ │ Processing     │ │ Orchestration  │
└───────┬────────┘ └───────┬────────┘ └───────┬────────┘
        │                  │                   │
        ▼                  ▼                   │
┌────────────────┐ ┌────────────────┐          │
│  FalAi.psm1    │ │  MCP Server    │          │
│ (Shared Module)│ │ (Python/stdio) │          │
│                │ │                │          │
│ • Auth         │ │ • OpenCV       │          │
│ • HTTP + Retry │ │ • YOLO         │          │
│ • CDN Upload   │ │ • EasyOCR      │          │
│ • Queue Poll   │ │                │          │
└───────┬────────┘ └────────────────┘          │
        │                                      │
        ▼                                      │
┌────────────────┐                             │
│  fal.ai Cloud  │◄────────────────────────────┘
│  REST API      │  (media-agents coordinates
│                │   both fal-ai and image-sorcery)
│ • Flux, Kling  │
│ • Veo, SD      │
│ • Queue system │
└────────────────┘
```

## Three-Skill Architecture

The extension exposes three complementary skills that Copilot selects based on the user's request:

### 1. fal-ai Skill

**Purpose:** Generate media using cloud AI models.

- Text-to-image (Flux, Stable Diffusion, Ideogram)
- Text-to-video (Veo, Kling, Minimax)
- Image-to-video (Kling, Veo)
- Image upscaling, inpainting, style transfer

**Implementation:** PowerShell scripts in `scripts/` that call fal.ai REST APIs via the shared `FalAi.psm1` module.

**Skill definition:** [`skills/fal-ai/SKILL.md`](../skills/fal-ai/SKILL.md)

### 2. image-sorcery Skill

**Purpose:** Process and analyze images locally using deterministic tools.

- Transform: resize, crop, rotate, blur, fill, overlay
- Annotate: draw rectangles, circles, lines, arrows, text
- Analyze: object detection (YOLO), open-vocabulary search, OCR, metadata

**Implementation:** Python-based MCP server communicating via stdio. Configured in `.mcp.json` at the repository root.

**Skill definition:** [`skills/image-sorcery/SKILL.md`](../skills/image-sorcery/SKILL.md)

### 3. media-agents Skill

**Purpose:** Orchestrate complex multi-step media workflows.

- Fleet-pattern dispatch for parallel independent tasks
- Sequential chaining for dependent operations
- Checkpoint/resume for fault tolerance
- Quality validation after each stage

**Implementation:** Agent coordination patterns documented in the skill definition; uses both fal-ai and image-sorcery as sub-tools.

**Skill definition:** [`skills/media-agents/SKILL.md`](../skills/media-agents/SKILL.md)

## Shared Module — FalAi.psm1

All fal.ai scripts share a single PowerShell module (`scripts/FalAi.psm1`) that centralizes cross-cutting concerns:

```
┌────────────────────────────────────────────┐
│               FalAi.psm1                   │
├────────────────────────────────────────────┤
│ Get-FalApiKey      │ Load FAL_KEY from     │
│                    │ $env or .env file     │
├────────────────────┼──────────────────────│
│ Invoke-FalApi      │ HTTP wrapper with     │
│                    │ auth headers, retry   │
│                    │ on 429/5xx, error     │
│                    │ parsing               │
├────────────────────┼──────────────────────│
│ Send-FalFile       │ 2-step CDN upload:    │
│                    │ get token → upload    │
│                    │ file → return URL     │
├────────────────────┼──────────────────────│
│ Wait-FalJob        │ Queue submit → poll   │
│                    │ status → retrieve     │
│                    │ result with timeout   │
├────────────────────┼──────────────────────│
│ ConvertTo-FalError │ Parse error responses │
│                    │ from multiple formats │
└────────────────────┴──────────────────────┘
```

**Design decisions:**
- Scripts import the module; no manual setup needed.
- API key resolution follows a priority chain: `$env:FAL_KEY` → `.env` file → error.
- Retry logic uses exponential backoff (2s → 4s → 8s) with a maximum of 3 attempts.
- All HTTP responses are parsed into `PSCustomObject` for consistent downstream handling.

## Data Flow

### Synchronous Generation

```
User Request
    │
    ▼
Invoke-FalGenerate.ps1
    │
    ├─ Import-Module FalAi.psm1
    ├─ Get-FalApiKey → FAL_KEY
    ├─ Invoke-FalApi POST https://fal.run/{model}
    │      ├─ Auth header: Key {FAL_KEY}
    │      ├─ Body: { prompt, image_size, ... }
    │      └─ Response: { images: [{ url, width, height }] }
    │
    ▼
PSCustomObject Result
    │
    ▼
User receives image URLs
```

### Queue-Based Generation (Video)

```
User Request
    │
    ▼
Invoke-FalGenerate.ps1 -Queue
    │
    ├─ Import-Module FalAi.psm1
    ├─ Wait-FalJob
    │      ├─ POST https://queue.fal.run/{model}
    │      │      → { request_id: "..." }
    │      │
    │      ├─ GET .../requests/{id}/status  (poll loop)
    │      │      → { status: "IN_QUEUE" }
    │      │      → { status: "IN_PROGRESS" }
    │      │      → { status: "COMPLETED" }
    │      │
    │      └─ GET .../requests/{id}  (retrieve result)
    │             → { video: { url: "..." } }
    │
    ▼
PSCustomObject Result
    │
    ▼
User receives video URL
```

### Multi-Step Workflow (Fleet Pattern)

```
User Request: "Create 3 social media variants"
    │
    ▼
media-agents Skill
    │
    ├─ Step 1: Analyze input (dimensions, format, content)
    │
    ├─ Step 2: Plan pipeline
    │      ├─ Variant 1: 1200×628 (Facebook)
    │      ├─ Variant 2: 1080×1080 (Instagram)
    │      └─ Variant 3: 1200×675 (Twitter)
    │
    ├─ Step 3: Fleet dispatch (parallel)
    │      ├─ Agent 1 → fal-ai generate → ImageSorcery resize
    │      ├─ Agent 2 → fal-ai generate → ImageSorcery resize
    │      └─ Agent 3 → fal-ai generate → ImageSorcery resize
    │
    ├─ Step 4: Validate all outputs
    │      ├─ get_metainfo → check dimensions
    │      ├─ detect → verify content
    │      └─ file size check
    │
    └─ Step 5: Aggregate and report
           ├─ ✅ Facebook: 1200×628, 145KB
           ├─ ✅ Instagram: 1080×1080, 182KB
           └─ ✅ Twitter: 1200×675, 138KB
```

## Fleet Pattern

The media-agents skill uses a **fleet pattern** for orchestrating complex workflows:

| Role | Responsibility | Tools Used |
|------|---------------|------------|
| **Generator** | Create base media via AI models | fal-ai skill |
| **Processor** | Transform media (resize, crop, convert) | ImageSorcery MCP |
| **Validator** | Check quality, dimensions, format | ImageSorcery `get_metainfo`, `detect` |
| **Optimizer** | Compress, convert formats | ImageSorcery `resize` |

**Key principles:**
- Independent subtasks run in parallel.
- Dependent steps are chained sequentially (output → next input).
- Checkpoints are saved after each mutation for fault tolerance.
- Partial failures preserve successful results.

## Testing Strategy

Tests are organized in tiers of increasing scope and cost:

```
┌─────────────────────────────────────────┐
│            Quality Gates                │  ← Pre-merge checks
├─────────────────────────────────────────┤
│          End-to-End Tests               │  ← Full workflows with real APIs
├─────────────────────────────────────────┤
│         Integration Tests               │  ← Module interactions, mocked APIs
├─────────────────────────────────────────┤
│           Unit Tests                    │  ← Individual functions, fully mocked
└─────────────────────────────────────────┘
```

| Tier | Location | Scope | External Calls |
|------|----------|-------|----------------|
| **Unit** | `tests/unit/` | Individual functions and parameter validation | Fully mocked |
| **Integration** | `tests/integration/` | Module imports, function chaining, error paths | Mocked API responses |
| **E2E** | `tests/e2e/` | Complete workflows from script invocation to result | Real fal.ai API (requires `FAL_KEY`) |
| **Evaluation** | `tests/evaluation/` | Output quality assessment | Real API + quality metrics |
| **Gates** | `tests/gates/` | Pre-merge quality checks | Varies by gate |

All tests use [Pester 5](https://pester.dev/) and can be run with:

```powershell
Invoke-Pester -Path tests/
```

---

## v2: PR-Driven Iterative Media Generation

The following sections describe the v2 architecture, which adds a TypeScript generation pipeline, reusable GitHub Actions workflows, JSON Schema validation, and a lineage viewer on top of the existing Copilot skills and PowerShell scripts.

### v2 Directory Structure

```
ahuofe/
├── pipeline/                  # NEW: TypeScript generation engine
│   ├── src/
│   │   ├── stages/            # 6-stage pipeline
│   │   │   ├── load-yaml.ts
│   │   │   ├── compile-prompt.ts
│   │   │   ├── reference-sheet.ts
│   │   │   ├── generate-panel.ts
│   │   │   ├── evaluate-drift.ts
│   │   │   └── loop.ts
│   │   ├── actions/           # GitHub Actions integration layer
│   │   │   ├── parse-comment.ts
│   │   │   ├── post-results.ts
│   │   │   ├── diff-brand.ts
│   │   │   ├── prune-generations.ts
│   │   │   └── request-approval.ts
│   │   ├── local/             # Local iteration mode (no API keys)
│   │   │   ├── validate-yaml.ts
│   │   │   ├── mock-generate.ts
│   │   │   └── preview-prompt.ts
│   │   ├── fal/               # fal.ai integration with retention controls
│   │   │   ├── client.ts
│   │   │   ├── cleanup.ts
│   │   │   └── config.ts
│   │   ├── config.ts
│   │   ├── types.ts
│   │   └── index.ts
│   ├── package.json
│   └── tsconfig.json
├── schema/                    # NEW: JSON Schema for brand YAML validation
│   ├── entity.schema.json
│   ├── shared.schema.json
│   └── preset.schema.json
├── workflow-templates/        # NEW: Reusable GitHub Actions workflows
│   ├── ahuofe-generate.yml
│   ├── ahuofe-evaluate.yml
│   └── ahuofe-cleanup.yml
├── viewer/                    # NEW: Lineage browser (static site)
│   ├── index.html
│   ├── embed.js
│   └── assets/
├── scripts/                   # Existing: PowerShell scripts
│   ├── FalAi.psm1
│   └── ...
├── skills/                    # Existing: Copilot skill definitions
│   ├── fal-ai/
│   ├── fal-workflow/
│   ├── image-sorcery/
│   └── media-agents/
├── docs/                      # Updated: Documentation
│   ├── ARCHITECTURE.md
│   ├── SETUP_GUIDE.md
│   ├── LOCAL_ITERATION.md
│   └── RESEARCH_INSIGHTS.md
└── README.md
```

### Cross-Repo Binding Model

Ahuofe is a **plugin** that lives in `anokye-labs/plugins/ahuofe`. Brand files do NOT live in the plugin. Instead, project repos (e.g., `anokye-system`) contain their own `brand/` directories with entity YAML files, and bind to the plugin via a `.ahuofe.yaml` config file at the repo root.

```
┌──────────────────────────────────┐    ┌──────────────────────────────────┐
│  anokye-labs/plugins/ahuofe      │    │  anokye-labs/anokye-system       │
│  (THE PLUGIN — reusable)         │    │  (A PROJECT REPO — uses plugin)  │
│                                  │    │                                  │
│  pipeline/    → generation code  │◄───│  .ahuofe.yaml  → binding config │
│  schema/      → validation rules │    │  brand/         → YAML entities  │
│  workflow-templates/ → Actions   │◄───│  .github/workflows/ahuofe.yml   │
│  viewer/      → lineage browser  │    │                   (thin wrapper) │
│  scripts/     → PowerShell       │    │                                  │
│  skills/      → Copilot          │    │                                  │
└──────────────────────────────────┘    └──────────────────────────────────┘
```

The `.ahuofe.yaml` config specifies:
- Which plugin repo/ref to use
- Where brand files live in the project
- Model selections and cost thresholds per stage
- Approval gate configuration
- fal.ai retention policies
- Secret name mappings

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for the full config reference.

### Ephemeral Storage Model

Generated images flow through a short lifecycle designed to avoid repo bloat and external storage costs:

```
fal.ai CDN              Actions Runner             PR Branch              main
─────────               ──────────────             ─────────              ────
  │                          │                         │                    │
  │  1. Generate image       │                         │                    │
  │◄─── POST with ephemeral  │                         │                    │
  │     lifecycle headers    │                         │                    │
  │                          │                         │                    │
  │  2. Download immediately │                         │                    │
  │────────────────────────► │                         │                    │
  │                          │                         │                    │
  │  3. Explicit DELETE      │  4. git commit + push   │                    │
  │◄─────────────────────────│────────────────────────►│                    │
  │  (belt-and-suspenders)   │                         │                    │
  │                          │  5. Prune old gens      │                    │
  │  6. CDN auto-expires     │────────────────────────►│ (git rm + commit)  │
  │     (safety net)         │                         │                    │
  │                          │                         │  7. Squash merge   │
  │                          │                         │───────────────────►│
  │                          │                         │  (only HEAD files) │
  │                          │                         │                    │
  │                          │                         │  8. Branch deleted  │
  │                          │                         X  (GC'd by git)    │
```

Key principles:
- **fal.ai never retains images** -- three layers of protection: lifecycle headers, explicit deletion, account-level settings
- **PR branch is a scratchpad** -- images are pruned after each stage escalation
- **Squash merge is essential** -- only files at HEAD (finalized images) land on main
- **Branch auto-deletion** -- once deleted, intermediate commits are unreachable and garbage-collected

### Pipeline Architecture

The TypeScript pipeline processes brand YAML files through six stages:

```
                    ┌─────────────┐
                    │  load-yaml  │  Read entity YAML + shared files
                    └──────┬──────┘  Resolve cross-references
                           │
                    ┌──────▼──────┐
                    │compile-prompt│  YAML → generation prompt text
                    └──────┬──────┘  Include drift checklist + negatives
                           │
                    ┌──────▼──────────┐
                    │ reference-sheet  │  Generate reference image (final only)
                    └──────┬──────────┘  Establishes visual baseline
                           │
                    ┌──────▼──────────┐
                    │ generate-panel   │  Call fal.ai with ephemeral headers
                    └──────┬──────────┘  Download + delete from CDN
                           │
                    ┌──────▼──────────┐
                    │ evaluate-drift   │  Compare output against brand spec
                    └──────┬──────────┘  Rule-based (draft) or vision (final)
                           │
                    ┌──────▼──────┐
                    │    loop     │  If drift score < threshold and
                    └──────┬──────┘  iterations remaining, go to generate
                           │
                     Pass / Max iterations
                           │
                    ┌──────▼──────┐
                    │   Output    │  Images + manifest + drift report
                    └─────────────┘
```

The pipeline supports three stage configurations with escalating cost and quality:

| Aspect | Draft | Review | Final |
|--------|-------|--------|-------|
| Model | nano-banana-2 | flux-pro | flux-pro/kontext/max/multi |
| Reference sheet | Skip | Skip | Generate first |
| Iterations | 1 | 1 | Up to 3 |
| Drift evaluation | Rule-based | Rule-based + summary | Claude vision |
| Approval required | No | Yes | Yes |

### PR-Driven Iteration Flow

```
 User edits brand YAML → pushes → opens PR
     │
     ▼
 ┌─── DRAFT (automatic, no approval) ──────────────────────────────┐
 │  diff-brand.ts detects changed entities                         │
 │  Pipeline runs with draft preset (cheap, fast)                  │
 │  Images committed to PR branch, gallery posted as PR comment    │
 └──────────────────────────────────────┬──────────────────────────┘
                                        │
     User reviews drafts, posts "@ahuofe review okyeame"
                                        │
 ┌─── REVIEW (approval gate) ──────────▼───────────────────────────┐
 │  Bot posts: "Review generation requested. Approve?"             │
 │  Authorized approver posts "@ahuofe approve"                    │
 │  Pipeline runs with review preset (mid-tier model)              │
 │  Old drafts pruned, review images committed, gallery updated    │
 └──────────────────────────────────────┬──────────────────────────┘
                                        │
     User reviews, posts "@ahuofe finalize okyeame"
                                        │
 ┌─── FINALIZE (approval gate) ────────▼───────────────────────────┐
 │  Bot posts: "Finalization requested. Est. cost: $X. Approve?"   │
 │  Authorized approver posts "@ahuofe approve"                    │
 │  Pipeline runs full consistency loop (expensive model + eval)   │
 │  All previous images pruned, only finalized survive             │
 │  "art-approved" label applied if drift score passes threshold   │
 └──────────────────────────────────────┬──────────────────────────┘
                                        │
     Human reviews final art, approves PR via GitHub review
                                        │
 ┌─── MERGE ───────────────────────────▼───────────────────────────┐
 │  Squash merge: all commits become one (only HEAD files)         │
 │  Branch auto-deleted: intermediate generations garbage-collected│
 │  Viewer manifests rebuilt, deployed to GitHub Pages              │
 └─────────────────────────────────────────────────────────────────┘
```
