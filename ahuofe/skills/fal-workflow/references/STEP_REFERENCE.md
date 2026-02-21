# Step Reference

All available step types for `New-FalWorkflow.ps1`, their inputs, outputs,
and chaining rules.

---

## Step Types

### generate

Create an image from a text prompt.

| Property | Value |
|----------|-------|
| **Models** | `fal-ai/flux/dev`, `fal-ai/flux/schnell`, `fal-ai/flux-pro/v1.1-ultra` |
| **Mode** | Sync (auto) |
| **Typical Time** | 1–20s depending on model |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Text description |
| `image_size` | string | | `landscape_4_3` | Size preset |
| `num_images` | int | | `1` | Number of images |
| `seed` | int | | random | Reproducibility seed |
| `num_inference_steps` | int | | model default | Quality steps |
| `guidance_scale` | float | | model default | Prompt adherence |

**Output:**

```json
{ "images": [{ "url": "https://...", "width": 1024, "height": 768 }], "seed": 42 }
```

**Chains to:** Any step that accepts `image_url` (upscale, edit, animate, restyle).

---

### upscale

Increase image resolution using AI super-resolution.

| Property | Value |
|----------|-------|
| **Models** | `fal-ai/aura-sr` |
| **Mode** | Sync (auto) |
| **Typical Time** | 2–5s |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `image_url` | string | ✅ | *auto from prior step* | Image to upscale |
| `scale` | int | | `2` | Upscale factor (2 or 4) |

**Output:**

```json
{ "image": { "url": "https://...", "width": 2048, "height": 1536 } }
```

**Chains from:** generate, edit, restyle — any step producing `images[].url`.
**Chains to:** animate — passes `image.url` as `image_url`.

**Note:** Aura SR ignores the `scale` parameter in its payload; the output
is determined by the model. The engine passes the output `image.url` to
the next step. If the next step expects `images[0].url` format, the engine
handles the mapping automatically.

---

### edit (inpaint)

Edit a region of an image using a mask and replacement prompt.

| Property | Value |
|----------|-------|
| **Models** | `fal-ai/inpainting` |
| **Mode** | Sync (auto) |
| **Typical Time** | 5–10s |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `image_url` | string | ✅ | *auto from prior step* | Source image |
| `mask_url` | string | ✅ | — | Mask image (white = edit area) |
| `prompt` | string | ✅ | — | What to paint in masked region |
| `strength` | float | | `0.85` | Edit intensity (0.0–1.0) |
| `num_inference_steps` | int | | `30` | Quality steps |
| `guidance_scale` | float | | `7.5` | Prompt adherence |

**Output:**

```json
{ "images": [{ "url": "https://...", "width": 1024, "height": 1024 }], "seed": 42 }
```

**Chains from:** generate — receives `images[0].url` as `image_url`.
**Chains to:** upscale, animate, restyle.

**Important:** The `mask_url` must point to a hosted image. Upload local
masks with `Send-FalFile` before building the workflow.

---

### animate (image-to-video)

Animate a still image into a video.

| Property | Value |
|----------|-------|
| **Models** | `fal-ai/kling-video/v2.6/pro/image-to-video` |
| **Mode** | Queue (auto — model matches `video` pattern) |
| **Typical Time** | 60–120s |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `image_url` | string | ✅ | *auto from prior step* | Source image |
| `prompt` | string | | — | Motion guidance text |
| `duration` | int | | `5` | Video duration (5 or 10 seconds) |

**Output:**

```json
{ "video": { "url": "https://v3.fal.media/files/.../video.mp4" } }
```

**Chains from:** generate, upscale, edit — any step producing an image URL.
**Chains to:** Typically the final step. Cannot chain to image-based steps.

**Tips for motion prompts:**
- Use specific motion verbs: "pan left", "zoom in", "orbit around"
- Describe what moves: "wind blows through the trees", "waves crash"
- Keep prompts short and focused on motion, not scene description

---

### restyle (img2img)

Re-render an image with a new style using img2img.

| Property | Value |
|----------|-------|
| **Models** | `fal-ai/flux/dev`, `fal-ai/flux/schnell` |
| **Mode** | Sync (auto) |
| **Typical Time** | 3–5s |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `image_url` | string | ✅ | *auto from prior step* | Source image |
| `prompt` | string | ✅ | — | Style description |
| `strength` | float | ✅ | — | How much to change (0.0–1.0) |
| `num_inference_steps` | int | | `28` | Quality steps |

**Output:**

```json
{ "images": [{ "url": "https://...", "width": 1024, "height": 768 }], "seed": 42 }
```

**Chains from:** generate, edit.
**Chains to:** upscale, animate.

**Strength guide:**
| Value | Effect |
|-------|--------|
| 0.3–0.4 | Subtle style shift, strong original preservation |
| 0.5–0.6 | Balanced transformation |
| 0.7–0.8 | Heavy restyling, loose composition from original |
| 0.9–1.0 | Near-complete regeneration using prompt |

---

### video-gen (text-to-video)

Generate a video directly from a text prompt (no source image).

| Property | Value |
|----------|-------|
| **Models** | `fal-ai/kling-video/v2.6/pro/text-to-video`, `fal-ai/veo3.1` |
| **Mode** | Queue (auto) |
| **Typical Time** | 60–180s |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Video description |
| `duration` | int | | `5` | Duration in seconds |
| `aspect_ratio` | string | | `16:9` | Aspect ratio |

**Output:**

```json
{ "video": { "url": "https://v3.fal.media/files/.../video.mp4" } }
```

**Chains from:** Typically the first step (no image input needed).
**Chains to:** extract-frame, merge-videos, merge-audio-video, *(terminal)*.

---

### extract-frame

Extract the first or last frame from a video as a static image. Bridges video
output into image-based steps (upscale, edit, animate).

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/ffmpeg-api/extract-frame` |
| **Mode** | Sync (auto) |
| **Typical Time** | 1–3s |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `video_url` | string | ✅ | *auto from prior video step* | Source video |
| `frame_type` | string | ✅ | — | `"first"` or `"last"` |

**Output:**

```json
{ "frame": { "url": "https://v3.fal.media/files/.../frame.jpg" } }
```

**Chains from:** animate, video-gen — any step producing `video.url`.
**Chains to:** upscale, edit, restyle, animate — any step accepting `image_url`.

**Example:**

```powershell
@{
    name       = "last-frame"
    model      = "fal-ai/ffmpeg-api/extract-frame"
    params     = @{ frame_type = "last" }
    dependsOn  = @("scene1")
}
```

---

### merge-videos

Concatenate multiple video clips into a single video in the order supplied.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/ffmpeg-api/merge-videos` |
| **Mode** | Sync (auto) |
| **Typical Time** | 2–10s |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `video_urls` | string[] | ✅ | — | Ordered array of video URLs to concatenate |

**Output:**

```json
{ "video": { "url": "https://v3.fal.media/files/.../merged.mp4" } }
```

**Chains from:** animate, video-gen — depends on multiple video-producing steps.
**Chains to:** merge-audio-video, or terminal.

**Example:**

```powershell
@{
    name       = "final-cut"
    model      = "fal-ai/ffmpeg-api/merge-videos"
    params     = @{
        video_urls = @("$($steps['scene1'].video.url)", "$($steps['scene2'].video.url)")
    }
    dependsOn  = @("scene1", "scene2")
}
```

---

### merge-audio-video

Overlay an audio track onto a video. Audio loops if shorter than the video and
is trimmed if longer.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/ffmpeg-api/merge-audio-video` |
| **Mode** | Sync (auto) |
| **Typical Time** | 2–10s |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `video_url` | string | ✅ | *auto from prior video step* | Source video |
| `audio_url` | string | ✅ | — | Audio track URL to overlay |

**Output:**

```json
{ "video": { "url": "https://v3.fal.media/files/.../output.mp4" } }
```

**Chains from:** animate, video-gen, merge-videos — any step producing `video.url`.
**Chains to:** *(terminal)*

**Example:**

```powershell
@{
    name       = "with-soundtrack"
    model      = "fal-ai/ffmpeg-api/merge-audio-video"
    params     = @{ audio_url = "https://cdn.example.com/music.mp3" }
    dependsOn  = @("final-cut")
}
```

---

### llm (Text Generation)

Generate text from a prompt using a language model.

| Property | Value |
|----------|-------|
| **Endpoint** | `openrouter/router` |
| **Mode** | Sync (auto) |
| **Typical Time** | 1–5s |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | User instruction or question |
| `system_prompt` | string | | — | System-level instruction |
| `model` | string | | `google/gemini-2.5-flash` | OpenRouter model identifier |
| `temperature` | float | | model default | Sampling temperature (0.0–2.0) |

**Output:**

```json
{ "output": "Generated text string" }
```

**Reference output path:** `$node.output`

**Chains from:** Any step — `llm` typically starts a workflow or follows another text node.
**Chains to:** text-concat, merge-text, generate (passes output as `prompt`).

> **Note:** Text-only. Use `vision-llm` when you need to analyze an image.

---

### vision-llm (Image Analysis)

Analyze one or more images and produce a text description or answer.

| Property | Value |
|----------|-------|
| **Endpoint** | `openrouter/router/vision` |
| **Mode** | Sync (auto) |
| **Typical Time** | 2–8s |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Question or instruction about the image(s) |
| `image_urls` | array | ✅ | — | Image URLs to analyze |
| `system_prompt` | string | | — | System-level instruction |
| `model` | string | | `google/gemini-3-pro-preview` | OpenRouter vision model identifier |
| `temperature` | float | | model default | Sampling temperature (0.0–2.0) |
| `reasoning` | bool | | `false` | Enable chain-of-thought reasoning |

**Output:**

```json
{ "output": "Analysis or description text" }
```

**Reference output path:** `$node.output`

**Chains from:** generate, upscale, edit — any step producing an image URL.
**Chains to:** text-concat, merge-text, generate (passes output as `prompt`).

> **Warning:** ONLY use `vision-llm` when you need to analyze an image. For
> all text-only tasks use the plain `llm` step — it is faster and cheaper.

---

### text-concat (Concatenate 2 texts)

Concatenate exactly two text values into one.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/text-concat` |
| **Mode** | Sync (auto) |
| **Typical Time** | <1s |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `text1` | string | ✅ | — | First text (static string or `$node.output` reference) |
| `text2` | string | ✅ | — | Second text (typically a `$node.output` reference) |

**Output:**

```json
{ "results": "text1text2" }
```

**Reference output path:** `$node.results`

**Chains from:** llm, vision-llm — receives `$node.output` as `text1` or `text2`.
**Chains to:** merge-text, generate (passes `results` as `prompt`).

**Common pattern — Label + dynamic value:**

```json
{ "text1": "Cinematic scene: ", "text2": "$llm_step.output" }
```

---

### merge-text (Merge 3+ texts)

Merge an array of text values using a separator.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/workflow-utilities/merge-text` |
| **Mode** | Sync (auto) |
| **Typical Time** | <1s |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `texts` | array | ✅ | — | Array of text values or `$node.output` references |
| `separator` | string | | `""` | String inserted between each value |

**Output:**

```json
{ "text": "merged result" }
```

**Reference output path:** `$node.text`

**Chains from:** llm, vision-llm, text-concat — receives output references in the `texts` array.
**Chains to:** generate (passes `text` as `prompt`), llm (passes `text` as `prompt`).

**Common pattern — Combine labeled expert outputs:**

```json
{
  "texts": ["$expert1.results", "$expert2.results", "$expert3.results"],
  "separator": "\n\n"
}
```

---

## Chaining Rules

### Compatibility Matrix

Source output → Target input compatibility:

| Source Step | Output Format | Compatible Targets |
|------------|---------------|--------------------|
| generate | `images[0].url` | upscale, edit, animate, restyle, vision-llm |
| upscale | `image.url` | animate, edit, restyle, vision-llm |
| edit | `images[0].url` | upscale, animate, restyle, vision-llm |
| restyle | `images[0].url` | upscale, animate, vision-llm |
| animate | `video.url` | extract-frame, merge-videos, merge-audio-video |
| video-gen | `video.url` | extract-frame, merge-videos, merge-audio-video |
| extract-frame | `frame.url` (image) | upscale, edit, restyle, animate |
| merge-videos | `video.url` | merge-audio-video, *(terminal)* |
| merge-audio-video | `video.url` | *(terminal)* |
| llm | `output` (text) | text-concat, merge-text, generate, video-gen |
| vision-llm | `output` (text) | text-concat, merge-text, generate, video-gen |
| text-concat | `results` (text) | merge-text, generate, llm |
| merge-text | `text` (text) | generate, llm, video-gen |

### Auto-Injection Rules

The workflow engine in `New-FalWorkflow.ps1` auto-injects output from
the **last dependency** into the dependent step:

1. If prior step has `images[]` → injects `images[0].url` as `image_url`
2. If prior step has `image.url` → injects `image.url` as `image_url`
3. If prior step has `frame.url` → injects `frame.url` as `image_url`
4. If prior step has `video.url` → injects `video.url` as `video_url`
5. Explicit parameters in step `params` override auto-injection

Each step produces exactly one output type, so rules 1–4 are mutually exclusive.

### Invalid Chains

These combinations will fail:

| Chain | Why It Fails |
|-------|-------------|
| animate → upscale | Animate outputs video, upscale expects image — use extract-frame first |
| animate → edit | Animate outputs video, edit expects image — use extract-frame first |
| video-gen → upscale | Video output, image input expected — use extract-frame first |
| edit without mask_url | Inpainting requires both image and mask |
| merge-videos with single URL | Provide at least two URLs in `video_urls` |
| vision-llm without image_urls | Vision LLM requires at least one image URL |
| llm → vision-llm (no image) | llm output is text, vision-llm needs image URLs |

### Dependency Rules

1. Steps must form a **DAG** (directed acyclic graph) — no circular dependencies
2. A step can depend on **multiple** prior steps — the last dependency's output is used
3. Steps with **no dependencies** (`dependsOn = @()`) run first
4. The engine detects circular dependencies and throws before execution

---

## Output Formats by Model

### Image Models

All image models return the same structure:

```json
{
  "images": [
    {
      "url": "https://v3.fal.media/files/...",
      "width": 1024,
      "height": 768
    }
  ],
  "seed": 42
}
```

**Exception:** `fal-ai/aura-sr` (upscale) returns:

```json
{
  "image": {
    "url": "https://v3.fal.media/files/...",
    "width": 2048,
    "height": 1536
  }
}
```

Note the singular `image` vs. plural `images`.

### Video Models

```json
{
  "video": {
    "url": "https://v3.fal.media/files/.../video.mp4"
  }
}
```

---

## Common Parameters Across Steps

| Parameter | Used By | Description |
|-----------|---------|-------------|
| `prompt` | All except upscale, extract-frame, merge-videos, merge-audio-video, text-concat, merge-text | Text description or guidance |
| `system_prompt` | llm, vision-llm | System-level instruction for the model |
| `model` | llm, vision-llm | OpenRouter model identifier |
| `temperature` | llm, vision-llm | Sampling temperature (0.0–2.0) |
| `image_url` | upscale, edit, animate, restyle | Source image (auto-injected) |
| `image_urls` | vision-llm | Images to analyze (array) |
| `text1`, `text2` | text-concat | Text values to concatenate |
| `texts` | merge-text | Array of text values to merge |
| `separator` | merge-text | Delimiter between merged values |
| `video_url` | extract-frame, merge-audio-video | Source video (auto-injected from video step) |
| `video_urls` | merge-videos | Ordered array of video URLs to concatenate |
| `audio_url` | merge-audio-video | Audio track to overlay |
| `frame_type` | extract-frame | `"first"` or `"last"` frame to extract |
| `image_size` | generate | Output dimensions preset |
| `seed` | generate, edit, restyle | Reproducibility |
| `strength` | edit, restyle | Transform intensity |
| `duration` | animate, video-gen | Video length in seconds |
| `mask_url` | edit | Region mask for inpainting |
| `scale` | upscale | Upscale factor |
| `guidance_scale` | generate, edit, restyle | Prompt adherence |
| `num_inference_steps` | generate, edit, restyle | Quality/speed trade-off |

---

## Error Reference

| Error | Step | Cause | Fix |
|-------|------|-------|-----|
| `Circular dependency detected` | Any | `dependsOn` forms a loop | Remove the circular reference |
| `depends on unknown step` | Any | Typo in `dependsOn` name | Check step names match exactly |
| `image_url is required` | upscale, edit, animate | No prior step output or empty result | Verify prior step produces images |
| `image_urls is required` | vision-llm | No image URLs provided | Add `image_urls` array to step params |
| `video_url is required` | extract-frame, merge-audio-video | No prior video step or empty result | Verify prior step produces a video |
| `video_urls is required` | merge-videos | Missing or empty `video_urls` array | Provide at least two video URLs |
| `mask_url is required` | edit | Missing mask parameter | Add `mask_url` to edit step params |
| `audio_url is required` | merge-audio-video | Missing audio parameter | Add `audio_url` to merge-audio-video step params |
| `Job timed out` | animate, video-gen | Video generation exceeded timeout | Retry — video gen can be slow |
| `HTTP 422` | Any | Invalid parameters for model | Check model schema with `Get-FalModel.ps1` |
| `HTTP 429` | Any | Rate limited | Auto-retried; reduce request frequency |
