# ImageSorcery Examples

> Concrete examples with full parameter values covering all four operation
> tiers. Each example includes a description, the complete tool call, and the
> expected output.

---

## Example 1 — Inspect Image Metadata (Tier 1)

**Goal:** Check the dimensions and format of a photo before processing.

**Tool call:**

```jsonc
// get_metainfo
{
  "input_path": "/photos/hero-banner.jpg"
}
```

**Expected output:**

```jsonc
{
  "input_path": "/photos/hero-banner.jpg",
  "width": 3840,
  "height": 2160,
  "format": "JPEG",
  "file_size": "4.2 MB",
  "color_mode": "RGB"
}
```

---

## Example 2 — Resize for Web with Aspect Ratio (Tier 1)

**Goal:** Scale a 4K image down to 800px width for web, preserving aspect ratio.

**Tool call:**

```jsonc
// resize
{
  "input_path": "/photos/hero-banner.jpg",
  "width": 800,
  "interpolation": "lanczos",
  "output_path": "/photos/hero-banner-web.jpg"
}
```

**Expected output:**

```text
"/photos/hero-banner-web.jpg"
```

Resulting image: 800 × 450 pixels (16:9 preserved).

---

## Example 3 — Detect Objects and Crop (Tier 1 + Tier 2)

**Goal:** Find the first person in a group photo and crop to their bounding box.

**Step 1 — Detect:**

```jsonc
// detect
{
  "input_path": "/photos/team.jpg",
  "confidence": 0.5,
  "model_name": "yolov8m.pt"
}
```

**Step 1 output:**

```jsonc
{
  "input_path": "/photos/team.jpg",
  "objects": [
    { "class": "person", "confidence": 0.94, "bbox": [120, 30, 340, 420] },
    { "class": "person", "confidence": 0.91, "bbox": [360, 25, 580, 415] },
    { "class": "person", "confidence": 0.88, "bbox": [600, 40, 810, 430] }
  ]
}
```

**Step 2 — Crop the first detection:**

```jsonc
// crop
{
  "input_path": "/photos/team.jpg",
  "x1": 120,
  "y1": 30,
  "x2": 340,
  "y2": 420,
  "output_path": "/photos/person1.jpg"
}
```

**Step 2 output:**

```text
"/photos/person1.jpg"
```

---

## Example 4 — Blur License Plate for Privacy (Tier 2)

**Goal:** Anonymize a license plate in a street photo.

**Tool call:**

```jsonc
// blur
{
  "input_path": "/photos/street-view.jpg",
  "areas": [
    {
      "x1": 450,
      "y1": 380,
      "x2": 620,
      "y2": 420,
      "blur_strength": 45
    }
  ],
  "output_path": "/photos/street-view-redacted.jpg"
}
```

**Expected output:**

```text
"/photos/street-view-redacted.jpg"
```

---

## Example 5 — Overlay Logo Watermark (Tier 2)

**Goal:** Place a semi-transparent PNG logo on the bottom-right of a product photo.

**Step 1 — Get base image dimensions:**

```jsonc
// get_metainfo
{
  "input_path": "/photos/product-shot.jpg"
}
// → { width: 1200, height: 800 }
```

**Step 2 — Overlay logo at bottom-right (logo is 150×50):**

```jsonc
// overlay
{
  "base_image_path": "/photos/product-shot.jpg",
  "overlay_image_path": "/assets/logo-watermark.png",
  "x": 1040,
  "y": 740,
  "output_path": "/photos/product-watermarked.jpg"
}
```

**Expected output:**

```text
"/photos/product-watermarked.jpg"
```

---

## Example 6 — Annotate Screenshot for Documentation (Tier 3)

**Goal:** Add a highlight rectangle, arrow, and label to a UI screenshot.

**Step 1 — Draw rectangle around navigation bar:**

```jsonc
// draw_rectangles
{
  "input_path": "/screenshots/dashboard.png",
  "rectangles": [
    { "x1": 0, "y1": 0, "x2": 1920, "y2": 60, "color": [0, 255, 0], "thickness": 3 }
  ],
  "output_path": "/screenshots/step1.png"
}
```

**Step 2 — Draw arrow pointing to the search button:**

```jsonc
// draw_arrows
{
  "input_path": "/screenshots/step1.png",
  "arrows": [
    { "x1": 1700, "y1": 100, "x2": 1700, "y2": 55, "color": [0, 255, 0], "thickness": 2, "tip_length": 0.2 }
  ],
  "output_path": "/screenshots/step2.png"
}
```

**Step 3 — Add text label:**

```jsonc
// draw_texts
{
  "input_path": "/screenshots/step2.png",
  "texts": [
    { "text": "Click here to search", "x": 1550, "y": 125, "font_scale": 0.7, "color": [0, 255, 0], "thickness": 2 }
  ],
  "output_path": "/screenshots/annotated-dashboard.png"
}
```

**Final output:**

```text
"/screenshots/annotated-dashboard.png"
```

---

## Example 7 — OCR Text Extraction from Receipt (Tier 4)

**Goal:** Extract all text from a scanned receipt image.

**Tool call:**

```jsonc
// ocr
{
  "input_path": "/scans/receipt-2024.png",
  "language": "en"
}
```

**Expected output:**

```jsonc
{
  "input_path": "/scans/receipt-2024.png",
  "segments": [
    { "text": "ACME STORE", "confidence": 0.97, "bbox": [[45,12], [280,12], [280,45], [45,45]] },
    { "text": "Item: Widget x2", "confidence": 0.93, "bbox": [[45,60], [300,60], [300,85], [45,85]] },
    { "text": "$19.98", "confidence": 0.91, "bbox": [[320,60], [400,60], [400,85], [320,85]] },
    { "text": "Total: $21.47", "confidence": 0.95, "bbox": [[45,120], [250,120], [250,150], [45,150]] }
  ]
}
```

---

## Example 8 — Find Object by Description and Remove Background (Tier 4)

**Goal:** Locate a product in a photo by description and make the background
transparent.

**Step 1 — Find the product:**

```jsonc
// find
{
  "input_path": "/photos/product-on-table.jpg",
  "description": "water bottle",
  "return_geometry": true,
  "geometry_format": "mask",
  "confidence": 0.4
}
```

**Step 1 output:**

```jsonc
{
  "input_path": "/photos/product-on-table.jpg",
  "objects": [
    {
      "confidence": 0.82,
      "bbox": [200, 50, 500, 600],
      "mask_path": "/photos/product-on-table_find_mask_0.png"
    }
  ]
}
```

**Step 2 — Remove background using the mask:**

```jsonc
// fill
{
  "input_path": "/photos/product-on-table.jpg",
  "areas": [
    { "mask_path": "/photos/product-on-table_find_mask_0.png", "color": null }
  ],
  "invert_areas": true,
  "output_path": "/photos/bottle-transparent.png"
}
```

**Step 2 output:**

```text
"/photos/bottle-transparent.png"
```

The output is a PNG with transparent background, keeping only the water bottle.

---

## Edge Cases

### Large Images (> 4000px)

Resize before detection to improve performance:

```jsonc
// Step 1: Downscale
{ "input_path": "/photos/8k-panorama.jpg", "scale_factor": 0.25, "output_path": "/tmp/preview.jpg" }

// Step 2: Detect on smaller image
{ "input_path": "/tmp/preview.jpg", "confidence": 0.4 }

// Step 3: Scale bounding boxes back (multiply coordinates by 4)
// Step 4: Crop from original full-resolution image
```

### Transparent PNGs

When processing transparent PNGs, always output to `.png` — JPEG drops the
alpha channel:

```jsonc
// ✓ Correct — preserves transparency
{ "input_path": "/assets/icon.png", "width": 64, "output_path": "/assets/icon-small.png" }

// ✗ Wrong — transparency lost
{ "input_path": "/assets/icon.png", "width": 64, "output_path": "/assets/icon-small.jpg" }
```

### Batch Processing Pattern

Process multiple images by repeating tool calls with different paths. Use
consistent `output_path` naming:

```text
For each image in [img1.jpg, img2.jpg, img3.jpg]:
  1. resize(input_path="/photos/{name}", width=800, output_path="/web/{name}")
  2. get_metainfo(input_path="/web/{name}")  // verify
```

There is no built-in batch API — each image requires its own tool call. Group
similar operations for readability.