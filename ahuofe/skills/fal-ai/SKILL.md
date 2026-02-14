---
name: fal-ai
description: >
  Generate images, videos, and audio using fal.ai AI models. Use when the user
  requests "generate image", "create video", "text to image", "image to video",
  "upscale image", "edit image", "search fal models", "get model schema", or
  similar AI generation tasks. Also covers file uploads to fal CDN and queue
  management for long-running jobs.
metadata:
  author: anokye-labs
  version: "1.0.0"
---

# fal.ai Skill

Generate and manipulate media using state-of-the-art AI models on [fal.ai](https://fal.ai).
All scripts are PowerShell and share the `FalAi.psm1` module for authentication,
HTTP calls, uploads, and queue polling.

For **local** image processing (crop, resize, detect, OCR) use **image-sorcery**.
Chain both skills for generate-then-process workflows.

---

## Shared Module

All scripts depend on `scripts/FalAi.psm1`. The module exports:

| Function            | Purpose                                           |
|---------------------|---------------------------------------------------|
| `Get-FalApiKey`     | Load `FAL_KEY` from `$env:FAL_KEY` or `.env` file |
| `Invoke-FalApi`     | HTTP wrapper with auth, retry, error parsing       |
| `Send-FalFile`      | 2-step CDN upload (token → upload → URL)          |
| `Wait-FalJob`       | Queue submit → poll → retrieve result             |
| `ConvertTo-FalError`| Extract error messages from fal.ai responses       |

Scripts import the module automatically. No manual setup needed.

---

## Available Scripts

| Script                        | Purpose                                  |
|-------------------------------|------------------------------------------|
| `Invoke-FalGenerate.ps1`      | Generate images from text prompts        |
| `Invoke-FalUpscale.ps1`       | AI-powered image upscaling               |
| `Invoke-FalInpainting.ps1`    | Image inpainting with masks              |
| `Invoke-FalVideoGen.ps1`      | Text-to-video generation                 |
| `Invoke-FalImageToVideo.ps1`  | Animate still images to video            |
| `Search-FalModels.ps1`        | Search available fal.ai models           |
| `Get-FalModel.ps1`            | Get model info and OpenAPI schema        |
| `Get-ModelSchema.ps1`         | Get model input/output schema            |
| `Get-FalUsage.ps1`            | Check account usage and costs            |
| `Get-QueueStatus.ps1`         | Check async request queue status         |
| `Upload-ToFalCDN.ps1`         | Upload files to fal.ai CDN              |
| `New-FalWorkflow.ps1`         | Define multi-step media workflows        |
| `Test-FalConnection.ps1`      | Verify API key and connectivity          |
| `Test-FalWorkflow.ps1`        | Validate workflow definitions            |

---

## Authentication

fal.ai requires a `FAL_KEY`. The module checks (in order):

1. `$env:FAL_KEY` environment variable
2. `FAL_KEY=...` in a `.env` file in the current directory

```powershell
# Option 1: Environment variable
$env:FAL_KEY = "your-key-here"

# Option 2: .env file
"FAL_KEY=your-key-here" | Set-Content .env
```

---

## Common Patterns

### Text-to-Image (Sync)

```powershell
.\scripts\Invoke-FalGenerate.ps1 -Prompt "A serene mountain landscape"
# Returns: PSCustomObject with .Images[].Url, .Seed, .Prompt
```

### Text-to-Image (Queue Mode)

```powershell
.\scripts\Invoke-FalGenerate.ps1 -Prompt "Epic fantasy castle" `
    -Model "fal-ai/flux/dev" -Queue
# Submits to queue, polls until complete, returns result
```

### Image-to-Video

```powershell
.\scripts\Invoke-FalGenerate.ps1 `
    -Prompt "Camera slowly zooms in" `
    -Model "fal-ai/kling-video/v2.6/pro/image-to-video" `
    -ImageUrl "https://example.com/photo.jpg" `
    -Queue
```

### Upload Then Generate

```powershell
Import-Module .\scripts\FalAi.psm1
$url = Send-FalFile -FilePath ".\photo.jpg"
.\scripts\Invoke-FalGenerate.ps1 -Prompt "Animate this" `
    -Model "fal-ai/kling-video/v2.6/pro/image-to-video" `
    -ImageUrl $url -Queue
```

### Get Model Schema

```powershell
.\scripts\Get-FalModel.ps1 -ModelId "fal-ai/flux/dev"
# Shows input parameters, output fields, category
```

### Test Connection

```powershell
.\scripts\Test-FalConnection.ps1
# [PASS] FAL_KEY found (fal-xxxx...)
# [PASS] API reachable (response: 245ms)
```

---

## Queue System

Long-running tasks (especially video) use the queue system:

```
Submit → Queue → Poll Status → Retrieve Result
                    ↓
              request_id
```

The `Wait-FalJob` function handles this automatically. Use the `-Queue` switch
on `Invoke-FalGenerate.ps1` to enable it.

**Queue flow:**
1. `POST https://queue.fal.run/{MODEL}` → `{ request_id: "..." }`
2. `GET  https://queue.fal.run/{MODEL}/requests/{ID}/status` → `{ status: "IN_QUEUE" | "IN_PROGRESS" | "COMPLETED" | "FAILED" }`
3. `GET  https://queue.fal.run/{MODEL}/requests/{ID}` → final result

**Status values:** `IN_QUEUE`, `IN_PROGRESS`, `COMPLETED`, `FAILED`

---

## File Upload (CDN)

`Send-FalFile` uploads local files to fal.ai CDN:

```
1. POST rest.alpha.fal.ai/storage/auth/token?storage_type=fal-cdn-v3
   → { token, token_type, base_url }

2. POST {base_url}/files/upload
   Authorization: {token_type} {token}
   → { access_url: "https://v3b.fal.media/files/..." }
```

**Supported:** jpg, jpeg, png, gif, webp, mp4, mov, mp3, wav  
**Max size:** 100 MB (simple upload)

---

## Error Handling

fal.ai returns errors in several formats. `ConvertTo-FalError` handles all:

```json
{"detail": "Invalid API key"}
{"detail": [{"msg": "field required", "type": "value_error"}]}
{"error": "Model not found"}
{"message": "Rate limit exceeded"}
```

`Invoke-FalApi` automatically retries on HTTP 429 (rate limit) and 5xx (server error)
with exponential backoff, up to 3 attempts.

**Common errors:**
| Error | Cause | Fix |
|-------|-------|-----|
| `FAL_KEY not found` | No API key configured | Set `$env:FAL_KEY` |
| `HTTP 401` | Invalid API key | Check key at fal.ai dashboard |
| `HTTP 429` | Rate limited | Auto-retried; reduce request rate |
| `HTTP 422` | Invalid parameters | Check model schema with `Get-FalModel.ps1` |
| `Job timed out` | Generation exceeded timeout | Increase `-TimeoutSeconds` |

---

## Recommended Models

### Text-to-Image

| Model | Notes |
|-------|-------|
| `fal-ai/flux/dev` | Good balance (default) |
| `fal-ai/flux/schnell` | Fast (~1 second) |
| `fal-ai/nano-banana-pro` | Best overall |
| `fal-ai/ideogram/v3` | Best for text rendering |

### Text-to-Video

| Model | Notes |
|-------|-------|
| `fal-ai/veo3.1` | High quality |
| `fal-ai/kling-video/v2.5-turbo/pro` | Fast, reliable |

### Image-to-Video

| Model | Notes |
|-------|-------|
| `fal-ai/kling-video/v2.6/pro/image-to-video` | Best overall |
| `fal-ai/veo3/fast` | Fast, high quality |

---

## Script Parameters Reference

### Invoke-FalGenerate.ps1

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Prompt` | string | *(required)* | Text description |
| `-Model` | string | `fal-ai/flux/dev` | Model endpoint |
| `-ImageSize` | string | `landscape_4_3` | Size preset |
| `-NumImages` | int | 1 | Number of images |
| `-Seed` | int | — | Reproducibility seed |
| `-ImageUrl` | string | — | Input image URL |
| `-Strength` | double | — | img2img strength |
| `-NumInferenceSteps` | int | — | Inference steps |
| `-GuidanceScale` | double | — | CFG scale |
| `-EnableSafetyChecker` | switch | — | Safety filter |
| `-Queue` | switch | — | Use queue mode |

### Get-FalModel.ps1

| Parameter | Type | Description |
|-----------|------|-------------|
| `-ModelId` | string | Model endpoint (required) |
| `-InputOnly` | switch | Show only input schema |
| `-OutputOnly` | switch | Show only output schema |

---

## Output Format

### Image Generation

```json
{
  "Images": [{ "Url": "https://v3.fal.media/files/...", "Width": 1024, "Height": 768 }],
  "Seed": 42,
  "Prompt": "A serene mountain landscape",
  "Model": "fal-ai/flux/dev",
  "Video": null
}
```

### Video Generation

```json
{
  "Images": [],
  "Seed": null,
  "Prompt": "Ocean waves crashing",
  "Model": "fal-ai/veo3.1",
  "Video": { "Url": "https://v3.fal.media/files/.../video.mp4" }
}
```

---

## Presenting Results

**Images:**
```
![Generated](https://v3.fal.media/files/...)
• 1024×768 | Model: fal-ai/flux/dev
```

**Videos:**
```
[Click to view video](https://v3.fal.media/files/.../video.mp4)
• Model: fal-ai/veo3.1
```
