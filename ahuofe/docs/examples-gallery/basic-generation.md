# Basic Generation Examples

Fundamental text-to-image generation patterns.

---

## Example 1: Simple Text-to-Image

**Goal:** Generate a single image from a text prompt with default settings.

### Prompt

```
Generate an image of a golden retriever playing in autumn leaves
```

### What Happens

1. The extension selects the default model (`fal-ai/flux/dev`)
2. Uses default parameters: 20 steps, guidance scale 7.0, random seed
3. Returns the generated image URL

### Equivalent Script Call

```powershell
Invoke-FalGenerate -Prompt "A golden retriever playing in autumn leaves"
```

### Expected Output

```
✓ Image generated successfully
  Model: fal-ai/flux/dev
  Size: 1024x1024
  Seed: 847291
  URL: https://fal.media/files/...
```

---

## Example 2: Reproducible Generation with Seed Control

**Goal:** Generate an image with a fixed seed, then create variations by changing one parameter at a time.

### Step 1: Generate Base Image

```powershell
Invoke-FalGenerate -Prompt "A futuristic city skyline at dusk" -Seed 12345 -OutputPath "./output/city_base.png"
```

### Step 2: Vary the Steps (Same Seed)

```powershell
# Low steps — fast draft
Invoke-FalGenerate -Prompt "A futuristic city skyline at dusk" -Seed 12345 -Steps 10 -OutputPath "./output/city_10steps.png"

# High steps — fine detail
Invoke-FalGenerate -Prompt "A futuristic city skyline at dusk" -Seed 12345 -Steps 50 -OutputPath "./output/city_50steps.png"
```

### Step 3: Compare

All three images share the same composition (same seed) but differ in detail level. This technique helps you find the optimal step count for your use case.

### Key Takeaway

Using a fixed seed makes generation **deterministic** — you get the same image every time. Change one parameter to understand its effect in isolation.

---

## Example 3: Model Selection Comparison

**Goal:** Generate the same prompt across multiple models to compare quality and style.

### Script

```powershell
$prompt = "A watercolor painting of a Japanese garden in spring"
$seed = 42
$models = @("fal-ai/flux/dev", "fal-ai/flux-pro", "fal-ai/stable-diffusion-v35-large")

foreach ($model in $models) {
    $name = ($model -split '/')[-1]
    Invoke-FalGenerate `
        -Prompt $prompt `
        -Model $model `
        -Seed $seed `
        -OutputPath "./output/comparison_$name.png"
    Write-Output "Generated with $model"
}
```

### Expected Output

```
Generated with fal-ai/flux/dev
Generated with fal-ai/flux-pro
Generated with fal-ai/stable-diffusion-v35-large
```

Three images in `./output/`:
- `comparison_dev.png` — Flux Dev (fast, good quality)
- `comparison_flux-pro.png` — Flux Pro (slower, highest quality)
- `comparison_stable-diffusion-v35-large.png` — SD 3.5 (different style characteristics)

### Key Takeaway

Different models have different strengths. Use this pattern to pick the best model for your specific subject and style before committing to a full batch.

---

## Next Steps

- [Image Processing Examples](image-processing.md) — post-process these generated images
- [Advanced Workflows](advanced-workflows.md) — chain generation with processing
- [Image Generation Guide](../user-guides/image-generation.md) — full parameter reference
