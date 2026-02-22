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

**Note:** This node is typically the terminal step in a pipeline. Use
`extract-frame` to bridge its video output into image-based processor nodes.

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

## FFmpeg Utility Nodes

Nodes that invoke the `fal-ai/ffmpeg-api` endpoints for video manipulation.
These enable video chaining, scene extension, and soundtrack overlay — patterns
that are impossible with generator/processor nodes alone.

### extract-frame

| Property | Value |
|----------|-------|
| **Node Type** | FFmpeg Utility |
| **Mode** | Sync |
| **Endpoint** | `fal-ai/ffmpeg-api/extract-frame` |

Extract the first or last frame from a video as a static image. Use this to
bridge video output into image-based steps (upscale, edit, image-to-video).

**Required Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `video_url` | string | Source video URL (auto-injected from prior video step) |
| `frame_type` | string | Which frame to extract: `"first"` or `"last"` |

**Output Schema:**

```json
{ "frame": { "url": "https://v3.fal.media/files/.../frame.jpg" } }
```

**Reference expression:** `$node.frame.url`

**Use Cases:** Get last frame for video extension, first frame for transitions.
Bridge an animate or video-gen step into upscale, edit, restyle, or a new animate step.

---

### merge-videos

| Property | Value |
|----------|-------|
| **Node Type** | FFmpeg Utility |
| **Mode** | Sync |
| **Endpoint** | `fal-ai/ffmpeg-api/merge-videos` |

Concatenate multiple video URLs into a single video in the order supplied.

**Required Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `video_urls` | string[] | Ordered array of video URLs to concatenate |

**Output Schema:**

```json
{ "video": { "url": "https://v3.fal.media/files/.../merged.mp4" } }
```

**Reference expression:** `$node.video.url`

**Use Cases:** Multi-scene compilation, merge parallel video-gen results into one clip.

---

### merge-audio-video

| Property | Value |
|----------|-------|
| **Node Type** | FFmpeg Utility |
| **Mode** | Sync |
| **Endpoint** | `fal-ai/ffmpeg-api/merge-audio-video` |

Overlay an audio track onto a video. The audio is mixed to the full duration of
the video; if the audio is shorter it loops, if longer it is trimmed.

**Required Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `video_url` | string | Source video URL |
| `audio_url` | string | Audio track URL to overlay |

**Output Schema:**

```json
{ "video": { "url": "https://v3.fal.media/files/.../output.mp4" } }
```

**Reference expression:** `$node.video.url`

**Use Cases:** Add soundtrack, add narration or sound effects to a video.

---

## Text Nodes

Nodes that generate or manipulate text. Use these to produce dynamic prompts
or combine text values within a workflow.

### LLM (Text Generation)

| Property | Value |
|----------|-------|
| **Node Type** | Text |
| **Mode** | Sync |
| **Model Endpoint** | `openrouter/router` |

**Required Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `prompt` | string | User-facing instruction or question |

**Optional Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `system_prompt` | string | — | System-level instruction for the model |
| `model` | string | `google/gemini-2.5-flash` | OpenRouter model identifier |
| `temperature` | float | model default | Sampling temperature (0.0–2.0) |

**Output Schema:**

```json
{ "output": "Generated text string" }
```

**Reference output path:** `$node.output`

> **Note:** Text-only node. Cannot analyze images. Use Vision LLM when you
> need to describe or interpret an image.

---

### Vision LLM (Image Analysis)

| Property | Value |
|----------|-------|
| **Node Type** | Text |
| **Mode** | Sync |
| **Model Endpoint** | `openrouter/router/vision` |

**Required Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `prompt` | string | Question or instruction about the image(s) |
| `image_urls` | array | One or more image URLs to analyze |

**Optional Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `system_prompt` | string | — | System-level instruction |
| `model` | string | `google/gemini-3-pro-preview` | OpenRouter vision model identifier |
| `temperature` | float | model default | Sampling temperature (0.0–2.0) |
| `reasoning` | bool | `false` | Enable chain-of-thought reasoning |

**Output Schema:**

```json
{ "output": "Analysis or description text" }
```

**Reference output path:** `$node.output`

> **Warning:** ONLY use Vision LLM when you actually need to analyze an image.
> For all text-only tasks (e.g., generating a scene description from a topic),
> use the plain LLM node (`openrouter/router`) — it is faster and cheaper.

---

### Text Concat (2 texts)

| Property | Value |
|----------|-------|
| **Node Type** | Text |
| **Mode** | Sync |
| **Model Endpoint** | `fal-ai/text-concat` |

**Required Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `text1` | string | First text value (static string or prior step output injected in PowerShell) |
| `text2` | string | Second text value (static string or prior step output injected in PowerShell) |

**Output Schema:**

```json
{ "results": "text1text2" }
```

**Reference output path:** `$node.results`

**Use cases:**
- Add a label or prefix to a dynamic value: set `text1` to a static prefix and `text2` to a prior step's output (extracted in PowerShell)
- Combine a static suffix with generated text

---

### Merge Text (Multiple texts)

| Property | Value |
|----------|-------|
| **Node Type** | Text |
| **Mode** | Sync |
| **Model Endpoint** | `fal-ai/workflow-utilities/merge-text` |

**Required Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `texts` | array | Array of text values to merge |

**Optional Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `separator` | string | `""` | String inserted between each text value |

**Output Schema:**

```json
{ "text": "merged result" }
```

**Reference output path:** `$node.text`

**Use cases:**
- Combine three or more LLM outputs into a single prompt
- Merge labeled expert responses with a newline separator

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
| text-to-video | `video.url` | extract-frame, merge-videos, merge-audio-video |
| image-to-video | `video.url` | extract-frame, merge-videos, merge-audio-video |
| upscale | `image.url` | inpaint, edit, image-to-video |
| inpaint | `images[0].url` | upscale, edit, image-to-video |
| edit | `images[0].url` | upscale, inpaint, image-to-video |
| extract-frame | `frame.url` (image) | upscale, edit, restyle, animate (image-to-video) |
| merge-videos | `video.url` | merge-audio-video, *(terminal)* |
| merge-audio-video | `video.url` | *(terminal)* |
| llm | `output` (text) | text-concat, merge-text, text-to-image (manual prompt), text-to-video (manual prompt) |
| vision-llm | `output` (text) | text-concat, merge-text, text-to-image (manual prompt), text-to-video (manual prompt) |
| text-concat | `results` (text) | merge-text, text-to-image (manual prompt), llm (manual prompt) |
| merge-text | `text` (text) | text-to-image (manual prompt), llm (manual prompt), text-to-video (manual prompt) |

Video nodes produce `video.url` which cannot chain to image-based nodes directly.
Use `extract-frame` to bridge a video step into an image-based step.
Text nodes produce string values that you can wire into prompt parameters of compatible generator or LLM nodes when defining workflows. The engine only auto-injects `image_url` outputs; it does not automatically inject text outputs into `prompt` parameters.
