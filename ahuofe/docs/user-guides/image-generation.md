# Image Generation

Generate images from text prompts using fal.ai models through the Copilot Media Plugins extension.

## Using fal.ai for Text-to-Image

The extension wraps fal.ai's image generation APIs into a simple conversational interface. You describe what you want, and the extension handles model selection, parameter configuration, and API calls.

### Basic Usage

```
Generate an image of a red fox in a snowy forest
```

The extension translates this into an API call with sensible defaults and returns the generated image.

## Model Selection

| Model | ID | Best For | Speed | Quality |
|-------|----|----------|-------|---------|
| Flux Dev | `fal-ai/flux/dev` | General purpose, development | Fast | Good |
| Flux Pro | `fal-ai/flux-pro` | Production-quality output | Medium | High |
| Stable Diffusion XL | `fal-ai/stable-diffusion-v35-large` | Wide style range, community models | Medium | High |

### Choosing a Model

- **Flux Dev** — Default choice. Fast iteration, good quality, lower cost.
- **Flux Pro** — When you need the highest quality and are willing to wait.
- **Stable Diffusion** — When you need specific styles or fine-tuned variants.

### Specifying a Model

```
Generate a portrait using flux-pro
```

Or explicitly:

```
Generate an image of a city skyline with model fal-ai/flux/dev
```

## Parameter Tuning

### Inference Steps

Controls how many denoising steps the model performs. More steps generally produce higher quality but take longer.

| Steps | Speed | Quality | Use Case |
|-------|-------|---------|----------|
| 10–15 | Fast | Draft | Quick previews, iteration |
| 20–30 | Medium | Good | General use |
| 40–50 | Slow | High | Final output, fine detail |

```
Generate a landscape with 30 steps
```

### Guidance Scale (CFG)

Controls how closely the image follows your prompt. Higher values produce more literal interpretations; lower values allow more creative freedom.

| Scale | Effect |
|-------|--------|
| 1–3 | Very creative, may drift from prompt |
| 5–7 | Balanced — recommended starting point |
| 8–12 | Strict prompt adherence |
| 15+ | Over-saturated, artifacts likely |

```
Generate a watercolor painting with guidance scale 5
```

### Seed

A seed value produces deterministic output — the same seed with the same prompt and parameters generates the same image. Useful for:

- **Reproducibility** — recreate a specific result
- **Iteration** — change one parameter while keeping composition fixed
- **Comparison** — evaluate models or settings side by side

```
Generate a forest scene with seed 42
```

### Image Size

Specify dimensions for the output image:

```
Generate a banner image at 1920x1080
```

Common sizes:

| Size | Aspect Ratio | Use Case |
|------|-------------|----------|
| 512×512 | 1:1 | Thumbnails, avatars |
| 1024×1024 | 1:1 | Standard output |
| 1920×1080 | 16:9 | Banners, headers |
| 1080×1920 | 9:16 | Stories, mobile |

## Output Handling

### Image URL

By default, the extension returns a URL to the generated image hosted on fal.ai's CDN. These URLs are temporary (typically valid for ~1 hour).

### Downloading Images

Request a local download:

```
Generate an image and save it to ./output/landscape.png
```

### Batch Generation

Generate multiple variations:

```
Generate 4 variations of a sunset over the ocean
```

Each variation uses a different seed while keeping all other parameters constant.

## Tips

- **Start broad, then refine** — begin with simple prompts and add detail iteratively
- **Use seeds for iteration** — lock the seed, then adjust one parameter at a time
- **Match steps to purpose** — use low steps for drafts, high steps for final output
- **Keep guidance scale moderate** — 5–7 is the sweet spot for most models

## Next Steps

- [Image Processing](image-processing.md) — post-process generated images
- [Workflows](workflows.md) — chain generation with processing steps
- [Examples Gallery](../examples-gallery/basic-generation.md) — see complete examples
