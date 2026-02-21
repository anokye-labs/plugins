# fal.ai Usage Examples

Concrete PowerShell examples covering all scripts and common workflows.

---

## 1. Basic Image Generation

Generate an image using the default model (FLUX Dev).

```powershell
.\scripts\Invoke-FalGenerate.ps1 -Prompt "A serene mountain landscape at golden hour"
```

**Expected Output:**
```
Generating with fal-ai/flux/dev (sync)...
Image: https://v3.fal.media/files/abc123/image.png

Images : {Url: https://v3.fal.media/files/abc123/image.png, Width: 1024, Height: 768}
Seed   : 2948571
Prompt : A serene mountain landscape at golden hour
Model  : fal-ai/flux/dev
Video  :
```

---

## 2. Queue Mode Generation

Use queue mode for reliable generation with progress tracking.

```powershell
.\scripts\Invoke-FalGenerate.ps1 `
    -Prompt "Epic fantasy castle floating in the clouds" `
    -Model "fal-ai/flux/dev" `
    -ImageSize "landscape_16_9" `
    -NumImages 2 `
    -Seed 42 `
    -Queue
```

**Expected Output:**
```
Submitting to queue: fal-ai/flux/dev...
Image: https://v3.fal.media/files/abc123/image1.png
Image: https://v3.fal.media/files/abc123/image2.png

Images : {2 images}
Seed   : 42
Prompt : Epic fantasy castle floating in the clouds
Model  : fal-ai/flux/dev
Video  :
```

---

## 3. File Upload to CDN

Upload a local file to fal.ai CDN for use with image-to-video or inpainting.

```powershell
.\scripts\Upload-ToFalCDN.ps1 -FilePath ".\photo.png"
```

**Expected Output:**
```
Uploading: photo.png (245.3 KB)
Upload complete!
URL: https://v3b.fal.media/files/upload/abc123/photo.png

Url         : https://v3b.fal.media/files/upload/abc123/photo.png
FileName    : photo.png
ContentType : image/png
Size        : 251187
```

---

## 4. Image Upscaling

Upscale an image to 2× resolution using Aura SR.

```powershell
.\scripts\Invoke-FalUpscale.ps1 `
    -ImageUrl "https://v3.fal.media/files/abc123/image.png" `
    -Scale 2
```

**Expected Output:**
```
Upscaling with fal-ai/aura-sr (sync)...
Upscaled: https://v3.fal.media/files/def456/upscaled.png
Size: 2048x1536

Image  : {Url: https://v3.fal.media/files/def456/upscaled.png, Width: 2048, Height: 1536}
Width  : 2048
Height : 1536
```

---

## 5. Inpainting (Image Editing)

Edit a specific region of an image using a mask.

```powershell
.\scripts\Invoke-FalInpainting.ps1 `
    -ImageUrl "https://v3.fal.media/files/abc123/photo.png" `
    -MaskUrl "https://v3.fal.media/files/abc123/mask.png" `
    -Prompt "A bright red rose bush" `
    -Strength 0.9 `
    -GuidanceScale 8.0
```

**Expected Output:**
```
Inpainting with fal-ai/inpainting (sync)...
Image: https://v3.fal.media/files/ghi789/inpainted.png

Images : {Url: https://v3.fal.media/files/ghi789/inpainted.png, Width: 1024, Height: 1024}
Seed   : 8374621
```

---

## 6. Text-to-Video Generation

Generate a video from a text prompt.

```powershell
.\scripts\Invoke-FalVideoGen.ps1 `
    -Prompt "Ocean waves crashing on a beach at sunset, cinematic" `
    -Duration 5 `
    -AspectRatio "16:9"
```

**Expected Output:**
```
Submitting to queue: fal-ai/kling-video/v2.6/pro/text-to-video...
Video: https://v3.fal.media/files/jkl012/video.mp4

Video    : {Url: https://v3.fal.media/files/jkl012/video.mp4}
Duration : 5
Prompt   : Ocean waves crashing on a beach at sunset, cinematic
Model    : fal-ai/kling-video/v2.6/pro/text-to-video
```

---

## 7. Image-to-Video Generation

Animate a static image into a video.

```powershell
.\scripts\Invoke-FalImageToVideo.ps1 `
    -ImageUrl "https://v3.fal.media/files/abc123/landscape.png" `
    -Prompt "Camera slowly pans right, clouds drift across the sky" `
    -Duration 5
```

**Expected Output:**
```
Submitting to queue: fal-ai/kling-video/v2.6/pro/image-to-video...
Video: https://v3.fal.media/files/mno345/animated.mp4

Video    : {Url: https://v3.fal.media/files/mno345/animated.mp4}
Duration : 5
ImageUrl : https://v3.fal.media/files/abc123/landscape.png
Model    : fal-ai/kling-video/v2.6/pro/image-to-video
```

---

## 8. Multi-Step Workflow

Run a generate → animate workflow using the workflow engine.

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

.\scripts\New-FalWorkflow.ps1 -Name 'eagle-animation' -Steps $steps
```

**Expected Output:**
```
Running workflow: eagle-animation (2 steps)...
  Step 'generate': fal-ai/flux/dev...
  Step 'generate': Completed
  Step 'animate': fal-ai/kling-video/v2.6/pro/image-to-video...
  Step 'animate': Completed
Workflow 'eagle-animation' completed.

WorkflowName : eagle-animation
Steps        : {generate (Completed), animate (Completed)}
```

---

## 9. Search for Models

Search the fal.ai model registry.

```powershell
.\scripts\Search-FalModels.ps1 -Query "flux" -Limit 5
```

**Expected Output:**
```
Searching fal.ai models...
Found 5 model(s).

EndpointId                    Name              Category
----------                    ----              --------
fal-ai/flux/dev               FLUX.1 Dev        text-to-image
fal-ai/flux/schnell           FLUX.1 Schnell    text-to-image
fal-ai/flux-pro/v1.1-ultra    FLUX Pro Ultra    text-to-image
fal-ai/flux-realism           FLUX Realism      text-to-image
fal-ai/flux-lora              FLUX LoRA         text-to-image
```

---

## 10. Get Model Schema

Inspect a model's input parameters and output fields.

```powershell
.\scripts\Get-ModelSchema.ps1 -ModelId "fal-ai/flux/dev" -InputOnly
```

**Expected Output:**
```
Fetching schema for fal-ai/flux/dev...

Input Parameters:

Name                    Type     Required Default
----                    ----     -------- -------
prompt                  string   True
image_size              enum     False    landscape_4_3
num_images              integer  False    1
seed                    integer  False
num_inference_steps     integer  False    28
guidance_scale          number   False    3.5
enable_safety_checker   boolean  False    True
```

---

## 11. Check API Usage

View usage statistics and costs.

```powershell
.\scripts\Get-FalUsage.ps1 -Days 7
```

**Expected Output:**
```
Fetching usage data for the last 7 day(s)...

Usage Summary (2025-01-20 to 2025-01-27):
  Total Cost:     $2.45
  Total Requests: 127

By Endpoint:
EndpointId                                     Cost  Quantity
----------                                     ----  --------
fal-ai/flux/dev                                1.20  98
fal-ai/kling-video/v2.6/pro/image-to-video     0.85  12
fal-ai/aura-sr                                 0.25  10
fal-ai/flux-pro/v1.1-ultra                     0.15  7
```

---

## 12. Test API Connection

Verify API key and connectivity.

```powershell
.\scripts\Test-FalConnection.ps1
```

**Expected Output:**
```
[PASS] FAL_KEY found (fal-xxxx...)
[PASS] API reachable (response: 245ms)

fal.ai connection OK

KeyFound     : True
ApiReachable : True
ResponseTime : 245ms
Error        :
```

---

## 13. Check Queue Status

Check the status of a queued request.

```powershell
.\scripts\Get-QueueStatus.ps1 `
    -RequestId "abc-123-def-456" `
    -Model "fal-ai/kling-video/v2.6/pro/text-to-video"
```

**Expected Output:**
```
Checking queue status for abc-123-def-456...
Status: IN_PROGRESS

RequestId     : abc-123-def-456
Model         : fal-ai/kling-video/v2.6/pro/text-to-video
Status        : IN_PROGRESS
QueuePosition :
ResponseUrl   :
Logs          :
```

---

## 14. Upload and Generate End-to-End

Full pipeline: upload a local image, then animate it.

```powershell
# Step 1: Upload
$upload = .\scripts\Upload-ToFalCDN.ps1 -FilePath ".\my-photo.jpg"

# Step 2: Animate
$video = .\scripts\Invoke-FalImageToVideo.ps1 `
    -ImageUrl $upload.Url `
    -Prompt "Gentle zoom in with parallax effect" `
    -Duration 5

# Step 3: Download
Invoke-WebRequest -Uri $video.Video.Url -OutFile "animated.mp4"
Write-Host "Saved: animated.mp4"
```

---

## 15. Generate, Upscale, and Download

Full enhancement pipeline.

```powershell
# Step 1: Generate
$img = .\scripts\Invoke-FalGenerate.ps1 `
    -Prompt "A detailed steampunk clocktower" `
    -Model "fal-ai/flux/dev"

# Step 2: Upscale
$hires = .\scripts\Invoke-FalUpscale.ps1 `
    -ImageUrl $img.Images[0].Url `
    -Scale 4

# Step 3: Download
Invoke-WebRequest -Uri $hires.Image.Url -OutFile "clocktower_4x.png"
Write-Host "Saved: clocktower_4x.png ($($hires.Width)x$($hires.Height))"
```
