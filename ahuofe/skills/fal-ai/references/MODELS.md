# fal.ai Model Reference

Comprehensive reference for all supported fal.ai models. Use `Get-FalModel.ps1`
or `Get-ModelSchema.ps1` to fetch live schemas for any model.

---

## Quick Reference

| Model | Endpoint | Category | Speed | Cost |
|-------|----------|----------|-------|------|
| FLUX Dev | `fal-ai/flux/dev` | Text-to-Image | ⚡⚡ Medium | 💰 Low |
| FLUX Schnell | `fal-ai/flux/schnell` | Text-to-Image | ⚡⚡⚡ Fast | 💰 Low |
| FLUX Pro Ultra | `fal-ai/flux-pro/v1.1-ultra` | Text-to-Image | ⚡ Slow | 💰💰💰 High |
| Kling Video (T2V) | `fal-ai/kling-video/v2.6/pro/text-to-video` | Text-to-Video | ⚡ Slow | 💰💰💰 High |
| Kling Video (I2V) | `fal-ai/kling-video/v2.6/pro/image-to-video` | Image-to-Video | ⚡ Slow | 💰💰💰 High |
| Aura SR | `fal-ai/aura-sr` | Upscale | ⚡⚡⚡ Fast | 💰 Low |
| Whisper | `fal-ai/whisper` | Speech-to-Text | ⚡⚡ Medium | 💰 Low |
| MiniMax TTS | `fal-ai/minimax-tts` | Text-to-Speech | ⚡⚡ Medium | 💰💰 Medium |
| Inpainting | `fal-ai/inpainting` | Image Editing | ⚡⚡ Medium | 💰 Low |

---

## Text-to-Image Models

### FLUX Dev

General-purpose image generation with good quality/speed balance. **Default model.**

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/flux/dev` |
| **Mode** | Sync or Queue |
| **Speed** | ~3–5 seconds |
| **Cost Tier** | Low |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Text description of the image |
| `image_size` | string | | `landscape_4_3` | Size preset (`square_hd`, `square`, `portrait_4_3`, `portrait_16_9`, `landscape_4_3`, `landscape_16_9`) |
| `num_images` | integer | | `1` | Number of images (1–4) |
| `seed` | integer | | random | Seed for reproducibility |
| `num_inference_steps` | integer | | `28` | Denoising steps (higher = better quality, slower) |
| `guidance_scale` | number | | `3.5` | CFG scale — how closely to follow prompt |
| `enable_safety_checker` | boolean | | `true` | Enable content safety filter |
| `image_url` | string | | — | Input image for img2img |
| `strength` | number | | `0.85` | img2img denoising strength (0.0–1.0) |

**Output Format:**

```json
{
  "images": [{ "url": "https://v3.fal.media/files/...", "width": 1024, "height": 768 }],
  "seed": 42,
  "has_nsfw_concepts": [false],
  "prompt": "A serene mountain landscape"
}
```

---

### FLUX Schnell

Optimized for speed. Best for rapid iteration and prototyping.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/flux/schnell` |
| **Mode** | Sync or Queue |
| **Speed** | ~1 second |
| **Cost Tier** | Low |

**Input Parameters:** Same as FLUX Dev.

**Key Differences from FLUX Dev:**
- Fewer inference steps required (default: 4)
- Lower quality ceiling but dramatically faster
- Best for drafts and rapid exploration

---

### FLUX Pro v1.1 Ultra

Highest-quality image generation. Premium model for production-grade output.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/flux-pro/v1.1-ultra` |
| **Mode** | Sync or Queue |
| **Speed** | ~10–20 seconds |
| **Cost Tier** | High |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Text description |
| `image_size` | string | | `landscape_4_3` | Size preset |
| `num_images` | integer | | `1` | Number of images |
| `seed` | integer | | random | Reproducibility seed |
| `guidance_scale` | number | | `3.5` | CFG scale |
| `safety_tolerance` | string | | `2` | Safety tolerance level |
| `raw` | boolean | | `false` | Generate less processed images |

**Key Differences:**
- Higher resolution output (up to 2048×2048)
- Better coherence for complex prompts
- Supports `raw` mode for more natural outputs
- Premium pricing — use for final output, not iteration

---

## Video Models

### Kling Video — Text-to-Video

Generate videos from text descriptions.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/kling-video/v2.6/pro/text-to-video` |
| **Mode** | Queue only (always async) |
| **Speed** | ~60–120 seconds |
| **Cost Tier** | High |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Text description of the video |
| `duration` | integer | | `5` | Duration in seconds (5 or 10) |
| `aspect_ratio` | string | | `16:9` | Aspect ratio (`16:9`, `9:16`, `1:1`) |

**Output Format:**

```json
{
  "video": { "url": "https://v3.fal.media/files/.../video.mp4" }
}
```

**Script:** `Invoke-FalVideoGen.ps1`

---

### Kling Video — Image-to-Video

Animate a static image into a video.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/kling-video/v2.6/pro/image-to-video` |
| **Mode** | Queue only (always async) |
| **Speed** | ~60–120 seconds |
| **Cost Tier** | High |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `image_url` | string | ✅ | — | URL of source image |
| `prompt` | string | | — | Motion guidance text |
| `duration` | integer | | `5` | Duration in seconds (5 or 10) |

**Output Format:**

```json
{
  "video": { "url": "https://v3.fal.media/files/.../video.mp4" }
}
```

**Script:** `Invoke-FalImageToVideo.ps1`

---

## Enhancement Models

### Aura SR (Super Resolution)

Upscale images using AI super-resolution.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/aura-sr` |
| **Mode** | Sync or Queue |
| **Speed** | ~2–5 seconds |
| **Cost Tier** | Low |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `image_url` | string | ✅ | — | URL of image to upscale |
| `scale` | integer | | `2` | Upscale factor (2 or 4) |

**Output Format:**

```json
{
  "image": {
    "url": "https://v3.fal.media/files/...",
    "width": 2048,
    "height": 1536
  }
}
```

**Script:** `Invoke-FalUpscale.ps1`

---

### Inpainting

Edit specific regions of an image using a mask and text prompt.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/inpainting` |
| **Mode** | Sync or Queue |
| **Speed** | ~5–10 seconds |
| **Cost Tier** | Low |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `image_url` | string | ✅ | — | URL of source image |
| `mask_url` | string | ✅ | — | URL of mask (white = inpaint area) |
| `prompt` | string | ✅ | — | What to paint in masked region |
| `strength` | number | | `0.85` | Inpainting strength (0.0–1.0) |
| `num_inference_steps` | integer | | `30` | Denoising steps |
| `guidance_scale` | number | | `7.5` | CFG scale |

**Output Format:**

```json
{
  "images": [{ "url": "https://v3.fal.media/files/...", "width": 1024, "height": 1024 }],
  "seed": 42
}
```

**Script:** `Invoke-FalInpainting.ps1`

---

## Audio Models

### Whisper (Speech-to-Text)

Transcribe audio files to text.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/whisper` |
| **Mode** | Sync or Queue |
| **Speed** | ~5–30 seconds (depends on audio length) |
| **Cost Tier** | Low |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `audio_url` | string | ✅ | — | URL of audio file |
| `language` | string | | auto | Language code (e.g., `en`, `es`) |
| `task` | string | | `transcribe` | `transcribe` or `translate` |
| `chunk_level` | string | | `segment` | `segment` or `word` |

**Output Format:**

```json
{
  "text": "Hello, this is a test transcription.",
  "chunks": [
    { "timestamp": [0.0, 2.5], "text": "Hello, this is" },
    { "timestamp": [2.5, 4.0], "text": "a test transcription." }
  ]
}
```

---

### MiniMax TTS (Text-to-Speech)

Convert text to natural-sounding speech.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/minimax-tts` |
| **Mode** | Sync or Queue |
| **Speed** | ~3–10 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `text` | string | ✅ | — | Text to synthesize |
| `voice_id` | string | | default | Voice preset identifier |
| `speed` | number | | `1.0` | Playback speed (0.5–2.0) |

**Output Format:**

```json
{
  "audio": { "url": "https://v3.fal.media/files/.../audio.mp3" }
}
```

---

## Model Selection Guide

### By Use Case

| I want to... | Use this model | Why |
|--------------|---------------|-----|
| Quickly iterate on prompts | `fal-ai/flux/schnell` | ~1s generation, lowest cost |
| Generate production images | `fal-ai/flux-pro/v1.1-ultra` | Highest quality output |
| Generate with good balance | `fal-ai/flux/dev` | Quality/speed/cost sweet spot |
| Create a video from text | `fal-ai/kling-video/v2.6/pro/text-to-video` | Best text-to-video quality |
| Animate a photo | `fal-ai/kling-video/v2.6/pro/image-to-video` | Best image-to-video |
| Upscale a low-res image | `fal-ai/aura-sr` | Fast, reliable upscaling |
| Edit part of an image | `fal-ai/inpainting` | Mask-based regional editing |
| Transcribe audio | `fal-ai/whisper` | Industry-standard STT |
| Generate speech | `fal-ai/minimax-tts` | Natural-sounding TTS |

### By Priority

| Priority | Model | Trade-off |
|----------|-------|-----------|
| **Speed** | `flux/schnell` | Lower quality |
| **Quality** | `flux-pro/v1.1-ultra` | Slower, more expensive |
| **Cost** | `flux/schnell` | Good enough for most uses |
| **Balance** | `flux/dev` | Default recommendation |

### Sync vs Queue Mode

| Mode | Best for | Timeout |
|------|----------|---------|
| **Sync** (`fal.run`) | Image generation, upscaling | ~60s |
| **Queue** (`queue.fal.run`) | Video generation, long tasks | Configurable (default: 300s) |

> **Rule of thumb:** Use sync for image models, queue for video models.
> Video scripts (`Invoke-FalVideoGen.ps1`, `Invoke-FalImageToVideo.ps1`) default
> to queue mode automatically.

---

## Discovering New Models

Use `Search-FalModels.ps1` to find models beyond this reference:

```powershell
# Search by keyword
.\scripts\Search-FalModels.ps1 -Query "upscale"

# Search by category
.\scripts\Search-FalModels.ps1 -Category "text-to-image"

# Get full schema for any model
.\scripts\Get-FalModel.ps1 -ModelId "fal-ai/flux/dev"
.\scripts\Get-ModelSchema.ps1 -ModelId "fal-ai/flux/dev" -InputOnly
```
