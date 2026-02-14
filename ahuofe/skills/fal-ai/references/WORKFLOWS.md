# fal.ai Workflow Patterns

Multi-step workflow patterns for common media generation pipelines.
Each workflow includes step-by-step instructions, parameter passing,
and error recovery guidance.

---

## 1. Text-to-Image Workflow

**Goal:** Generate an image from a text prompt and download it.

### Steps

```
Prompt → Generate → Download
```

### Step 1 — Generate the Image

```powershell
$result = .\scripts\Invoke-FalGenerate.ps1 `
    -Prompt "A serene mountain landscape at golden hour" `
    -Model "fal-ai/flux/dev" `
    -ImageSize "landscape_16_9" `
    -NumImages 1
```

### Step 2 — Extract the URL

```powershell
$imageUrl = $result.Images[0].Url
Write-Host "Generated: $imageUrl"
```

### Step 3 — Download the Image

```powershell
Invoke-WebRequest -Uri $imageUrl -OutFile "mountain.png"
```

### Variations

**Fast draft with Schnell:**
```powershell
$result = .\scripts\Invoke-FalGenerate.ps1 `
    -Prompt "A serene mountain landscape" `
    -Model "fal-ai/flux/schnell"
```

**High-quality with FLUX Pro:**
```powershell
$result = .\scripts\Invoke-FalGenerate.ps1 `
    -Prompt "A serene mountain landscape" `
    -Model "fal-ai/flux-pro/v1.1-ultra" `
    -Queue
```

**Reproducible with seed:**
```powershell
$result = .\scripts\Invoke-FalGenerate.ps1 `
    -Prompt "A serene mountain landscape" `
    -Seed 42
```

### Error Recovery

| Error | Recovery |
|-------|----------|
| HTTP 422 (invalid params) | Check model schema: `.\scripts\Get-FalModel.ps1 -ModelId "fal-ai/flux/dev"` |
| HTTP 429 (rate limited) | Auto-retried by `Invoke-FalApi`. If persistent, wait 30 seconds. |
| Empty `Images` array | Check `$result` for error details. Safety checker may have filtered output. |

---

## 2. Image-to-Video Workflow

**Goal:** Take an existing image, upload it, generate a video, and download.

### Steps

```
Local Image → Upload to CDN → Video Generation → Download
```

### Step 1 — Upload the Image

```powershell
Import-Module .\scripts\FalAi.psm1 -Force
$cdnUrl = Send-FalFile -FilePath ".\photo.jpg"
Write-Host "Uploaded: $cdnUrl"
```

Or use the script wrapper:

```powershell
$upload = .\scripts\Upload-ToFalCDN.ps1 -FilePath ".\photo.jpg"
$cdnUrl = $upload.Url
```

### Step 2 — Generate the Video

```powershell
$result = .\scripts\Invoke-FalImageToVideo.ps1 `
    -ImageUrl $cdnUrl `
    -Prompt "Camera slowly zooms in, gentle parallax motion" `
    -Duration 5
```

### Step 3 — Download the Video

```powershell
$videoUrl = $result.Video.Url
Invoke-WebRequest -Uri $videoUrl -OutFile "animated.mp4"
```

### Alternative: Use Invoke-FalGenerate Directly

```powershell
$result = .\scripts\Invoke-FalGenerate.ps1 `
    -Prompt "Camera slowly zooms in" `
    -Model "fal-ai/kling-video/v2.6/pro/image-to-video" `
    -ImageUrl $cdnUrl `
    -Queue
```

### Error Recovery

| Error | Recovery |
|-------|----------|
| Upload fails | Verify file exists and is under 100 MB. Check `FAL_KEY`. |
| `--ImageUrl is required` | Ensure `-ImageUrl` is provided for image-to-video models. |
| Job timeout | Increase timeout: `Wait-FalJob -TimeoutSeconds 600`. Video gen is slow. |
| `FAILED` status | Check prompt — some content may be filtered. Retry with simpler prompt. |

---

## 3. Batch Generation Workflow

**Goal:** Generate multiple images from different prompts in parallel.

### Steps

```
Multiple Prompts → Parallel Queue Submissions → Collect Results
```

### Step 1 — Define Prompts

```powershell
$prompts = @(
    "A serene mountain landscape at sunrise"
    "A bustling cyberpunk city street at night"
    "An underwater coral reef with tropical fish"
    "A cozy cabin in the woods during snowfall"
)
```

### Step 2 — Submit All to Queue

```powershell
Import-Module .\scripts\FalAi.psm1 -Force

$model = "fal-ai/flux/dev"
$requestIds = @()

foreach ($prompt in $prompts) {
    $body = @{
        prompt     = $prompt
        image_size = "landscape_4_3"
        num_images = 1
    }
    $submitUrl = "https://queue.fal.run/$model"
    $apiKey = Get-FalApiKey
    $headers = @{
        'Authorization' = "Key $apiKey"
        'Content-Type'  = 'application/json'
    }
    $response = Invoke-RestMethod -Uri $submitUrl -Method POST `
        -Headers $headers -Body ($body | ConvertTo-Json) -UseBasicParsing
    $requestIds += $response.request_id
    Write-Host "Submitted: $($response.request_id) — $prompt"
}
```

### Step 3 — Poll and Collect Results

```powershell
$results = @()
foreach ($reqId in $requestIds) {
    $result = Wait-FalJob -Model $model -RequestId $reqId -TimeoutSeconds 120
    $results += $result
    Write-Host "Completed: $reqId"
}
```

### Step 4 — Download All

```powershell
for ($i = 0; $i -lt $results.Count; $i++) {
    $url = $results[$i].images[0].url
    Invoke-WebRequest -Uri $url -OutFile "batch_$i.png"
    Write-Host "Downloaded: batch_$i.png"
}
```

### Error Recovery

| Error | Recovery |
|-------|----------|
| Some requests fail | Track failed request IDs and retry only those. |
| Rate limiting (429) | Add a small delay between submissions: `Start-Sleep -Milliseconds 500` |
| Timeout on poll | Use `Get-QueueStatus.ps1` to check individual request status. |

---

## 4. Enhancement Pipeline

**Goal:** Generate an image, then upscale it, then edit a region.

### Steps

```
Generate → Upscale → Inpaint (edit region)
```

### Step 1 — Generate Base Image

```powershell
$genResult = .\scripts\Invoke-FalGenerate.ps1 `
    -Prompt "A fantasy castle on a cliff overlooking the ocean" `
    -Model "fal-ai/flux/dev" `
    -ImageSize "landscape_4_3"

$baseUrl = $genResult.Images[0].Url
Write-Host "Base image: $baseUrl"
```

### Step 2 — Upscale the Image

```powershell
$upscaleResult = .\scripts\Invoke-FalUpscale.ps1 `
    -ImageUrl $baseUrl `
    -Scale 2

$upscaledUrl = $upscaleResult.Image.Url
Write-Host "Upscaled: $upscaledUrl ($($upscaleResult.Width)x$($upscaleResult.Height))"
```

### Step 3 — Inpaint a Region

Prepare a mask image (white = area to edit) and upload it:

```powershell
$maskUrl = (.\scripts\Upload-ToFalCDN.ps1 -FilePath ".\mask.png").Url

$editResult = .\scripts\Invoke-FalInpainting.ps1 `
    -ImageUrl $upscaledUrl `
    -MaskUrl $maskUrl `
    -Prompt "A dragon perched on the castle tower" `
    -Strength 0.9
```

### Step 4 — Download Final Result

```powershell
$finalUrl = $editResult.Images[0].Url
Invoke-WebRequest -Uri $finalUrl -OutFile "enhanced_castle.png"
```

### Using New-FalWorkflow.ps1

For the generate → upscale portion, you can use the workflow engine:

```powershell
$steps = @(
    @{
        name      = 'generate'
        model     = 'fal-ai/flux/dev'
        params    = @{ prompt = 'A fantasy castle on a cliff'; image_size = 'landscape_4_3' }
        dependsOn = @()
    }
    @{
        name      = 'upscale'
        model     = 'fal-ai/aura-sr'
        params    = @{ scale = 2 }
        dependsOn = @('generate')
    }
)

$workflow = .\scripts\New-FalWorkflow.ps1 -Name 'enhance-castle' -Steps $steps
```

The workflow engine automatically passes `image_url` from the generate step
to the upscale step via the `dependsOn` mechanism.

### Error Recovery

| Error | Recovery |
|-------|----------|
| Upscale fails on large image | Use `Scale = 2` instead of `4` for very large inputs. |
| Inpainting looks wrong | Adjust `Strength` (lower = more of original, higher = more of prompt). Tune `GuidanceScale`. |
| Workflow step fails | Workflow engine throws on failure. Fix the failing step and re-run. |
| Mask not aligned | Ensure mask dimensions match the image. White = edit, black = keep. |

---

## 5. Generate-then-Animate Workflow

**Goal:** Generate an image from text, then animate it into a video.

### Steps

```
Text Prompt → Image Generation → Image-to-Video → Download
```

### Using New-FalWorkflow.ps1

```powershell
$steps = @(
    @{
        name      = 'generate'
        model     = 'fal-ai/flux/dev'
        params    = @{
            prompt     = 'A majestic eagle soaring over mountains'
            image_size = 'landscape_16_9'
        }
        dependsOn = @()
    }
    @{
        name      = 'animate'
        model     = 'fal-ai/kling-video/v2.6/pro/image-to-video'
        params    = @{
            prompt   = 'The eagle flaps its wings and flies forward'
            duration = 5
        }
        dependsOn = @('generate')
    }
)

$workflow = .\scripts\New-FalWorkflow.ps1 -Name 'eagle-animation' -Steps $steps
```

### Manual Step-by-Step

```powershell
# Step 1: Generate
$img = .\scripts\Invoke-FalGenerate.ps1 `
    -Prompt "A majestic eagle soaring over mountains" `
    -ImageSize "landscape_16_9"

# Step 2: Animate
$vid = .\scripts\Invoke-FalImageToVideo.ps1 `
    -ImageUrl $img.Images[0].Url `
    -Prompt "The eagle flaps its wings and flies forward" `
    -Duration 5

# Step 3: Download
Invoke-WebRequest -Uri $vid.Video.Url -OutFile "eagle.mp4"
```

### Error Recovery

| Error | Recovery |
|-------|----------|
| Video generation timeout | Default is 300s. For longer videos, increase `-TimeoutSeconds 600`. |
| Video looks static | Make the animation prompt more specific with motion keywords ("pan", "zoom", "fly"). |
| Circular dependency error | Check `dependsOn` arrays for cycles. Steps must form a DAG. |
