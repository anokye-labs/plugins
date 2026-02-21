---
name: fal-workflow
description: >
  Chain multiple fal.ai operations into multi-step pipelines. Use when the user
  requests "multi-step workflow", "chain generation", "generate then edit",
  "generate then upscale", "create workflow pipeline", "generate and animate",
  "text to image then video", "build media pipeline", or any task requiring
  sequential fal.ai model invocations with output passing between steps.
metadata:
  author: anokye-labs
  version: "1.0.0"
---

# fal-workflow Skill

Chain multiple fal.ai model invocations into multi-step pipelines with
automatic output passing, dependency resolution, and error recovery.

Use **fal-ai** for single-model calls. Use **fal-workflow** when you need
two or more fal.ai operations where one step's output feeds the next.
For local image processing between steps, combine with **image-sorcery**.
For full fleet-pattern orchestration, see **media-agents**.

---

## Core Concept

A workflow is an ordered sequence of **steps**. Each step invokes a fal.ai
model and can consume output from previous steps. The workflow engine
resolves dependencies via topological sort and passes results automatically.

```
Step 1 (generate) → Step 2 (upscale) → Step 3 (animate)
       ↓ image_url        ↓ image_url
```

---

## Execution Engine

All workflows execute through `scripts/New-FalWorkflow.ps1`.

```powershell
.\scripts\New-FalWorkflow.ps1 -Name <workflow-name> -Steps <step-array>
```

The engine:
1. Validates all steps and their `dependsOn` references
2. Resolves execution order via topological sort (detects circular deps)
3. Executes steps sequentially in dependency order
4. Passes `image_url` from prior step output to dependent steps automatically
5. Uses queue mode for video models, sync for image models
6. Throws on step failure with the failing step identified

---

## Step Definition Format

Each step is a hashtable with four fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | ✅ | Unique step identifier |
| `model` | string | ✅ | fal.ai model endpoint |
| `params` | hashtable | | Model-specific parameters |
| `dependsOn` | string[] | | Names of steps that must complete first |

```powershell
@{
    name      = 'generate'
    model     = 'fal-ai/flux/dev'
    params    = @{
        prompt     = 'A mountain landscape'
        image_size = 'landscape_16_9'
    }
    dependsOn = @()
}
```

### Output Passing Rules

When a step declares `dependsOn`, the engine automatically injects the
prior step's output:

| Prior Step Output | Injected As |
|-------------------|-------------|
| `images[0].url` | `image_url` in dependent step params |
| `video.url` | `image_url` in dependent step params |

You can override this by explicitly setting `image_url` in the step's `params`.

---

## ⚠️ Critical Guardrails

These rules prevent the most common workflow construction errors.

### 1. No String Interpolation in Variable References

Variable references must be the **entire value** — never mix text with variables.

```powershell
# WRONG — mixing literal text with variable references will break
params = @{ prompt = "Create image of ${input.subject} in ${input.style}" }

# CORRECT — variable reference is the entire value
params = @{ prompt = '${input.prompt}' }
```

To combine multiple values into one string, use `fal-ai/text-concat` or
`fal-ai/workflow-utilities/merge-text` as an explicit step before the step
that needs the combined text.

---

### 2. Output Reference Cheat Sheet

Use this table to find the correct field path when referencing a prior step's output.

| Model Type | Output Reference | Auto-injected as `image_url`? |
|------------|-----------------|-------------------------------|
| LLM | `$node.output` | No |
| Text Concat | `$node.results` | No |
| Merge Text | `$node.text` | No |
| Image Gen (array) | `$node.images.0.url` | ✅ Yes |
| Image Process (single) | `$node.image.url` | ✅ Yes |
| Video | `$node.video.url` | No |
| Music | `$node.audio_file.url` | No |
| Frame Extract | `$node.frame.url` | No |

When the engine auto-injects `image_url`, dependent steps receive it automatically.
For all other fields, reference the prior step's output explicitly in `params`.

---

### 3. Pre-Output Checklist

Before constructing workflow steps, verify each of the following:

- [ ] Every `dependsOn` entry matches a step name that actually exists in the workflow
- [ ] Step names match exactly (case-sensitive)
- [ ] No circular dependencies (A → B → A will throw at validation)
- [ ] Correct LLM type selected (`router` vs `router/vision`) for the task
- [ ] Video steps will use queue mode (handled automatically by the engine)
- [ ] All `image_url` values are publicly hosted URLs, not local file paths

---

### 4. Dependency Must Match References

If a step uses output from another step, it **MUST** declare that step in
`dependsOn`. The engine does **not** auto-detect references from `params`.

```powershell
# WRONG — 'upscale' reads from 'generate' but never declares the dependency
@{
    name      = 'upscale'
    model     = 'fal-ai/aura-sr'
    params    = @{ image_url = '${generate.images.0.url}' }
    dependsOn = @()   # ← missing 'generate'!
}

# CORRECT — dependency is declared so the engine orders execution correctly
@{
    name      = 'upscale'
    model     = 'fal-ai/aura-sr'
    params    = @{}   # image_url auto-injected from 'generate' output
    dependsOn = @('generate')
}
```

Missing a `dependsOn` entry causes the engine to run the step before its
input is available, resulting in a missing-parameter error.

---

## Workflow Templates

### 1. Text-to-Image + Upscale

Generate an image then upscale it with AI super-resolution.

```powershell
$steps = @(
    @{
        name      = 'generate'
        model     = 'fal-ai/flux/dev'
        params    = @{
            prompt     = 'A fantasy castle on a cliff'
            image_size = 'landscape_4_3'
        }
        dependsOn = @()
    }
    @{
        name      = 'upscale'
        model     = 'fal-ai/aura-sr'
        params    = @{}
        dependsOn = @('generate')
    }
)

$result = .\scripts\New-FalWorkflow.ps1 -Name 'generate-upscale' -Steps $steps
```

### 2. Text-to-Image + Edit

Generate an image then edit a region with inpainting.

```powershell
$steps = @(
    @{
        name      = 'generate'
        model     = 'fal-ai/flux/dev'
        params    = @{
            prompt     = 'A cozy cabin in the woods'
            image_size = 'square_hd'
        }
        dependsOn = @()
    }
    @{
        name      = 'edit'
        model     = 'fal-ai/inpainting'
        params    = @{
            mask_url = 'https://example.com/mask.png'
            prompt   = 'A campfire in front of the cabin'
            strength = 0.85
        }
        dependsOn = @('generate')
    }
)

$result = .\scripts\New-FalWorkflow.ps1 -Name 'generate-edit' -Steps $steps
```

### 3. Text-to-Image + Video

Generate an image then animate it into a video.

```powershell
$steps = @(
    @{
        name      = 'generate'
        model     = 'fal-ai/flux/dev'
        params    = @{
            prompt     = 'A majestic eagle soaring over mountains'
            image_size = 'landscape_16_9'
        }
        dependsOn = @()
    }
    @{
        name      = 'animate'
        model     = 'fal-ai/kling-video/v2.6/pro/image-to-video'
        params    = @{
            prompt   = 'The eagle flaps its wings and flies forward'
            duration = 5
        }
        dependsOn = @('generate')
    }
)

$result = .\scripts\New-FalWorkflow.ps1 -Name 'generate-animate' -Steps $steps
```

### 4. Full Pipeline (Generate → Edit → Upscale → Animate)

Four-step pipeline combining generation, editing, enhancement, and animation.

```powershell
$steps = @(
    @{
        name      = 'generate'
        model     = 'fal-ai/flux/dev'
        params    = @{
            prompt     = 'A serene Japanese garden with a koi pond'
            image_size = 'landscape_16_9'
        }
        dependsOn = @()
    }
    @{
        name      = 'edit'
        model     = 'fal-ai/inpainting'
        params    = @{
            mask_url = 'https://example.com/sky-mask.png'
            prompt   = 'A dramatic sunset sky with orange and purple clouds'
            strength = 0.9
        }
        dependsOn = @('generate')
    }
    @{
        name      = 'upscale'
        model     = 'fal-ai/aura-sr'
        params    = @{ scale = 2 }
        dependsOn = @('edit')
    }
    @{
        name      = 'animate'
        model     = 'fal-ai/kling-video/v2.6/pro/image-to-video'
        params    = @{
            prompt   = 'Gentle ripples on the koi pond, clouds drifting slowly'
            duration = 5
        }
        dependsOn = @('upscale')
    }
)

$result = .\scripts\New-FalWorkflow.ps1 -Name 'full-pipeline' -Steps $steps
```

---

## Error Handling

### Step Failures

The workflow engine throws immediately when a step fails. The error
includes the step name and the underlying fal.ai error message.

```
Step 'upscale': Failed — HTTP 422: image_url is required
```

**Recovery strategy:**
1. Identify which step failed from the error message
2. Fix the step's `params` or `dependsOn` configuration
3. Re-run the entire workflow (the engine re-executes from the start)

### Retry Pattern

For transient failures (429, 5xx), the underlying `Invoke-FalApi` function
retries automatically with exponential backoff (up to 3 attempts). No
workflow-level retry configuration is needed for transient errors.

For persistent failures, wrap the workflow call:

```powershell
$maxRetries = 2
for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
    try {
        $result = .\scripts\New-FalWorkflow.ps1 -Name 'my-workflow' -Steps $steps
        break
    }
    catch {
        Write-Warning "Attempt $attempt failed: $_"
        if ($attempt -eq $maxRetries) { throw }
        Start-Sleep -Seconds (2 * $attempt)
    }
}
```

### Partial Results

When a later step fails, prior step results are lost because the engine
throws. To preserve partial results, run steps manually:

```powershell
# Step 1 — always succeeds first
$gen = .\scripts\Invoke-FalGenerate.ps1 -Prompt "A castle" -Model "fal-ai/flux/dev"
$baseUrl = $gen.Images[0].Url
Write-Host "✅ Generated: $baseUrl"

# Step 2 — may fail, but step 1 output is preserved
try {
    $vid = .\scripts\Invoke-FalGenerate.ps1 -Prompt "Zoom in" `
        -Model "fal-ai/kling-video/v2.6/pro/image-to-video" `
        -ImageUrl $baseUrl -Queue
    Write-Host "✅ Animated: $($vid.Video.Url)"
}
catch {
    Write-Warning "❌ Animation failed: $_"
    Write-Host "Base image preserved at: $baseUrl"
}
```

---

## Quality Checkpoints

Insert quality validation between workflow steps by running the pipeline
manually and checking outputs with ImageSorcery MCP tools.

### Between Steps

```powershell
# Step 1: Generate
$gen = .\scripts\Invoke-FalGenerate.ps1 -Prompt "Product photo" -Model "fal-ai/flux/dev"
$baseUrl = $gen.Images[0].Url

# Quality checkpoint: verify dimensions and content
# Use ImageSorcery get_metainfo to check the generated image
# Use ImageSorcery detect to verify expected content is present

# Step 2: Upscale (only if checkpoint passes)
$upscale = .\scripts\Invoke-FalGenerate.ps1 `
    -Model "fal-ai/aura-sr" -ImageUrl $baseUrl
```

### Validation Criteria

| Check | Tool | Pass Condition |
|-------|------|----------------|
| Dimensions | `get_metainfo` | Width/height match expected size |
| Content | `detect` | Expected objects detected with confidence > 0.8 |
| Text legibility | `ocr` | Expected text is readable |
| File size | `get_metainfo` | Under target limit |

---

## Workflow Output Format

`New-FalWorkflow.ps1` returns a PSCustomObject:

```json
{
  "WorkflowName": "generate-upscale",
  "Description": null,
  "Steps": [
    {
      "StepName": "generate",
      "Model": "fal-ai/flux/dev",
      "Status": "Completed",
      "Output": { "images": [{ "url": "https://..." }], "seed": 42 }
    },
    {
      "StepName": "upscale",
      "Model": "fal-ai/aura-sr",
      "Status": "Completed",
      "Output": { "image": { "url": "https://...", "width": 2048, "height": 1536 } }
    }
  ]
}
```

### Accessing Results

```powershell
# Final step output
$lastStep = $result.Steps[-1]
$finalUrl = $lastStep.Output.images[0].url  # or .image.url or .video.url

# Specific step output
$genOutput = $result.Steps | Where-Object StepName -eq 'generate'
$seed = $genOutput.Output.seed
```

---

## Best Practices

1. **Start simple** — begin with 2-step workflows before building complex pipelines
2. **Use queue for video** — video models require queue mode (handled automatically)
3. **Name steps descriptively** — `generate`, `upscale`, `animate` not `step1`, `step2`
4. **Set seeds for reproducibility** — include `seed` in generation params for repeatable results
5. **Check model compatibility** — verify output format of step N matches input format of step N+1
6. **Test each step independently** — validate a step works alone before adding it to a pipeline

---

## Related Skills

| Skill | Use For |
|-------|---------|
| [fal-ai](../fal-ai/SKILL.md) | Single-model calls, model reference, authentication |
| [media-agents](../media-agents/SKILL.md) | Fleet-pattern orchestration, parallel dispatch, checkpoints |
| [image-sorcery](../image-sorcery/SKILL.md) | Local image processing between pipeline steps |

## References

| Document | Content |
|----------|---------|
| [PIPELINE_TEMPLATES.md](references/PIPELINE_TEMPLATES.md) | Ready-to-use workflow templates |
| [STEP_REFERENCE.md](references/STEP_REFERENCE.md) | All step types, inputs/outputs, chaining rules |
