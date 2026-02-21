---
name: image-sorcery
description: >
  Use when the user wants to process, analyze, or manipulate images using
  local tools — detect objects, find items by description, crop, resize, blur,
  overlay, draw annotations, run OCR, or inspect metadata. Trigger phrases
  include "detect objects", "find in image", "crop image", "resize photo",
  "blur area", "add text to image", "read text from image", "overlay images",
  "rotate image", "draw on image", "image metadata", "annotate screenshot".
---

# ImageSorcery Skill

ImageSorcery is an MCP server providing local image processing tools powered
by OpenCV, YOLO models, and EasyOCR. Use it for deterministic image operations
that do not require generative AI — detection, measurement, annotation,
transformation, and text extraction.

For **generative** tasks (create images from text, style transfer, inpainting,
upscaling) use the **fal-ai** skill instead. Chain both skills for
generate-then-process workflows.

---

## MCP Connection

ImageSorcery runs as an MCP stdio server. The Copilot Extension discovers its
tools automatically via the MCP tool listing protocol.

```jsonc
// .github/mcp.json (or mcp.json at repo root)
{
  "servers": {
    "image-sorcery": {
      "type": "stdio",
      "command": "python",
      "args": ["-m", "image_sorcery.server"],
      "env": {
        "MODELS_DIR": "${workspaceFolder}/models"
      }
    }
  }
}
```

Once connected, all tools listed below are available. Call `config` to inspect
or override runtime settings (confidence thresholds, default blur strength,
interpolation method).

---

## Operation Tiers

Organize work by frequency and complexity. Start with Tier 1; escalate only
when needed.

### Tier 1 — Universal (every pipeline)

| Operation | Tool | Notes |
|-----------|------|-------|
| Resize / scale | `resize` | Width, height, or scale factor; preserves aspect ratio |
| Crop | `crop` | Bounding-box coordinates `(x1,y1,x2,y2)` |
| Rotate | `rotate` | Degrees; auto-expands canvas to fit |
| Metadata inspection | `get_metainfo` | Dimensions, format, file size |

### Tier 2 — High-Frequency (most pipelines)

| Operation | Tool | Notes |
|-----------|------|-------|
| Color conversion | `change_color` | Grayscale, sepia palettes |
| Blur / anonymize | `blur` | Rectangular or polygonal areas; adjustable strength |
| Compression / format | `resize` | Re-save at target dimensions for size control |
| Background removal | `find` + `fill` | Find subject → invert fill with transparency |

### Tier 3 — Specialized

| Operation | Tools | Notes |
|-----------|-------|-------|
| Masking | `find` (return_geometry) + `fill` | Segment objects, apply masks |
| Compositing | `overlay` | Place one image on another with alpha blending |
| Annotations | `draw_*` tools | Rectangles, circles, lines, arrows, text |
| Text extraction | `ocr` | EasyOCR with language selection |

### Tier 4 — Advanced / AI-Assisted

| Operation | Approach | Notes |
|-----------|----------|-------|
| Object detection | `detect` | YOLO models; returns classes + bounding boxes |
| Open-vocab search | `find` | Text-prompt object search with YOLOE |
| Segmentation masks | `detect` / `find` with `return_geometry: true` | Per-object masks or polygons |
| Upscaling, inpainting | Use **fal-ai** skill | Not handled locally by ImageSorcery |

---

## Available Tools

### detect

Run object detection with a YOLO model. Returns class names, confidence
scores, and bounding boxes. Optionally returns segmentation masks or polygons.

```jsonc
{
  "input_path": "/images/photo.jpg",
  "confidence": 0.5,
  "return_geometry": true,
  "geometry_format": "mask"  // "mask" or "polygon"
}
```

### find

Open-vocabulary object search — describe what to find in natural language.
Uses YOLOE text-prompt models.

```jsonc
{
  "input_path": "/images/photo.jpg",
  "description": "red car",
  "return_all_matches": false,
  "return_geometry": true
}
```

### crop

Extract a rectangular region by coordinates.

```jsonc
{
  "input_path": "/images/photo.jpg",
  "x1": 100, "y1": 50, "x2": 400, "y2": 300
}
```

### resize

Scale an image by dimensions or factor. Omit one dimension to preserve
aspect ratio.

```jsonc
{
  "input_path": "/images/photo.jpg",
  "width": 800
  // height auto-calculated
}
// OR
{
  "input_path": "/images/photo.jpg",
  "scale_factor": 0.5
}
```

### blur

Blur rectangular or polygonal areas. Use `invert_areas: true` to blur
everything except the specified regions (background blur).

```jsonc
{
  "input_path": "/images/photo.jpg",
  "areas": [
    { "x1": 50, "y1": 50, "x2": 200, "y2": 200, "blur_strength": 25 }
  ]
}
```

### fill

Fill areas with a color and opacity, or set `color: null` to make areas
transparent. Supports rectangles, polygons, and mask files.

```jsonc
{
  "input_path": "/images/photo.jpg",
  "areas": [
    { "polygon": [[0,0],[100,0],[100,100],[0,100]], "color": [255,0,0], "opacity": 0.5 }
  ]
}
```

### overlay

Place one image on top of another at a given position. Handles alpha
transparency automatically.

```jsonc
{
  "base_image_path": "/images/background.jpg",
  "overlay_image_path": "/images/logo.png",
  "x": 10, "y": 10
}
```

### draw_rectangles

Draw one or more rectangles with customizable color, thickness, and fill.

```jsonc
{
  "input_path": "/images/photo.jpg",
  "rectangles": [
    { "x1": 50, "y1": 50, "x2": 200, "y2": 200, "color": [0,255,0], "thickness": 2 }
  ]
}
```

### draw_circles

Draw circles by center and radius.

```jsonc
{
  "input_path": "/images/photo.jpg",
  "circles": [
    { "center_x": 150, "center_y": 150, "radius": 50, "color": [0,0,255], "thickness": 2 }
  ]
}
```

### draw_lines

Draw straight lines between two points.

```jsonc
{
  "input_path": "/images/photo.jpg",
  "lines": [
    { "x1": 0, "y1": 0, "x2": 300, "y2": 300, "color": [255,255,0], "thickness": 3 }
  ]
}
```

### draw_arrows

Draw arrows with customizable tip length.

```jsonc
{
  "input_path": "/images/photo.jpg",
  "arrows": [
    { "x1": 50, "y1": 50, "x2": 200, "y2": 200, "tip_length": 0.15 }
  ]
}
```

### draw_texts

Add text labels to an image. Multiple font faces available.

```jsonc
{
  "input_path": "/images/photo.jpg",
  "texts": [
    { "text": "Hello", "x": 10, "y": 30, "font_scale": 1.0, "color": [255,255,255] }
  ]
}
```

### ocr

Extract text from an image using EasyOCR. Returns text segments with
confidence scores and bounding boxes.

```jsonc
{
  "input_path": "/images/document.png",
  "language": "en"  // "en", "fr", "de", "ru", etc.
}
```

### rotate

Rotate an image by degrees (positive = counter-clockwise). Canvas auto-expands.

```jsonc
{
  "input_path": "/images/photo.jpg",
  "angle": 90
}
```

### change_color

Apply a color palette transformation.

```jsonc
{
  "input_path": "/images/photo.jpg",
  "palette": "grayscale"  // "grayscale" or "sepia"
}
```

### get_metainfo

Return image metadata: dimensions, format, file size.

```jsonc
{
  "input_path": "/images/photo.jpg"
}
```

### config

View or update runtime settings.

```jsonc
{ "action": "get" }
{ "action": "set", "key": "detection.confidence_threshold", "value": 0.6 }
```

---

## Integration with fal.ai

Chain fal.ai generation with ImageSorcery post-processing for end-to-end
media workflows.

### Pattern: Generate → Process

1. **Generate** an image with fal.ai (text-to-image, image-to-image).
2. **Inspect** with `get_metainfo` — verify dimensions, format.
3. **Transform** with ImageSorcery — resize, crop, annotate, convert.
4. **Deliver** the final asset.

### Example: Generate hero image, resize for web

```text
User: "Create a hero banner for my site, 1200×400"

Step 1 → fal.ai: generate landscape image from prompt
Step 2 → get_metainfo: confirm output dimensions
Step 3 → resize: scale to exactly 1200×400
Step 4 → return final image path to user
```

### Example: Generate product shot, remove background

```text
User: "Generate a product photo on transparent background"

Step 1 → fal.ai: generate product image
Step 2 → find: locate product subject (return_geometry: true)
Step 3 → fill: set color to null with invert_areas to remove background
Step 4 → return transparent PNG
```

### Example: Generate + annotate for documentation

```text
User: "Create a diagram and label the components"

Step 1 → fal.ai: generate base diagram
Step 2 → draw_rectangles: highlight regions of interest
Step 3 → draw_arrows: point to components
Step 4 → draw_texts: add labels
Step 5 → return annotated image
```

---

## Best Practices

### Input Requirements

- All `input_path` and `output_path` values must be **absolute paths**.
- Supported formats: JPEG, PNG, WebP, BMP, TIFF.
- For transparency operations, use PNG output (JPEG drops alpha).
- YOLO models must be pre-downloaded before using `detect` or `find`.

### Output Handling

- Tools return the **path** to the output file, not raw image data.
- Default output paths append a suffix (e.g., `_resized`, `_cropped`).
- Provide explicit `output_path` to control naming and location.
- Chain operations by passing one tool's output path as the next tool's input.

### Error Patterns

| Error | Cause | Fix |
|-------|-------|-----|
| File not found | Relative path or typo | Use absolute path; verify with `get_metainfo` |
| Model not found | YOLO model not downloaded | Run model download command first |
| No detections | Low confidence or wrong model | Lower `confidence` threshold or try `find` with text prompt |
| Transparent output is JPEG | JPEG does not support alpha | Change output to `.png` |
| Blur strength must be odd | Even kernel size | Use odd numbers: 15, 25, 35 |

### Performance Tips

- Resize large images **before** running detection to reduce processing time.
- Use `scale_factor` for proportional resizing instead of calculating dimensions.
- Set `return_geometry: false` when you only need bounding boxes, not masks.
- Batch annotations: pass multiple items in a single `draw_*` call instead of
  calling the tool repeatedly.

---

## Example Workflows

### 1. Resize for Web

Resize an image to a maximum width of 800px while preserving aspect ratio,
then inspect the result.

```text
1. resize(input_path="/photos/original.jpg", width=800)
   → /photos/original_resized.jpg
2. get_metainfo(input_path="/photos/original_resized.jpg")
   → { width: 800, height: 533, format: "JPEG", size: "124 KB" }
```

### 2. Detect Objects + Crop

Find all people in a photo, then crop the first detection.

```text
1. detect(input_path="/photos/group.jpg", confidence=0.5)
   → [{ class: "person", bbox: [120, 50, 380, 400], confidence: 0.92 }, ...]
2. crop(input_path="/photos/group.jpg", x1=120, y1=50, x2=380, y2=400)
   → /photos/group_cropped.jpg
```

### 3. Generate + Enhance

Generate a product image with fal.ai, then post-process with ImageSorcery.

```text
1. fal-ai: generate product photo (text-to-image)
   → /generated/product_raw.png
2. resize(input_path="/generated/product_raw.png", width=1024)
   → /generated/product_raw_resized.png
3. find(input_path=..., description="product", return_geometry=true)
   → mask_path: /generated/product_mask.png
4. fill(input_path=..., areas=[{mask_path: "...mask.png", color: null}],
        invert_areas=true, output_path="/final/product.png")
   → /final/product.png  (transparent background)
```

### 4. Annotate Screenshot for Documentation

Add bounding boxes and labels to a screenshot.

```text
1. draw_rectangles(input_path="/screenshots/ui.png",
     rectangles=[{ x1:10, y1:50, x2:300, y2:120, color:[0,255,0], thickness:2 }])
   → /screenshots/ui_with_rectangles.png
2. draw_arrows(input_path=...,
     arrows=[{ x1:150, y1:130, x2:150, y2:200, color:[0,255,0] }])
   → /screenshots/ui_with_arrows.png
3. draw_texts(input_path=...,
     texts=[{ text:"Navigation Bar", x:10, y:45, color:[0,255,0] }])
   → /screenshots/ui_with_text.png
```
