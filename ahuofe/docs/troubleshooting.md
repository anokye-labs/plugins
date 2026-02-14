# Troubleshooting Guide

Common issues and solutions for the Copilot Media Plugins extension.

---

## API Connection Issues

### FAL_KEY Not Set

**Symptom:** Error `FAL_KEY not found. Set $env:FAL_KEY or add FAL_KEY=<key> to a .env file.`

**Cause:** The `FAL_KEY` environment variable is not configured and no `.env` file exists in the working directory.

**Solution:**
```powershell
# Option 1: Set environment variable
$env:FAL_KEY = 'your-api-key-here'

# Option 2: Create a .env file in the project root
# Add: FAL_KEY=your-api-key-here
```

**Prevention:** Add `FAL_KEY` to your shell profile or use a `.env` file checked into your local config (never commit keys to source control).

### Invalid API Key

**Symptom:** `fal.ai API error (HTTP 401): Unauthorized` or `Invalid API key`.

**Cause:** The key is malformed, expired, or belongs to a deactivated account.

**Solution:**
1. Verify the key at [fal.ai dashboard](https://fal.ai/dashboard)
2. Regenerate if expired
3. Ensure no extra whitespace or quotes around the key value

**Prevention:** Use `Test-FalConnection.ps1` to validate your key before running workflows.

### Network Errors

**Symptom:** `The remote server returned an error` or connection timeout exceptions.

**Cause:** Network connectivity issues, proxy blocking, or fal.ai service outage.

**Solution:**
1. Check internet connectivity: `Test-NetConnection fal.run -Port 443`
2. If behind a proxy, configure PowerShell proxy settings
3. Check [fal.ai status page](https://status.fal.ai) for outages
4. Retry after a brief wait — transient errors resolve quickly

**Prevention:** Implement retry logic (the `FalAi.psm1` module retries on HTTP 429 and 5xx automatically up to 3 times with exponential backoff).

---

## Generation Failures

### Model Not Found

**Symptom:** `fal.ai API error (HTTP 404): Model not found` or `Unknown model endpoint`.

**Cause:** The model path is incorrect, deprecated, or not yet available.

**Solution:**
```powershell
# Search for available models
.\scripts\Search-FalModels.ps1 -Query 'flux'

# Verify a specific model exists
.\scripts\Get-FalModel.ps1 -ModelId 'fal-ai/flux/dev'
```

**Prevention:** Use the model constants from the documentation rather than hard-coding paths. Check the fal.ai model gallery for current endpoints.

### Invalid Parameters

**Symptom:** `fal.ai API error (HTTP 422): Unprocessable Entity` with validation details.

**Cause:** Request body contains invalid values (e.g., unsupported image size, negative guidance scale, or missing required fields).

**Solution:**
1. Check the model schema: `.\scripts\Get-ModelSchema.ps1 -ModelId 'fal-ai/flux/dev'`
2. Verify parameter names match the API (use snake_case: `image_size`, `num_inference_steps`)
3. Ensure numeric values are within valid ranges

**Prevention:** Use the typed script parameters (e.g., `-GuidanceScale`, `-NumInferenceSteps`) which include validation attributes.

### Quota Exceeded

**Symptom:** `fal.ai API error (HTTP 429): Rate limit exceeded` or billing-related errors.

**Cause:** Account has exceeded its rate limit or billing quota.

**Solution:**
1. Check usage: `.\scripts\Get-FalUsage.ps1`
2. Wait for rate limit reset (typically 60 seconds)
3. Upgrade your fal.ai plan if hitting billing limits

**Prevention:** Use `Measure-ApiCost.ps1` to estimate costs before running large batch jobs. Implement throttling for batch operations.

---

## Queue Problems

### Jobs Stuck in Queue

**Symptom:** Job status remains `IN_QUEUE` for an extended period with no progress.

**Cause:** High platform load, large queue backlog, or the specific model is under heavy demand.

**Solution:**
```powershell
# Check job status manually
.\scripts\Get-QueueStatus.ps1 -RequestId 'your-request-id' -Model 'fal-ai/flux/dev'

# Cancel and resubmit during off-peak hours
```

**Prevention:** Use `flux/schnell` for faster generation when quality requirements allow. Set reasonable timeout values.

### Job Timeout

**Symptom:** `fal.ai job timed out after 300s. Request ID: <id>`

**Cause:** The default timeout (300 seconds) elapsed before the job completed. Video generation and upscaling often take longer.

**Solution:**
1. Increase the timeout: `-TimeoutSeconds 600`
2. For video models, use longer timeouts (600-900 seconds)
3. Check if the job actually completed: `Get-QueueStatus.ps1 -RequestId <id>`

**Prevention:** Set timeout values appropriate to the model — image generation typically completes in 10-60s, video generation in 60-300s.

### Expired Results

**Symptom:** Previously successful job returns 404 when fetching results.

**Cause:** fal.ai queue results expire after a period (typically 1 hour). CDN URLs for generated content also expire.

**Solution:**
1. Download results immediately after job completion
2. Re-run the generation if results have expired
3. Upload important outputs to permanent storage using `Upload-ToFalCDN.ps1`

**Prevention:** Process and save results in the workflow immediately after each step completes.

---

## ImageSorcery MCP Issues

### Server Not Starting

**Symptom:** MCP tool calls fail with connection errors or `ImageSorcery server not available`.

**Cause:** The ImageSorcery MCP server is not configured or failed to start.

**Solution:**
1. Verify `.mcp.json` configuration exists and references ImageSorcery
2. Check that Python dependencies are installed: `pip install imagesorcery-mcp`
3. Verify the server starts manually: `python -m imagesorcery_mcp`
4. Check logs for startup errors

**Prevention:** Run `Test-ImageSorcery.ps1` to validate the MCP server connection before starting workflows.

### Model Download Failures

**Symptom:** `Failed to download model` or YOLO model errors during detection/find operations.

**Cause:** The required YOLO model files are not downloaded or the download was interrupted.

**Solution:**
1. Download models manually: `download-yolo-models` command
2. Check available disk space (models can be 50-200 MB)
3. Verify network access to the model hosting service

**Prevention:** Pre-download all required models before running detection workflows.

### Tool Execution Errors

**Symptom:** MCP tool returns `{ "error": "Tool execution failed" }` with no result.

**Cause:** Invalid input parameters (bad file path, unsupported format, out-of-bounds coordinates).

**Solution:**
1. Verify the input image exists and is a supported format (PNG, JPEG, WebP)
2. Check that coordinates are within image dimensions — use `get_metainfo` first
3. Ensure output paths are writable

**Prevention:** Always call `get_metainfo` before manipulation operations to validate dimensions. Use the `New-MockMcpResponse` helper in tests for error scenarios.

---

## Workflow Issues

### Step Dependency Errors

**Symptom:** `Step 'X' depends on unknown step 'Y'` during workflow execution.

**Cause:** A step references a dependency that doesn't exist in the workflow definition.

**Solution:**
```powershell
# Verify all step names in dependsOn arrays match defined step names
$steps = @(
    @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = '...' }; dependsOn = @() }
    @{ name = 'upscale';  model = 'fal-ai/aura-sr';  params = @{};                 dependsOn = @('generate') }
)
```

**Prevention:** Define steps before referencing them. Use consistent naming (lowercase, hyphenated).

### Circular Dependencies

**Symptom:** `Circular dependency detected at step 'X'.`

**Cause:** Two or more steps depend on each other, forming a cycle (A → B → A).

**Solution:**
1. Map out the dependency graph on paper
2. Remove or redirect one edge to break the cycle
3. Consider splitting the circular workflow into sequential stages

**Prevention:** Keep dependency chains linear or tree-shaped. Use `New-FalWorkflow.ps1` which validates the graph with topological sort before execution.

### Output Mapping Failures

**Symptom:** A dependent step receives `$null` for `image_url` even though the prior step succeeded.

**Cause:** The prior step's output structure doesn't match the expected shape (e.g., `images` array vs. `image` object).

**Solution:**
1. Check what the prior step actually returned — video models return `{ video: { url } }` while image models return `{ images: [{ url }] }`
2. Manually set `image_url` in the step params if automatic mapping doesn't work
3. Verify the model endpoint produces the expected output format

**Prevention:** The workflow engine auto-maps `images[0].url` and `video.url` to `image_url`. For non-standard outputs, explicitly set the URL in step params.

---

## Performance

### Slow Generation

**Symptom:** Image or video generation takes significantly longer than expected.

**Cause:** Using high-quality models with large dimensions, high inference steps, or during peak platform load.

**Solution:**
1. Use `flux/schnell` instead of `flux/dev` for faster results (~4x speedup)
2. Reduce `num_inference_steps` (20 is often sufficient)
3. Use smaller image dimensions when prototyping
4. Generate during off-peak hours

**Prevention:** Use `Measure-ApiPerformance.ps1` to benchmark different configurations and find the optimal quality-speed tradeoff.

### High Latency

**Symptom:** API calls take 10+ seconds even for simple operations.

**Cause:** Cold start latency on serverless models, network distance, or DNS resolution delays.

**Solution:**
1. Send a warm-up request before critical workflows
2. Use queue-based mode for all non-trivial operations
3. Check if your region has better connectivity to fal.ai endpoints

**Prevention:** Factor cold start time into timeout calculations. The first request to a model may take 30-60 seconds.

### Cost Overruns

**Symptom:** fal.ai billing exceeds budget expectations.

**Cause:** Running too many generations, using premium models, or generating at unnecessary resolutions.

**Solution:**
1. Review usage: `.\scripts\Get-FalUsage.ps1`
2. Estimate costs before batch runs: `.\scripts\Measure-ApiCost.ps1`
3. Switch to cheaper models for development/testing
4. Set budget alerts in the fal.ai dashboard

**Prevention:** Use `Measure-TokenBudget.ps1` to track spending. Always mock API calls in tests — never call real APIs from test suites.

---

## Testing

### Pester Setup

**Symptom:** `The term 'Describe' is not recognized` or Pester module import errors.

**Cause:** Pester 5 is not installed or an older version is loaded.

**Solution:**
```powershell
# Install Pester 5
Install-Module Pester -MinimumVersion 5.0 -Force -Scope CurrentUser

# Verify version
Get-Module Pester -ListAvailable | Select-Object Version
```

**Prevention:** The project includes `.pester.ps1` configuration — run tests with:

```powershell
$config = New-PesterConfiguration -Hashtable (& './tests/.pester.ps1')
Invoke-Pester -Configuration $config
```

### Mock Patterns

**Symptom:** Mocks don't intercept API calls, or tests call real APIs unexpectedly.

**Cause:** Mocks must target the correct module scope. fal.ai calls go through `FalAi.psm1`, so mocks must specify `-ModuleName FalAi`.

**Solution:**
```powershell
# Correct: mock within the module scope
Mock Invoke-RestMethod {
    return [PSCustomObject]@{ images = @([PSCustomObject]@{ url = 'https://fal.ai/test.png' }) }
} -ModuleName FalAi

# Incorrect: mock without module scope (won't intercept module-internal calls)
Mock Invoke-RestMethod { ... }
```

**Prevention:** Always use `-ModuleName FalAi` when mocking `Invoke-RestMethod` or `Start-Sleep`. Use the `TestHelper.psm1` functions (`New-MockFalApiResponse`, `New-MockMcpResponse`) for consistent mock data.

### Test Failures

**Symptom:** Tests pass locally but fail in CI, or vice versa.

**Cause:** Environment differences (missing fixtures, different Pester version, missing `FAL_KEY` handling).

**Solution:**
1. Ensure all tests use `$TestDrive` for temporary files
2. Verify fixtures exist: `tests/fixtures/` should contain `golden-prompts.json` and `quality-thresholds.json`
3. Never depend on `$env:FAL_KEY` being set — always set/clean it in `try/finally` blocks
4. Check that `TestHelper.psm1` is imported in `BeforeAll`

**Prevention:** Follow the pattern in existing validation tests: import helpers in `BeforeAll`, mock `Import-Module` for FalAi, and wrap `$env:FAL_KEY` usage in `try/finally`.

---

## Quick Reference

| Issue | First Check | Script to Run |
|-------|-------------|---------------|
| Auth failure | `$env:FAL_KEY` is set | `Test-FalConnection.ps1` |
| Model error | Model path is correct | `Search-FalModels.ps1` |
| Timeout | Timeout value is sufficient | `Get-QueueStatus.ps1` |
| MCP error | `.mcp.json` config exists | `Test-ImageSorcery.ps1` |
| Workflow error | Step names & deps are valid | `Test-FalWorkflow.ps1` |
| Cost concern | Budget is within limits | `Measure-ApiCost.ps1` |
| Test failure | Pester 5 is installed | `Invoke-Pester` |
