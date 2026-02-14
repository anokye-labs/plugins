# Node Types

All workflow node types supported by `scripts/New-FalWorkflow.ps1`. Each node
wraps a fal.ai model endpoint and defines required/optional parameters and
output schema.

---

## Generator Nodes

Nodes that create media from text prompts or source images.

### text-to-image

| Property | Value |
|----------|-------|
| **Node Type** | Generator |
| **Mode** | Sync |

| Model Endpoint | Speed | Quality | Cost |
|----------------|-------|---------|------|
| `fal-ai/flux/dev` | Medium (~5s) | High | $$ |
| `fal-ai/flux/schnell` | Fast (~1s) | Good | $ |
| `fal-ai/flux-pro/v1.1-ultra` | Slow (~15s) | Best | $$$ |

**Required Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `prompt` | string | Text description of the image to generate |

**Optional Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `image_size` | string | `landscape_4_3` | Size preset (`square_hd`, `landscape_16_9`, `portrait_4_3`, etc.) |
| `num_images` | int | `1` | Number of images to generate (1–4) |
| `seed` | int | random | Reproducibility seed |
| `num_inference_steps` | int | model default | Denoising steps (higher = more detail) |
| `guidance_scale` | float | model default | Prompt adherence (higher = stricter) |

**Output Schema:**

```json
{
  "images": [{ "url": "https://...", "width": 1024, "height": 768 }],
  "seed": 42
}
```

---

### text-to-video

| Property | Value |
|----------|-------|
| **Node Type** | Generator |
| **Mode** | Queue (automatic) |

| Model Endpoint | Duration | Quality |
|----------------|----------|---------|
| `fal-ai/kling-video/v2.6/pro/text-to-video` | 5–10s | High |
| `fal-ai/veo3.1` | 5–10s | High |

**Required Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `prompt` | string | Video scene description |

**Optional Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `duration` | int | `5` | Video duration in seconds (5 or 10) |
| `aspect_ratio` | string | `16:9` | Output aspect ratio |

**Output Schema:**

```json
{ "video": { "url": "https://v3.fal.media/files/.../video.mp4" } }
```

---

### image-to-video

| Property | Value |
|----------|-------|
| **Node Type** | Generator |
| **Mode** | Queue (automatic — model matches `video` pattern) |
| **Model Endpoint** | `fal-ai/kling-video/v2.6/pro/image-to-video` |

**Required Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `image_url` | string | Source image (auto-injected from prior step) |

**Optional Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `prompt` | string | — | Motion guidance text |
| `duration` | int | `5` | Video duration in seconds (5 or 10) |

**Output Schema:**

```json
{ "video": { "url": "https://v3.fal.media/files/.../video.mp4" } }
```

**Note:** This node is typically the terminal step in a pipeline. Its video
output cannot chain to image-based processor nodes.

---

## Processor Nodes

Nodes that transform existing images. They receive `image_url` from a prior
step via auto-injection or explicit parameter.

### upscale

| Property | Value |
|----------|-------|
| **Node Type** | Processor |
| **Mode** | Sync |
| **Model Endpoint** | `fal-ai/aura-sr` |

**Required Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `image_url` | string | Image to upscale (auto-injected from prior step) |

**Optional Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `scale` | int | `2` | Upscale factor (2 or 4) |

**Output Schema:**

```json
{ "image": { "url": "https://...", "width": 2048, "height": 1536 } }
```

**Note:** Output uses singular `image` (not `images[]`). The workflow engine
handles the mapping automatically when chaining to the next step.

---

### inpaint

| Property | Value |
|----------|-------|
| **Node Type** | Processor |
| **Mode** | Sync |
| **Model Endpoint** | `fal-ai/inpainting` |

**Required Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `image_url` | string | Source image (auto-injected from prior step) |
| `mask_url` | string | Mask image (white = area to edit) |
| `prompt` | string | What to paint in the masked region |

**Optional Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `strength` | float | `0.85` | Edit intensity (0.0–1.0) |
| `num_inference_steps` | int | `30` | Denoising steps |
| `guidance_scale` | float | `7.5` | Prompt adherence |

**Output Schema:**

```json
{ "images": [{ "url": "https://...", "width": 1024, "height": 1024 }], "seed": 42 }
```

**Important:** `mask_url` must be a hosted URL. Upload local masks with
`Send-FalFile` before building the workflow.

---

### edit (restyle / img2img)

| Property | Value |
|----------|-------|
| **Node Type** | Processor |
| **Mode** | Sync |
| **Model Endpoints** | `fal-ai/flux/dev`, `fal-ai/flux/schnell` |

**Required Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `image_url` | string | Source image (auto-injected from prior step) |
| `prompt` | string | Style or content description |
| `strength` | float | How much to change (0.0–1.0) |

**Optional Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `num_inference_steps` | int | `28` | Quality steps |
| `guidance_scale` | float | model default | Prompt adherence |

**Output Schema:**

```json
{ "images": [{ "url": "https://...", "width": 1024, "height": 768 }], "seed": 42 }
```

---

## Utility Nodes

Utility operations used around workflow steps. These are not invoked by the
workflow engine directly but are available as helper scripts.

### CDN Upload

| Property | Value |
|----------|-------|
| **Script** | `scripts/Upload-ToFalCDN.ps1` |
| **Function** | `Send-FalFile` (in `FalAi.psm1`) |

Upload a local file to fal.ai CDN to obtain a hosted URL for use in
workflow step parameters (e.g., `mask_url`, `image_url`).

**Input:** Local file path
**Output:** CDN URL string

---

### Queue Poll

| Property | Value |
|----------|-------|
| **Script** | `scripts/Get-QueueStatus.ps1` |
| **Function** | `Wait-FalJob` (in `FalAi.psm1`) |

Poll a queued job until completion. The workflow engine calls this
automatically for video models (any model matching the `video|veo` pattern).

**Input:** `RequestId`, `Model`
**Output:** Job result (same schema as the model's sync output)

---

### Quality Check

| Property | Value |
|----------|-------|
| **Scripts** | `scripts/Measure-ImageQuality.ps1`, `scripts/Measure-VideoQuality.ps1` |

Evaluate output quality between workflow steps. Use these scripts
outside the workflow engine for quality checkpoints.

**Input:** Image or video URL
**Output:** Quality metrics object

---

## Node Chaining Compatibility

| Source Node | Output Type | Compatible Targets |
|-------------|-------------|--------------------|
| text-to-image | `images[0].url` | upscale, inpaint, edit, image-to-video |
| text-to-video | `video.url` | *(terminal)* |
| image-to-video | `video.url` | *(terminal)* |
| upscale | `image.url` | inpaint, edit, image-to-video |
| inpaint | `images[0].url` | upscale, edit, image-to-video |
| edit | `images[0].url` | upscale, inpaint, image-to-video |

Video nodes produce `video.url` which cannot chain to image-based nodes.
