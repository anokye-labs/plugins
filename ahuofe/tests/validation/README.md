# Validation Tests

Real-world validation tests for media generation and manipulation workflows.

## Purpose

These tests validate end-to-end workflows using golden prompts and quality thresholds from `tests/fixtures/`. They ensure that text-to-image and image-to-video pipelines produce correctly structured outputs, handle errors gracefully, and integrate with quality measurement tooling.

All external API calls are mocked — no real HTTP requests are made.

## Test Files

| File | Description |
|------|-------------|
| `TextToImageWorkflow.Tests.ps1` | Golden prompt generation, model variants, quality measurement integration |
| `ImageToVideoWorkflow.Tests.ps1` | Image-to-video, text-to-video, queue processing, error scenarios |

## How to Run

```powershell
# Run all validation tests
Invoke-Pester ./tests/validation

# Run a specific test file
Invoke-Pester ./tests/validation/TextToImageWorkflow.Tests.ps1

# Run with detailed output
Invoke-Pester ./tests/validation -Output Detailed
```

## Fixtures

- **`tests/fixtures/golden-prompts.json`** — 20+ curated prompts across categories (photorealistic, artistic, product, landscape, video, abstract)
- **`tests/fixtures/quality-thresholds.json`** — CI/CD quality gates for image dimensions, brightness, contrast, entropy, and video duration/resolution
