# Evaluation 7: End-to-End Workflow

**Priority:** 🔴 Critical  
**Time:** 10 minutes  
**Prerequisites:** Installed plugin, `FAL_KEY` set, all connectivity confirmed

## Objective

Verify a complete media workflow from generation through processing to delivery.

## Test Steps

### 7.1 Upload → Generate → Retrieve

**Action:** Upload a local file, use it as input, retrieve the result.

```powershell
# Upload a test image
Import-Module ahuofe\scripts\FalAi.psm1 -Force
$url = Send-FalFile -FilePath "path\to\test-image.jpg"
Write-Host "Uploaded: $url"

# Use it for image-to-video
$result = & ahuofe\scripts\Invoke-FalImageToVideo.ps1 `
    -ImageUrl $url `
    -Prompt "Gentle zoom in" `
    -Queue
Write-Host "Video: $($result.Video.Url)"
```

**Expected:**
- [ ] File uploads to fal.ai CDN successfully
- [ ] Upload URL is a valid `https://v3b.fal.media/files/...` URL
- [ ] Video generation completes using uploaded image
- [ ] Final video URL is accessible

### 7.2 Multi-Step Copilot Workflow

**Action:** In a Copilot chat session, ask:

> "Generate an image of a product mockup for a water bottle, upscale it to high resolution, then tell me the final image dimensions"

**Expected:**
- [ ] Copilot generates the initial image (fal-ai skill)
- [ ] Copilot upscales the result (fal-ai skill, upscale script)
- [ ] Copilot reports dimensions (image-sorcery or script output)
- [ ] Multi-step workflow completes without manual intervention

### 7.3 Error Recovery

**Action:** In a Copilot chat session, simulate a partial failure:

> "Generate 3 images: a cat, a dog, and a dragon. If any fail, tell me which ones succeeded."

**Expected:**
- [ ] Copilot attempts all 3 generations
- [ ] Reports results per image
- [ ] Handles any failures gracefully (does not stop on first error)

### 7.4 Cost Tracking

**Action:** Check API usage after running evaluations.

```powershell
& ahuofe\scripts\Get-FalUsage.ps1
```

**Expected:**
- [ ] Shows usage statistics
- [ ] Reflects the API calls made during evaluations

### 7.5 Uninstall Clean

**Action:** Verify the plugin can be cleanly removed.

```powershell
& <plugins-root>\Uninstall-Plugins.ps1 -TargetRepo $testRepo -Plugins ahuofe -Force
```

**Expected:**
- [ ] All ahuofe skill directories are removed
- [ ] Script directory is removed
- [ ] No orphaned files remain in `.github/skills/`

## Cleanup

```powershell
Remove-Item $testRepo -Recurse -Force
```

## Pass/Fail

- **PASS:** Steps 7.1 and 7.2 succeed, and 7.5 succeeds
- **FAIL:** Any critical step fails
