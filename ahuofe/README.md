# Ahuofe Plugin

**The beauty of media creation for GitHub Copilot** — AI image/video generation via fal.ai and local image processing via ImageSorcery, orchestrated for the Anokye System.

*Ahuofe* (Akan: "the beautiful one") is the media generation and manipulation plugin of the asafo.

## What It Does

When installed, Ahuofe gives GitHub Copilot the ability to:

- **Generate images** — text-to-image, inpainting, and upscaling via fal.ai cloud models
- **Generate video** — text-to-video and image-to-video workflows
- **Process images locally** — crop, resize, detect, OCR via ImageSorcery MCP
- **Orchestrate workflows** — multi-step media pipelines combining generation and manipulation
- **Manage fal.ai resources** — model discovery, queue monitoring, cost tracking

## Skills

| Skill | Description | References |
|-------|-------------|------------|
| [fal-ai](skills/fal-ai/) | AI generation — text-to-image, text-to-video, image-to-video via fal.ai | 4 |
| [fal-workflow](skills/fal-workflow/) | Multi-step fal.ai workflow orchestration and pipeline management | 5 |
| [image-sorcery](skills/image-sorcery/) | Local image processing — crop, resize, detect, OCR via ImageSorcery MCP | 6 |
| [media-agents](skills/media-agents/) | Fleet-pattern agent coordination for media workflows | 4 |

## Scripts

All scripts live in `scripts/` and use the shared `FalAi.psm1` module.

### Shared Module — FalAi.psm1

Provides core functions used by all scripts:
- `Get-FalApiKey` — Load API key from `$env:FAL_KEY` or `.env`
- `Invoke-FalApi` — HTTP wrapper with auth, retry, error parsing
- `Send-FalFile` — CDN file upload (2-step token flow)
- `Wait-FalJob` — Queue submit → poll → retrieve
- `ConvertTo-FalError` — Extract error messages from fal.ai responses

### Script Inventory

| Script | Purpose |
|--------|---------|
| `Get-FalModel.ps1` | Get fal.ai model details |
| `Get-FalUsage.ps1` | Check API usage statistics |
| `Get-ModelSchema.ps1` | Retrieve model input/output schema |
| `Get-QueueStatus.ps1` | Monitor queue job status |
| `Invoke-FalGenerate.ps1` | Generate images from text prompts |
| `Invoke-FalImageToVideo.ps1` | Convert images to video |
| `Invoke-FalInpainting.ps1` | Inpaint regions of images |
| `Invoke-FalUpscale.ps1` | Upscale images |
| `Invoke-FalVideoGen.ps1` | Generate video from text |
| `Measure-ApiCost.ps1` | Track API cost per operation |
| `Measure-ApiPerformance.ps1` | Benchmark API latency |
| `Measure-ImageQuality.ps1` | Assess generated image quality |
| `Measure-TokenBudget.ps1` | Monitor token budget usage |
| `Measure-VideoQuality.ps1` | Assess generated video quality |
| `New-FalWorkflow.ps1` | Create multi-step workflows |
| `Search-FalModels.ps1` | Search available fal.ai models |
| `Test-FalConnection.ps1` | Verify fal.ai API connectivity |
| `Test-FalWorkflow.ps1` | Validate workflow definitions |
| `Test-ImageSorcery.ps1` | Test ImageSorcery MCP connection |
| `Upload-ToFalCDN.ps1` | Upload files to fal.ai CDN |

## v2 Capabilities

Ahuofe v2 adds a PR-driven iterative media generation system on top of the existing Copilot skills and scripts. Project repos define brand entities in YAML, and Ahuofe handles generation, evaluation, and approval through GitHub Actions and PR comments.

- **Pipeline** -- TypeScript generation engine with a 6-stage workflow: load YAML, compile prompt, generate reference sheet, generate panel, evaluate drift, and loop until consistency threshold is met
- **Schemas** -- JSON Schema validation for brand YAML files (`schema/entity.schema.json`, `shared.schema.json`, `preset.schema.json`), ensuring entity definitions are correct before generation
- **Workflows** -- Reusable GitHub Actions workflows (`workflow-templates/`) that project repos call via thin wrappers, handling draft/review/finalize stages with human approval gates
- **Viewer** -- Lineage browser (`viewer/`) for browsing generation history, comparing outputs side-by-side, and viewing drift evaluation reports, deployed to GitHub Pages

### Quick Start (v2)

1. Add `.ahuofe.yaml` to your project repo root (see [Setup Guide](docs/SETUP_GUIDE.md) for the full config reference)
2. Create a `brand/` directory with entity YAML files and stage presets
3. Add the thin workflow wrapper at `.github/workflows/ahuofe.yml`
4. Configure `FAL_KEY` and `ANTHROPIC_API_KEY` as GitHub Actions secrets
5. Push a branch that edits brand files, open a PR -- draft generation runs automatically

### Local Iteration

Iterate on brand YAML files locally without API keys:

```bash
npx ahuofe validate --brand ./brand              # Validate YAML against schemas
npx ahuofe preview-prompt --entity okyeame --brand ./brand  # Preview compiled prompt
npx ahuofe mock-generate --entity okyeame --brand ./brand   # Generate placeholder images
```

See [Local Iteration Guide](docs/LOCAL_ITERATION.md) for the full workflow.

### Documentation

| Document | Description |
|----------|-------------|
| [Setup Guide](docs/SETUP_GUIDE.md) | How to configure a project repo to use Ahuofe |
| [Local Iteration](docs/LOCAL_ITERATION.md) | Local development workflow without API keys |
| [Architecture](docs/ARCHITECTURE.md) | System architecture, pipeline design, data flow |

## Installation

### Prerequisites

- PowerShell 7+
- fal.ai API key (`FAL_KEY` environment variable or `.env` file)
- ImageSorcery MCP server (optional, for local image processing)

### Setup

```powershell
# Set your fal.ai API key
$env:FAL_KEY = "your-api-key"

# Test connectivity
& ahuofe/scripts/Test-FalConnection.ps1

# Test ImageSorcery (optional)
& ahuofe/scripts/Test-ImageSorcery.ps1
```

## Testing

Tests use **Pester 5** and are organized in `tests/` by tier:

```powershell
Invoke-Pester ahuofe/tests/
```

## Version

See [.github/plugin/plugin.json](.github/plugin/plugin.json) for current version and compatibility information.
