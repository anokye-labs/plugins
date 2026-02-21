# Pipeline Templates

Ready-to-use workflow templates for `scripts/New-FalWorkflow.ps1`.
Copy a template, adjust prompts and parameters, and run.

---

## 1. Quick Generate + Upscale

**Use case:** Generate a high-resolution image by creating at standard resolution
then upscaling with AI super-resolution.

**Steps:** Generate → Upscale

```powershell
$steps = @(
    @{
        name      = 'generate'
        model     = 'fal-ai/flux/dev'
        params    = @{
            prompt     = 'YOUR PROMPT HERE'
            image_size = 'landscape_4_3'
            seed       = 42
        }
        dependsOn = @()
    }
    @{
        name      = 'upscale'
        model     = 'fal-ai/aura-sr'
        params    = @{}
        dependsOn = @('generate')
    }
)

.\scripts\New-FalWorkflow.ps1 -Name 'quick-upscale' -Steps $steps
```

**Output:** Upscaled image (~2048×1536 from default 1024×768).

**Customization:**
- Use `fal-ai/flux/schnell` for faster drafts
- Use `fal-ai/flux-pro/v1.1-ultra` for maximum quality base image
- Add `scale = 4` to upscale params for even higher resolution

---

## 2. Generate + Inpaint Edit

**Use case:** Generate a base image then edit a specific region using a mask.

**Steps:** Generate → Inpaint

```powershell
# Prepare mask: upload a mask image (white = area to edit)
Import-Module .\scripts\FalAi.psm1 -Force
$maskUrl = (Send-FalFile -FilePath '.\mask.png')

$steps = @(
    @{
        name      = 'generate'
        model     = 'fal-ai/flux/dev'
        params    = @{
            prompt     = 'A modern office with a blank wall'
            image_size = 'landscape_16_9'
        }
        dependsOn = @()
    }
    @{
        name      = 'inpaint'
        model     = 'fal-ai/inpainting'
        params    = @{
            mask_url = $maskUrl
            prompt   = 'A large window showing a city skyline'
            strength = 0.85
        }
        dependsOn = @('generate')
    }
)

.\scripts\New-FalWorkflow.ps1 -Name 'generate-inpaint' -Steps $steps
```

**Output:** Edited image with the masked region replaced.

**Customization:**
- Lower `strength` (e.g., 0.6) to blend more of the original
- Raise `strength` (e.g., 0.95) for more aggressive replacement
- Add `guidance_scale` to control prompt adherence

---

## 3. Generate + Animate

**Use case:** Create a still image then animate it into a short video.

**Steps:** Generate → Image-to-Video

```powershell
$steps = @(
    @{
        name      = 'generate'
        model     = 'fal-ai/flux/dev'
        params    = @{
            prompt     = 'Ocean waves crashing on a rocky shore at sunset'
            image_size = 'landscape_16_9'
        }
        dependsOn = @()
    }
    @{
        name      = 'animate'
        model     = 'fal-ai/kling-video/v2.6/pro/image-to-video'
        params    = @{
            prompt   = 'Waves rolling in and crashing, camera slowly panning right'
            duration = 5
        }
        dependsOn = @('generate')
    }
)

.\scripts\New-FalWorkflow.ps1 -Name 'generate-animate' -Steps $steps
```

**Output:** 5-second video animating the generated image.

**Customization:**
- Set `duration = 10` for longer videos
- Use specific motion keywords in animate prompt: "pan", "zoom", "orbit", "dolly"
- Use `fal-ai/flux-pro/v1.1-ultra` for higher quality source frame

---

## 4. Upscale + Animate

**Use case:** Take an existing image, upscale it for quality, then animate.

**Steps:** Upscale → Image-to-Video

```powershell
$steps = @(
    @{
        name      = 'upscale'
        model     = 'fal-ai/aura-sr'
        params    = @{
            image_url = 'https://example.com/your-image.jpg'
        }
        dependsOn = @()
    }
    @{
        name      = 'animate'
        model     = 'fal-ai/kling-video/v2.6/pro/image-to-video'
        params    = @{
            prompt   = 'Slow cinematic zoom into the scene'
            duration = 5
        }
        dependsOn = @('upscale')
    }
)

.\scripts\New-FalWorkflow.ps1 -Name 'upscale-animate' -Steps $steps
```

**Note:** For this template the first step takes an explicit `image_url`
since there is no generation step. Upload local files first with `Send-FalFile`.

---

## 5. Full Pipeline (Generate → Edit → Upscale → Animate)

**Use case:** Complete media pipeline from text prompt to final animated video.

**Steps:** Generate → Inpaint → Upscale → Animate

```powershell
Import-Module .\scripts\FalAi.psm1 -Force
$maskUrl = (Send-FalFile -FilePath '.\mask.png')

$steps = @(
    @{
        name      = 'generate'
        model     = 'fal-ai/flux/dev'
        params    = @{
            prompt     = 'A medieval village marketplace at dawn'
            image_size = 'landscape_16_9'
            seed       = 100
        }
        dependsOn = @()
    }
    @{
        name      = 'edit'
        model     = 'fal-ai/inpainting'
        params    = @{
            mask_url = $maskUrl
            prompt   = 'A dragon flying above the village in the sky'
            strength = 0.9
        }
        dependsOn = @('generate')
    }
    @{
        name      = 'upscale'
        model     = 'fal-ai/aura-sr'
        params    = @{ scale = 2 }
        dependsOn = @('edit')
    }
    @{
        name      = 'animate'
        model     = 'fal-ai/kling-video/v2.6/pro/image-to-video'
        params    = @{
            prompt   = 'The dragon breathes fire, villagers scatter, camera slowly zooms out'
            duration = 5
        }
        dependsOn = @('upscale')
    }
)

.\scripts\New-FalWorkflow.ps1 -Name 'full-pipeline' -Steps $steps `
    -Description 'Generate medieval scene, add dragon, upscale, animate'
```

**Output:** 5-second video from a fully processed 4-step pipeline.

**Customization:**
- Remove the `edit` step if no region editing is needed
- Remove the `upscale` step if resolution is sufficient
- Swap `fal-ai/flux/dev` for `fal-ai/flux/schnell` for faster iteration

---

## 6. Style Transfer Pipeline

**Use case:** Generate a base image then re-render it with a style reference.

**Steps:** Generate → Img2Img Style Transfer

```powershell
$steps = @(
    @{
        name      = 'generate'
        model     = 'fal-ai/flux/dev'
        params    = @{
            prompt     = 'A portrait of a woman in a garden'
            image_size = 'portrait_4_3'
        }
        dependsOn = @()
    }
    @{
        name      = 'restyle'
        model     = 'fal-ai/flux/dev'
        params    = @{
            prompt   = 'Oil painting in the style of Monet, impressionist brushstrokes'
            strength = 0.65
        }
        dependsOn = @('generate')
    }
)

.\scripts\New-FalWorkflow.ps1 -Name 'style-transfer' -Steps $steps
```

**Output:** Re-styled image using img2img with the generated image as input.

**Customization:**
- Adjust `strength` to control how much of the original to keep (lower = more original)
- Change the style prompt to any artistic style
- Chain an upscale step after restyle for high-resolution output

---

## 7. Iterative Refinement

**Use case:** Generate an image then refine it through img2img with a more
detailed prompt at reduced strength.

**Steps:** Generate (fast) → Refine (quality)

```powershell
$steps = @(
    @{
        name      = 'draft'
        model     = 'fal-ai/flux/schnell'
        params    = @{
            prompt     = 'A futuristic cityscape'
            image_size = 'landscape_16_9'
        }
        dependsOn = @()
    }
    @{
        name      = 'refine'
        model     = 'fal-ai/flux/dev'
        params    = @{
            prompt   = 'A futuristic cityscape with neon lights, flying cars, holographic billboards, rain-slicked streets, 8k detail'
            strength = 0.5
            num_inference_steps = 40
        }
        dependsOn = @('draft')
    }
)

.\scripts\New-FalWorkflow.ps1 -Name 'iterative-refine' -Steps $steps
```

**Output:** Refined image that preserves the composition from the fast draft
while adding detail from the quality model.

---

## Template Quick Reference

| Template | Steps | Est. Time | Use Case |
|----------|-------|-----------|----------|
| Quick Upscale | 2 | ~8s | High-res from standard gen |
| Generate + Edit | 2 | ~15s | Region editing after gen |
| Generate + Animate | 2 | ~70s | Still-to-video |
| Upscale + Animate | 2 | ~65s | Enhance then animate existing |
| Full Pipeline | 4 | ~90s | End-to-end media pipeline |
| Style Transfer | 2 | ~10s | Artistic re-rendering |
| Iterative Refine | 2 | ~8s | Fast draft → quality refine |
