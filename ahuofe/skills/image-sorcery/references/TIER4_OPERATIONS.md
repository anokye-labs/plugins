# Tier 4 — Advanced / AI-Assisted Operations

> These operations use machine-learning models for open-vocabulary object
> search and optical character recognition. They require pre-downloaded models
> and benefit from confidence tuning.

---

## find

Open-vocabulary object detection — describe what you want to find in natural
language and the tool locates matching objects. Uses YOLOE models with text
prompts (e.g., `yoloe-11l-seg.pt`).

### Model Requirements

- Requires a YOLOE model that supports text prompts (file name typically
  includes `yoloe` and ends in `.pt`).
- Models must be pre-downloaded to the `MODELS_DIR` directory configured in
  the MCP server environment.
- The default model is set via `config` — override per-call with `model_name`.

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | **Yes** | — | Absolute path to the input image |
| `description` | string | **Yes** | — | Natural-language description of the object to find (e.g., `"red car"`, `"coffee mug"`) |
| `confidence` | float (0.0–1.0) | No | Config default | Minimum confidence threshold |
| `model_name` | string | No | Config default | YOLOE model file supporting text prompts |
| `return_all_matches` | boolean | No | `false` | If `true`, returns all matches; if `false`, only the best match |
| `return_geometry` | boolean | No | `false` | If `true`, returns segmentation mask or polygon |
| `geometry_format` | `"mask"` \| `"polygon"` | No | `"mask"` | Geometry output format |

### Return Value

```jsonc
{
  "input_path": "/images/photo.jpg",
  "objects": [
    {
      "confidence": 0.87,
      "bbox": [150, 80, 420, 350],
      // When return_geometry=true and geometry_format="mask":
      "mask_path": "/images/photo_find_mask_0.png",
      // When return_geometry=true and geometry_format="polygon":
      "polygon": [[150,80], [420,80], [420,350], [150,350]]
    }
  ]
}
```

When `return_all_matches` is `false`, the `objects` array contains at most one
entry — the highest-confidence match.

### Confidence Tuning

| Scenario | Recommended Confidence |
|----------|----------------------|
| Well-defined objects (cars, faces) | 0.5–0.7 |
| Ambiguous descriptions ("something red") | 0.2–0.4 |
| High-precision filtering | 0.7–0.9 |
| Exploratory / "find anything matching" | 0.1–0.3 |

Lower confidence returns more matches but increases false positives. Start at
the default and adjust based on results.

### Example Calls

**Find the best match for a description:**

```jsonc
{
  "input_path": "/photos/kitchen.jpg",
  "description": "coffee mug"
}
```

**Find all people with geometry:**

```jsonc
{
  "input_path": "/photos/crowd.jpg",
  "description": "person",
  "return_all_matches": true,
  "return_geometry": true,
  "geometry_format": "polygon",
  "confidence": 0.3
}
```

**Background removal pattern (find subject → fill invert):**

```jsonc
// Step 1: Find the product
{
  "input_path": "/photos/product.png",
  "description": "product bottle",
  "return_geometry": true,
  "geometry_format": "mask"
}
// Step 2: Use the returned mask_path with fill(invert_areas=true, color=null)
```

### Error Cases

| Error | Cause | Fix |
|-------|-------|-----|
| Model not found | YOLOE model not downloaded or wrong name | Download model; check `MODELS_DIR` |
| Model does not support text prompts | Non-YOLOE model specified | Use a model with `yoloe` in the name |
| No matches found | Object not present or confidence too high | Lower `confidence`; rephrase `description` |
| Empty description | `description` parameter is blank | Provide a meaningful text description |

---

## ocr

Extract text from an image using EasyOCR. Returns detected text segments with
confidence scores and bounding-box coordinates. Supports multiple languages.

### Model Requirements

- EasyOCR downloads language models on first use for each language code.
- The first call for a new language may take longer due to model download.
- English (`en`) is the default and most reliable language.

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | **Yes** | — | Absolute path to the input image |
| `language` | string | No | Config default (`"en"`) | Language code for OCR |

### Multi-Language Support

| Code | Language | Code | Language |
|------|----------|------|----------|
| `en` | English | `ja` | Japanese |
| `fr` | French | `ko` | Korean |
| `de` | German | `zh` | Chinese (Simplified) |
| `es` | Spanish | `ar` | Arabic |
| `pt` | Portuguese | `hi` | Hindi |
| `it` | Italian | `th` | Thai |
| `ru` | Russian | `vi` | Vietnamese |

See the [EasyOCR documentation](https://www.jaided.ai/easyocr/) for the full
list of 80+ supported languages.

### Return Value

```jsonc
{
  "input_path": "/images/document.png",
  "segments": [
    {
      "text": "Invoice #12345",
      "confidence": 0.95,
      "bbox": [[10, 20], [250, 20], [250, 50], [10, 50]]
    },
    {
      "text": "Total: $99.00",
      "confidence": 0.89,
      "bbox": [[10, 80], [200, 80], [200, 110], [10, 110]]
    }
  ]
}
```

Each `bbox` is a list of four `[x, y]` corner points forming a quadrilateral
around the detected text.

### Example Calls

**Extract English text:**

```jsonc
{
  "input_path": "/scans/receipt.png"
}
```

**Extract French text:**

```jsonc
{
  "input_path": "/scans/french_document.jpg",
  "language": "fr"
}
```

**Extract text for PII redaction pipeline:**

```jsonc
// Step 1: OCR to find text locations
{
  "input_path": "/documents/form.png",
  "language": "en"
}
// Step 2: Use returned bbox coordinates with blur() to redact sensitive text
```

### Confidence Tuning

| Text Quality | Expected Confidence |
|--------------|-------------------|
| Printed, high-resolution | 0.85–0.99 |
| Handwritten, clear | 0.50–0.80 |
| Low-resolution / noisy | 0.20–0.60 |
| Stylized / decorative fonts | 0.30–0.70 |

Filter results by confidence to exclude low-quality detections:

```text
segments.filter(s => s.confidence > 0.7)
```

### Error Cases

| Error | Cause | Fix |
|-------|-------|-----|
| Language model download failed | Network issue during first use | Retry; ensure internet connectivity |
| No text detected | Image has no readable text or resolution is too low | Resize image larger before OCR; check image quality |
| Wrong language results | Incorrect `language` code specified | Match the `language` parameter to the document language |
| Slow first run | EasyOCR downloading model weights | Expected on first use per language; subsequent calls are fast |
