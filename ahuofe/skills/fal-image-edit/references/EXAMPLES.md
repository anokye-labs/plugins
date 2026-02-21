# Examples — fal-image-edit

Usage patterns per operation type with expected outputs.

---

## style — Style Transfer

### Watercolor Painting
```powershell
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://v3.fal.media/files/photo.jpg" `
    -Prompt    "apply soft watercolor painting style with visible brushstrokes" `
    -Operation style `
    -Strength  0.75
```
**Output:**
```
Editing image with operation 'style' using fal-ai/flux/dev/image-to-image...
Image: https://v3.fal.media/files/edited-watercolor.png
```

### Anime Conversion
```powershell
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://v3.fal.media/files/portrait.jpg" `
    -Prompt    "convert to Studio Ghibli anime art style" `
    -Operation style `
    -Strength  0.85
```

### Subtle Texture Overlay (Low Strength)
```powershell
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://v3.fal.media/files/product.jpg" `
    -Prompt    "add slight film grain and vintage warmth" `
    -Operation style `
    -Strength  0.35
```

---

## remove — Object Removal

### Remove a Person
```powershell
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://v3.fal.media/files/street.jpg" `
    -Prompt    "remove the pedestrian on the left" `
    -Operation remove
```

### Erase a Watermark
```powershell
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://v3.fal.media/files/image.jpg" `
    -Prompt    "remove the watermark text in the bottom right corner" `
    -Operation remove
```

### Clean Power Lines from Sky
```powershell
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://v3.fal.media/files/cityscape.jpg" `
    -Prompt    "remove the power lines crossing the sky, fill with clear sky" `
    -Operation remove
```

---

## background — Background Replacement

### Studio Background for Portrait
```powershell
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://v3.fal.media/files/portrait.jpg" `
    -Prompt    "replace background with a clean white studio backdrop" `
    -Operation background `
    -Strength  0.75
```

### Add Dramatic Sky
```powershell
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://v3.fal.media/files/landscape.jpg" `
    -Prompt    "replace sky with dramatic storm clouds at golden hour" `
    -Operation background `
    -Strength  0.70
```

### Professional Headshot Background
```powershell
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://v3.fal.media/files/headshot.jpg" `
    -Prompt    "modern blurred office background with soft lighting" `
    -Operation background `
    -Strength  0.75
```

---

## inpaint — Mask-Based Edits

### Replace a Specific Region
```powershell
# First, upload your mask
Import-Module .\scripts\FalAi.psm1
$maskUrl = Send-FalFile -FilePath ".\mask.png"

# Then run inpaint
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://v3.fal.media/files/room.jpg" `
    -MaskUrl   $maskUrl `
    -Prompt    "a large potted plant" `
    -Operation inpaint `
    -Strength  0.85
```

### Change Sign Text
```powershell
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://v3.fal.media/files/storefront.jpg" `
    -MaskUrl   "https://v3.fal.media/files/sign-mask.png" `
    -Prompt    "OPEN sign in bright neon red letters" `
    -Operation inpaint
```

### Soft Blend (Low Strength)
```powershell
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://v3.fal.media/files/photo.jpg" `
    -MaskUrl   "https://v3.fal.media/files/mask.png" `
    -Prompt    "smooth skin texture matching the surrounding area" `
    -Operation inpaint `
    -Strength  0.60
```

---

## general — Best Overall Edit

### Photo Enhancement
```powershell
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://v3.fal.media/files/snapshot.jpg" `
    -Prompt    "enhance to professional photography quality with better lighting and sharpness" `
    -Operation general
```

### Complex Multi-Aspect Edit
```powershell
# When the edit mixes style, background, and tone — use general
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://v3.fal.media/files/photo.jpg" `
    -Prompt    "make this look like a luxury fashion magazine editorial shoot" `
    -Operation general `
    -Strength  0.80
```

### Fallback When Other Operations Fail
```powershell
# If 'remove' produced poor results, retry with 'general'
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://v3.fal.media/files/photo.jpg" `
    -Prompt    "remove the telephone pole and fill naturally" `
    -Operation general `
    -Strength  0.75
```

---

## Model Override Examples

### Use nano-banana-pro for Any Operation
```powershell
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://v3.fal.media/files/photo.jpg" `
    -Prompt    "dramatic cinematic lighting and color grade" `
    -Operation style `
    -Model     "fal-ai/nano-banana-pro" `
    -Strength  0.75
```

### Use flux-kontext for Inpainting
```powershell
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://v3.fal.media/files/photo.jpg" `
    -MaskUrl   "https://v3.fal.media/files/mask.png" `
    -Prompt    "replace with a sunset sky" `
    -Operation inpaint `
    -Model     "fal-ai/flux-kontext"
```

---

## Combined with Upload

Upload a local file first, then edit:

```powershell
Import-Module .\scripts\FalAi.psm1

# Upload source image
$imageUrl = Send-FalFile -FilePath ".\photo.jpg"

# Apply style
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  $imageUrl `
    -Prompt    "convert to oil painting style" `
    -Operation style
```

---

## Presenting Results

```
✅ Edited with operation: style
   Model: fal-ai/flux/dev/image-to-image

![Edited](https://v3.fal.media/files/...)
• 1024×1024
```
