# Ahuofe v2 Setup Guide

How to configure a project repository to use the Ahuofe plugin for PR-driven iterative media generation.

## Prerequisites

- A GitHub repository for your project (e.g., `anokye-system`)
- GitHub Actions enabled on the repository
- Access to the `anokye-labs/plugins` repository (for reusable workflows)

## 1. Create `.ahuofe.yaml`

Add a `.ahuofe.yaml` file at the root of your project repository. This binds your project to the Ahuofe plugin and configures all generation behavior.

```yaml
# .ahuofe.yaml
plugin:
  repo: anokye-labs/plugins       # Repository containing the Ahuofe plugin
  path: ahuofe                    # Path within the repo
  ref: main                       # Pin to a tag for stability, or main for latest

project:
  name: "Anokye System"           # Human-readable project name
  command_prefix: "@ahuofe"       # PR comment command prefix
  viewer_title: "Anokye Brand Viewer"  # Title shown in the lineage viewer

brand_path: "./brand"             # Path to brand directory, relative to repo root

defaults:
  stage: draft                    # Default generation stage
  max_iterations: 3               # Max iterations for finalization loop
  pass_threshold: 85              # Drift score threshold (0-100) for passing

approval:
  require_human_approval: true    # Enable approval gates
  stages_requiring_approval:      # Which stages need human sign-off
    - review                      # After initial drafts, human reviews direction
    - finalize                    # Before running expensive final generation
    - merge                       # Before merging finalized art to main
  approvers:                      # GitHub usernames authorized to approve
    - henry-somuah
  auto_approve_draft: true        # Drafts can run without approval

fal:
  retention:
    cdn_expiration_seconds: 3600  # Images expire from fal CDN after 1 hour
    store_payloads: false         # Never store request payloads on fal.ai
    delete_after_download: true   # Explicitly delete CDN files after downloading
  models:
    draft: fal-ai/nano-banana-2                   # Fast, cheap drafts
    review: fal-ai/flux-pro                       # Mid-tier review quality
    final: fal-ai/flux-pro/kontext/max/multi      # Full quality finalization
    reference: fal-ai/flux-pro/kontext            # Reference sheet generation
    evaluator: claude-sonnet-4-20250514           # Drift evaluation model

secrets:                          # GitHub Actions secret names (never put values here)
  fal_key: FAL_KEY
  anthropic_key: ANTHROPIC_API_KEY

notifications:
  post_to_pr: true                # Post generation galleries to PR comments
  label_on_pass: "art-approved"   # Label applied when all entities pass threshold
```

### Configuration Reference

| Block | Purpose |
|-------|---------|
| `plugin` | Points to the Ahuofe plugin repository, path, and version |
| `project` | Project identity: name, command prefix, viewer title |
| `brand_path` | Where brand YAML files live, relative to repo root |
| `defaults` | Default stage, iteration limits, and pass threshold |
| `approval` | Human approval gate configuration |
| `fal` | fal.ai retention controls and model selections per stage |
| `secrets` | Maps logical secret names to GitHub Actions secret names |
| `notifications` | PR notification and labeling behavior |

## 2. Set Up Brand Directory Structure

Create a `brand/` directory (or whatever `brand_path` points to) with the following layout:

```
brand/
├── shared/                    # Shared visual properties across all entities
│   ├── colors.yaml            # Color palette definitions (hex values)
│   ├── materials.yaml         # Material descriptions (kente, gold, wood, etc.)
│   ├── environment.yaml       # Background and environment settings
│   ├── adinkra-map.yaml       # Adinkra symbol definitions and rendering rules
│   ├── proportions.yaml       # Shared proportional guidelines
│   └── differentiation-matrix.yaml  # Cross-entity differentiation rules
├── entities/                  # Entity definitions (one YAML file per entity)
│   ├── physical/              # Physical entities
│   │   └── okyeame.yaml      # Example: The Linguist entity
│   ├── virtual/               # Virtual entities
│   │   └── asafo.yaml
│   └── collective/            # Collective entities
│       └── ahene-council.yaml
└── presets/                   # Generation presets per stage
    ├── draft.yaml             # Draft stage: fast, cheap, low quality
    ├── review.yaml            # Review stage: mid-tier quality
    └── final.yaml             # Final stage: production quality
```

### Preset Files

Presets control generation behavior per stage. Example:

```yaml
# brand/presets/draft.yaml
name: draft
model: fal-ai/nano-banana-2
reference_sheet: false
max_iterations: 1
drift_evaluation: quick         # Rule-based, no vision API
output_format: jpg              # Smaller files for quick review
quality: 80
aspect_ratio: "16:9"
requires_approval: false
```

```yaml
# brand/presets/review.yaml
name: review
model: fal-ai/flux-pro
reference_sheet: false
max_iterations: 1
drift_evaluation: quick_plus    # Rule-based + text summary
output_format: jpg
quality: 90
aspect_ratio: "16:9"
requires_approval: true
```

```yaml
# brand/presets/final.yaml
name: final
model: fal-ai/flux-pro/kontext/max/multi
reference_sheet: true
reference_model: fal-ai/flux-pro/kontext
max_iterations: 3
pass_threshold: 85
drift_evaluation: vision        # Claude vision API evaluation
output_format: png              # Lossless for final assets
aspect_ratio: "16:9"
requires_approval: true
```

### Entity Files

Entity YAML files define the visual properties of each entity at body-part-level granularity. They are validated against JSON schemas provided by the plugin (`ahuofe/schema/entity.schema.json`). See the plugin's schema directory for the full specification.

## 3. Create Workflow Wrapper

Add a thin workflow file to your project repo that delegates to the plugin's reusable workflows:

```yaml
# .github/workflows/ahuofe.yml
name: Ahuofe Generate

on:
  pull_request:
    paths:
      - 'brand/**'
    types: [opened, synchronize]
  issue_comment:
    types: [created]

permissions:
  contents: write
  pull-requests: write
  issues: write

jobs:
  ahuofe:
    uses: anokye-labs/plugins/.github/workflows/ahuofe-generate.yml@main
    with:
      config_path: .ahuofe.yaml
      brand_path: brand/
    secrets:
      FAL_KEY: ${{ secrets.FAL_KEY }}
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

This workflow triggers on:
- **Pull request events** when files under `brand/` are changed (opens draft generation automatically)
- **Issue comments** on PRs (handles `@ahuofe` commands like `review`, `finalize`, `approve`)

All pipeline logic, approval gates, pruning, and PR posting are handled by the plugin's reusable workflow.

## 4. Configure Secrets

Add the following secrets to your GitHub repository (Settings > Secrets and variables > Actions):

| Secret | Description | Required For |
|--------|-------------|-------------|
| `FAL_KEY` | fal.ai API key for image generation | All generation stages (draft, review, final) |
| `ANTHROPIC_API_KEY` | Anthropic API key for drift evaluation | Final stage (Claude vision evaluation) |

These secrets are only used in GitHub Actions. Local iteration does not require API keys. See [LOCAL_ITERATION.md](LOCAL_ITERATION.md) for the local workflow.

### fal.ai Account Configuration (Recommended)

As an additional safety net, configure your fal.ai account's default retention policy:

1. Go to https://fal.ai/settings
2. Set default CDN retention to a short duration (e.g., 1 hour)
3. This catches any request that somehow bypasses the per-request lifecycle headers

## 5. Branch Protection (Recommended)

Configure branch protection rules for your `main` branch to enforce the PR-driven workflow:

| Setting | Recommended Value | Why |
|---------|-------------------|-----|
| Require pull request reviews | Yes (1 reviewer) | Human approval before merging art to main |
| Require status checks | Yes (`ahuofe` job) | Ensure generation completed before merge |
| Require squash merging | Yes | Only final images survive in main's history |
| Auto-delete branches | Yes | Intermediate generations are garbage-collected |
| Restrict pushes to main | Yes | All changes go through PRs |

Squash merging is essential to the ephemeral storage model. When a PR with 20 generation/prune commits is squash-merged, only the files at HEAD (the final, approved images) become part of main's history. All intermediate generations that were pruned are permanently gone.

## Verification Checklist

After completing setup:

- [ ] `.ahuofe.yaml` exists at the repo root with all required blocks
- [ ] `brand/` directory contains at least one entity YAML file
- [ ] `brand/presets/` contains `draft.yaml`, `review.yaml`, and `final.yaml`
- [ ] `.github/workflows/ahuofe.yml` exists and references the correct plugin workflow
- [ ] `FAL_KEY` secret is configured in GitHub repo settings
- [ ] `ANTHROPIC_API_KEY` secret is configured in GitHub repo settings
- [ ] Branch protection is configured with squash merge required
- [ ] Auto-delete branches is enabled

## What Happens Next

1. Create a branch, edit a brand file under `brand/`, and open a PR
2. The workflow detects the changed entities and runs draft generation automatically
3. Draft images appear as a PR comment gallery with a drift checklist
4. Use `@ahuofe review <entity>` to escalate to review quality (requires approval)
5. Use `@ahuofe finalize <entity>` to run the full consistency loop (requires approval)
6. Merge the PR -- only finalized images land on main

For iterating on brand files locally without API keys, see [LOCAL_ITERATION.md](LOCAL_ITERATION.md).
