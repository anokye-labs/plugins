---
name: fal-image-edit
description: >
  Edit existing images using AI models. Use when the user says "edit image",
  "remove object", "change background", "apply style", "style transfer",
  "remove person", "replace background", "fill masked area", or "inpaint image".
  Routes to the best fal.ai model based on the editing operation type.
metadata:
  author: anokye-labs
  version: "1.0.0"
---

# fal-image-edit Skill

Apply AI-powered edits to existing images using operation-based model routing.
Each operation type uses the best available fal.ai model for that specific task.

For **generation from scratch** use **fal-ai**. For **local processing** use **image-sorcery**.

---

## Script

| Script                     | Purpose                               |
|----------------------------|---------------------------------------|
| `Invoke-FalImageEdit.ps1`  | Route image edits by operation type   |

---

## Operation Taxonomy

| Operation    | Best Model                          | When to Use                             |
|--------------|-------------------------------------|-----------------------------------------|
| `style`      | `fal-ai/flux/dev/image-to-image`    | Style transfer, artistic transforms     |
| `remove`     | `fal-ai/bria/fibo-edit`             | Object/person removal (no mask needed)  |
| `background` | `fal-ai/flux-kontext`               | Context-aware background replacement    |
| `inpaint`    | `fal-ai/flux/dev/inpainting`        | Precise mask-based region edits         |
| `general`    | `fal-ai/nano-banana-pro`            | Best overall for any editing task       |

---

## Quick Start

```powershell
# Style transfer (default operation)
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl "https://example.com/photo.jpg" `
    -Prompt   "apply impressionist oil painting style"

# Remove an object (no mask needed)
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://example.com/photo.jpg" `
    -Prompt    "remove the parked car" `
    -Operation remove

# Replace the background
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://example.com/portrait.jpg" `
    -Prompt    "replace background with a sunset beach" `
    -Operation background

# Inpaint a masked region
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://example.com/photo.jpg" `
    -MaskUrl   "https://example.com/mask.png" `
    -Prompt    "a bouquet of red roses" `
    -Operation inpaint

# General edit (best overall quality)
.\scripts\Invoke-FalImageEdit.ps1 `
    -ImageUrl  "https://example.com/photo.jpg" `
    -Prompt    "make it look like a professional photo shoot" `
    -Operation general
```

---

## Parameters

| Parameter     | Type    | Default  | Description                                        |
|---------------|---------|----------|----------------------------------------------------|
| `-ImageUrl`   | string  | required | Source image URL                                   |
| `-Prompt`     | string  | required | Edit instruction                                   |
| `-Operation`  | string  | `style`  | style \| remove \| background \| inpaint \| general |
| `-MaskUrl`    | string  | —        | Mask URL (required for `inpaint`)                  |
| `-Strength`   | double  | `0.75`   | Edit strength 0.0–1.0                              |
| `-Model`      | string  | —        | Override auto-selected model                       |

---

## Strength Guide

| Range     | Effect                              | Recommended For             |
|-----------|-------------------------------------|-----------------------------|
| 0.3–0.5   | Subtle — preserves most of original | Minor color/tone shifts     |
| 0.5–0.7   | Moderate — balanced edit            | Most style and edits        |
| 0.7–1.0   | Dramatic — heavy transformation     | Major style transfers       |

---

## Output Format

```json
{
  "Images":    [{ "Url": "https://v3.fal.media/files/...", "Width": 1024, "Height": 1024 }],
  "Seed":      42,
  "Operation": "style",
  "Model":     "fal-ai/flux/dev/image-to-image"
}
```

The `inpaint` operation returns the same structure as `Invoke-FalInpainting.ps1`
(`Images`, `Seed`) since it delegates to that script.

---

## Auth & Error Handling

Authentication and error handling follow the **fal-ai** skill conventions:

- `FAL_KEY` loaded from `$env:FAL_KEY` or `.env` file
- HTTP 429 and 5xx retried automatically (exponential backoff, 3 attempts)
- HTTP 401 and 400 fail immediately — check your key or prompt

See `skills/fal-ai/references/ERROR_CODES.md` for full error reference.

---

## References

- [OPERATIONS.md](references/OPERATIONS.md) — Per-operation model guide and mask tips
- [EXAMPLES.md](references/EXAMPLES.md) — Usage patterns per operation
