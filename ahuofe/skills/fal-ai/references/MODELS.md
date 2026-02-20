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
| Nano Banana Pro | `fal-ai/nano-banana-pro` | Text-to-Image | ⚡⚡ Medium | 💰 Low |
| Nano Banana Pro Edit | `fal-ai/nano-banana-pro/edit` | Image Editing | ⚡⚡ Medium | 💰 Low |
| Ideogram v3 | `fal-ai/ideogram/v3` | Text-to-Image | ⚡⚡ Medium | 💰💰 Medium |
| Recraft v3 | `fal-ai/recraft-v3` | Text-to-Image | ⚡⚡ Medium | 💰💰 Medium |
| Seedream v4 Edit | `fal-ai/bytedance/seedream/v4/edit` | Image Editing | ⚡⚡ Medium | 💰💰 Medium |
| Kling Video (T2V) | `fal-ai/kling-video/v2.6/pro/text-to-video` | Text-to-Video | ⚡ Slow | 💰💰💰 High |
| Kling Video (I2V) | `fal-ai/kling-video/v2.6/pro/image-to-video` | Image-to-Video | ⚡ Slow | 💰💰💰 High |
| Seedance 1.5 Pro | `fal-ai/bytedance/seedance/v1.5/pro/image-to-video` | Image-to-Video | ⚡ Slow | 💰💰💰 High |
| Kling Video O1 | `fal-ai/kling-video/o1/image-to-video` | Image-to-Video | ⚡ Slow | 💰💰💰 High |
| Veo 3.1 Fast | `fal-ai/veo3.1/fast/image-to-video` | Image-to-Video | ⚡⚡ Medium | 💰💰 Medium |
| Aura SR | `fal-ai/aura-sr` | Upscale | ⚡⚡⚡ Fast | 💰 Low |
| SeedVR Upscale | `fal-ai/seedvr/upscale/image` | Upscale | ⚡⚡ Medium | 💰 Low |
| Background Remove | `fal-ai/bria/background/remove` | Image Processing | ⚡⚡⚡ Fast | 💰 Low |
| Crop Image | `fal-ai/workflow-utilities/crop-image` | Image Processing | ⚡⚡⚡ Fast | 💰 Free |
| Whisper | `fal-ai/whisper` | Speech-to-Text | ⚡⚡ Medium | 💰 Low |
| MiniMax TTS | `fal-ai/minimax-tts` | Text-to-Speech | ⚡⚡ Medium | 💰💰 Medium |
| ElevenLabs TTS v3 | `fal-ai/elevenlabs/tts/eleven-v3` | Text-to-Speech | ⚡⚡ Medium | 💰💰 Medium |
| MiniMax Speech 2.6 HD | `fal-ai/minimax/speech-2.6-hd` | Text-to-Speech | ⚡⚡ Medium | 💰💰 Medium |
| MiniMax Speech 2.6 Turbo | `fal-ai/minimax/speech-2.6-turbo` | Text-to-Speech | ⚡⚡⚡ Fast | 💰 Low |
| MiniMax Voice Clone | `fal-ai/minimax/voice-clone` | Voice Cloning | ⚡⚡ Medium | 💰💰 Medium |
| Chatterbox | `fal-ai/chatterbox/multilingual` | Text-to-Speech | ⚡⚡ Medium | 💰💰 Medium |
| ElevenLabs Music | `fal-ai/elevenlabs/music` | Music Generation | ⚡⚡ Medium | 💰💰 Medium |
| MMAudio | `fal-ai/mmaudio` | Video-to-Audio | ⚡⚡ Medium | 💰 Low |
| Stable Audio | `fal-ai/stable-audio` | Audio Generation | ⚡⚡ Medium | 💰 Low |
| MiniMax Music v2 | `fal-ai/minimax-music/v2` | Music Generation | ⚡⚡ Medium | 💰💰 Medium |
| Inpainting | `fal-ai/inpainting` | Image Editing | ⚡⚡ Medium | 💰 Low |
| Hunyuan3D v3 | `fal-ai/hunyuan3d-v3/image-to-3d` | 3D Generation | ⚡ Slow | 💰💰 Medium |
| Rodin v2 | `fal-ai/hyper3d/rodin/v2` | 3D Generation | ⚡ Slow | 💰💰 Medium |

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

### Nano Banana Pro

Best overall image generation. Community default for text-to-image.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/nano-banana-pro` |
| **Mode** | Sync or Queue |
| **Speed** | ~3–5 seconds |
| **Cost Tier** | Low |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Text description of the image |
| `aspect_ratio` | string | | `16:9` | Aspect ratio (`1:1`, `16:9`, `9:16`, `4:3`, `3:4`) |
| `num_images` | integer | | `1` | Number of images (1–4) |
| `seed` | integer | | random | Seed for reproducibility |

**Output Format:**

```json
{
  "images": [{ "url": "https://v3.fal.media/files/...", "width": 1024, "height": 576 }],
  "seed": 42
}
```

---

### Nano Banana Pro Edit

Edit existing images with text prompts. Community default for image editing.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/nano-banana-pro/edit` |
| **Mode** | Sync or Queue |
| **Speed** | ~5–10 seconds |
| **Cost Tier** | Low |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Editing instruction |
| `image_urls` | array | ✅ | — | Source image URL(s) to edit |
| `aspect_ratio` | string | | `16:9` | Output aspect ratio |
| `resolution` | string | | `4K` | Output resolution (`HD`, `4K`) |

**Output Format:**

```json
{
  "images": [{ "url": "https://v3.fal.media/files/...", "width": 3840, "height": 2160 }]
}
```

---

### Ideogram v3

Superior text rendering in images. Best when prompts include text, logos, or typography.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/ideogram/v3` |
| **Mode** | Sync or Queue |
| **Speed** | ~5–10 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Text description of the image |
| `aspect_ratio` | string | | `1:1` | Aspect ratio |
| `num_images` | integer | | `1` | Number of images (1–4) |
| `seed` | integer | | random | Reproducibility seed |
| `style` | string | | — | Style preset |

**Output Format:**

```json
{
  "images": [{ "url": "https://v3.fal.media/files/...", "width": 1024, "height": 1024 }]
}
```

---

### Recraft v3

Design-focused image generation with strong style control. Excellent for branding and illustrations.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/recraft-v3` |
| **Mode** | Sync or Queue |
| **Speed** | ~5–10 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Text description of the image |
| `image_size` | string | | `square_hd` | Size preset |
| `num_images` | integer | | `1` | Number of images |
| `style` | string | | — | Style identifier (e.g., `realistic_image`, `digital_illustration`) |
| `seed` | integer | | random | Reproducibility seed |

**Output Format:**

```json
{
  "images": [{ "url": "https://v3.fal.media/files/...", "width": 1024, "height": 1024 }]
}
```

---

### Seedream v4 Edit

Advanced image editing from ByteDance with high fidelity output.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/bytedance/seedream/v4/edit` |
| **Mode** | Queue only |
| **Speed** | ~10–20 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Editing instruction |
| `image_url` | string | ✅ | — | Source image URL |
| `seed` | integer | | random | Reproducibility seed |

**Output Format:**

```json
{
  "images": [{ "url": "https://v3.fal.media/files/...", "width": 1024, "height": 1024 }]
}
```

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

### Seedance 1.5 Pro — Image-to-Video

Animate a still image to video with optional built-in audio. **Community default for image-to-video.**

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/bytedance/seedance/v1.5/pro/image-to-video` |
| **Mode** | Queue only (always async) |
| **Speed** | ~60–120 seconds |
| **Cost Tier** | High |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `image_url` | string | ✅ | — | URL of source image |
| `prompt` | string | | — | Motion guidance text |
| `aspect_ratio` | string | | `16:9` | Output aspect ratio (`16:9`, `9:16`, `1:1`) |
| `resolution` | string | | `720p` | Output resolution (`480p`, `720p`, `1080p`) |
| `duration` | string | | `5` | Duration in seconds (`5` or `10`) |
| `generate_audio` | boolean | | `true` | Generate ambient audio from prompt |

**Output Format:**

```json
{
  "video": { "url": "https://v3.fal.media/files/.../video.mp4" }
}
```

---

### Kling Video O1 — Image-to-Video

Image-to-video generation with optional first **and** last frame control.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/kling-video/o1/image-to-video` |
| **Mode** | Queue only (always async) |
| **Speed** | ~60–120 seconds |
| **Cost Tier** | High |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `image_url` | string | ✅ | — | URL of the starting frame image |
| `prompt` | string | | — | Motion guidance text |
| `tail_image_url` | string | | — | URL of the ending frame image (optional) |
| `duration` | string | | `5` | Duration in seconds (`5` or `10`) |
| `aspect_ratio` | string | | `16:9` | Aspect ratio (`16:9`, `9:16`, `1:1`) |

**Output Format:**

```json
{
  "video": { "url": "https://v3.fal.media/files/.../video.mp4" }
}
```

**Use case:** Provide both `image_url` and `tail_image_url` to generate a video that smoothly transitions between two specific frames.

---

### Veo 3.1 Fast — Image-to-Video

High-quality image-to-video from Google Veo with fast generation times.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/veo3.1/fast/image-to-video` |
| **Mode** | Queue only (always async) |
| **Speed** | ~30–60 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `image_url` | string | ✅ | — | URL of source image |
| `prompt` | string | | — | Motion guidance text |
| `duration` | integer | | `5` | Duration in seconds |

**Output Format:**

```json
{
  "video": { "url": "https://v3.fal.media/files/.../video.mp4" }
}
```

---

## Enhancement Models

### SeedVR Upscale

High-quality AI image upscaling from ByteDance. Newer and higher quality than Aura SR.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/seedvr/upscale/image` |
| **Mode** | Sync or Queue |
| **Speed** | ~5–15 seconds |
| **Cost Tier** | Low |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `image_url` | string | ✅ | — | URL of image to upscale |

**Output Format:**

```json
{
  "image": {
    "url": "https://v3.fal.media/files/...",
    "width": 4096,
    "height": 2304
  }
}
```

---

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

### ElevenLabs TTS v3

High-quality text-to-speech with expressive voice control.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/elevenlabs/tts/eleven-v3` |
| **Mode** | Sync or Queue |
| **Speed** | ~3–10 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `text` | string | ✅ | — | Text to convert to speech |
| `voice` | string | | `Aria` | Voice name (e.g., `Aria`, `Roger`, `Sarah`) |
| `stability` | number | | `0.5` | Voice stability (0–1) |
| `similarity_boost` | number | | `0.75` | Voice clarity and similarity (0–1) |
| `speed` | number | | `1` | Speech speed multiplier |

**Output Format:**

```json
{
  "audio": { "url": "https://v3.fal.media/files/.../audio.mp3" }
}
```

---

### MiniMax Speech 2.6 HD

Best quality text-to-speech with fine-grained voice control.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/minimax/speech-2.6-hd` |
| **Mode** | Sync or Queue |
| **Speed** | ~3–10 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Text to convert to speech |
| `voice_setting` | object | | — | Voice configuration object |
| `voice_setting.voice_id` | string | | `Wise_Woman` | Voice ID (e.g., `Wise_Woman`, `Young_Man`) |
| `voice_setting.speed` | number | | `1` | Speech speed (0.5–2) |
| `voice_setting.vol` | number | | `1` | Volume (0–1) |
| `voice_setting.pitch` | integer | | `0` | Pitch adjustment (-12 to 12) |
| `output_format` | string | | `mp3` | Output format (`mp3`, `wav`, `hex`) |

**Output Format:**

```json
{
  "audio": { "url": "https://v3.fal.media/files/.../audio.mp3" }
}
```

---

### MiniMax Speech 2.6 Turbo

Fast text-to-speech for high-throughput or latency-sensitive use cases.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/minimax/speech-2.6-turbo` |
| **Mode** | Sync or Queue |
| **Speed** | ~1–3 seconds |
| **Cost Tier** | Low |

**Input Parameters:** Same as MiniMax Speech 2.6 HD.

**Key Differences:**
- Lower latency than HD variant
- Slightly reduced audio quality
- Best for real-time or high-volume applications

---

### MiniMax Voice Clone

Clone a voice from an audio sample, then use the resulting voice ID in MiniMax Speech models.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/minimax/voice-clone` |
| **Mode** | Queue only |
| **Speed** | ~10–30 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `audio_url` | string | ✅ | — | URL of voice sample audio |
| `text` | string | | — | Preview text to test the cloned voice |
| `model` | string | | `speech-02-hd` | TTS model to use for preview |

**Output Format:**

```json
{
  "audio": { "url": "https://v3.fal.media/files/.../audio.mp3" },
  "voice_id": "cloned_voice_abc123"
}
```

**Usage:** Pass `$node.voice_id` as `voice_setting.voice_id` in MiniMax Speech 2.6 HD/Turbo to use the cloned voice.

---

### Chatterbox (Multilingual TTS)

Multi-language text-to-speech supporting diverse languages and accents.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/chatterbox/multilingual` |
| **Mode** | Sync or Queue |
| **Speed** | ~3–10 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `text` | string | ✅ | — | Text to convert to speech |
| `language` | string | | auto | Language code (e.g., `en`, `es`, `fr`, `de`) |
| `voice` | string | | — | Voice identifier |

**Output Format:**

```json
{
  "audio": { "url": "https://v3.fal.media/files/.../audio.mp3" }
}
```

---

## Music Generation Models

### ElevenLabs Music

Generate music from text descriptions with section-aware composition.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/elevenlabs/music` |
| **Mode** | Queue only |
| **Speed** | ~30–60 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Music description (e.g., "Mysterious jungle soundtrack") |
| `respect_sections_durations` | boolean | | `true` | Respect section timings in prompt |
| `output_format` | string | | `mp3_44100_128` | Audio format and quality |

**Output Format:**

```json
{
  "audio_file": { "url": "https://v3.fal.media/files/.../audio.mp3" }
}
```

---

### MMAudio (Video-to-Audio)

Generate ambient audio that matches the content of a video.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/mmaudio` |
| **Mode** | Queue only |
| **Speed** | ~15–30 seconds |
| **Cost Tier** | Low |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `video_url` | string | ✅ | — | URL of input video |
| `prompt` | string | | — | Audio guidance text (e.g., `Ambient nature sounds`) |

**Output Format:**

```json
{
  "audio": { "url": "https://v3.fal.media/files/.../audio.mp3" }
}
```

---

### Stable Audio

General-purpose AI audio generation for sound effects and music.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/stable-audio` |
| **Mode** | Sync or Queue |
| **Speed** | ~10–30 seconds |
| **Cost Tier** | Low |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Audio description (e.g., `Cinematic orchestral music`) |
| `seconds_total` | number | | `30` | Duration of audio output in seconds |

**Output Format:**

```json
{
  "audio_file": { "url": "https://v3.fal.media/files/.../audio.mp3" }
}
```

---

### MiniMax Music v2

High-quality music generation from text descriptions.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/minimax-music/v2` |
| **Mode** | Queue only |
| **Speed** | ~30–60 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Music description |

**Output Format:**

```json
{
  "audio": { "url": "https://v3.fal.media/files/.../audio.mp3" }
}
```

---

## 3D Generation Models

### Hunyuan3D v3 — Image-to-3D

Generate a 3D mesh from a single image. Recommended for single-view 3D generation.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/hunyuan3d-v3/image-to-3d` |
| **Mode** | Queue only |
| **Speed** | ~60–120 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_image_url` | string | ✅ | — | Source image URL |
| `face_count` | integer | | `500000` | Mesh polygon detail level |
| `generate_type` | string | | `Normal` | Generation mode: `Normal` or `Fast` |
| `polygon_type` | string | | `triangle` | Mesh polygon type: `triangle` or `quad` |

**Output Format:**

```json
{
  "model_mesh": { "url": "https://v3.fal.media/files/.../model.glb" }
}
```

---

### Rodin v2 — Multi-view to 3D

Generate a high-quality 3D mesh from multiple view images. Best results with 4 views (front, left, right, back).

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/hyper3d/rodin/v2` |
| **Mode** | Queue only |
| **Speed** | ~60–120 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_image_urls` | array | ✅ | — | Array of image URLs (front, left, right, back) |
| `quality_mesh_option` | string | | `500K Triangle` | Mesh quality (`200K Triangle`, `500K Triangle`, `1M Triangle`) |
| `material` | string | | `All` | Material type: `All`, `PBR`, `Albedo` |

**Output Format:**

```json
{
  "model_mesh": { "url": "https://v3.fal.media/files/.../model.glb" }
}
```

**Best for:** Multi-view 3D generation. Providing multiple angles yields significantly better 3D models.

---

## Image Processing Models

### Background Remove

Remove the background from an image, returning a PNG with transparency.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/bria/background/remove` |
| **Mode** | Sync or Queue |
| **Speed** | ~2–5 seconds |
| **Cost Tier** | Low |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `image_url` | string | ✅ | — | URL of the source image |

**Output Format:**

```json
{
  "image": { "url": "https://v3.fal.media/files/.../image.png" }
}
```

---

### Crop Image

Crop a region from an image using percentage-based coordinates. Useful for splitting images into tiles.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/workflow-utilities/crop-image` |
| **Mode** | Sync or Queue |
| **Speed** | ~1–2 seconds |
| **Cost Tier** | Free |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `image_url` | string | ✅ | — | URL of image to crop |
| `x_percent` | number | ✅ | — | Starting X position as percentage (0–100) |
| `y_percent` | number | ✅ | — | Starting Y position as percentage (0–100) |
| `width_percent` | number | ✅ | — | Width of the crop area as percentage (0–100) |
| `height_percent` | number | ✅ | — | Height of the crop area as percentage (0–100) |

**Output Format:**

```json
{
  "image": { "url": "https://v3.fal.media/files/.../image.png" }
}
```

**Example — Split into 3×3 grid:**

```json
// Top-left tile
{ "x_percent": 0, "y_percent": 0, "width_percent": 33.33, "height_percent": 33.33 }
// Top-center tile
{ "x_percent": 33.33, "y_percent": 0, "width_percent": 33.33, "height_percent": 33.33 }
// Top-right tile
{ "x_percent": 66.67, "y_percent": 0, "width_percent": 33.33, "height_percent": 33.33 }
```

---

## Model Selection Guide

### By Use Case

| I want to... | Use this model | Why |
|--------------|---------------|-----|
| Quickly iterate on prompts | `fal-ai/flux/schnell` | ~1s generation, lowest cost |
| Generate production images | `fal-ai/flux-pro/v1.1-ultra` | Highest quality output |
| Generate with good balance | `fal-ai/nano-banana-pro` | Community default, best overall |
| Generate images with text | `fal-ai/ideogram/v3` | Superior text rendering |
| Design-focused generation | `fal-ai/recraft-v3` | Strong style control |
| Edit an image with a prompt | `fal-ai/nano-banana-pro/edit` | Community default for editing |
| Create a video from text | `fal-ai/kling-video/v2.6/pro/text-to-video` | Best text-to-video quality |
| Animate a photo | `fal-ai/bytedance/seedance/v1.5/pro/image-to-video` | Community default, includes audio |
| Animate with first+last frame | `fal-ai/kling-video/o1/image-to-video` | First and last frame control |
| Upscale a low-res image | `fal-ai/seedvr/upscale/image` | High-quality upscaling |
| Edit part of an image | `fal-ai/inpainting` | Mask-based regional editing |
| Remove image background | `fal-ai/bria/background/remove` | Clean background removal |
| Crop an image | `fal-ai/workflow-utilities/crop-image` | Percentage-based crop |
| Transcribe audio | `fal-ai/whisper` | Industry-standard STT |
| Generate speech (best quality) | `fal-ai/minimax/speech-2.6-hd` | Best quality TTS |
| Generate speech (fastest) | `fal-ai/minimax/speech-2.6-turbo` | Low-latency TTS |
| Generate speech (expressive) | `fal-ai/elevenlabs/tts/eleven-v3` | Expressive voice control |
| Clone a voice | `fal-ai/minimax/voice-clone` | Clone voice from audio sample |
| Generate music | `fal-ai/elevenlabs/music` | Prompt-based music generation |
| Add audio to a video | `fal-ai/mmaudio` | Video-to-audio synthesis |
| Generate 3D from one image | `fal-ai/hunyuan3d-v3/image-to-3d` | Single-view 3D mesh |
| Generate 3D from multiple views | `fal-ai/hyper3d/rodin/v2` | Multi-view 3D mesh |

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
