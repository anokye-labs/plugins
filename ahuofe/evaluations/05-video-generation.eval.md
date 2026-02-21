# Evaluation 5: Video Generation

**Priority:** 🟡 Important  
**Time:** 10 minutes  
**Prerequisites:** Installed plugin, `FAL_KEY` set, fal.ai connectivity confirmed

## Objective

Verify text-to-video and image-to-video generation work correctly.

## Test Steps

### 5.1 Text-to-Video

**Action:** Generate a short video from a text prompt.

```powershell
$result = & ahuofe\scripts\Invoke-FalVideoGen.ps1 `
    -Prompt "Ocean waves gently crashing on a sandy beach" `
    -Queue
$result | Format-List
```

**Expected:**
- [ ] Script submits to queue and polls for completion
- [ ] Returns a result with `Video.Url`
- [ ] Video URL is accessible
- [ ] Generation may take 1–5 minutes (queue mode)

### 5.2 Image-to-Video

**Action:** Animate a still image.

```powershell
# First generate an image
$image = & ahuofe\scripts\Invoke-FalGenerate.ps1 -Prompt "A still lake with mountains"
$imageUrl = $image.Images[0].Url

# Then animate it
$video = & ahuofe\scripts\Invoke-FalImageToVideo.ps1 `
    -ImageUrl $imageUrl `
    -Prompt "Camera slowly zooms in, water ripples" `
    -Queue
$video.Video.Url
```

**Expected:**
- [ ] Image generates successfully
- [ ] Image URL is passed to video generation
- [ ] Video result contains a valid URL
- [ ] Video shows animation of the still image

### 5.3 Queue Status Monitoring

**Action:** Check queue status during generation.

```powershell
& ahuofe\scripts\Get-QueueStatus.ps1
```

**Expected:**
- [ ] Shows current queue jobs (if any active)
- [ ] Displays status per job (IN_QUEUE, IN_PROGRESS, COMPLETED, FAILED)

### 5.4 Copilot Video Generation

**Action:** In a Copilot chat session, ask:

> "Create a short video of a sunset over the ocean"

**Expected:**
- [ ] Copilot uses the fal-ai skill with a video model
- [ ] Queue-based generation is used
- [ ] Video URL is displayed when complete

## Pass/Fail

- **PASS:** Steps 5.1 and 5.4 succeed
- **FAIL:** Both 5.1 and 5.4 fail
