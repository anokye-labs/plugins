# Tier 1 — Universal Operations

> Used in every pipeline. These are the foundational tools for image inspection,
> sizing, and object detection.

---

## detect

Run object detection using YOLO models. Returns class names, confidence scores,
and bounding boxes. Optionally returns segmentation masks or polygons when using
a segmentation model (e.g., `yoloe-11l-seg-pf.pt`).

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | **Yes** | — | Absolute path to the input image |
| `confidence` | float (0.0–1.0) | No | Config default | Minimum confidence threshold for detections |
| `model_name` | string | No | Config default | YOLO model file name (e.g., `yoloe-11l-seg-pf.pt`, `yolov8m.pt`) |
| `return_geometry` | boolean | No | `false` | If `true`, returns segmentation masks or polygons |
| `geometry_format` | `"mask"` \| `"polygon"` | No | `"mask"` | Format for returned geometry data |

### Return Value

```jsonc
{
  "input_path": "/images/photo.jpg",
  "objects": [
    {
      "class": "person",
      "confidence": 0.92,
      "bbox": [120, 50, 380, 400],
      // When return_geometry=true and geometry_format="mask":
      "mask_path": "/images/photo_mask_0.png",
      // When return_geometry=true and geometry_format="polygon":
      "polygon": [[120,50], [380,50], [380,400], [120,400]]
    }
  ]
}
```

### Example Calls

**Basic detection:**

```jsonc
{
  "input_path": "/photos/street.jpg",
  "confidence": 0.5
}
```

**Detection with segmentation masks:**

```jsonc
{
  "input_path": "/photos/street.jpg",
  "confidence": 0.6,
  "model_name": "yoloe-11l-seg-pf.pt",
  "return_geometry": true,
  "geometry_format": "mask"
}
```

**Detection with polygon output:**

```jsonc
{
  "input_path": "/photos/product.png",
  "confidence": 0.4,
  "return_geometry": true,
  "geometry_format": "polygon"
}
```

### Error Cases

| Error | Cause | Fix |
|-------|-------|-----|
| File not found | Path is relative or file does not exist | Use an absolute path; verify with `get_metainfo` |
| Model not found | YOLO model file not downloaded | Download the model to `MODELS_DIR` first |
| No detections returned | Confidence too high or wrong model for the content | Lower `confidence` threshold; try a different model |
| Invalid geometry_format | Value is not `"mask"` or `"polygon"` | Use exactly `"mask"` or `"polygon"` |

---

## get_metainfo

Return metadata about an image file: dimensions, format, color mode, and file
size. Use this to verify images before processing or to confirm output after
a transformation.

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | **Yes** | — | Absolute path to the image file |

### Return Value

```jsonc
{
  "input_path": "/images/photo.jpg",
  "width": 1920,
  "height": 1080,
  "format": "JPEG",
  "file_size": "2.4 MB",
  "color_mode": "RGB"
}
```

### Example Calls

**Inspect a JPEG:**

```jsonc
{
  "input_path": "/photos/landscape.jpg"
}
```

**Verify a resized output:**

```jsonc
{
  "input_path": "/photos/landscape_resized.png"
}
```

### Error Cases

| Error | Cause | Fix |
|-------|-------|-----|
| File not found | Path does not exist or is relative | Use an absolute path |
| Unsupported format | File is not a recognized image format | Use JPEG, PNG, WebP, BMP, or TIFF |
| Permission denied | Insufficient file system permissions | Check file/directory permissions |

---

## resize

Scale an image by specifying target dimensions or a scale factor. When only
`width` or `height` is provided, the other dimension is calculated automatically
to preserve the aspect ratio.

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | **Yes** | — | Absolute path to the input image |
| `width` | integer | No | Auto-calculated | Target width in pixels |
| `height` | integer | No | Auto-calculated | Target height in pixels |
| `scale_factor` | float | No | — | Scale multiplier (e.g., `0.5` = half, `2.0` = double). Overrides `width`/`height` |
| `interpolation` | string | No | Config default | Interpolation method: `"nearest"`, `"linear"`, `"area"`, `"cubic"`, `"lanczos"` |
| `output_path` | string | No | `{input}_resized` | Absolute path for the output file |

### Interpolation Methods

| Method | Best For |
|--------|----------|
| `nearest` | Pixel art, sharp edges, fastest |
| `linear` | General-purpose, balanced quality/speed |
| `area` | Downscaling (shrinking images) |
| `cubic` | Upscaling with smooth gradients |
| `lanczos` | Highest quality upscaling, slowest |

### Return Value

Returns the absolute path to the resized image:

```text
"/photos/landscape_resized.jpg"
```

### Example Calls

**Resize to specific width (auto height):**

```jsonc
{
  "input_path": "/photos/original.jpg",
  "width": 800
}
```

**Resize to exact dimensions:**

```jsonc
{
  "input_path": "/photos/original.jpg",
  "width": 1200,
  "height": 400
}
```

**Scale by factor:**

```jsonc
{
  "input_path": "/photos/original.jpg",
  "scale_factor": 0.5
}
```

**High-quality upscale with Lanczos:**

```jsonc
{
  "input_path": "/photos/small.png",
  "scale_factor": 2.0,
  "interpolation": "lanczos",
  "output_path": "/photos/upscaled.png"
}
```

### Error Cases

| Error | Cause | Fix |
|-------|-------|-----|
| File not found | Input path does not exist | Use an absolute path |
| No dimensions specified | Neither `width`, `height`, nor `scale_factor` provided | Provide at least one sizing parameter |
| Invalid scale_factor | Value is zero or negative | Use a positive number |
| Output directory missing | Parent directory for `output_path` does not exist | Create the directory first |
