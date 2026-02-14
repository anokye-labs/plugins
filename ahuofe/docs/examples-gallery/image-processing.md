# Image Processing Examples

Common image manipulation patterns using ImageSorcery MCP tools.

---

## Example 1: Batch Resize for Web

**Goal:** Resize a directory of images to multiple sizes for responsive web delivery.

### Script

```powershell
$inputDir = "./input/photos"
$sizes = @(
    @{ name = "thumbnail"; width = 150; height = 150 },
    @{ name = "medium"; width = 800 },
    @{ name = "large"; width = 1920 }
)

$images = Get-ChildItem $inputDir -Include *.jpg, *.png -Recurse

foreach ($image in $images) {
    foreach ($size in $sizes) {
        $outputPath = "./output/$($size.name)/$($image.BaseName)_$($size.name)$($image.Extension)"
        New-Item -ItemType Directory -Path (Split-Path $outputPath) -Force | Out-Null

        # Uses ImageSorcery resize tool
        # Width-only specification preserves aspect ratio
        $params = @{ input_path = $image.FullName; width = $size.width; output_path = $outputPath }
        if ($size.height) { $params.height = $size.height }
    }
}
```

### Result

```
./output/
├── thumbnail/    # 150x150 (cropped square)
├── medium/       # 800px wide (aspect ratio preserved)
└── large/        # 1920px wide (aspect ratio preserved)
```

### Key Takeaway

Specify only `width` to preserve aspect ratio automatically. Use both `width` and `height` when you need exact dimensions (e.g., thumbnails).

---

## Example 2: Detect and Crop Objects

**Goal:** Detect all people in a group photo and crop each person into a separate file.

### Step 1: Detect Objects

```powershell
# Detect all objects in the image
# ImageSorcery detect tool with YOLO model
```

**Using Copilot Chat:**

```
Detect objects in ./input/group-photo.jpg
```

### Step 2: Review Detections

```
Detected objects:
  1. person (confidence: 0.95) — bbox: (120, 50, 380, 600)
  2. person (confidence: 0.93) — bbox: (400, 60, 650, 590)
  3. person (confidence: 0.91) — bbox: (670, 70, 920, 610)
```

### Step 3: Crop Each Detection

```
Crop each detected person from ./input/group-photo.jpg with 20px padding and save to ./output/people/
```

### Result

```
./output/people/
├── person_1.jpg    # First person, cropped with padding
├── person_2.jpg    # Second person
└── person_3.jpg    # Third person
```

### Key Takeaway

Combine `detect` → `crop` for automated subject extraction. Adding padding avoids cropping too tightly.

---

## Example 3: Background Removal and Overlay

**Goal:** Remove the background from a product image and place it on a branded background.

### Step 1: Find the Product

```
Find "coffee mug" in ./input/product-raw.jpg and return the segmentation mask
```

Returns a mask PNG isolating the mug from the background.

### Step 2: Remove Background

```
Fill ./input/product-raw.jpg with transparency everywhere except the detected mug
```

Produces a transparent PNG with only the mug visible.

### Step 3: Create Branded Composite

```
Overlay the transparent product image onto ./assets/brand-background.jpg at position (300, 200)
```

### Step 4: Add Text

```
Draw text "Premium Coffee Mug — $24.99" at position (100, 50) on the composited image with font scale 1.5
```

### Full Pipeline

```powershell
# 1. Find product with segmentation
# Uses ImageSorcery find tool → returns mask_path

# 2. Remove background using mask
# Uses ImageSorcery fill tool with color: null (transparent), invert_areas: true

# 3. Overlay product on branded background
# Uses ImageSorcery overlay tool

# 4. Add price text
# Uses ImageSorcery draw_texts tool
```

### Result

A polished product image on a branded background with pricing text — ready for an e-commerce listing.

### Key Takeaway

Chain `find` → `fill` → `overlay` → `draw_texts` for a complete product photo pipeline. Each tool produces a new file, so you can inspect and adjust at any stage.

---

## Next Steps

- [Advanced Workflows](advanced-workflows.md) — full production pipelines
- [MCP Tools Reference](../api-reference/mcp-tools.md) — complete parameter details
- [Image Processing Guide](../user-guides/image-processing.md) — concepts and best practices
