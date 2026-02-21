# Advanced Workflow Examples

Multi-step pipelines combining generation, processing, and optimization.

---

## Example 1: Product Photo Pipeline

**Goal:** Generate a product photo, process it for e-commerce, and produce multiple format variants — all in a single automated workflow.

### Pipeline Definition

```powershell
$workflow = @{
    name = "product-photo-pipeline"
    checkpoint = $true
    steps = @(
        # Phase 1: Generation
        @{
            step = 1
            action = "generate"
            prompt = "Professional product photo of a minimalist desk lamp on a clean white surface, studio lighting, 8k"
            model = "fal-ai/flux-pro"
            seed = 2024
            steps = 40
            width = 1024
            height = 1024
            output = "./pipeline/01_generated.png"
        },

        # Phase 2: Enhancement
        @{
            step = 2
            action = "upscale"
            scale = 2
            output = "./pipeline/02_upscaled.png"
        },

        # Phase 3: Processing
        @{
            step = 3
            action = "detect"
            description = "desk lamp"
            return_geometry = $true
        },
        @{
            step = 4
            action = "crop"
            padding = 50
            output = "./pipeline/04_cropped.png"
        },

        # Phase 4: Branding
        @{
            step = 5
            action = "resize"
            width = 1200
            height = 1200
            output = "./pipeline/05_sized.png"
        },
        @{
            step = 6
            action = "overlay"
            overlay_path = "./assets/watermark.png"
            x = 1050
            y = 1100
            output = "./pipeline/06_branded.png"
        },

        # Phase 5: Format Variants
        @{
            step = 7
            action = "resize"
            variants = @(
                @{ width = 1200; height = 1200; name = "square" },
                @{ width = 1920; height = 1080; name = "banner" },
                @{ width = 800; height = 800; name = "thumbnail" }
            )
            output_dir = "./pipeline/final/"
        }
    )
}
```

### Execution

```powershell
New-FalWorkflow @workflow
```

### Output Structure

```
./pipeline/
├── 01_generated.png        # Raw generation (1024x1024)
├── 02_upscaled.png         # AI upscaled (2048x2048)
├── 04_cropped.png          # Cropped to product
├── 05_sized.png            # Resized to 1200x1200
├── 06_branded.png          # With watermark
└── final/
    ├── square_1200x1200.png
    ├── banner_1920x1080.png
    └── thumbnail_800x800.png
```

### Checkpoint Recovery

If step 4 fails (e.g., detection didn't find the lamp):

```powershell
# Adjust detection and resume
# Steps 1–3 are skipped; outputs already exist
New-FalWorkflow @workflow -ResumeFrom 3
```

### Key Takeaway

Checkpointed pipelines save time on expensive operations like generation and upscaling. If a later step fails, you don't have to regenerate images.

---

## Example 2: Social Media Content Generation

**Goal:** Generate a hero image and automatically produce variants optimized for multiple social media platforms.

### Platform Specifications

| Platform | Size | Aspect Ratio | Notes |
|----------|------|-------------|-------|
| Instagram Post | 1080×1080 | 1:1 | Square |
| Instagram Story | 1080×1920 | 9:16 | Vertical |
| Twitter/X Post | 1200×675 | 16:9 | Horizontal |
| LinkedIn Post | 1200×627 | ~2:1 | Horizontal |
| Facebook Cover | 820×312 | ~2.6:1 | Wide banner |

### Pipeline

```powershell
$prompt = "Modern coworking space with natural light, plants, and diverse team collaborating"
$seed = 100

# Phase 1: Generate hero image at high resolution
Invoke-FalGenerate `
    -Prompt $prompt `
    -Model "fal-ai/flux-pro" `
    -Seed $seed `
    -Width 2048 -Height 2048 `
    -Steps 40 `
    -OutputPath "./social/hero.png"

# Phase 2: Generate platform variants (parallel)
$platforms = @(
    @{ name = "instagram-post";  width = 1080; height = 1080 },
    @{ name = "instagram-story"; width = 1080; height = 1920 },
    @{ name = "twitter-post";    width = 1200; height = 675  },
    @{ name = "linkedin-post";   width = 1200; height = 627  },
    @{ name = "facebook-cover";  width = 820;  height = 312  }
)

foreach ($platform in $platforms) {
    $outputPath = "./social/$($platform.name).png"

    # Smart crop: resize maintaining aspect ratio, then center-crop to exact dimensions
    # Step 1: Resize so the shorter dimension matches the target
    # Step 2: Center-crop to exact target dimensions

    Write-Output "Created $($platform.name) variant: $($platform.width)x$($platform.height)"
}

# Phase 3: Add branding to each variant
foreach ($platform in $platforms) {
    $inputPath = "./social/$($platform.name).png"

    # Overlay logo (scaled appropriately per platform)
    # Draw campaign tagline text

    Write-Output "Branded $($platform.name)"
}
```

### Output

```
./social/
├── hero.png                 # 2048x2048 master image
├── instagram-post.png       # 1080x1080 with branding
├── instagram-story.png      # 1080x1920 with branding
├── twitter-post.png         # 1200x675 with branding
├── linkedin-post.png        # 1200x627 with branding
└── facebook-cover.png       # 820x312 with branding
```

### Extending This Workflow

- **A/B testing**: Generate multiple hero images (different seeds) and produce full variant sets for each
- **Campaign themes**: Swap the prompt while keeping the platform specs constant
- **Seasonal updates**: Change only the prompt and regenerate all variants
- **Brand consistency**: Use the same overlay and text positioning templates across campaigns

### Key Takeaway

Generate once at high resolution, then derive all platform variants through cropping and resizing. This ensures visual consistency across platforms while optimizing for each platform's requirements.

---

## Next Steps

- [User Guides](../user-guides/README.md) — detailed guides for each capability
- [API Reference](../api-reference/README.md) — full parameter documentation
- [Basic Generation Examples](basic-generation.md) — start with simpler examples
