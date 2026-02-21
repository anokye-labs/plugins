# Image Processing

Use the ImageSorcery MCP tools to resize, crop, detect objects, overlay images, and more.

## Using ImageSorcery MCP Tools

ImageSorcery provides a set of image manipulation tools accessible via the MCP (Model Context Protocol) server. These tools handle common image operations without leaving the Copilot chat.

### Available Tools

| Tool | Operation | Description |
|------|-----------|-------------|
| `resize` | Scale images | Resize by dimensions or scale factor |
| `crop` | Extract regions | Crop to bounding box coordinates |
| `detect` | Find objects | YOLO-based object detection with bounding boxes |
| `find` | Text-based search | Open-vocabulary detection by description |
| `blur` | Blur regions | Blur rectangular or polygonal areas |
| `fill` | Fill areas | Fill regions with color or transparency |
| `overlay` | Composite images | Place one image on top of another |
| `rotate` | Rotate images | Rotate by angle with auto-sizing |
| `draw_*` | Annotate | Draw text, rectangles, circles, lines, arrows |
| `ocr` | Extract text | Optical character recognition |
| `change_color` | Color palette | Apply grayscale or sepia transformations |
| `get_metainfo` | Image metadata | Get dimensions, format, file size |

## Common Workflows

### Resize

Scale an image to specific dimensions or by a factor:

```
Resize ./input/photo.jpg to 800x600
```

```
Resize ./input/photo.jpg by 50%
```

The tool preserves aspect ratio when only width or height is specified.

### Crop

Extract a region using pixel coordinates (x1, y1) → (x2, y2):

```
Crop ./input/photo.jpg from (100, 50) to (500, 400)
```

### Detect and Crop

Detect objects first, then crop to a specific detection:

```
Detect objects in ./input/photo.jpg
```

Returns bounding boxes with class labels and confidence scores. Then:

```
Crop the detected person from the image
```

### Overlay

Composite one image onto another at a specific position:

```
Overlay ./logo.png onto ./input/photo.jpg at position (50, 50)
```

Supports transparency — PNG overlays with alpha channels blend correctly.

### Background Removal

Use `find` to locate the subject, get a segmentation mask, then use `fill` with transparency:

```
Find the main subject in ./input/photo.jpg and remove the background
```

### Batch Resize

Process multiple images with the same operation:

```
Resize all images in ./input/ to 1024x1024
```

## Chaining Operations

Chain multiple operations into a pipeline: generate → process → optimize.

### Example: Generate, Resize, and Add Watermark

```
1. Generate an image of a product on a white background
2. Resize the result to 1200x1200
3. Overlay my watermark logo at the bottom-right corner
```

The extension processes these steps sequentially, passing the output of each step as input to the next.

### Example: Detect, Crop, and Enhance

```
1. Detect the main object in ./input/scene.jpg
2. Crop to the detected object with 20px padding
3. Resize the crop to 512x512
```

### Pipeline Tips

- **Each step produces a new file** — originals are never modified
- **Use descriptive output paths** — e.g., `./output/photo_resized.jpg`
- **Check intermediate results** — verify each step before proceeding
- **ImageSorcery handles format conversion** — input and output formats can differ

## Next Steps

- [Workflows](workflows.md) — advanced multi-step pipelines and parallel processing
- [MCP Tools Reference](../api-reference/mcp-tools.md) — full parameter reference
- [Image Processing Examples](../examples-gallery/image-processing.md) — complete worked examples
