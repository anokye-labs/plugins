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
