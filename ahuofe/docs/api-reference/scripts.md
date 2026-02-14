# PowerShell Scripts Reference

Complete reference for all 20 PowerShell scripts and the shared module in the `scripts/` directory.

## Script Index

| Script | Category | Description |
|--------|----------|-------------|
| [Invoke-FalGenerate](#invoke-falgenerate) | Generation | Text-to-image generation |
| [Invoke-FalUpscale](#invoke-falupscale) | Processing | AI-powered image upscaling |
| [Invoke-FalInpainting](#invoke-falinpainting) | Processing | Image inpainting with masks |
| [Invoke-FalVideoGen](#invoke-falvideogen) | Video | Text-to-video generation |
| [Invoke-FalImageToVideo](#invoke-falimage­tovideo) | Video | Image-to-video animation |
| [Search-FalModels](#search-falmodels) | Discovery | Search available fal.ai models |
| [Get-FalModel](#get-falmodel) | Discovery | Get model info and OpenAPI schema |
| [Get-ModelSchema](#get-modelschema) | Discovery | Get model input/output schema |
| [Get-FalUsage](#get-falusage) | Billing | Check account usage statistics |
| [Get-QueueStatus](#get-queuestatus) | Utility | Check queue status of a request |
| [Upload-ToFalCDN](#upload-tofalcdn) | Utility | Upload files to fal.ai CDN |
| [Test-FalConnection](#test-falconnection) | Utility | Verify API key and connectivity |
| [New-FalWorkflow](#new-falworkflow) | Workflow | Define multi-step media workflows |
| [Test-FalWorkflow](#test-falworkflow) | Workflow | Validate a workflow definition |
| [Measure-ImageQuality](#measure-imagequality) | Quality | Analyze image quality metrics |
| [Measure-VideoQuality](#measure-videoquality) | Quality | Analyze video quality metrics |
| [Measure-ApiPerformance](#measure-apiperformance) | Quality | Benchmark API latency |
| [Measure-ApiCost](#measure-apicost) | Quality | Analyze and project API costs |
| [Measure-TokenBudget](#measure-tokenbudget) | Quality | Check SKILL.md token budgets |
| [Test-ImageSorcery](#test-imagesorcery) | Utility | Verify ImageSorcery MCP tools |

**Shared module:** `FalAi.psm1` — provides authentication, HTTP helpers, CDN upload, and queue polling. All scripts import it automatically.

---

## Generation

### Invoke-FalGenerate

Generate images from text prompts using fal.ai models.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-Prompt` | string | Yes | — | Text description of the image to generate |
| `-Model` | string | No | `fal-ai/flux/dev` | Model identifier |
| `-ImageSize` | string | No | `landscape_4_3` | Output size preset (e.g., `square_hd`, `landscape_4_3`, `portrait_4_3`) |
| `-NumImages` | int | No | 1 | Number of images to generate |
| `-Seed` | int | No | Random | Seed for reproducibility |
| `-ImageUrl` | string | No | — | Input image URL (for image-to-image) |
| `-Strength` | double | No | — | Denoising strength for image-to-image (0.0–1.0) |
| `-NumInferenceSteps` | int | No | — | Number of inference steps |
| `-GuidanceScale` | double | No | — | Prompt adherence strength |
| `-EnableSafetyChecker` | switch | No | `$false` | Enable safety content filter |
| `-Queue` | switch | No | `$false` | Submit via async queue instead of sync |

**Returns:** Object with `images` (array of `{url, width, height, content_type}`), `seed`, `timings`, `has_nsfw_concepts`

**Example:**

```powershell
# Basic generation
Invoke-FalGenerate -Prompt "A red fox in a snowy forest"

# With specific settings
Invoke-FalGenerate -Prompt "Mountain sunset" -Model "fal-ai/flux-pro/v1.1-ultra" -Seed 42 -ImageSize square_hd

# Multiple images via queue
Invoke-FalGenerate -Prompt "Abstract art" -NumImages 4 -Queue
```

---

## Processing

### Invoke-FalUpscale

Upscale images using AI super-resolution models.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-ImageUrl` | string | Yes | — | URL of the input image |
| `-Scale` | int | No | 2 | Upscale factor (`2` or `4`) |
| `-Model` | string | No | `fal-ai/aura-sr` | Upscaling model to use |
| `-Queue` | switch | No | `$false` | Submit via async queue |

**Returns:** Object with `image` (`{url, width, height, content_type}`), `timings`

**Example:**

```powershell
Invoke-FalUpscale -ImageUrl "https://example.com/photo.jpg" -Scale 4
```

### Invoke-FalInpainting

Edit images using inpainting with a mask.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-ImageUrl` | string | Yes | — | URL of the input image |
| `-MaskUrl` | string | Yes | — | URL of the mask image |
| `-Prompt` | string | Yes | — | Description of what to fill |
| `-Model` | string | No | `fal-ai/inpainting` | Inpainting model |
| `-Strength` | double | No | 0.85 | Denoising strength |
| `-NumInferenceSteps` | int | No | 30 | Number of inference steps |
| `-GuidanceScale` | double | No | 7.5 | Prompt adherence |
| `-Queue` | switch | No | `$false` | Submit via async queue |

**Returns:** Object with `images`, `seed`, `timings`

**Example:**

```powershell
Invoke-FalInpainting -ImageUrl $imgUrl -MaskUrl $maskUrl -Prompt "Replace the sky with a sunset"
```

---

## Video

### Invoke-FalVideoGen

Generate video from a text prompt.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-Prompt` | string | Yes | — | Text description of the video |
| `-Model` | string | No | `fal-ai/kling-video/v2.6/pro/text-to-video` | Video model |
| `-Duration` | int | No | 5 | Duration in seconds |
| `-AspectRatio` | string | No | `16:9` | Aspect ratio |
| `-Queue` | bool | No | `$true` | Submit via async queue (enabled by default) |

**Returns:** Object with `video` (`{url}`), `timings`

**Example:**

```powershell
Invoke-FalVideoGen -Prompt "A drone shot flying over a mountain lake" -Duration 10
```

### Invoke-FalImageToVideo

Animate a still image into a video.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-ImageUrl` | string | Yes | — | URL of the input image |
| `-Prompt` | string | No | — | Motion description |
| `-Model` | string | No | `fal-ai/kling-video/v2.6/pro/image-to-video` | Video model |
| `-Duration` | int | No | 5 | Duration in seconds |
| `-Queue` | bool | No | `$true` | Submit via async queue (enabled by default) |

**Returns:** Object with `video` (`{url}`), `timings`

**Example:**

```powershell
Invoke-FalImageToVideo -ImageUrl $imgUrl -Prompt "Slow zoom into the scene"
```

---

## Discovery

### Search-FalModels

Search available models on fal.ai by keyword or category.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-Query` | string | No | — | Search keyword |
| `-Category` | string | No | — | Filter by category |
| `-Limit` | int | No | 10 | Maximum results to return |

**Returns:** Array of model objects with `id`, `title`, `category`, `description`

**Example:**

```powershell
Search-FalModels -Query "upscale" -Category "image"
```

### Get-FalModel

Get detailed information about a specific fal.ai model.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-ModelId` | string | Yes | — | Model identifier (e.g., `fal-ai/flux/dev`) |
| `-InputOnly` | switch | No | — | Return only input schema |
| `-OutputOnly` | switch | No | — | Return only output schema |

**Returns:** Object with model metadata, `input_schema`, `output_schema`

**Example:**

```powershell
Get-FalModel -ModelId "fal-ai/flux/dev"
```

### Get-ModelSchema

Get the input/output schema for a specific model.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-ModelId` | string | Yes | — | Model identifier |
| `-InputOnly` | switch | No | — | Return only input schema |
| `-OutputOnly` | switch | No | — | Return only output schema |

**Returns:** Object with `input_schema`, `output_schema` as JSON schema objects

**Example:**

```powershell
Get-ModelSchema -ModelId "fal-ai/flux/dev" -InputOnly
```

---

## Billing

### Get-FalUsage

Check account usage statistics and cost breakdown.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-Days` | int | No | 30 | Number of days to query |
| `-GroupBy` | string | No | `endpoint` | Group results by `endpoint` or `timeframe` |
| `-Model` | string | No | — | Filter to a specific model |
| `-Timeframe` | string | No | — | Time bucket: `minute`, `hour`, `day`, `week`, `month` |

**Returns:** Object with `TotalCost`, `TotalRequests`, `ByEndpoint`, `StartDate`, `EndDate`

**Example:**

```powershell
Get-FalUsage -Days 7 -GroupBy endpoint
```

---

## Utility

### Upload-ToFalCDN

Upload a local file to fal.ai CDN storage for use in API calls.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-FilePath` | string | Yes | — | Path to the file to upload |
| `-ContentType` | string | No | Auto-detected | MIME type of the file |

**Returns:** Object with `url`

**Example:**

```powershell
$uploaded = Upload-ToFalCDN -FilePath "./input/photo.jpg"
Invoke-FalInpainting -ImageUrl $uploaded.url -MaskUrl $maskUrl -Prompt "Add a hat"
```

### Get-QueueStatus

Check the queue status of an async fal.ai request.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-RequestId` | string | Yes | — | Request ID from a queued submission |
| `-Model` | string | Yes | — | The fal.ai model endpoint |

**Returns:** Object with queue position, status, and logs

**Example:**

```powershell
Get-QueueStatus -RequestId "abc-123" -Model "fal-ai/flux/dev"
```

### Test-FalConnection

Verify that the fal.ai API key is configured and the API is reachable. Takes no parameters.

**Returns:** Object with `KeyFound`, `ApiReachable`, and diagnostic info

**Example:**

```powershell
Test-FalConnection
```

### Test-ImageSorcery

Verify that ImageSorcery MCP tools are available and functioning.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-TestImagePath` | string | No | — | Path to an image for testing |

**Returns:** Test results with pass/fail counts

**Example:**

```powershell
Test-ImageSorcery -TestImagePath "./test-image.png"
```

---

## Workflow

### New-FalWorkflow

Define and execute a multi-step media workflow with dependency resolution.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-Name` | string | Yes | — | Workflow name |
| `-Steps` | hashtable[] | Yes | — | Array of step definitions |
| `-Description` | string | No | — | Workflow description |

Each step hashtable uses the format: `@{ name = 'stepId'; model = 'fal-ai/...'; params = @{...}; dependsOn = @('otherStep') }`

**Returns:** Workflow execution results with step outputs

**Example:**

```powershell
$steps = @(
    @{ name = 'gen'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'Product photo'; seed = 42 }; dependsOn = @() },
    @{ name = 'upscale'; model = 'fal-ai/aura-sr'; params = @{ scale = 2 }; dependsOn = @('gen') }
)

New-FalWorkflow -Name "product-photo" -Steps $steps
```

### Test-FalWorkflow

Validate a workflow definition without executing it. Checks for structural errors, invalid model names, dependency cycles, and parameter issues.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-Steps` | hashtable[] | Yes* | — | Array of step definitions (inline) |
| `-Path` | string | Yes* | — | Path to a JSON workflow file |
| `-DryRun` | switch | No | Default | Full validation without API calls |

*One of `-Steps` or `-Path` is required.

**Returns:** Object with `Valid` (bool), `Errors`, `Warnings`, `StepCount`, `ExecutionOrder`

**Example:**

```powershell
Test-FalWorkflow -Steps $steps
Test-FalWorkflow -Path './my-workflow.json'
```

---

## Quality & Measurement

### Measure-ImageQuality

Analyze image quality metrics (resolution, file size, format, and optional SSIM comparison).

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-ImagePath` | string | Yes | — | Path to the image file |
| `-ReferenceImagePath` | string | No | — | Reference image for comparison |
| `-Prompt` | string | No | — | Original prompt (for relevance scoring) |
| `-OutputFormat` | string | No | `PSObject` | Output as `PSObject` or `JSON` |
| `-Threshold` | hashtable | No | `@{}` | Custom quality thresholds |

**Example:**

```powershell
Measure-ImageQuality -ImagePath "./output/result.png" -Prompt "A red fox"
```

### Measure-VideoQuality

Analyze video quality metrics (resolution, duration, format, codec).

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-VideoPath` | string | Yes | — | Path to the video file |
| `-ReferenceVideoPath` | string | No | — | Reference video for comparison |
| `-OutputFormat` | string | No | `PSObject` | Output as `PSObject` or `JSON` |

**Example:**

```powershell
Measure-VideoQuality -VideoPath "./output/video.mp4"
```

### Measure-ApiPerformance

Benchmark fal.ai API latency by running multiple requests.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-Model` | string | No | `fal-ai/flux/dev` | Model to benchmark |
| `-Prompt` | string | No | `A simple test image...` | Test prompt |
| `-Iterations` | int | No | 5 | Number of requests (1–100) |
| `-OutputPath` | string | No | — | Path to save JSON results |

**Example:**

```powershell
Measure-ApiPerformance -Model "fal-ai/flux/schnell" -Iterations 10
```

### Measure-ApiCost

Analyze fal.ai API costs and project monthly spending from usage data.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-UsageData` | PSObject | Yes | — | Output from `Get-FalUsage` |
| `-BudgetLimit` | double | No | — | Monthly budget cap in USD |
| `-OutputPath` | string | No | — | Path to write JSON results |

**Example:**

```powershell
$usage = Get-FalUsage -Days 30
Measure-ApiCost -UsageData $usage -BudgetLimit 50
```

### Measure-TokenBudget

Check SKILL.md files against token and line budgets.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-Path` | string | Yes | — | Path to a SKILL.md file or directory |
| `-MaxTokens` | int | No | 6500 | Maximum token budget |
| `-MaxLines` | int | No | 500 | Maximum line count |
| `-TokensPerLine` | double | No | 13.0 | Estimated tokens per line |
| `-OutputFormat` | string | No | `Table` | Output as `Table` or `JSON` |

**Example:**

```powershell
Measure-TokenBudget -Path ./skills/fal-ai/SKILL.md
```
