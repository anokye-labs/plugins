# Common Multi-Step Workflows

> These workflows chain multiple ImageSorcery operations (and optionally fal-ai
> generation) into end-to-end pipelines. Each section describes the step
> sequence, inputs/outputs at each stage, and error recovery strategies.

---

## 1. Generate → Detect → Crop (Product Extraction)

Extract a product from a generated or photographed image by detecting it and
cropping to its bounding box.

### Steps

| # | Tool | Input | Output | Notes |
|---|------|-------|--------|-------|
| 1 | `fal-ai` (or existing image) | Text prompt | `/gen/product_raw.png` | Skip if starting from an existing photo |
| 2 | `get_metainfo` | `/gen/product_raw.png` | Metadata dict | Verify dimensions and format |
| 3 | `detect` | `/gen/product_raw.png`, confidence=0.5 | Objects array with bounding boxes | Use class filter if needed |
| 4 | `crop` | `/gen/product_raw.png`, bbox from step 3 | `/gen/product_cropped.png` | Use the first detection's bbox |

### Data Flow

```text
[Text Prompt] → fal-ai → raw image
                            ↓
                      get_metainfo → verify OK
                            ↓
                        detect → [{ class: "bottle", bbox: [x1,y1,x2,y2] }]
                            ↓
                         crop(x1,y1,x2,y2) → cropped product image
```

### Error Recovery

| Failure Point | Symptom | Recovery |
|---------------|---------|----------|
| Step 2 | Unexpected format/dimensions | Resize or re-generate with different parameters |
| Step 3 | No detections | Lower confidence; try `find` with a text description instead |
| Step 3 | Multiple detections | Filter by class name or pick the highest confidence |
| Step 4 | Crop coordinates out of bounds | Clamp coordinates to image dimensions via `get_metainfo` |

---

## 2. Generate → Resize → Overlay (Social Media Kit)

Create a social media image set by generating a base image, resizing to
platform dimensions, and compositing a logo/watermark.

### Steps

| # | Tool | Input | Output | Notes |
|---|------|-------|--------|-------|
| 1 | `fal-ai` | Text prompt | `/gen/base.png` | Generate the hero image |
| 2 | `resize` | `/gen/base.png`, width=1200, height=630 | `/gen/base_og.png` | Open Graph / Facebook size |
| 3 | `resize` | `/gen/base.png`, width=1080, height=1080 | `/gen/base_square.png` | Instagram square |
| 4 | `resize` | `/gen/base.png`, width=1500, height=500 | `/gen/base_twitter.png` | Twitter/X header |
| 5 | `overlay` | Each resized image + logo | `/final/og.png`, etc. | Position logo at bottom-right corner |

### Data Flow

```text
[Text Prompt] → fal-ai → base image
                            ↓
               ┌────────────┼────────────┐
               ↓            ↓            ↓
          resize 1200×630  resize 1080²  resize 1500×500
               ↓            ↓            ↓
          overlay logo   overlay logo  overlay logo
               ↓            ↓            ↓
           og.png      square.png    twitter.png
```

### Error Recovery

| Failure Point | Symptom | Recovery |
|---------------|---------|----------|
| Step 1 | Generation fails | Retry with a simplified prompt |
| Step 2–4 | Aspect ratio distortion | Use only `width` or `height` (not both) to preserve ratio, then crop |
| Step 5 | Logo invisible | Check logo file path; verify logo has transparency (PNG) |
| Step 5 | Logo too large/small | Resize the logo first to an appropriate size |

---

## 3. OCR → Find → Blur (PII Redaction)

Detect text in a document image, locate sensitive fields, and blur them for
privacy compliance.

### Steps

| # | Tool | Input | Output | Notes |
|---|------|-------|--------|-------|
| 1 | `ocr` | `/docs/form.png` | Text segments with bounding boxes | Extract all text |
| 2 | Filter | OCR segments | Sensitive field coordinates | Client-side: match patterns (SSN, email, phone) |
| 3 | `blur` | `/docs/form.png`, areas from step 2 | `/docs/form_redacted.png` | Use high blur_strength (35+) |

### Data Flow

```text
[Document Image] → ocr → segments: [{ text: "SSN: 123-45-6789", bbox: [...] }, ...]
                            ↓
                     filter sensitive fields (regex matching)
                            ↓
                  blur(areas=[{ x1, y1, x2, y2, blur_strength: 45 }])
                            ↓
                     redacted document image
```

### Converting OCR Bounding Boxes to Blur Areas

OCR returns quadrilateral bounding boxes as `[[x1,y1], [x2,y2], [x3,y3], [x4,y4]]`.
Convert to rectangle format for `blur`:

```text
OCR bbox: [[10, 80], [200, 80], [200, 110], [10, 110]]
  → blur area: { "x1": 10, "y1": 80, "x2": 200, "y2": 110, "blur_strength": 45 }
```

### Error Recovery

| Failure Point | Symptom | Recovery |
|---------------|---------|----------|
| Step 1 | No text detected | Image may be too low-res — resize larger first, then re-run OCR |
| Step 1 | Wrong language | Set `language` parameter to match the document |
| Step 2 | False positives | Tighten regex patterns; filter by OCR confidence > 0.7 |
| Step 3 | Blur too weak | Increase `blur_strength` to 45 or higher |

---

## 4. Detect → Draw Annotations → Export (Documentation Screenshots)

Annotate a screenshot with bounding boxes, arrows, and labels for use in
technical documentation.

### Steps

| # | Tool | Input | Output | Notes |
|---|------|-------|--------|-------|
| 1 | `get_metainfo` | `/screenshots/app.png` | Metadata | Confirm dimensions for positioning |
| 2 | `detect` | `/screenshots/app.png` | UI elements with bounding boxes | Optional: auto-detect buttons, text fields |
| 3 | `draw_rectangles` | Step 2 output | `/screenshots/app_rects.png` | Highlight regions of interest |
| 4 | `draw_arrows` | Step 3 output | `/screenshots/app_arrows.png` | Point to annotated regions |
| 5 | `draw_texts` | Step 4 output | `/screenshots/app_final.png` | Add descriptive labels |

### Data Flow

```text
[Screenshot] → get_metainfo → { width: 1920, height: 1080 }
                    ↓
               detect → [{ class: "button", bbox: [100,200,300,250] }]
                    ↓
          draw_rectangles(rects from detections)
                    ↓
          draw_arrows(callout arrows)
                    ↓
          draw_texts(labels)
                    ↓
            annotated screenshot
```

### Chaining Output Paths

Each draw tool returns a new file path. Feed it into the next tool:

```text
Step 3 output: "/screenshots/app_with_rectangles.png"
  → Step 4 input_path: "/screenshots/app_with_rectangles.png"

Step 4 output: "/screenshots/app_with_rectangles_with_arrows.png"
  → Step 5 input_path: "/screenshots/app_with_rectangles_with_arrows.png"
```

**Tip:** Use explicit `output_path` values to keep file names clean:

```text
Step 3: output_path="/screenshots/step1_rects.png"
Step 4: input_path="/screenshots/step1_rects.png", output_path="/screenshots/step2_arrows.png"
Step 5: input_path="/screenshots/step2_arrows.png", output_path="/screenshots/final.png"
```

### Error Recovery

| Failure Point | Symptom | Recovery |
|---------------|---------|----------|
| Step 2 | No UI elements detected | Skip auto-detection; manually specify rectangle coordinates |
| Step 3 | Rectangles invisible on dark backgrounds | Use bright contrasting colors (e.g., `[0, 255, 255]` yellow) |
| Step 4 | Arrows point wrong direction | Swap `(x1,y1)` and `(x2,y2)` — arrow points toward `(x2,y2)` |
| Step 5 | Text overlaps other annotations | Adjust `x`, `y` positions; reduce `font_scale` |

---

## General Workflow Tips

1. **Always start with `get_metainfo`** to verify image dimensions and format
   before processing.
2. **Chain outputs → inputs** by passing the returned file path from one tool
   as `input_path` to the next.
3. **Use explicit `output_path`** values to avoid accumulating suffixes
   (`_resized_cropped_blurred`).
4. **Resize before detection** for large images — smaller images process faster
   with minimal accuracy loss.
5. **Save transparency as PNG** — JPEG does not support alpha channels.
