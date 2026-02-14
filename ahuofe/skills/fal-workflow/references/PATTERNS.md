# Workflow Patterns

Common patterns and best practices for building multi-step workflows
with `scripts/New-FalWorkflow.ps1`.

---

## Sequential Pipeline (A → B → C)

The simplest pattern: each step depends on the previous one. The workflow
engine resolves the linear dependency chain automatically.

```powershell
$steps = @(
    @{ name = 'generate'; model = 'fal-ai/flux/dev'
       params = @{ prompt = 'A mountain lake' }; dependsOn = @() }
    @{ name = 'upscale'; model = 'fal-ai/aura-sr'
       params = @{}; dependsOn = @('generate') }
    @{ name = 'animate'; model = 'fal-ai/kling-video/v2.6/pro/image-to-video'
       params = @{ prompt = 'Gentle ripples on the lake' }; dependsOn = @('upscale') }
)
```

**When to use:** Most workflows. Start with a sequential pipeline and add
complexity only when needed.

**Best practice:** Keep pipelines to 2–4 steps. Each additional step adds
latency and a potential failure point.

---

## Fan-Out (A → B1, B2, B3)

Generate variants from a single source by creating multiple steps that
depend on the same parent. Run the variants as separate workflows or
manually to compare results.

```powershell
# Step 1: Generate base image
$base = .\scripts\Invoke-FalGenerate.ps1 -Prompt 'A fantasy castle' -Model 'fal-ai/flux/dev'
$baseUrl = $base.Images[0].Url

# Step 2: Fan-out — create style variants
$styles = @(
    @{ name = 'watercolor'; prompt = 'Watercolor painting style'; strength = 0.6 }
    @{ name = 'cyberpunk';  prompt = 'Cyberpunk neon style'; strength = 0.7 }
    @{ name = 'anime';      prompt = 'Studio Ghibli anime style'; strength = 0.65 }
)

$variants = foreach ($style in $styles) {
    $steps = @(
        @{ name = 'restyle'; model = 'fal-ai/flux/dev'
           params = @{ image_url = $baseUrl; prompt = $style.prompt; strength = $style.strength }
           dependsOn = @() }
    )
    .\scripts\New-FalWorkflow.ps1 -Name "variant-$($style.name)" -Steps $steps
}
```

**When to use:** Exploring creative directions, A/B testing styles, or
generating multiple options for client review.

---

## Fan-In (B1, B2, B3 → C)

Collect results from multiple branches and select the best one before
continuing the pipeline. Use quality metrics to pick the winner.

```powershell
# After fan-out (above), pick the best variant
$bestVariant = $null
$bestScore = 0

foreach ($v in $variants) {
    $url = $v.Steps[-1].Output.images[0].url
    $quality = .\scripts\Measure-ImageQuality.ps1 -ImageUrl $url
    if ($quality.OverallScore -gt $bestScore) {
        $bestScore = $quality.OverallScore
        $bestVariant = $url
    }
}

# Continue pipeline with the winner
$steps = @(
    @{ name = 'upscale'; model = 'fal-ai/aura-sr'
       params = @{ image_url = $bestVariant }; dependsOn = @() }
    @{ name = 'animate'; model = 'fal-ai/kling-video/v2.6/pro/image-to-video'
       params = @{ prompt = 'Slow pan across the castle' }; dependsOn = @('upscale') }
)

.\scripts\New-FalWorkflow.ps1 -Name 'best-variant-pipeline' -Steps $steps
```

**When to use:** Quality-gated pipelines where you want automatic selection
from multiple candidates.

---

## Conditional Branching

Branch the workflow based on quality metrics or output properties. If the
output doesn't meet a threshold, regenerate with different parameters.

```powershell
$maxAttempts = 3
$qualityThreshold = 0.7
$result = $null

for ($i = 1; $i -le $maxAttempts; $i++) {
    $gen = .\scripts\Invoke-FalGenerate.ps1 `
        -Prompt 'Product photo of a watch on marble' `
        -Model 'fal-ai/flux/dev' `
        -NumInferenceSteps (20 + ($i * 5))

    $quality = .\scripts\Measure-ImageQuality.ps1 -ImageUrl $gen.Images[0].Url

    if ($quality.OverallScore -ge $qualityThreshold) {
        $result = $gen
        Write-Host "Passed quality check on attempt $i (score: $($quality.OverallScore))"
        break
    }
    Write-Warning "Attempt $i below threshold ($($quality.OverallScore) < $qualityThreshold)"
}

if (-not $result) {
    throw "Failed to meet quality threshold after $maxAttempts attempts."
}

# Continue with the accepted result
$steps = @(
    @{ name = 'upscale'; model = 'fal-ai/aura-sr'
       params = @{ image_url = $result.Images[0].Url }; dependsOn = @() }
)
.\scripts\New-FalWorkflow.ps1 -Name 'quality-gated' -Steps $steps
```

**When to use:** Production pipelines where output quality is critical, or
when model results are non-deterministic and need validation.

---

## Error Recovery

Handle step failures with retry logic, parameter adjustment, or fallback
models.

### Retry with Same Parameters

```powershell
$maxRetries = 3
for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
    try {
        $result = .\scripts\New-FalWorkflow.ps1 -Name 'my-workflow' -Steps $steps
        break
    }
    catch {
        Write-Warning "Attempt $attempt failed: $_"
        if ($attempt -eq $maxRetries) { throw }
        Start-Sleep -Seconds ([math]::Pow(2, $attempt))
    }
}
```

### Fallback to a Different Model

```powershell
$models = @('fal-ai/flux-pro/v1.1-ultra', 'fal-ai/flux/dev', 'fal-ai/flux/schnell')

foreach ($model in $models) {
    try {
        $steps = @(
            @{ name = 'generate'; model = $model
               params = @{ prompt = 'A sunset over the ocean' }; dependsOn = @() }
        )
        $result = .\scripts\New-FalWorkflow.ps1 -Name 'fallback' -Steps $steps
        Write-Host "Succeeded with $model"
        break
    }
    catch {
        Write-Warning "$model failed: $_"
    }
}
```

### Adjust Parameters on Failure

```powershell
$stepsConfig = @{ steps = 28; guidance = 7.5 }
$succeeded = $false

for ($i = 0; $i -lt 3; $i++) {
    try {
        $steps = @(
            @{ name = 'generate'; model = 'fal-ai/flux/dev'
               params = @{
                   prompt = 'A detailed botanical illustration'
                   num_inference_steps = $stepsConfig.steps
                   guidance_scale = $stepsConfig.guidance
               }; dependsOn = @() }
        )
        $result = .\scripts\New-FalWorkflow.ps1 -Name 'adaptive' -Steps $steps
        $succeeded = $true
        break
    }
    catch {
        # Reduce complexity on failure
        $stepsConfig.steps = [math]::Max(10, $stepsConfig.steps - 5)
        $stepsConfig.guidance = [math]::Max(3, $stepsConfig.guidance - 1)
        Write-Warning "Retrying with reduced params: steps=$($stepsConfig.steps)"
    }
}
```

---

## Quality Checkpoint Pattern

Insert quality validation between pipeline steps. Run steps manually
instead of using the workflow engine to inspect intermediate outputs.

```powershell
# Step 1: Generate
$gen = .\scripts\Invoke-FalGenerate.ps1 -Prompt 'Product photo' -Model 'fal-ai/flux/dev'
$imageUrl = $gen.Images[0].Url

# Checkpoint: validate dimensions
$meta = .\scripts\Measure-ImageQuality.ps1 -ImageUrl $imageUrl
if ($meta.Width -lt 512 -or $meta.Height -lt 512) {
    throw "Generated image too small: $($meta.Width)x$($meta.Height)"
}

# Step 2: Upscale (only if checkpoint passes)
$steps = @(
    @{ name = 'upscale'; model = 'fal-ai/aura-sr'
       params = @{ image_url = $imageUrl }; dependsOn = @() }
)
$result = .\scripts\New-FalWorkflow.ps1 -Name 'checked-upscale' -Steps $steps
```

**Quality criteria examples:**

| Check | Script | Pass Condition |
|-------|--------|----------------|
| Dimensions | `Measure-ImageQuality.ps1` | Width/height ≥ minimum |
| Overall quality | `Measure-ImageQuality.ps1` | OverallScore ≥ threshold |
| Video quality | `Measure-VideoQuality.ps1` | Score ≥ threshold |
| API cost | `Measure-ApiCost.ps1` | Cost ≤ budget |

---

## Pattern Selection Guide

| Scenario | Pattern | Complexity |
|----------|---------|------------|
| Simple generation + processing | Sequential | Low |
| Exploring creative options | Fan-out | Medium |
| Automatic best-of-N selection | Fan-out → Fan-in | Medium |
| Production quality assurance | Conditional branching | Medium |
| Unreliable model or network | Error recovery | Low |
| Critical output requirements | Quality checkpoint | Medium |
| Full production pipeline | Sequential + checkpoints | High |

**Start simple.** Use a sequential pipeline first, then add quality checks
or error recovery as needed. Fan-out/fan-in adds complexity and cost — only
use when variant exploration is genuinely required.
