# Agent Patterns — Fleet Dispatch Reference

Detailed patterns for dispatching, coordinating, and aggregating results
across single and multi-agent media workflows.

---

## 1. Single-Agent vs Multi-Agent Decision Matrix

| Criteria | Single Agent | Multi-Agent Fleet |
|----------|-------------|-------------------|
| Task count | 1 operation | 2+ independent operations |
| Dependencies | Linear chain | Parallelizable branches |
| Latency budget | Tight (<10s) | Flexible (>10s acceptable) |
| Complexity | Simple transform | Multi-format / multi-variant |
| Error isolation | Not critical | Need per-task failure handling |
| Resource usage | Minimal | Scales with agent count |

**Rule of thumb:** If you can draw the task as a single line, use one agent.
If it branches into a tree, dispatch a fleet.

### Decision Flow

```
Is the task a single operation? ──yes──▶ Single agent
  │ no
  ▼
Can subtasks run independently? ──yes──▶ Multi-agent fleet (parallel)
  │ no
  ▼
Are there clear pipeline stages? ──yes──▶ Single agent, sequential chain
  │ no
  ▼
Decompose further until one of the above applies.
```

---

## 2. Worktree-per-Agent Pattern

This project uses Git worktrees to give each agent an isolated workspace,
preventing file conflicts and enabling true parallel execution.

### How It Works

```
main repo: S:\anokye-labs\copilot-media-plugins
  │
  ├── worktree: S:\anokye-labs\worktrees\agents     (branch: wave2/agents)
  ├── worktree: S:\anokye-labs\worktrees\docs        (branch: wave2/docs)
  └── worktree: S:\anokye-labs\worktrees\testing     (branch: wave2/testing)
```

### Rules

1. **Each agent works exclusively in its assigned worktree** — never touch
   the main repo or another agent's worktree.
2. **Each worktree tracks a dedicated branch** — agents commit to their own
   branch, avoiding merge conflicts during parallel work.
3. **Merge happens at integration time** — after all agents complete, branches
   are merged to `main` via pull requests.
4. **Shared fixtures are read-only** — if agents need shared test data, they
   read from `tests/fixtures/` without modification.

### When to Use Worktrees

- Multiple agents need to create or modify files simultaneously
- Tasks span different areas of the codebase (docs, scripts, tests)
- You need clean rollback — just delete the worktree branch

### When NOT to Use Worktrees

- Single-agent tasks with no parallelism
- Read-only analysis or validation tasks
- Tasks that modify a single file

---

## 3. Task Decomposition Strategies

### By File

Split work so each agent owns distinct files. Best when outputs are
independent artifacts.

```
Task: "Create social media kit with 4 platform variants"

agent-1 → output/facebook_cover.webp
agent-2 → output/instagram_post.webp
agent-3 → output/twitter_header.webp
agent-4 → output/linkedin_banner.webp
```

**Pros:** Zero conflict risk, simple aggregation.
**Cons:** No shared state; each agent must have full context.

### By Feature

Split by functional concern. Best for pipeline stages.

```
Task: "Generate, enhance, and validate a product hero image"

agent-generate  → creates base image
agent-enhance   → sharpens and color-corrects
agent-validate  → checks dimensions, format, quality
```

**Pros:** Clean separation of concerns, specialized agents.
**Cons:** Sequential dependencies; later agents wait for earlier ones.

### By Layer

Split by architectural layer. Best for cross-cutting changes.

```
Task: "Add a new media workflow with scripts, tests, and docs"

agent-scripts → scripts/Invoke-NewWorkflow.ps1
agent-tests   → tests/unit/Invoke-NewWorkflow.Tests.ps1
agent-docs    → docs/workflows/new-workflow.md
```

**Pros:** Each agent is an expert in its layer.
**Cons:** Must ensure consistency across layers (shared interfaces).

---

## 4. Result Aggregation Patterns

### Merge Branches

Used when agents work in separate worktrees on separate branches.

```
After all agents complete:

1. Create PR: wave2/agents → main
2. Create PR: wave2/docs → main
3. Create PR: wave2/testing → main
4. Review each PR independently
5. Merge in dependency order (scripts → tests → docs)
```

### Collect Outputs

Used when agents produce independent output files.

```
After all agents complete:

1. List all output files:
   output/
   ├── facebook_cover.webp   (agent-1)
   ├── instagram_post.webp   (agent-2)
   ├── twitter_header.webp   (agent-3)
   └── linkedin_banner.webp  (agent-4)

2. Run validator across all outputs
3. Build summary table:
   | File | Dimensions | Size | Status |
   |------|-----------|------|--------|
   | facebook_cover.webp | 820×312 | 45KB | ✅ |
   | instagram_post.webp | 1080×1080 | 112KB | ✅ |
   | twitter_header.webp | 1500×500 | 67KB | ✅ |
   | linkedin_banner.webp | 1584×396 | 58KB | ✅ |
```

### Reduce to Summary

Used when agents produce metrics or scores that need combining.

```
After quality-check agents complete:

agent-1 result: { quality: 0.92, artifacts: 0, dimensions: "pass" }
agent-2 result: { quality: 0.87, artifacts: 1, dimensions: "pass" }
agent-3 result: { quality: 0.95, artifacts: 0, dimensions: "pass" }

Aggregated:
  Average quality: 0.91
  Total artifacts: 1
  All dimensions: pass
  Overall: PASS (threshold: 0.85)
```

---

## 5. Conflict Resolution

When multiple agents must touch overlapping files, use these strategies:

### Prevention (Preferred)

1. **Assign file ownership** — each agent owns specific files and never
   touches files owned by another agent.
2. **Use append-only patterns** — agents add to a shared file (e.g., a
   registry or index) rather than modifying existing lines.
3. **Separate by directory** — each agent writes to its own subdirectory.

### Detection

If conflicts occur despite prevention:

1. **Git detects conflicts at merge time** — review and resolve manually.
2. **CI check** — run a workflow that attempts to merge all agent branches
   and reports conflicts before human review.

### Resolution Strategies

| Conflict Type | Resolution |
|---------------|-----------|
| Both agents added to same file | Concatenate additions (order by agent ID) |
| Both agents modified same function | Human review required |
| Formatting/whitespace only | Accept either; re-format with linter |
| Incompatible logic changes | Escalate to task owner |

---

## 6. Concrete Dispatch Prompts

### Example 1: Parallel Image Generation

```
You are working in the git worktree at S:\anokye-labs\worktrees\gen-1.
Your task: Generate a Facebook cover image (820×312) using fal-ai flux-pro.
Prompt: "Professional product photography of wireless headphones on gradient background"
Save to: output/social-kit/facebook_cover.png
After generation, run get_metainfo to verify dimensions.
Commit with message: "feat: generate Facebook cover variant"
```

### Example 2: Sequential Pipeline

```
You are working in the git worktree at S:\anokye-labs\worktrees\enhance.
Your task: Enhance the base product image through a 3-step pipeline.

Step 1: Read output/base_product.png with get_metainfo
Step 2: Sharpen using ImageSorcery (unsharp mask)
Step 3: Color-correct (auto white balance)

Save intermediate results with checkpoints.
Final output: output/product_enhanced.png
Commit with message: "feat: enhance product base image"
```

### Example 3: Validation Fleet

```
You are working in the git worktree at S:\anokye-labs\worktrees\validate.
Your task: Validate all images in output/social-kit/.

For each image:
1. Run get_metainfo — verify dimensions match platform requirements
2. Check file size is under 2MB
3. Run detect — verify confidence > 0.8 for expected content
4. Run ocr if the image should contain text

Report results as a markdown table.
Commit with message: "feat: validate social media kit outputs"
```

### Example 4: Multi-Agent with Shared Fixture

```
Dispatcher prompt (you are the coordinator):

Dispatch 3 agents in parallel:
1. agent-scripts: Create Invoke-SocialKit.ps1 in scripts/
2. agent-tests: Create Invoke-SocialKit.Tests.ps1 in tests/unit/
3. agent-docs: Create social-kit.md in docs/workflows/

All agents should read the shared schema from tests/fixtures/social-kit-schema.json.
No agent should modify files outside its assigned directory.
After all complete, merge branches in order: scripts → tests → docs.
```
