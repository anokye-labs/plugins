# Troubleshooting

Common workflow issues and solutions for `scripts/New-FalWorkflow.ps1`.

---

## Step Dependency Errors

### Circular dependency detected at step 'X'

**Cause:** Two or more steps depend on each other forming a loop
(e.g., A → B → A).

**Fix:** Review the `dependsOn` arrays and remove the back-edge. Workflows
must form a directed acyclic graph (DAG). Use `Test-FalWorkflow.ps1 -DryRun`
to validate the graph before execution.

### Step 'X' depends on unknown step 'Y'

**Cause:** A typo in the `dependsOn` array, or the referenced step was
removed from the workflow.

**Fix:** Check that the step name in `dependsOn` exactly matches the `name`
field of the target step. Names are case-sensitive.

### Steps execute in unexpected order

**Cause:** Dependencies not declared. The engine uses topological sort —
steps without explicit dependencies may run before you expect.

**Fix:** Add `dependsOn` entries to enforce ordering. Every step that needs
a prior step's output must declare it.

---

## API Failures

### HTTP 429 — Rate Limited

**Cause:** Too many requests to fal.ai in a short period.

**Fix:** The underlying `Invoke-FalApi` retries automatically with
exponential backoff (up to 3 attempts). If 429 persists:
- Reduce concurrent workflows
- Add `Start-Sleep` between workflow runs
- Check your fal.ai plan limits

### HTTP 422 — Invalid Parameters

**Cause:** A step parameter is invalid for the target model (wrong type,
missing required field, unsupported value).

**Fix:**
1. Check the model's required parameters in [NODE_TYPES.md](NODE_TYPES.md)
2. Verify `image_url` / `mask_url` are valid hosted URLs (not local paths)
3. Use `Get-FalModel.ps1` to inspect the model's schema

### HTTP 5xx — Server Error

**Cause:** Transient fal.ai infrastructure issue.

**Fix:** Auto-retried by `Invoke-FalApi`. If persistent, check
[fal.ai status](https://status.fal.ai) and retry later.

### Request Timeout

**Cause:** Video generation or large model inference exceeded the timeout.

**Fix:**
- Video models use `Wait-FalJob` which polls with its own timeout
- Increase `TimeoutSeconds` on `Wait-FalJob` if needed
- Reduce `duration` parameter for video models
- Try a faster model (e.g., `flux/schnell` instead of `flux/dev`)

---

## Output Mapping Errors

### image_url is required

**Cause:** A processor step (upscale, inpaint, animate) did not receive
an image URL from its dependency.

**Fix:**
1. Verify the prior step actually produces images (`images[0].url`)
2. Check that `dependsOn` points to the correct step
3. Video outputs (`video.url`) cannot chain to image-based processors
4. Set `image_url` explicitly in `params` as a workaround

### Wrong output field used between steps

**Cause:** The auto-injection logic passes `images[0].url` or `video.url`
from the last dependency. If a step produces `image.url` (singular, e.g.,
upscale), the engine handles it, but custom output formats may not map.

**Fix:** If auto-injection doesn't work for a specific model, set the
`image_url` parameter explicitly in the dependent step's `params`.

### Prior step output is empty

**Cause:** The dependency step returned an empty result (no images or
video in the response).

**Fix:**
- Check the model endpoint is correct
- Verify the prompt and parameters produce output
- Test the step independently before including it in a pipeline

---

## Queue Management Issues

### Job stuck in IN_QUEUE or IN_PROGRESS

**Cause:** Video generation jobs can take 60–180 seconds. The engine
polls via `Wait-FalJob` until completion.

**Fix:**
- Wait longer — video models legitimately take 2–3 minutes
- Check job status with `Get-QueueStatus.ps1 -RequestId <id> -Model <model>`
- If stuck beyond 5 minutes, the job likely failed silently — retry

### Queue result expired

**Cause:** fal.ai queue results expire after a period. If you poll too
late, the result may be gone.

**Fix:** Process queue results immediately. Don't store request IDs for
later retrieval across sessions.

### Multiple queue jobs running simultaneously

**Cause:** Fan-out pattern or rapid sequential workflows.

**Fix:** fal.ai rate-limits concurrent queue jobs per account. Run
video generation steps sequentially rather than in parallel.

---

## Cost Overruns

### Unexpected high costs

**Cause:** Premium models (`flux-pro`, `kling-video`) cost significantly
more than standard models. Multi-step workflows multiply costs.

**Fix:**
1. Use `Measure-ApiCost.ps1` to estimate cost before running
2. Use `Measure-TokenBudget.ps1` to track cumulative spend
3. Use `fal-ai/flux/schnell` for drafts, switch to premium for final output
4. Reduce `num_images` to 1 during development

### Model selection for cost control

| Priority | Image Model | Video Model |
|----------|-------------|-------------|
| Cheapest | `fal-ai/flux/schnell` | — |
| Balanced | `fal-ai/flux/dev` | `fal-ai/kling-video/v2.6/pro/text-to-video` |
| Premium | `fal-ai/flux-pro/v1.1-ultra` | `fal-ai/veo3.1` |

**Tip:** Develop and test workflows with `schnell`, then swap to
`dev` or `flux-pro` for production runs.

---

## Quick Diagnostic Checklist

| Symptom | Check | Solution |
|---------|-------|----------|
| `FAL_KEY not found` | `$env:FAL_KEY` set? | Set env var or create `.env` file |
| Circular dependency | `dependsOn` forms a loop | Remove back-edge |
| Unknown step | Typo in `dependsOn` | Match step names exactly |
| 422 error | Invalid params | Check model schema |
| 429 error | Rate limited | Reduce request frequency |
| No image passed | Missing `dependsOn` | Add dependency declaration |
| Video timeout | Job takes too long | Increase timeout or retry |
| High cost | Premium model usage | Switch to cheaper model for dev |
