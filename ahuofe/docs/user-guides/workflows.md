# Workflows

Build multi-step media pipelines, run parallel operations, and checkpoint progress for complex media tasks.

## Multi-Step Media Pipelines

A pipeline chains multiple operations — generation, processing, optimization — into a single workflow. Each step's output feeds the next step's input.

### Defining a Pipeline

Describe the steps in sequence:

```
Workflow:
1. Generate a product photo of a coffee mug on a wooden table (flux-pro, seed 42)
2. Detect the mug in the generated image
3. Crop to the detected mug with 30px padding
4. Resize the crop to 1024x1024
5. Overlay the brand logo at position (850, 850)
6. Save as ./output/product-final.png
```

The extension executes each step, passing results forward automatically.

### Pipeline Design Guidelines

| Principle | Description |
|-----------|-------------|
| **Immutable outputs** | Each step creates a new file; originals are never modified |
| **Explicit ordering** | Number your steps; ambiguous order causes failures |
| **Fail-fast** | Pipeline stops at the first error; fix and resume |
| **Deterministic seeds** | Use seeds in generation steps for reproducible pipelines |

## Fleet Pattern for Parallel Operations

When you need to process multiple items independently, use the fleet pattern: dispatch a group of tasks and collect results.

### Example: Generate Variations

```
Generate 6 variations of "a minimalist logo for a tech startup" using:
- Models: flux-dev, flux-pro
- Seeds: 100, 200, 300
Run all combinations in parallel.
```

This produces 6 images (2 models × 3 seeds) without waiting for each to complete before starting the next.

### Example: Batch Processing

```
For each image in ./input/:
1. Resize to 800x800
2. Apply grayscale
3. Save to ./output/processed/
Run in parallel.
```

### Fleet Guidelines

- **Independent tasks only** — each task must not depend on another's output
- **Shared configuration** — all tasks in a fleet share the same parameter template
- **Result collection** — results are gathered after all tasks complete
- **Error isolation** — one task's failure doesn't affect others

## Checkpointing and Resume

Long-running workflows benefit from checkpointing — saving intermediate state so you can resume after failures without restarting from scratch.

### How Checkpointing Works

1. **After each step**, the extension records the completed step and its output
2. **On failure**, the workflow stops and reports which step failed
3. **On resume**, the workflow skips completed steps and continues from the failure point

### Example: Resume After Failure

```
Resume the product-photo workflow from step 4
```

The extension loads the checkpoint, verifies that steps 1–3 completed successfully, and continues with step 4.

### Checkpoint Best Practices

| Practice | Why |
|----------|-----|
| **Name your workflows** | Enables referencing for resume |
| **Use deterministic seeds** | Ensures resumed steps produce identical results |
| **Save intermediates to disk** | Provides fallback if checkpoint metadata is lost |
| **Review before resuming** | Verify intermediate outputs haven't been modified |

## Error Handling in Workflows

### Automatic Retry

The extension retries transient errors (rate limits, network timeouts) with exponential backoff:

- **Attempt 1**: Immediate
- **Attempt 2**: 1 second delay
- **Attempt 3**: 2 seconds delay
- **Attempt 4**: 4 seconds delay
- **Max attempts**: 5

### Manual Intervention

For non-transient errors:

```
The workflow stopped at step 3 with error: "Image too small for detection."
Fix: Resize the image to at least 640x640 before detection.
```

The extension provides actionable suggestions for each error type.

## Combining Patterns

### Fleet + Pipeline

Generate variants in parallel, then process each through a pipeline:

```
Phase 1 (parallel): Generate 4 product photos with seeds 10, 20, 30, 40
Phase 2 (per image): Detect → Crop → Resize → Overlay logo
Phase 3 (parallel): Optimize all results for web (WebP, quality 85)
```

### Pipeline + Checkpoint

Long pipelines with expensive steps:

```
Workflow "marketing-assets" (checkpointed):
1. Generate hero image (flux-pro, 50 steps)
2. Generate 3 supporting images (flux-dev, parallel)
3. Process all images: resize, color-correct, add branding
4. Create social media variants (crop to 1:1, 16:9, 9:16)
5. Optimize all for web delivery
```

Each numbered step is a checkpoint. If step 3 fails, resume from step 3 without regenerating images.

## Next Steps

- [Examples Gallery](../examples-gallery/advanced-workflows.md) — complete workflow examples
- [API Reference](../api-reference/scripts.md) — script parameters for workflow automation
- [Getting Started](getting-started.md) — initial setup if you haven't started yet
