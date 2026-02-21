# Example Workflows

Production-ready complete workflow examples demonstrating multi-step pipelines
with real-world use cases. Each example is copy-paste ready and uses models
documented in [MODELS.md](../../fal-ai/references/MODELS.md) and patterns from
[PATTERNS.md](PATTERNS.md).

---

## 1. Film Scene Generator

Generate a short film composed of N scenes. An LLM plans the scenes from a
film name, then images and videos are generated for each scene and merged
into a single final video.

**Flow:**

```
Film Name
    │
    ▼
LLM (plan N scenes)
    │
    ├──► Scene 1: Generate Image ──► Animate ──► scene-1.mp4
    ├──► Scene 2: Generate Image ──► Animate ──► scene-2.mp4
    │   ...
    └──► Scene N: Generate Image ──► Animate ──► scene-N.mp4
                                                      │
                                                      ▼
                                               Merge Videos
                                                      │
                                                      ▼
                                               final-film.mp4
```

**Input:** Film name (string)  
**Output:** Per-scene video files + merged `final-film.mp4`  
**Models used:**
- `fal-ai/openrouter/router` — scene planning (LLM)
- `fal-ai/nano-banana-pro` — scene image generation
- `fal-ai/seedance/v1/lite/image-to-video` — scene animation
- `fal-ai/ffmpeg-api/merge-videos` — final merge

```powershell
param(
    [Parameter(Mandatory)]
    [string]$FilmName,

    [int]$SceneCount = 3,

    [string]$OutputDir = '.\output'
)

Import-Module .\scripts\FalAi.psm1 -Force

# ── Step 1: Plan scenes with LLM ──────────────────────────────────────────────
$planPrompt = @"
You are a film director. Given the film title "$FilmName", generate exactly
$SceneCount short scene descriptions for a cinematic storyboard. Each scene
should be a single evocative sentence suitable as an image generation prompt.

Respond with ONLY a JSON array of strings, e.g.:
["Scene one description.", "Scene two description.", "Scene three description."]
"@

$planResult = Invoke-FalApi `
    -Endpoint 'fal-ai/openrouter/router' `
    -Body @{
        model  = 'openai/gpt-4o-mini'
        prompt = $planPrompt
    }

$scenes = $planResult.output | ConvertFrom-Json

Write-Host "Planned $($scenes.Count) scenes for '$FilmName'"

# ── Step 2: Generate image + video per scene ──────────────────────────────────
$sceneVideos = @()
$null = New-Item -ItemType Directory -Path $OutputDir -Force

for ($i = 0; $i -lt $scenes.Count; $i++) {
    $sceneNum   = $i + 1
    $sceneDesc  = $scenes[$i]

    Write-Host "Scene $sceneNum/$($scenes.Count): $sceneDesc"

    # Generate scene image
    $imageSteps = @(
        @{
            name      = "scene-$sceneNum-image"
            model     = 'fal-ai/nano-banana-pro'
            params    = @{
                prompt     = $sceneDesc
                image_size = 'landscape_16_9'
            }
            dependsOn = @()
        }
        @{
            name      = "scene-$sceneNum-video"
            model     = 'fal-ai/seedance/v1/lite/image-to-video'
            params    = @{
                prompt   = "Cinematic motion: $sceneDesc"
                duration = 5
            }
            dependsOn = @("scene-$sceneNum-image")
        }
    )

    $sceneResult = .\scripts\New-FalWorkflow.ps1 `
        -Name "film-scene-$sceneNum" `
        -Steps $imageSteps

    $videoUrl = $sceneResult.Steps[-1].Output.video.url
    $sceneVideos += $videoUrl
    Write-Host "  ✅ Scene $sceneNum video: $videoUrl"
}

# ── Step 3: Merge all scene videos ────────────────────────────────────────────
Write-Host "Merging $($sceneVideos.Count) scenes..."

$mergeResult = Wait-FalJob `
    -Model 'fal-ai/ffmpeg-api/merge-videos' `
    -Body @{ video_urls = $sceneVideos }

$finalUrl = $mergeResult.video.url
Write-Host "✅ Final film: $finalUrl"

[PSCustomObject]@{
    FilmName   = $FilmName
    Scenes     = $sceneVideos
    FinalVideo = $finalUrl
}
```

**Customization:**
- Increase `$SceneCount` for longer films (each scene adds ~70s generation time)
- Replace `openai/gpt-4o-mini` with `anthropic/claude-3-haiku` for faster planning
- Replace `seedance/v1/lite` with `fal-ai/kling-video/v2.6/pro/image-to-video` for
  higher quality animation
- Add a quality checkpoint after each scene image before animating

---

## 2. Campaign Video Generator

Personalize a marketing template image for multiple destinations, animate each
into a video, then compile into a single campaign video.

**Flow:**

```
Template Image URL + Destination Names
    │
    ▼
Analyze template with vision LLM
    │
    ├──► Destination 1: Edit Image ──► Upscale ──► Animate ──► dest-1.mp4
    ├──► Destination 2: Edit Image ──► Upscale ──► Animate ──► dest-2.mp4
    │   ...
    └──► Destination N: Edit Image ──► Upscale ──► Animate ──► dest-N.mp4
                                                                    │
                                                                    ▼
                                                             Merge Videos
                                                                    │
                                                                    ▼
                                                            campaign-final.mp4
```

**Input:** Template image URL, list of destination names  
**Output:** Per-destination video files + merged `campaign-final.mp4`  
**Models used:**
- `fal-ai/openrouter/router` with vision — analyze template image
- `fal-ai/nano-banana-pro/edit` — customize image per destination
- `fal-ai/seedvr/upscale` — enhance each customized image
- `fal-ai/kling-video/o1/image-to-video` — animate each image
- `fal-ai/ffmpeg-api/merge-videos` — compile final video

```powershell
param(
    [Parameter(Mandatory)]
    [string]$TemplateImageUrl,

    [Parameter(Mandatory)]
    [string[]]$Destinations,

    [string]$BrandName = 'Our Brand'
)

Import-Module .\scripts\FalAi.psm1 -Force

# ── Step 1: Analyze the template image with vision LLM ───────────────────────
Write-Host "Analyzing template image..."

$analysisResult = Invoke-FalApi `
    -Endpoint 'fal-ai/openrouter/router' `
    -Body @{
        model    = 'openai/gpt-4o'
        prompt   = "Describe this marketing image briefly. What elements could be customized per travel destination? Reply in one paragraph."
        image_url = $TemplateImageUrl
    }

$templateDescription = $analysisResult.output
Write-Host "Template: $templateDescription"

# ── Step 2: Create personalized video per destination ─────────────────────────
$destVideos = @()

foreach ($destination in $Destinations) {
    Write-Host "Processing destination: $destination"

    $editPrompt = "Marketing image for $destination travel destination. " +
                  "Based on: $templateDescription. " +
                  "Include iconic elements of $destination, keep $BrandName branding style."

    $destSteps = @(
        @{
            name      = 'customize'
            model     = 'fal-ai/nano-banana-pro/edit'
            params    = @{
                image_url = $TemplateImageUrl
                prompt    = $editPrompt
                strength  = 0.65
            }
            dependsOn = @()
        }
        @{
            name      = 'enhance'
            model     = 'fal-ai/seedvr/upscale'
            params    = @{}
            dependsOn = @('customize')
        }
        @{
            name      = 'animate'
            model     = 'fal-ai/kling-video/o1/image-to-video'
            params    = @{
                prompt   = "Cinematic pan across $destination landmarks, travel advertisement style"
                duration = 5
            }
            dependsOn = @('enhance')
        }
    )

    $destResult = .\scripts\New-FalWorkflow.ps1 `
        -Name "campaign-$destination" `
        -Steps $destSteps

    $videoUrl = $destResult.Steps[-1].Output.video.url
    $destVideos += $videoUrl
    Write-Host "  ✅ $destination video: $videoUrl"
}

# ── Step 3: Merge all destination videos ──────────────────────────────────────
Write-Host "Compiling campaign video..."

$mergeResult = Wait-FalJob `
    -Model 'fal-ai/ffmpeg-api/merge-videos' `
    -Body @{ video_urls = $destVideos }

$finalUrl = $mergeResult.video.url
Write-Host "✅ Campaign video: $finalUrl"

[PSCustomObject]@{
    BrandName    = $BrandName
    Destinations = $Destinations
    DestVideos   = $destVideos
    FinalVideo   = $finalUrl
}
```

**Customization:**
- Lower `strength` (e.g., 0.4) to preserve more of the original template
- Replace `kling-video/o1` with `fal-ai/kling-video/v2.6/pro/image-to-video`
  if `o1` variant is unavailable
- Add a quality checkpoint after `customize` to reject low-quality edits before
  upscaling and animation
- Run destination loops in parallel by collecting steps before executing (see
  Fan-Out pattern in [PATTERNS.md](PATTERNS.md))

---

## 3. Image-to-3D Asset Generator

Convert a 2D concept image into a production-ready 3D mesh. Generates
multi-angle views of the subject then feeds them to a 3D mesh generator.

**Flow:**

```
Input Image URL
    │
    ▼
Generate multi-angle views
(front, back, left, right, top, bottom)
    │
    ▼
3D Mesh Generator (Hyper3D Rodin)
    │
    ▼
3D Asset (.glb)
```

**Input:** Image URL (2D concept art or photo)  
**Output:** 3D mesh model file (`.glb`)  
**Models used:**
- `fal-ai/seedream/v4/edit` — multi-angle view synthesis
- `fal-ai/hyper3d/rodin/v2` — 3D mesh generation from multi-view images

```powershell
param(
    [Parameter(Mandatory)]
    [string]$ImageUrl,

    [string]$SubjectDescription = 'the object in the image'
)

Import-Module .\scripts\FalAi.psm1 -Force

# ── Step 1: Generate multi-angle views ────────────────────────────────────────
Write-Host "Generating multi-angle views for $SubjectDescription..."

$angles = @(
    @{ name = 'view-front';  prompt = "Front view of $SubjectDescription, white background, product photography" }
    @{ name = 'view-back';   prompt = "Back view of $SubjectDescription, white background, product photography" }
    @{ name = 'view-left';   prompt = "Left side view of $SubjectDescription, white background, product photography" }
    @{ name = 'view-right';  prompt = "Right side view of $SubjectDescription, white background, product photography" }
    @{ name = 'view-top';    prompt = "Top-down view of $SubjectDescription, white background, product photography" }
    @{ name = 'view-bottom'; prompt = "Bottom view of $SubjectDescription, white background, product photography" }
)

$viewUrls = @{}

foreach ($angle in $angles) {
    $viewSteps = @(
        @{
            name      = $angle.name
            model     = 'fal-ai/seedream/v4/edit'
            params    = @{
                image_url = $ImageUrl
                prompt    = $angle.prompt
                strength  = 0.55
            }
            dependsOn = @()
        }
    )

    $viewResult = .\scripts\New-FalWorkflow.ps1 `
        -Name "multiview-$($angle.name)" `
        -Steps $viewSteps

    $viewUrls[$angle.name] = $viewResult.Steps[0].Output.images[0].url
    Write-Host "  ✅ $($angle.name): $($viewUrls[$angle.name])"
}

# ── Step 2: Generate 3D mesh from multi-view images ───────────────────────────
Write-Host "Generating 3D mesh..."

$rodinBody = @{
    images = @(
        $viewUrls['view-front']
        $viewUrls['view-back']
        $viewUrls['view-left']
        $viewUrls['view-right']
        $viewUrls['view-top']
        $viewUrls['view-bottom']
    )
    output_format = 'glb'
}

$meshResult = Wait-FalJob `
    -Model 'fal-ai/hyper3d/rodin/v2' `
    -Body $rodinBody

$glbUrl = $meshResult.model_file.url
Write-Host "✅ 3D asset (.glb): $glbUrl"

[PSCustomObject]@{
    InputImage    = $ImageUrl
    MultiViewUrls = $viewUrls
    MeshUrl       = $glbUrl
}
```

**Customization:**
- Reduce the `$angles` array to 4 views (front, back, left, right) if top/bottom
  are not needed — fewer views speed up generation
- Adjust `strength` on `seedream/v4/edit` (lower preserves more of the original,
  higher allows more creative interpretation)
- Replace `output_format = 'glb'` with `'obj'` or `'fbx'` for other 3D formats
  if supported by the model
- Add a quality checkpoint after view generation to verify background removal
  succeeded before sending to the mesh generator

---

## Pattern Summary

| Example | Key Pattern | Steps | Est. Time |
|---------|-------------|-------|-----------|
| Film Scene Generator | Sequential (per scene) + Fan-Out | LLM + N×2 + merge | ~5 + N×90s |
| Campaign Video Generator | Fan-Out + Vision LLM | Analyze + N×3 + merge | ~10 + N×120s |
| Image-to-3D Asset | Sequential (multi-view fan-out + convergence) | 6 views + 3D | ~60–180s |

See [PATTERNS.md](PATTERNS.md) for fan-out, fan-in, and error recovery patterns
that can be combined with these examples.
