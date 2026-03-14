# Local Iteration Guide

Fast, free iteration on brand YAML files without needing fal.ai or Anthropic API keys. This is the primary development loop for editing entity descriptions, tweaking visual properties, and validating brand consistency before pushing to a PR.

## Overview

| Capability | Command | Needs API Keys? |
|-----------|---------|-----------------|
| YAML validation | `npx ahuofe validate` | No |
| Prompt preview | `npx ahuofe preview-prompt` | No |
| Drift checklist preview | `npx ahuofe preview-prompt --show-drift` | No |
| Mock generation | `npx ahuofe mock-generate` | No |
| Batch validation | `npx ahuofe validate --all` | No |
| Actual image generation | `npx tsx pipeline/src/index.ts --stage generate ...` | Yes (`FAL_KEY`) |
| Drift evaluation | `npx tsx pipeline/src/index.ts --stage evaluate ...` | Yes (`ANTHROPIC_API_KEY`) |

The first five commands work entirely offline. The last two require API keys and are handled by GitHub Actions in the PR-driven workflow.

## Installation

```bash
# From your project repo (e.g., anokye-system)
npm install --save-dev @anokye-labs/ahuofe-pipeline
```

Or, if working directly with the plugin source:

```bash
cd path/to/plugins/ahuofe/pipeline && npm install
```

## 1. validate-yaml -- Schema Validation

Validates brand YAML files against the JSON schemas provided by the plugin.

### Usage

```bash
# Validate all brand files
npx ahuofe validate --brand ./brand

# Validate a specific entity
npx ahuofe validate --brand ./brand --entity okyeame

# Direct invocation via tsx
npx tsx ahuofe/pipeline/src/local/validate-yaml.ts brand/entities/physical/okyeame.yaml
```

### What It Checks

- Required fields are present
- Type correctness (strings, numbers, arrays, etc.)
- Cross-references resolve (e.g., referenced adinkra symbols exist in `adinkra-map.yaml`)
- Differentiation matrix consistency across entities
- Color values are valid hex codes
- Material references match entries in `shared/materials.yaml`

### Output

```
brand/shared/colors.yaml .............. PASS
brand/shared/materials.yaml ........... PASS
brand/entities/physical/okyeame.yaml .. PASS
brand/presets/draft.yaml .............. PASS
brand/presets/review.yaml ............. PASS
brand/presets/final.yaml .............. PASS

6 files validated, 0 errors
```

On failure:

```
brand/entities/physical/okyeame.yaml .. FAIL
  - /body/torso/primary_garment: required property 'material' is missing
  - /head/helm/adinkra_symbol: "gye-nyame" not found in adinkra-map.yaml

6 files validated, 2 errors
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All files valid |
| 1 | Validation errors found |

## 2. preview-prompt -- Prompt Compilation Preview

Compiles entity YAML into the full generation prompt and prints it to stdout. Shows exactly what would be sent to fal.ai, so you can iterate on descriptions and see the effect instantly.

### Usage

```bash
# Preview the compiled prompt for an entity
npx ahuofe preview-prompt --entity okyeame --brand ./brand

# Include the drift checklist and negative constraints
npx ahuofe preview-prompt --entity okyeame --brand ./brand --show-drift

# Direct invocation via tsx
npx tsx ahuofe/pipeline/src/local/preview-prompt.ts --entity okyeame
```

### Output

```
=== Compiled Prompt for okyeame (idle-standing) ===

A full-body digital illustration of The Linguist (Okyeame), a robotic-royal
figure standing in an idle pose. The figure wears a golden helm adorned with
the Gye Nyame adinkra symbol...

[... full prompt text ...]

--- Statistics ---
Characters: 14,832
Estimated tokens: ~3,708
```

With `--show-drift`:

```
=== Drift Checklist (22 items) ===
 1. Golden helm present on head
 2. Gye Nyame adinkra symbol on helm
 3. Linguist staff in right hand
 4. Kente cloth draped toga-style
...

=== Negative Constraints (14 items) ===
 1. NOT human skin visible
 2. NOT modern clothing
 3. NOT weapons other than linguist staff
...
```

## 3. mock-generate -- Placeholder Generation

Generates placeholder images locally for layout testing. No API keys required. Produces colored rectangles with entity name and pose text overlaid, matching the correct aspect ratios from the preset configuration.

### Usage

```bash
# Mock-generate a single entity
npx ahuofe mock-generate --entity okyeame --brand ./brand --output ./output

# Mock-generate all entities
npx ahuofe mock-generate --brand ./brand --all --output ./output

# Direct invocation via tsx
npx tsx ahuofe/pipeline/src/local/mock-generate.ts --entity okyeame
```

### What It Produces

```
output/
├── okyeame/
│   ├── idle-standing-v1.jpg       # Placeholder image (colored rectangle)
│   └── manifest.json              # Manifest matching real generation format
└── ...
```

The placeholder images:
- Use entity-specific colors derived from the brand palette
- Display entity name and pose as overlaid text
- Match the aspect ratio specified in the active preset
- Produce a `manifest.json` in the same format as real generations

This is useful for:
- Testing the viewer layout before spending API credits
- Verifying PR comment formatting
- Validating the full pipeline flow without network calls
- Developing viewer features against realistic data structures

## 4. Recommended Workflow

The local iteration loop follows a validate-preview-mock cycle:

```
  Edit YAML
      |
      v
  validate-yaml  ----> Fix errors ----> Edit YAML
      |                                     ^
      | (passes)                            |
      v                                     |
  preview-prompt ----> Tweak descriptions --+
      |
      | (satisfied with prompt)
      v
  mock-generate  ----> Check layout ------> Edit YAML
      |                                     ^
      | (satisfied with output)             |
      v                                     |
  Push to PR     ----> Review real images --+
```

### Step by Step

```bash
# 1. Clone the project repo
git clone anokye-labs/anokye-system && cd anokye-system

# 2. Install the pipeline
npm install --save-dev @anokye-labs/ahuofe-pipeline

# 3. Create a feature branch
git checkout -b feature/okyeame-kente

# 4. Edit a brand file
vim brand/entities/physical/okyeame.yaml

# 5. Validate immediately
npx ahuofe validate --brand ./brand

# 6. Preview the compiled prompt
npx ahuofe preview-prompt --entity okyeame --brand ./brand

# 7. Preview with drift checklist
npx ahuofe preview-prompt --entity okyeame --brand ./brand --show-drift

# 8. Generate mock images for layout testing
npx ahuofe mock-generate --entity okyeame --brand ./brand --output ./output

# 9. Repeat steps 4-8 until satisfied

# 10. Push to open a PR -- Actions handles real generation
git add brand/
git commit -m "brand: refine okyeame kente draping"
git push origin feature/okyeame-kente
```

## CLI Quick Reference

```bash
# Validate all brand files
npx ahuofe validate --brand ./brand

# Validate a specific entity
npx ahuofe validate --brand ./brand --entity okyeame

# Preview compiled prompt
npx ahuofe preview-prompt --entity okyeame --brand ./brand

# Preview with drift checklist
npx ahuofe preview-prompt --entity okyeame --brand ./brand --show-drift

# Mock generation (single entity)
npx ahuofe mock-generate --entity okyeame --brand ./brand --output ./output

# Mock batch generation (all entities)
npx ahuofe mock-generate --brand ./brand --all --output ./output
```

## Troubleshooting

### "Cannot find module @anokye-labs/ahuofe-pipeline"

Ensure you have installed the pipeline package:

```bash
npm install --save-dev @anokye-labs/ahuofe-pipeline
```

### Validation passes but prompt preview looks wrong

Check that `shared/` files are complete. The prompt compiler resolves cross-references to shared colors, materials, and adinkra symbols. Missing shared files may result in incomplete prompts without validation errors.

### Mock images have wrong aspect ratio

Check your `brand/presets/draft.yaml` -- the `aspect_ratio` field controls the dimensions of mock-generated images.

## Next Steps

Once you are satisfied with local iteration:

1. Push your branch and open a PR
2. The Ahuofe workflow runs draft generation automatically
3. Review generated images in the PR comment gallery
4. Use `@ahuofe review <entity>` and `@ahuofe finalize <entity>` to escalate

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for full project setup instructions.
