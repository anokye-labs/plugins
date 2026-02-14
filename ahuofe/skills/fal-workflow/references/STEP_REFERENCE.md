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
**Chains to:** Cannot chain to image-based steps.

---

## Chaining Rules

### Compatibility Matrix

Source output → Target input compatibility:

| Source Step | Output Format | Compatible Targets |
|------------|---------------|--------------------|
| generate | `images[0].url` | upscale, edit, animate, restyle |
| upscale | `image.url` | animate, edit, restyle |
| edit | `images[0].url` | upscale, animate, restyle |
| restyle | `images[0].url` | upscale, animate |
| animate | `video.url` | *(terminal — no image output)* |
| video-gen | `video.url` | *(terminal — no image output)* |

### Auto-Injection Rules

The workflow engine in `New-FalWorkflow.ps1` auto-injects output from
the **last dependency** into the dependent step:

1. If prior step has `images[]` → injects `images[0].url` as `image_url`
2. If prior step has `video.url` → injects `video.url` as `image_url`
3. Explicit `image_url` in step `params` overrides auto-injection

### Invalid Chains

These combinations will fail:

| Chain | Why It Fails |
|-------|-------------|
| animate → upscale | Animate outputs video, upscale expects image |
| animate → edit | Animate outputs video, edit expects image |
| video-gen → upscale | Video output, image input expected |
| edit without mask_url | Inpainting requires both image and mask |

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
| `prompt` | All except upscale | Text description or guidance |
| `image_url` | upscale, edit, animate, restyle | Source image (auto-injected) |
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
| `mask_url is required` | edit | Missing mask parameter | Add `mask_url` to edit step params |
| `Job timed out` | animate, video-gen | Video generation exceeded timeout | Retry — video gen can be slow |
| `HTTP 422` | Any | Invalid parameters for model | Check model schema with `Get-FalModel.ps1` |
| `HTTP 429` | Any | Rate limited | Auto-retried; reduce request frequency |
