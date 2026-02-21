# Operations Reference — fal-image-edit

Per-operation model selection guide, payload details, and mask tips.

---

## style — Style Transfer

**Model:** `fal-ai/flux/dev/image-to-image`

Use for artistic style transforms: convert a photo to painting, sketch, anime, etc.

### Payload
```json
{
  "image_url": "<source>",
  "prompt":    "apply watercolor painting style",
  "strength":  0.75
}
```

### Strength Tips
| Strength | Result                                              |
|----------|-----------------------------------------------------|
| 0.3–0.5  | Subtle texture overlay, original structure intact   |
| 0.6–0.75 | Balanced — clear style shift while preserving shape |
| 0.8–0.9  | Heavy stylization — dramatic artistic transformation |

### When to Use
- "Apply impressionist painting style"
- "Convert photo to anime"
- "Make it look like a watercolor"
- "Sketch style"

---

## remove — Object / Person Removal

**Model:** `fal-ai/bria/fibo-edit`

Maskless removal using inpainting from text description. The model infers
what to remove from the prompt — no mask image required.

### Payload
```json
{
  "image_url": "<source>",
  "prompt":    "remove the parked car",
  "strength":  0.75
}
```

### Prompt Tips
- Be specific: "remove the red fire hydrant" not "remove object"
- Use "erase", "delete", "remove", or "take out" in the prompt
- Describe the background replacement if needed: "remove the person, fill with grass"

### When to Use
- "Remove the background people"
- "Erase the power lines"
- "Delete the watermark"
- "Take out the car from the scene"

---

## background — Background Replacement

**Model:** `fal-ai/flux-kontext`

Context-aware replacement that matches lighting, shadows, and perspective.

### Payload
```json
{
  "image_url": "<source>",
  "prompt":    "replace background with a sunset beach",
  "strength":  0.75
}
```

### Prompt Tips
- Describe lighting conditions to maintain realism: "soft golden hour lighting"
- Match the subject's environment: "office background matching the lighting"
- Avoid conflicting light directions from the original subject

### Strength Tips
| Strength | Result                                            |
|----------|---------------------------------------------------|
| 0.5–0.6  | Light background update, subject mostly preserved |
| 0.7–0.8  | Full background replacement, subject intact       |
| 0.85+    | May alter foreground — use carefully              |

### When to Use
- "Change the background to a forest"
- "Put this person in a studio setting"
- "Replace sky with dramatic clouds"
- "Office background for video call"

---

## inpaint — Mask-Based Region Edit

**Model:** `fal-ai/flux/dev/inpainting`

Delegates to `Invoke-FalInpainting.ps1`. Requires a mask image where **white
regions** mark the area to be repainted.

### Mask Requirements
- **White pixels** = areas to repaint
- **Black pixels** = areas to preserve
- Mask must be same dimensions as source image
- Recommended: PNG with no alpha channel

### Payload (via Invoke-FalInpainting.ps1)
```json
{
  "image_url":           "<source>",
  "mask_url":            "<mask>",
  "prompt":              "a bouquet of red roses",
  "strength":            0.85,
  "num_inference_steps": 30,
  "guidance_scale":      7.5
}
```

### Creating Masks
1. Open source image in any image editor
2. Paint white over regions you want to replace
3. Save as PNG
4. Upload to CDN: `.\scripts\Upload-ToFalCDN.ps1 -FilePath mask.png`

### Strength Tips
| Strength | Result                                              |
|----------|-----------------------------------------------------|
| 0.5–0.7  | Soft blend with surrounding pixels                  |
| 0.7–0.9  | Strong replacement (recommended for most edits)     |
| 0.85–1.0 | Near-complete replacement, may show seams           |

### When to Use
- "Fill this selected area with a flower arrangement"
- "Replace the sign text with 'OPEN'"
- "Change the shirt color in this region"
- "Add a window in this blank wall area"

---

## general — Best Overall Edit

**Model:** `fal-ai/nano-banana-pro`

The best all-around model for any editing task. Use when unsure which specific
operation to apply, or when the request blends multiple edit types.

### Payload
```json
{
  "image_url": "<source>",
  "prompt":    "make it look like a professional photo shoot",
  "strength":  0.75
}
```

### Strength Tips
| Strength | Result                                            |
|----------|---------------------------------------------------|
| 0.4–0.6  | Enhancement with minimal structural change        |
| 0.7–0.8  | Clear transformation, good default range          |
| 0.85+    | Major edit — significant departure from original  |

### When to Use
- Unspecified edit type ("edit this image to look better")
- Complex prompts mixing style + object + background changes
- When other operations produce unsatisfactory results
- "Improve this photo", "Enhance the scene", "Touch up this image"

---

## Model Override

Any operation can override its default model using `-Model`:

```powershell
# Use nano-banana-pro for style transfer instead of flux image-to-image
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://..." `
    -Prompt    "cyberpunk neon style" `
    -Operation style `
    -Model     "fal-ai/nano-banana-pro"
```

## Default Model Summary

| Operation    | Default Model                        |
|--------------|--------------------------------------|
| `style`      | `fal-ai/flux/dev/image-to-image`     |
| `remove`     | `fal-ai/bria/fibo-edit`              |
| `background` | `fal-ai/flux-kontext`                |
| `inpaint`    | `fal-ai/flux/dev/inpainting`         |
| `general`    | `fal-ai/nano-banana-pro`             |
