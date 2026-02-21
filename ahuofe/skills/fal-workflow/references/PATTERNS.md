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

## LLM Prompt → Image → Video

Use an LLM to generate optimized prompts for downstream image and video
models, rather than passing raw user input directly. Produces higher-quality
results because the LLM rewrites the input for each model's strengths.

```
[User Input] → [LLM: Image Prompt] → [Image Gen]
                     ↓
               [LLM: Video Prompt] → [Video Gen] → [Output]
```

> **Requires:** LLM node type from issue #145 (LLM + Text Utility Nodes)

```powershell
$userInput = 'A serene Japanese garden at dawn'

$steps = @(
    @{ name = 'llm-image-prompt'
       model = 'fal-ai/any-llm'
       params = @{
           system = 'You are an expert image generation prompt writer. Expand the user input into a detailed, vivid image generation prompt.'
           prompt = $userInput
       }
       dependsOn = @() }

    @{ name = 'llm-video-prompt'
       model = 'fal-ai/any-llm'
       params = @{
           system = 'You are an expert video generation prompt writer. Write a short motion-focused prompt based on this scene description.'
           prompt = $userInput
       }
       dependsOn = @() }

    @{ name = 'image-gen'
       model = 'fal-ai/flux/dev'
       params = @{ prompt = '${llm-image-prompt.output}' }
       dependsOn = @('llm-image-prompt') }

    # '${llm-video-prompt.output}' — the LLM node returns its text result in the
    # 'output' field (a plain string). See fal-ai/any-llm output schema for details.
    @{ name = 'video-gen'
       model = 'fal-ai/kling-video/v2.6/pro/image-to-video'
       params = @{ prompt = '${llm-video-prompt.output}' }
       dependsOn = @('image-gen', 'llm-video-prompt') }
)

.\scripts\New-FalWorkflow.ps1 -Name 'llm-image-video' -Steps $steps
```

**When to use:** Any workflow where prompt quality matters. LLM rewriting
consistently improves output quality for both image and video models.
Especially useful when the user input is brief or conversational.

---

## Video Extension with Extract Frame

Chain multiple video clips together by extracting the last frame of one
video and using it as the starting frame for the next. The FFmpeg
`extract-frame` node acts as the bridge.

```
[Video 1] → [Extract Last Frame] → [Video 2 with Start Frame] → [Merge Videos] → [Output]
```

> **Requires:** FFmpeg node types from issue #146 (FFmpeg Utility Nodes)

```powershell
$steps = @(
    @{ name = 'video-1'
       model = 'fal-ai/kling-video/v2.6/pro/text-to-video'
       params = @{ prompt = 'A hawk soaring over mountain peaks, cinematic'; duration = 5 }
       dependsOn = @() }

    @{ name = 'extract-frame'
       model = 'fal-ai/ffmpeg-api/extract-frame'
       params = @{ video_url = '${video-1.video.url}'; frame_type = 'last' }
       dependsOn = @('video-1') }

    @{ name = 'video-2'
       model = 'fal-ai/kling-video/v2.6/pro/image-to-video'
       params = @{
           prompt = 'The hawk dives towards a mountain lake, slow motion'
           image_url = '${extract-frame.frame.url}'
       }
       dependsOn = @('extract-frame') }

    @{ name = 'merge'
       model = 'fal-ai/ffmpeg-api/merge-videos'
       params = @{
           video_urls = @('${video-1.video.url}', '${video-2.video.url}')
       }
       dependsOn = @('video-1', 'video-2') }
)

.\scripts\New-FalWorkflow.ps1 -Name 'video-extension' -Steps $steps
```

**When to use:** Long-form video narratives that exceed a single model's
duration limit, or when you need visual continuity across separate video
generation calls.

---

## First/Last Frame Video (Kling O1)

Generate the start and end frames as separate images, then pass both to
Kling O1 to produce a smooth transition video between them.

```
[Start Image Gen] →
                    → [Kling O1 Video (image_url + tail_image_url)] → [Output]
[End Image Gen]   →
```

```powershell
$steps = @(
    @{ name = 'start-frame'
       model = 'fal-ai/flux/dev'
       params = @{ prompt = 'A sprinter crouched at the starting blocks, stadium crowd behind'; image_size = 'landscape_16_9' }
       dependsOn = @() }

    @{ name = 'end-frame'
       model = 'fal-ai/flux/dev'
       params = @{ prompt = 'The same sprinter breaking through the finish tape, arms raised'; image_size = 'landscape_16_9' }
       dependsOn = @() }

    @{ name = 'video'
       model = 'fal-ai/kling-video/o1/image-to-video'
       params = @{
           prompt        = 'Sprinter launches from blocks and races to the finish line'
           image_url     = '${start-frame.images.0.url}'
           tail_image_url = '${end-frame.images.0.url}'
       }
       dependsOn = @('start-frame', 'end-frame') }
)

.\scripts\New-FalWorkflow.ps1 -Name 'first-last-frame' -Steps $steps
```

**When to use:** Storyboarded sequences where you need precise control over
both the opening and closing frame. Kling O1 interpolates the motion between
the two anchor images.

---

## Video + Custom Music

Generate a video and a music track in parallel, then merge them into a
single output with synchronized audio.

```
[Video Gen] →                    → [Merge Audio/Video] → [Output]
[Music Gen] → [audio_file.url] →
```

> **Requires:** FFmpeg node types from issue #146 (FFmpeg Utility Nodes)

```powershell
$steps = @(
    @{ name = 'video'
       model = 'fal-ai/kling-video/v2.6/pro/text-to-video'
       params = @{ prompt = 'Aerial drone shot over a misty rainforest at sunrise'; duration = 10 }
       dependsOn = @() }

    @{ name = 'music'
       model = 'fal-ai/elevenlabs/music'
       params = @{ prompt = 'Ambient nature soundscape, soft birds, gentle wind, peaceful morning' }
       dependsOn = @() }

    @{ name = 'merge'
       model = 'fal-ai/ffmpeg-api/merge-audio-video'
       params = @{
           video_url = '${video.video.url}'
           audio_url = '${music.audio_file.url}'
       }
       dependsOn = @('video', 'music') }
)

.\scripts\New-FalWorkflow.ps1 -Name 'video-with-music' -Steps $steps
```

**When to use:** Any video that needs a bespoke soundtrack. Both generation
calls run in parallel, so total latency equals the slower of the two rather
than their sum.

---

## Multi-Scene Film Generation

An LLM plans N scenes, then parallel image and video generation runs for
all scenes simultaneously, and the clips are merged into a final film.

```
[Scene Planner LLM] → [N × Image Prompt LLMs] → [N × Image Gen]
                    → [N × Video Prompt LLMs] → [N × Video Gen] → [Merge Videos] → [Output]
```

> **Requires:** LLM node types from issue #145 (LLM + Text Utility Nodes)
> **Requires:** FFmpeg node types from issue #146 (FFmpeg Utility Nodes)

```powershell
$concept = 'A short nature documentary about the Amazon river'

# This pattern is two-phase: first run the scene-planner LLM to get the
# scene list, then dynamically build and run the parallel generation workflow.

# Phase 1: Plan scenes with an LLM
$planStep = @{
    name   = 'scene-planner'
    model  = 'fal-ai/any-llm'
    params = @{
        system = 'Output a JSON array of exactly 3 scene objects, each with "image_prompt" and "video_prompt" fields. No other text.'
        prompt = $concept
    }
    dependsOn = @()
}

$planResult = .\scripts\New-FalWorkflow.ps1 -Name 'scene-plan' -Steps @($planStep)
$scenes = $planResult.Steps['scene-planner'].Output.output | ConvertFrom-Json

# Phase 2: Build parallel image + video steps for each scene
# Note: workflow reference strings like '${image-0.images.0.url}' are resolved
# by the workflow engine at runtime, not by PowerShell string interpolation.
$steps = @()
$videoNames = @()

for ($i = 0; $i -lt $scenes.Count; $i++) {
    $scene = $scenes[$i]

    $imgName   = "image-$i"
    $videoName = "video-$i"
    $videoNames += $videoName

    # Build the workflow reference string for this scene's image output
    $imgRef = '${' + $imgName + '.images.0.url}'

    $steps += @{ name = $imgName
                 model = 'fal-ai/flux/dev'
                 params = @{ prompt = $scene.image_prompt; image_size = 'landscape_16_9' }
                 dependsOn = @() }

    $steps += @{ name = $videoName
                 model = 'fal-ai/kling-video/v2.6/pro/image-to-video'
                 params = @{ prompt = $scene.video_prompt; image_url = $imgRef }
                 dependsOn = @($imgName) }
}

# Phase 3: Merge all scene videos
$videoUrls = $videoNames | ForEach-Object { '${' + $_ + '.video.url}' }
$steps += @{
    name      = 'merge'
    model     = 'fal-ai/ffmpeg-api/merge-videos'
    params    = @{ video_urls = $videoUrls }
    dependsOn = $videoNames
}

.\scripts\New-FalWorkflow.ps1 -Name 'multi-scene-film' -Steps $steps
```

**When to use:** Short-form narrative videos, product demos, or any content
that benefits from LLM-driven scene planning. The parallel execution across
all scenes keeps total latency proportional to a single scene, not N scenes.

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
| High-quality prompts for image + video | LLM Prompt → Image → Video | Medium |
| Seamless multi-clip video | Video Extension with Extract Frame | Medium |
| Precise start/end frame control | First/Last Frame Video (Kling O1) | Medium |
| Video with bespoke soundtrack | Video + Custom Music | Medium |
| LLM-planned multi-scene narrative | Multi-Scene Film Generation | High |

**Start simple.** Use a sequential pipeline first, then add quality checks
or error recovery as needed. Fan-out/fan-in adds complexity and cost — only
use when variant exploration is genuinely required.
