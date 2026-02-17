# Evaluation 3: Text-to-Image Generation

**Priority:** 🔴 Critical  
**Time:** 5 minutes  
**Prerequisites:** Installed plugin, `FAL_KEY` set, fal.ai connectivity confirmed

## Objective

Verify text-to-image generation works via scripts and through Copilot.

## Test Steps

### 3.1 Basic Image Generation

**Action:** Generate an image with a simple prompt.

```powershell
$result = & ahuofe\scripts\Invoke-FalGenerate.ps1 -Prompt "A serene mountain landscape at sunset"
$result | Format-List
```

**Expected:**
- [ ] Returns a `PSCustomObject` with `Images`, `Seed`, `Prompt`, `Model` properties
- [ ] `Images` contains at least one entry with a `Url`
- [ ] URL is accessible (starts with `https://`)

### 3.2 Custom Model

**Action:** Generate using the fast model.

```powershell
$result = & ahuofe\scripts\Invoke-FalGenerate.ps1 `
    -Prompt "A red fox in a snowy forest" `
    -Model "fal-ai/flux/schnell"
$result.Model
```

**Expected:**
- [ ] Generation completes faster than default
- [ ] Model field shows `fal-ai/flux/schnell`
- [ ] Image URL is valid

### 3.3 Queue Mode

**Action:** Generate using queue mode for a complex prompt.

```powershell
$result = & ahuofe\scripts\Invoke-FalGenerate.ps1 `
    -Prompt "Epic fantasy castle on a cliff, dramatic lighting, photorealistic" `
    -Model "fal-ai/flux/dev" `
    -Queue
$result.Images[0].Url
```

**Expected:**
- [ ] Script submits to queue and polls for completion
- [ ] Returns completed result with image URL
- [ ] No timeout errors

### 3.4 Invalid Model Handling

**Action:** Try a non-existent model.

```powershell
try {
    & ahuofe\scripts\Invoke-FalGenerate.ps1 `
        -Prompt "test" `
        -Model "fal-ai/nonexistent-model-12345"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}
```

**Expected:**
- [ ] Error is caught and reported gracefully
- [ ] Message indicates model not found or invalid endpoint

### 3.5 Copilot Image Generation

**Action:** In a Copilot chat session, ask:

> "Generate an image of a cozy coffee shop on a rainy day"

**Expected:**
- [ ] Copilot uses the fal-ai skill
- [ ] Image is generated and URL is displayed
- [ ] Result includes model and metadata

## Pass/Fail

- **PASS:** Steps 3.1, 3.3, and 3.5 succeed
- **FAIL:** Any of these fail
