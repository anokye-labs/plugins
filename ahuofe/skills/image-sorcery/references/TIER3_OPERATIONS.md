# Tier 3 — Specialized Operations

> Annotation, rotation, and color transformation tools. Use these for
> documentation screenshots, visual labeling, and presentation-ready outputs.

---

## Coordinate System & Color Format

All drawing tools use the same conventions:

- **Coordinates** — pixel-based, origin `(0, 0)` at the top-left corner of the
  image. X increases rightward, Y increases downward.
- **Color format** — BGR (Blue, Green, Red) as a 3-element integer array.

| Desired Color | BGR Value |
|---------------|-----------|
| Red | `[0, 0, 255]` |
| Green | `[0, 255, 0]` |
| Blue | `[255, 0, 0]` |
| White | `[255, 255, 255]` |
| Black | `[0, 0, 0]` |
| Yellow | `[0, 255, 255]` |
| Cyan | `[255, 255, 0]` |
| Magenta | `[255, 0, 255]` |

---

## draw_rectangles

Draw one or more rectangles on an image.

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | **Yes** | — | Absolute path to the input image |
| `rectangles` | array | **Yes** | — | List of rectangle objects |
| `output_path` | string | No | `{input}_with_rectangles` | Absolute path for output |

**Rectangle object:**

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `x1` | integer | **Yes** | — | Top-left X |
| `y1` | integer | **Yes** | — | Top-left Y |
| `x2` | integer | **Yes** | — | Bottom-right X |
| `y2` | integer | **Yes** | — | Bottom-right Y |
| `color` | `[B, G, R]` | No | — | Line/fill color |
| `thickness` | integer | No | — | Line thickness in pixels |
| `filled` | boolean | No | — | Fill the rectangle with `color` |

### Example

```jsonc
{
  "input_path": "/screenshots/ui.png",
  "rectangles": [
    { "x1": 10, "y1": 50, "x2": 300, "y2": 120, "color": [0, 255, 0], "thickness": 2 },
    { "x1": 320, "y1": 50, "x2": 600, "y2": 120, "color": [0, 0, 255], "filled": true }
  ]
}
```

---

## draw_circles

Draw one or more circles on an image by center point and radius.

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | **Yes** | — | Absolute path to the input image |
| `circles` | array | **Yes** | — | List of circle objects |
| `output_path` | string | No | `{input}_with_circles` | Absolute path for output |

**Circle object:**

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `center_x` | integer | **Yes** | — | Center X coordinate |
| `center_y` | integer | **Yes** | — | Center Y coordinate |
| `radius` | integer | **Yes** | — | Circle radius in pixels |
| `color` | `[B, G, R]` | No | — | Line/fill color |
| `thickness` | integer | No | — | Line thickness in pixels |
| `filled` | boolean | No | — | Fill the circle with `color` |

### Example

```jsonc
{
  "input_path": "/photos/aerial.jpg",
  "circles": [
    { "center_x": 400, "center_y": 300, "radius": 50, "color": [0, 0, 255], "thickness": 3 },
    { "center_x": 600, "center_y": 200, "radius": 30, "color": [0, 255, 0], "filled": true }
  ]
}
```

---

## draw_lines

Draw straight lines between two points.

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | **Yes** | — | Absolute path to the input image |
| `lines` | array | **Yes** | — | List of line objects |
| `output_path` | string | No | `{input}_with_lines` | Absolute path for output |

**Line object:**

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `x1` | integer | **Yes** | — | Start X |
| `y1` | integer | **Yes** | — | Start Y |
| `x2` | integer | **Yes** | — | End X |
| `y2` | integer | **Yes** | — | End Y |
| `color` | `[B, G, R]` | No | — | Line color |
| `thickness` | integer | No | — | Line thickness in pixels |

### Example

```jsonc
{
  "input_path": "/photos/diagram.png",
  "lines": [
    { "x1": 0, "y1": 0, "x2": 300, "y2": 300, "color": [255, 255, 0], "thickness": 3 },
    { "x1": 300, "y1": 0, "x2": 0, "y2": 300, "color": [0, 255, 255], "thickness": 2 }
  ]
}
```

---

## draw_arrows

Draw arrows with customizable tip length. The tip length is relative to the
arrow's total length (e.g., `0.1` = 10% of arrow length).

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | **Yes** | — | Absolute path to the input image |
| `arrows` | array | **Yes** | — | List of arrow objects |
| `output_path` | string | No | `{input}_with_arrows` | Absolute path for output |

**Arrow object:**

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `x1` | integer | **Yes** | — | Start X (tail) |
| `y1` | integer | **Yes** | — | Start Y (tail) |
| `x2` | integer | **Yes** | — | End X (tip) |
| `y2` | integer | **Yes** | — | End Y (tip) |
| `color` | `[B, G, R]` | No | — | Arrow color |
| `thickness` | integer | No | — | Arrow line thickness |
| `tip_length` | float | No | — | Tip size relative to arrow length |

### Example

```jsonc
{
  "input_path": "/screenshots/app.png",
  "arrows": [
    { "x1": 150, "y1": 130, "x2": 150, "y2": 200, "color": [0, 255, 0], "tip_length": 0.15 },
    { "x1": 50, "y1": 50, "x2": 200, "y2": 80, "color": [0, 0, 255], "thickness": 2 }
  ]
}
```

---

## draw_texts

Add text labels to an image with configurable font, size, and color.

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | **Yes** | — | Absolute path to the input image |
| `texts` | array | **Yes** | — | List of text objects |
| `output_path` | string | No | `{input}_with_text` | Absolute path for output |

**Text object:**

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `text` | string | **Yes** | — | Text content to render |
| `x` | integer | **Yes** | — | X position (bottom-left of text baseline) |
| `y` | integer | **Yes** | — | Y position (bottom-left of text baseline) |
| `font_scale` | float | No | — | Font size multiplier |
| `color` | `[B, G, R]` | No | — | Text color |
| `thickness` | integer | No | — | Text stroke thickness |
| `font_face` | string | No | `FONT_HERSHEY_SIMPLEX` | OpenCV font face |

**Available font faces:**

| Font Face | Style |
|-----------|-------|
| `FONT_HERSHEY_SIMPLEX` | Sans-serif, normal size |
| `FONT_HERSHEY_PLAIN` | Sans-serif, small |
| `FONT_HERSHEY_DUPLEX` | Sans-serif, double-weight |
| `FONT_HERSHEY_COMPLEX` | Serif, normal size |
| `FONT_HERSHEY_TRIPLEX` | Serif, triple-weight |
| `FONT_HERSHEY_COMPLEX_SMALL` | Serif, small |
| `FONT_HERSHEY_SCRIPT_SIMPLEX` | Script/handwriting |
| `FONT_HERSHEY_SCRIPT_COMPLEX` | Script/handwriting, heavier |

### Example

```jsonc
{
  "input_path": "/screenshots/ui.png",
  "texts": [
    { "text": "Navigation Bar", "x": 10, "y": 45, "font_scale": 0.8, "color": [0, 255, 0], "thickness": 2 },
    { "text": "Footer", "x": 10, "y": 580, "font_scale": 0.6, "color": [255, 255, 255] }
  ]
}
```

---

## rotate

Rotate an image by a given angle in degrees. Positive values rotate
counter-clockwise. The output canvas auto-expands so the entire rotated image
is visible (uses `imutils.rotate_bound`).

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | **Yes** | — | Absolute path to the input image |
| `angle` | float | **Yes** | — | Rotation angle in degrees (positive = counter-clockwise) |
| `output_path` | string | No | `{input}_rotated` | Absolute path for output |

### Return Value

Returns the absolute path to the rotated image:

```text
"/photos/landscape_rotated.jpg"
```

### Example

```jsonc
{
  "input_path": "/photos/tilted.jpg",
  "angle": 90
}
```

```jsonc
{
  "input_path": "/scans/receipt.png",
  "angle": -5.2,
  "output_path": "/scans/receipt_straightened.png"
}
```

### Error Cases

| Error | Cause | Fix |
|-------|-------|-----|
| File not found | Input path does not exist | Use an absolute path |
| Canvas expansion | Rotated image is larger than original | Expected behavior — canvas auto-expands |

---

## change_color

Apply a color palette transformation to an image.

### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | **Yes** | — | Absolute path to the input image |
| `palette` | `"grayscale"` \| `"sepia"` | **Yes** | — | Color palette to apply |
| `output_path` | string | No | `{input}_{palette}` | Absolute path for output |

### Palette Options

| Palette | Effect |
|---------|--------|
| `grayscale` | Convert to black-and-white (single channel rendered as RGB) |
| `sepia` | Warm brown-tone vintage effect |

### Return Value

Returns the absolute path to the transformed image:

```text
"/photos/portrait_grayscale.jpg"
```

### Example

```jsonc
{
  "input_path": "/photos/portrait.jpg",
  "palette": "grayscale"
}
```

```jsonc
{
  "input_path": "/photos/landscape.jpg",
  "palette": "sepia",
  "output_path": "/photos/landscape_vintage.jpg"
}
```

### Error Cases

| Error | Cause | Fix |
|-------|-------|-----|
| Invalid palette | Value is not `"grayscale"` or `"sepia"` | Use exactly one of the supported values |
