# Plugin Infrastructure Architecture

> Core architecture documentation for the Copilot Media Plugins extension.

## Architecture Overview

The Copilot Media Plugins project extends GitHub Copilot with media generation
and manipulation capabilities through a layered plugin architecture:

```
┌─────────────────────────────────────────────────────────┐
│                   GitHub Copilot Chat                    │
│              (VS Code / CLI / Web IDE)                   │
└──────────────────────┬──────────────────────────────────┘
                       │ User prompt
                       ▼
┌─────────────────────────────────────────────────────────┐
│               Copilot Extension Layer                    │
│  ┌───────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Skill Files  │  │  Agent .md   │  │   Prompt     │  │
│  │  (SKILL.md)   │  │   Files      │  │  Templates   │  │
│  └───────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
│          └─────────────┬───┘────────────────┘           │
│                        ▼                                 │
│              Intent Classification                       │
│          & Skill / Agent Routing                          │
└──────────────────────┬──────────────────────────────────┘
                       │
          ┌────────────┴────────────┐
          ▼                         ▼
┌──────────────────┐     ┌──────────────────────┐
│  Plugin Handler  │     │  Plugin Handler      │
│  (fal.ai API)    │     │  (ImageSorcery MCP)  │
│                  │     │                      │
│  FalAi.psm1     │     │  MCP Tool Calls      │
│  Invoke-Fal*.ps1│     │  (detect, crop, etc) │
└────────┬─────────┘     └──────────┬───────────┘
         │                          │
         ▼                          ▼
┌──────────────────┐     ┌──────────────────────┐
│   fal.ai REST    │     │   ImageSorcery MCP   │
│   API Service    │     │   Server (local)     │
│                  │     │                      │
│  - flux/dev      │     │  - YOLO detection    │
│  - flux/schnell  │     │  - OpenCV transforms │
│  - kling-video   │     │  - EasyOCR           │
│  - creative-upsc │     │  - Image metadata    │
└──────────────────┘     └──────────────────────┘
```

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ Repository: copilot-media-plugins                               │
│                                                                  │
│  skills/                                                         │
│  ├── fal-ai/SKILL.md          # fal.ai generation skill         │
│  ├── image-sorcery/SKILL.md   # ImageSorcery manipulation skill │
│  └── media-agents/SKILL.md    # Multi-agent orchestration skill │
│                                                                  │
│  scripts/                                                        │
│  ├── FalAi.psm1               # PowerShell module (API wrapper) │
│  ├── Invoke-FalGenerate.ps1   # Image generation entry point    │
│  ├── Invoke-FalUpscale.ps1    # Upscaling entry point           │
│  ├── Invoke-FalVideo.ps1      # Video generation entry point    │
│  └── Measure-*.ps1            # Quality measurement scripts     │
│                                                                  │
│  tests/                                                          │
│  ├── unit/                    # Unit tests (Pester 5.x)         │
│  ├── integration/             # Integration tests               │
│  ├── e2e/                     # End-to-end tests                │
│  ├── evaluation/              # Quality evaluation tests        │
│  ├── gates/                   # Gate validation tests           │
│  ├── fixtures/                # Test fixtures & golden prompts  │
│  └── helpers/TestHelper.psm1  # Shared test utilities           │
│                                                                  │
│  docs/                                                           │
│  ├── architecture/            # Architecture documentation      │
│  ├── api-reference/           # API reference docs              │
│  ├── user-guides/             # User guides                     │
│  ├── security/                # Security documentation          │
│  └── examples-gallery/        # Usage examples                  │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Image Generation Flow

```
1. User Prompt
   "Generate a product photo of headphones on marble"
          │
          ▼
2. Intent Classification (Copilot)
   Detects: media generation intent
   Routes to: fal-ai skill
          │
          ▼
3. Skill Routing
   SKILL.md defines: model selection, parameters, constraints
   Selected model: fal-ai/flux/dev
   Parameters: { prompt, image_size, num_inference_steps }
          │
          ▼
4. API Call (FalAi.psm1)
   POST https://queue.fal.run/fal-ai/flux/dev
   Headers: Authorization: Key $FAL_KEY
   Body: { prompt, image_size: { width: 1024, height: 1024 } }
          │
          ▼
5. Queue & Poll
   GET /requests/{request_id}/status  (poll until complete)
   GET /requests/{request_id}         (retrieve result)
          │
          ▼
6. Response Formatting
   Download image → save to temp file → return path + metadata
   Quality checks: file size, dimensions, brightness, contrast
```

### Image Manipulation Flow

```
1. User Prompt
   "Detect objects in this image and crop the main subject"
          │
          ▼
2. Intent Classification (Copilot)
   Detects: image manipulation intent
   Routes to: image-sorcery skill
          │
          ▼
3. MCP Tool Routing
   SKILL.md defines: available tools, operation tiers
   Selected tools: detect → crop
          │
          ▼
4. MCP Tool Calls (sequential)
   a. detect(input_path, confidence=0.5)
      → Returns bounding boxes [{class, bbox, confidence}]
   b. crop(input_path, x1, y1, x2, y2)
      → Returns cropped image path
          │
          ▼
5. Response Formatting
   Return cropped image path + detection metadata
```

## Extension Points

### Adding a New fal.ai Model

1. **Update `skills/fal-ai/SKILL.md`** — add model to the supported models section:
   ```markdown
   ### Model: fal-ai/new-model-name
   - Use case: description
   - Parameters: list key params
   - Defaults: { image_size: { width: 1024, height: 1024 } }
   ```

2. **Update `scripts/FalAi.psm1`** — add model endpoint and default parameters:
   ```powershell
   $ModelDefaults['fal-ai/new-model-name'] = @{
       image_size = @{ width = 1024; height = 1024 }
       num_inference_steps = 28
   }
   ```

3. **Add golden prompts** in `tests/fixtures/golden-prompts.json` for quality regression.

4. **Add tests** in `tests/unit/` for the new model path.

### Adding a New ImageSorcery Tool

1. **Update `skills/image-sorcery/SKILL.md`** — add tool to Available Tools section.
2. **Add examples** in `docs/examples-gallery/`.
3. **Add integration tests** in `tests/integration/`.

### Adding a New Workflow

1. **Create an agent file** in `skills/media-agents/` or a new skill directory.
2. **Define the workflow** steps in SKILL.md with clear input/output contracts.
3. **Add e2e tests** in `tests/e2e/` covering the full workflow.

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `FAL_KEY` | Yes | fal.ai API key for model access |
| `FAL_KEY_ID` | No | fal.ai key identifier (for key rotation) |
| `COPILOT_MEDIA_LOG_LEVEL` | No | Log level: Debug, Info, Warning, Error |
| `COPILOT_MEDIA_TIMEOUT` | No | API timeout in seconds (default: 120) |
| `COPILOT_MEDIA_OUTPUT_DIR` | No | Output directory for generated media |

### .env File

Store secrets in a `.env` file at the repository root (excluded via `.gitignore`):

```env
FAL_KEY=your-fal-api-key-here
```

> **Security:** Never commit `.env` files. See `docs/security/api-key-management.md`.

### Skill File Locations

| Skill | Path | Purpose |
|-------|------|---------|
| fal.ai Generation | `skills/fal-ai/SKILL.md` | Image/video generation via fal.ai |
| ImageSorcery | `skills/image-sorcery/SKILL.md` | Local image manipulation via MCP |
| Media Agents | `skills/media-agents/SKILL.md` | Multi-agent orchestration |

Skill files must remain under **500 lines / 6500 tokens** to stay within
Copilot's context window budget.

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| PowerShell | 7.x+ | Script execution runtime |
| Pester | 5.x+ | Test framework |
| fal.ai API | — | Cloud image/video generation |
| ImageSorcery MCP | — | Local image manipulation server |
| Git | 2.x+ | Version control |

### Optional Dependencies

| Dependency | Purpose |
|------------|---------|
| Python 3.10+ | Quality measurement scripts (CLIP, SSIM) |
| Node.js 18+ | fal.ai client SDK (alternative to REST) |
