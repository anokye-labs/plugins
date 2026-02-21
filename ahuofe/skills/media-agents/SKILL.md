---
name: media-agents
description: >
  Use when the user requests complex media tasks requiring multiple steps,
  parallel generation, or coordinated image/video processing. Triggers on
  phrases like "create product images", "generate and resize", "batch process
  media", "build image variants", "create hero image", or any multi-step
  media workflow. Orchestrates fleet-pattern agents for generation,
  processing, validation, and optimization.
---

# Media Agents — Agentic Workflow Patterns

Orchestrate multi-step media tasks using fleet patterns, checkpoints,
and multi-tool chains. Prioritize tool calls over explanations.

---

## 1. Fleet Pattern

Dispatch specialized agents in parallel. Each agent owns one concern.

### Agent Roles

| Role | Responsibility | Tools |
|------|---------------|-------|
| **generator** | Create base media via fal.ai models | `fal-ai` skill |
| **processor** | Transform media (resize, crop, convert, enhance) | ImageSorcery MCP |
| **validator** | Check quality, dimensions, format compliance | ImageSorcery `detect`, `get_metainfo`, `ocr` |
| **optimizer** | Compress, convert formats, strip metadata | ImageSorcery `resize`, sharp pipelines |

### Parallel Dispatch

When a task decomposes into independent operations, dispatch agents simultaneously:

```
User: "Create 3 social media variants of this product photo"

Fleet dispatch:
  ├─ generator-1 → 1200×628 Facebook variant
  ├─ generator-2 → 1080×1080 Instagram variant
  └─ generator-3 → 1200×675 Twitter variant

All run in parallel. Aggregate results when all complete.
```

Rules for parallel dispatch:
1. Identify independent subtasks that share no dependencies
2. Assign each subtask to the appropriate agent role
3. Set a timeout per agent (default: 60s for generation, 30s for processing)
4. Collect results; if any agent fails, report partial success

### Result Aggregation

After all agents complete:
1. Collect outputs into a summary table (path, dimensions, format, size)
2. Run validator agent across all outputs
3. Report failures separately from successes
4. Present results as a single structured response

---

## 2. Multi-Step Reasoning

Follow this chain for every complex media request:

```
Analyze Input → Plan Pipeline → Execute Steps → Validate Output
```

### Step 1: Analyze Input

Determine what the user has and what they need:
- Input type: existing image path, text prompt, URL, or nothing
- Desired output: format, dimensions, quality, count
- Constraints: file size limits, aspect ratios, brand guidelines

### Step 2: Plan Pipeline

Build an ordered list of operations before executing anything:

```
Pipeline for "Create a product hero image":
  1. generate  → fal-ai flux-pro, 1920×1080, product photography style
  2. enhance   → sharpen, color-correct, remove artifacts
  3. resize    → create 3 variants: hero (1920×1080), thumb (400×300), og (1200×630)
  4. validate  → check dimensions, file size <2MB, format is WebP
```

Present the plan to the user. Execute only after confirmation (or if
the task is clearly unambiguous).

### Step 3: Execute Steps

Execute sequentially when steps depend on prior output.
Execute in parallel when steps are independent.

For each step:
1. Call the tool directly — no preamble
2. Capture the output path or result
3. Pass output as input to the next step
4. Checkpoint after each step (see §3)

### Step 4: Validate Output

After the final step:
- Verify dimensions match the request
- Verify format matches the request
- Check file size is within acceptable bounds
- Run quality detection if applicable
- Report results in a summary table

---

## 3. Checkpoint Pattern

Save intermediate results so partial failures don't restart the entire workflow.

### When to Checkpoint

| After This Step | Save What |
|----------------|-----------|
| Generation | Base image path, model used, prompt, seed |
| Enhancement | Enhanced image path, operations applied |
| Resize/Convert | Each variant path, dimensions, format |
| Validation | Quality scores, pass/fail per variant |

### Checkpoint Storage

Write checkpoints to the output directory:

```
output/
├── .checkpoint.json        ← workflow state
├── base_hero.png           ← generation output
├── base_hero_enhanced.png  ← enhancement output
├── hero_1920x1080.webp     ← final variant
├── thumb_400x300.webp      ← final variant
└── og_1200x630.webp        ← final variant
```

Checkpoint JSON structure:

```json
{
  "workflow_id": "hero-image-20260206-1842",
  "status": "in_progress",
  "current_step": 3,
  "steps": [
    {"name": "generate", "status": "done", "output": "base_hero.png"},
    {"name": "enhance", "status": "done", "output": "base_hero_enhanced.png"},
    {"name": "resize", "status": "in_progress", "completed": ["hero_1920x1080.webp"]},
    {"name": "validate", "status": "pending"}
  ]
}
```

### Resume on Failure

If a step fails:
1. Read `.checkpoint.json` from output directory
2. Skip completed steps
3. Resume from the last incomplete step
4. Use saved outputs as inputs

### Validation Checks

Run after each checkpoint:

| Check | Method | Threshold |
|-------|--------|-----------|
| Dimensions | `get_metainfo` → width, height | Must match request ±1px |
| Format | `get_metainfo` → format | Must match requested format |
| File size | File system check | Must be under specified limit |
| Quality | `detect` for artifacts | Confidence > 0.8 for expected content |
| Content | `ocr` if text expected | Text must be legible and correct |

---

## 4. Actions-First Design

Minimize chat. Maximize tool calls.

### Do This

```
User: "Resize this image to 800×600"

→ Call ImageSorcery resize with width=800, height=600
→ Return: "Resized to 800×600. Saved to output/image_resized.png (42KB)"
```

### Not This

```
User: "Resize this image to 800×600"

→ "I'd be happy to help resize your image! There are several approaches
   we could take. The most common method is bilinear interpolation..."
```

### Batching Rules

When multiple related operations are needed:
1. Group independent operations into parallel calls
2. Chain dependent operations sequentially
3. Report all results in a single summary
4. Never ask for confirmation on read-only operations

### Response Format

After executing tool calls, respond with a brief summary:

```
✅ Generated hero image (1920×1080, 245KB)
✅ Created 3 variants: hero, thumbnail, og-image
✅ All variants validated — WebP format, under 2MB

Output directory: output/hero-image/
```

---

## 5. Read-Only by Default

Never modify user files without explicit confirmation.

### Output Rules

1. **Always write to `output/` or a temp directory** — never overwrite source files
2. **Show the output path** in every response
3. **Ask before overwriting** if an output file already exists
4. **Never delete** user files under any circumstance

### Confirmation Required For

- Overwriting existing output files
- Writing to directories outside `output/`
- Any batch operation touching >10 files
- Format conversions that are lossy (e.g., PNG → JPEG)

### No Confirmation Needed For

- Reading/analyzing any file
- Writing new files to `output/`
- Generating new media to `output/`
- Running validation checks

---

## 6. Error Handling

### API Failures (Transient)

Retry with exponential backoff:

```
Attempt 1: immediate
Attempt 2: wait 1s  (±25% jitter)
Attempt 3: wait 2s  (±25% jitter)
Attempt 4: wait 4s  (±25% jitter)
Attempt 5: fail — report error to user
```

If all retries exhausted:
- Report what failed and why
- Suggest the user try again or use a different model
- Preserve any completed checkpoints

### Quality Failures

When generated output doesn't meet quality thresholds:

1. Regenerate with adjusted parameters (higher quality, different seed)
2. Maximum 2 regeneration attempts
3. If still failing, present the best result with a quality warning
4. Let the user decide whether to accept or retry manually

### Partial Failures

When some operations succeed and others fail:

```
✅ Generated base image (1920×1080)
✅ Created hero variant (1920×1080, WebP)
❌ Thumbnail resize failed: out of memory
✅ OG image variant (1200×630, WebP)

2 of 3 variants created. Retry thumbnail? [yes/no]
```

Rules:
- Never discard successful results because one step failed
- Report each step's status individually
- Offer to retry only the failed steps
- Checkpoint ensures no rework on success

### Permanent Failures

For non-retryable errors (401, 400, unsupported format):
- Report the error immediately — do not retry
- Suggest corrective action (check API key, fix input format)
- Preserve all completed work

---

## 7. Available Agent Types

### media-generator

Generates images and video from text prompts or image inputs.

**Tools:** `fal-ai` skill  
**Capabilities:**
- Text-to-image (flux-pro, flux-dev, stable-diffusion)
- Image-to-image (style transfer, variation)
- Image-to-video (runway, kling)
- Text-to-video (minimax)

**Parameters to always specify:**
- Model selection based on quality/speed requirement
- Output dimensions
- Seed for reproducibility

### image-processor

Transforms existing images through manipulation operations.

**Tools:** ImageSorcery MCP  
**Capabilities:**
- Resize, crop, rotate
- Color adjustments (grayscale, sepia)
- Drawing (text, shapes, arrows)
- Blur, fill, overlay
- Format conversion

### video-processor

Handles video-specific operations.

**Tools:** ImageSorcery MCP (frame extraction), `fal-ai` (generation)  
**Capabilities:**
- Frame extraction and analysis
- Video generation from images
- Thumbnail creation from video frames

### quality-validator

Validates media outputs against requirements.

**Tools:** ImageSorcery `get_metainfo`, `detect`, `ocr`  
**Capabilities:**
- Dimension verification
- Format and file size checks
- Object detection for content validation
- OCR for text verification
- Quality scoring via detection confidence

---

## 8. Example Workflows

### Workflow A: Product Hero Image

**User:** "Create a product hero image for our new headphones"

```
Step 1: Analyze
  - No source image → generate from scratch
  - Need: hero banner, likely 1920×1080, high quality

Step 2: Plan
  1. Generate base image via fal-ai flux-pro
  2. Enhance: sharpen, adjust contrast
  3. Create variants: hero (1920×1080), thumbnail (400×300), og (1200×630)
  4. Validate all outputs

Step 3: Execute
  [checkpoint] generate → output/base_headphones.png
  [checkpoint] enhance → output/base_headphones_enhanced.png
  [parallel]
    ├─ resize → output/hero_1920x1080.webp
    ├─ resize → output/thumb_400x300.webp
    └─ resize → output/og_1200x630.webp
  [checkpoint] validate all variants

Step 4: Report
  ✅ 3 variants created, all validated
  Output: output/hero-headphones/
```

### Workflow B: Batch Social Media Kit

**User:** "Take this logo and create a social media kit"

```
Step 1: Analyze
  - Source: user's logo file
  - Need: platform-specific variants with proper dimensions

Step 2: Plan (parallel fleet dispatch)
  generator-1 → Facebook cover (820×312)
  generator-2 → Instagram post (1080×1080)
  generator-3 → Twitter header (1500×500)
  generator-4 → LinkedIn banner (1584×396)
  validator   → check all outputs

Step 3: Execute
  [parallel] All 4 generators run simultaneously
  [sequential] Validator checks each output
  [checkpoint] Save all results

Step 4: Report
  ✅ 4 social media variants created
  All pass dimension and format validation
  Output: output/social-kit/
```

### Workflow C: Image Enhancement Pipeline

**User:** "Enhance this photo — sharpen it, fix the colors, and give me web-ready versions"

```
Step 1: Analyze
  - Source: user's photo (read path, get_metainfo)
  - Need: enhanced + web-optimized variants

Step 2: Plan (sequential chain)
  1. Analyze source dimensions and format
  2. Sharpen via unsharp mask
  3. Color-correct (auto white balance)
  4. Export WebP variants: original size + 50% + thumbnail
  5. Validate file sizes under 500KB

Step 3: Execute
  [checkpoint] get_metainfo → 4032×3024, JPEG, 3.2MB
  [checkpoint] sharpen → output/photo_sharp.png
  [checkpoint] color-correct → output/photo_corrected.png
  [parallel]
    ├─ export → output/photo_full.webp (4032×3024)
    ├─ export → output/photo_half.webp (2016×1512)
    └─ export → output/photo_thumb.webp (400×300)
  [checkpoint] validate sizes

Step 4: Report
  ✅ Enhanced and exported 3 web-ready variants
  Original: 3.2MB → Largest variant: 380KB (88% reduction)
  Output: output/photo-enhanced/
```

---

## Quick Reference

| Pattern | When | How |
|---------|------|-----|
| Fleet dispatch | Independent subtasks | Parallel agents, aggregate results |
| Sequential chain | Dependent steps | Output → next input, checkpoint each |
| Checkpoint | After every mutation | Write state + output to disk |
| Retry | Transient errors | Exponential backoff, max 5 attempts |
| Regenerate | Quality failure | Adjust params, max 2 retries |
| Partial report | Mixed success/failure | Report each step, offer retry |
| Read-only | Always | Write to output/, never touch source |
