# Tier 2 — High-Frequency Operations

> Used in most pipelines. These tools handle spatial extraction, area
> manipulation, color fills, and image compositing.

---

## crop

Extract a rectangular region from an image using bounding-box coordinates.
The region is defined by the top-left corner `(x1, y1)` and the bottom-right
corner `(x2, y2)`.

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | **Yes** | — | Absolute path to the input image |
| `x1` | integer | **Yes** | — | X-coordinate of the top-left corner |
| `y1` | integer | **Yes** | — | Y-coordinate of the top-left corner |
| `x2` | integer | **Yes** | — | X-coordinate of the bottom-right corner |
| `y2` | integer | **Yes** | — | Y-coordinate of the bottom-right corner |
| `output_path` | string | No | `{input}_cropped` | Absolute path for the output file |

### Return Value

Returns the absolute path to the cropped image:

```text
"/photos/group_cropped.jpg"
```

### Example Calls

**Crop a detected face region:**

```jsonc
{
  "input_path": "/photos/group.jpg",
  "x1": 120,
  "y1": 50,
  "x2": 380,
  "y2": 400
}
```

**Crop with explicit output path:**

```jsonc
{
  "input_path": "/screenshots/full.png",
  "x1": 0,
  "y1": 0,
  "x2": 800,
  "y2": 600,
  "output_path": "/screenshots/header.png"
}
```

### Error Cases

| Error | Cause | Fix |
|-------|-------|-----|
| File not found | Input path does not exist | Use an absolute path |
| Coordinates out of bounds | `x2`/`y2` exceed image dimensions | Check dimensions with `get_metainfo` first |
| Invalid region | `x1 >= x2` or `y1 >= y2` | Ensure top-left is before bottom-right |

---

## blur

Blur specified rectangular or polygonal areas of an image. Each area can have
its own blur strength. Use `invert_areas: true` to blur everything **except**
the specified regions (background blur).

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | **Yes** | — | Absolute path to the input image |
| `areas` | array | **Yes** | — | List of areas to blur (see area formats below) |
| `invert_areas` | boolean | No | `false` | If `true`, blurs everything except the specified areas |
| `output_path` | string | No | `{input}_blurred` | Absolute path for the output file |

### Area Formats

**Rectangle:**

```jsonc
{ "x1": 50, "y1": 50, "x2": 200, "y2": 200, "blur_strength": 25 }
```

**Polygon:**

```jsonc
{ "polygon": [[50,50], [200,50], [200,200], [50,200]], "blur_strength": 25 }
```

| Area Field | Type | Required | Default | Description |
|------------|------|----------|---------|-------------|
| `x1`, `y1`, `x2`, `y2` | integer | For rectangles | — | Bounding box coordinates |
| `polygon` | array of `[x,y]` | For polygons | — | List of vertex coordinate pairs |
| `blur_strength` | integer (odd) | No | `15` | Blur kernel size; must be an odd number |

### Return Value

Returns the absolute path to the blurred image:

```text
"/photos/portrait_blurred.jpg"
```

### Example Calls

**Blur a license plate:**

```jsonc
{
  "input_path": "/photos/street.jpg",
  "areas": [
    { "x1": 300, "y1": 400, "x2": 500, "y2": 450, "blur_strength": 35 }
  ]
}
```

**Background blur (keep subject sharp):**

```jsonc
{
  "input_path": "/photos/portrait.jpg",
  "areas": [
    { "x1": 200, "y1": 100, "x2": 600, "y2": 700 }
  ],
  "invert_areas": true
}
```

**Blur multiple polygonal areas:**

```jsonc
{
  "input_path": "/photos/document.png",
  "areas": [
    { "polygon": [[10,10], [150,10], [150,40], [10,40]], "blur_strength": 25 },
    { "polygon": [[10,60], [200,60], [200,90], [10,90]], "blur_strength": 25 }
  ]
}
```

### Error Cases

| Error | Cause | Fix |
|-------|-------|-----|
| Blur strength must be odd | Even number provided for `blur_strength` | Use odd values: 15, 25, 35, etc. |
| Empty areas array | No areas specified | Provide at least one area object |
| Invalid polygon | Fewer than 3 vertices | Supply at least 3 coordinate pairs |

---

## fill

Fill areas with a solid color and opacity. Supports rectangles, polygons, and
mask files. Set `color: null` to make areas fully transparent (delete pixels).
Use `invert_areas: true` to fill everything **except** the specified regions.

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | **Yes** | — | Absolute path to the input image |
| `areas` | array | **Yes** | — | List of areas to fill (see area formats below) |
| `invert_areas` | boolean | No | `false` | If `true`, fills everything except the specified areas |
| `output_path` | string | No | `{input}_filled` | Absolute path for the output file |

### Area Formats

**Rectangle:**

```jsonc
{ "x1": 0, "y1": 0, "x2": 100, "y2": 100, "color": [255, 0, 0], "opacity": 0.5 }
```

**Polygon:**

```jsonc
{ "polygon": [[0,0], [100,0], [100,100], [0,100]], "color": [0, 255, 0], "opacity": 0.7 }
```

**Mask from file:**

```jsonc
{ "mask_path": "/masks/object_mask.png", "color": null, "opacity": 1.0 }
```

| Area Field | Type | Required | Default | Description |
|------------|------|----------|---------|-------------|
| `x1`, `y1`, `x2`, `y2` | integer | For rectangles | — | Bounding box coordinates |
| `polygon` | array of `[x,y]` | For polygons | — | List of vertex coordinate pairs |
| `mask_path` | string | For masks | — | Path to a PNG mask file |
| `color` | `[B, G, R]` \| `null` | No | `[0, 0, 0]` (black) | BGR color; `null` = transparent deletion |
| `opacity` | float (0.0–1.0) | No | `0.5` | Fill transparency; ignored when `color` is `null` |

### Return Value

Returns the absolute path to the filled image:

```text
"/photos/redacted_filled.png"
```

### Example Calls

**Semi-transparent red overlay:**

```jsonc
{
  "input_path": "/photos/map.png",
  "areas": [
    { "polygon": [[100,100], [300,100], [300,300], [100,300]], "color": [0, 0, 255], "opacity": 0.4 }
  ]
}
```

**Remove background (transparent deletion):**

```jsonc
{
  "input_path": "/photos/product.png",
  "areas": [
    { "polygon": [[50,50], [450,50], [450,450], [50,450]], "color": null }
  ],
  "invert_areas": true,
  "output_path": "/photos/product_transparent.png"
}
```

**Fill using a segmentation mask:**

```jsonc
{
  "input_path": "/photos/scene.jpg",
  "areas": [
    { "mask_path": "/masks/sky_mask.png", "color": [255, 200, 150], "opacity": 0.6 }
  ]
}
```

### Error Cases

| Error | Cause | Fix |
|-------|-------|-----|
| Transparent output saved as JPEG | JPEG does not support alpha channel | Use `.png` for the output path |
| Mask dimensions mismatch | Mask size differs from input image | Ensure mask matches input dimensions |
| Empty areas array | No areas specified | Provide at least one area object |

---

## overlay

Place one image on top of another at a specified position. Handles alpha-channel
transparency automatically — PNG overlays with transparent regions blend
correctly with the base image.

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `base_image_path` | string | **Yes** | — | Absolute path to the base (background) image |
| `overlay_image_path` | string | **Yes** | — | Absolute path to the overlay (foreground) image |
| `x` | integer | **Yes** | — | X-coordinate of the top-left corner for overlay placement |
| `y` | integer | **Yes** | — | Y-coordinate of the top-left corner for overlay placement |
| `output_path` | string | No | `{base}_overlaid` | Absolute path for the output file |

### Return Value

Returns the absolute path to the composited image:

```text
"/photos/background_overlaid.jpg"
```

### Example Calls

**Add a logo watermark:**

```jsonc
{
  "base_image_path": "/photos/product.jpg",
  "overlay_image_path": "/assets/logo.png",
  "x": 10,
  "y": 10
}
```

**Composite with explicit output:**

```jsonc
{
  "base_image_path": "/photos/background.jpg",
  "overlay_image_path": "/photos/foreground.png",
  "x": 200,
  "y": 150,
  "output_path": "/photos/composite.png"
}
```

### Error Cases

| Error | Cause | Fix |
|-------|-------|-----|
| File not found | Base or overlay path does not exist | Verify both paths exist |
| Overlay extends beyond base | Overlay placed at coordinates that exceed base dimensions | Overlay is automatically cropped to fit; no error, but result may be clipped |
| No transparency visible | Overlay image has no alpha channel | Use a PNG with transparency for the overlay |
