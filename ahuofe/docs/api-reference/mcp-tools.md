# ImageSorcery MCP Tools Reference

Reference for all image manipulation tools available through the ImageSorcery MCP server.

## Tool Index

| Tool | Category | Description |
|------|----------|-------------|
| [detect](#detect) | Analysis | Object detection with YOLO models |
| [find](#find) | Analysis | Open-vocabulary object detection by text description |
| [ocr](#ocr) | Analysis | Optical character recognition |
| [get_metainfo](#get_metainfo) | Analysis | Image metadata (dimensions, format, size) |
| [resize](#resize) | Transform | Scale images by dimensions or factor |
| [crop](#crop) | Transform | Extract rectangular regions |
| [rotate](#rotate) | Transform | Rotate images by angle |
| [change_color](#change_color) | Transform | Apply color palette (grayscale, sepia) |
| [blur](#blur) | Manipulation | Blur rectangular or polygonal areas |
| [fill](#fill) | Manipulation | Fill areas with color or transparency |
| [overlay](#overlay) | Manipulation | Composite one image onto another |
| [draw_texts](#draw_texts) | Annotation | Draw text on images |
| [draw_rectangles](#draw_rectangles) | Annotation | Draw rectangles on images |
| [draw_circles](#draw_circles) | Annotation | Draw circles on images |
| [draw_lines](#draw_lines) | Annotation | Draw lines on images |
| [draw_arrows](#draw_arrows) | Annotation | Draw arrows on images |

---

## Analysis Tools

### detect

Detect objects in an image using YOLO models. Returns bounding boxes, class labels, and confidence scores. Optionally returns segmentation masks or polygons.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | Yes | — | Full path to the input image |
| `confidence` | float | No | Config default | Detection threshold (0.0–1.0) |
| `model_name` | string | No | Config default | YOLO model name (e.g., `yoloe-11l-seg-pf.pt`) |
| `return_geometry` | bool | No | `false` | Return segmentation masks or polygons |
| `geometry_format` | string | No | `mask` | `mask` (PNG file) or `polygon` (point list) |

**Returns:** `{ input_path, objects: [{ class, confidence, bbox: {x1, y1, x2, y2}, mask_path?, polygon? }] }`

### find

Find objects matching a text description using open-vocabulary detection.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | Yes | — | Full path to the input image |
| `description` | string | Yes | — | Text description of the object to find |
| `confidence` | float | No | Config default | Detection threshold (0.0–1.0) |
| `return_all_matches` | bool | No | `false` | Return all matches or only the best |
| `return_geometry` | bool | No | `false` | Return segmentation geometry |
| `geometry_format` | string | No | `mask` | `mask` or `polygon` |

**Returns:** `{ input_path, objects: [{ confidence, bbox, mask_path?, polygon? }] }`

### ocr

Extract text from images using EasyOCR.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | Yes | — | Full path to the input image |
| `language` | string | No | Config default | Language code (e.g., `en`, `ru`, `fr`) |

**Returns:** `{ input_path, segments: [{ text, confidence, bbox }] }`

### get_metainfo

Get metadata about an image file.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | Yes | — | Full path to the input image |

**Returns:** `{ width, height, format, file_size, color_mode }`

---

## Transform Tools

### resize

Resize an image by specifying dimensions or a scale factor. Preserves aspect ratio when only width or height is given.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | Yes | — | Full path to the input image |
| `width` | int | No | — | Target width in pixels |
| `height` | int | No | — | Target height in pixels |
| `scale_factor` | float | No | — | Scale multiplier (e.g., `0.5`, `2.0`) |
| `interpolation` | string | No | Config default | `nearest`, `linear`, `area`, `cubic`, `lanczos` |
| `output_path` | string | No | Auto | Output file path |

**Returns:** Path to the resized image

### crop

Crop an image to a rectangular region defined by bounding box coordinates.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | Yes | — | Full path to the input image |
| `x1` | int | Yes | — | Left edge x-coordinate |
| `y1` | int | Yes | — | Top edge y-coordinate |
| `x2` | int | Yes | — | Right edge x-coordinate |
| `y2` | int | Yes | — | Bottom edge y-coordinate |
| `output_path` | string | No | Auto | Output file path |

**Returns:** Path to the cropped image

### rotate

Rotate an image by a specified angle. The output is automatically resized to fit the full rotated image.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | Yes | — | Full path to the input image |
| `angle` | float | Yes | — | Rotation angle in degrees (positive = counterclockwise) |
| `output_path` | string | No | Auto | Output file path |

**Returns:** Path to the rotated image

### change_color

Apply a color palette transformation.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | Yes | — | Full path to the input image |
| `palette` | string | Yes | — | `grayscale` or `sepia` |
| `output_path` | string | No | Auto | Output file path |

**Returns:** Path to the transformed image

---

## Manipulation Tools

### blur

Blur specified rectangular or polygonal areas of an image.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | Yes | — | Full path to the input image |
| `areas` | array | Yes | — | List of areas: `{ x1, y1, x2, y2 }` or `{ polygon: [[x,y], ...] }` |
| `invert_areas` | bool | No | `false` | Blur everything *except* the specified areas |
| `output_path` | string | No | Auto | Output file path |

Each area can optionally include `blur_strength` (odd integer, default `15`).

**Returns:** Path to the blurred image

### fill

Fill areas with a color and opacity, or make areas transparent.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | Yes | — | Full path to the input image |
| `areas` | array | Yes | — | List of areas (rectangle, polygon, or mask) |
| `invert_areas` | bool | No | `false` | Fill everything *except* the specified areas |
| `output_path` | string | No | Auto | Output file path |

Each area can include:
- `color`: `[B, G, R]` or `null` (transparent)
- `opacity`: `0.0`–`1.0` (default `0.5`)

**Returns:** Path to the filled image

### overlay

Place one image on top of another with transparency support.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `base_image_path` | string | Yes | — | Full path to the base image |
| `overlay_image_path` | string | Yes | — | Full path to the overlay image |
| `x` | int | Yes | — | X position for the overlay's top-left corner |
| `y` | int | Yes | — | Y position for the overlay's top-left corner |
| `output_path` | string | No | Auto | Output file path |

**Returns:** Path to the composited image

---

## Annotation Tools

### draw_texts

Draw text labels on an image.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | Yes | — | Full path to the input image |
| `texts` | array | Yes | — | List of text items |
| `output_path` | string | No | Auto | Output file path |

Each text item: `{ text, x, y, font_scale?, color?: [B,G,R], thickness?, font_face? }`

**Returns:** Path to the annotated image

### draw_rectangles

Draw rectangles on an image.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | Yes | — | Full path to the input image |
| `rectangles` | array | Yes | — | List of rectangle items |
| `output_path` | string | No | Auto | Output file path |

Each item: `{ x1, y1, x2, y2, color?: [B,G,R], thickness?, filled? }`

**Returns:** Path to the annotated image

### draw_circles

Draw circles on an image.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | Yes | — | Full path to the input image |
| `circles` | array | Yes | — | List of circle items |
| `output_path` | string | No | Auto | Output file path |

Each item: `{ center_x, center_y, radius, color?: [B,G,R], thickness?, filled? }`

**Returns:** Path to the annotated image

### draw_lines

Draw lines on an image.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | Yes | — | Full path to the input image |
| `lines` | array | Yes | — | List of line items |
| `output_path` | string | No | Auto | Output file path |

Each item: `{ x1, y1, x2, y2, color?: [B,G,R], thickness? }`

**Returns:** Path to the annotated image

### draw_arrows

Draw arrows on an image.

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_path` | string | Yes | — | Full path to the input image |
| `arrows` | array | Yes | — | List of arrow items |
| `output_path` | string | No | Auto | Output file path |

Each item: `{ x1, y1, x2, y2, color?: [B,G,R], thickness?, tip_length? }`

**Returns:** Path to the annotated image
