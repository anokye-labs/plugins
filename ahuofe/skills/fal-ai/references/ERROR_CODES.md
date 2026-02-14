# fal.ai Error Code Reference

Complete reference for errors returned by the fal.ai API. The `ConvertTo-FalError`
function in `FalAi.psm1` parses all error formats automatically. `Invoke-FalApi`
retries transient errors (429, 5xx) with exponential backoff up to 3 attempts.

---

## HTTP Status Codes

### 400 — Bad Request

**Cause:** Malformed request body or missing required fields.

**Example Response:**
```json
{
  "detail": [
    {
      "loc": ["body", "prompt"],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

**Fix:** Check that all required parameters are present. Use `Get-FalModel.ps1`
or `Get-ModelSchema.ps1` to verify required fields for the model.

**Retry:** No — fix the request and resubmit.

---

### 401 — Unauthorized

**Cause:** Missing or invalid `FAL_KEY`.

**Example Response:**
```json
{
  "detail": "Invalid API key"
}
```

**Fix:**
1. Verify `$env:FAL_KEY` is set: `echo $env:FAL_KEY`
2. Check the key is valid at [fal.ai dashboard](https://fal.ai/dashboard)
3. Ensure no extra whitespace or quotes around the key
4. Run `.\scripts\Test-FalConnection.ps1` to diagnose

**Retry:** No — fix authentication first.

---

### 403 — Forbidden

**Cause:** API key lacks permission for the requested model or operation.

**Example Response:**
```json
{
  "detail": "Access denied for this endpoint"
}
```

**Fix:**
1. Verify your account has access to the model
2. Some premium models require a paid plan
3. Check billing status at fal.ai dashboard

**Retry:** No — resolve access/billing issue.

---

### 404 — Not Found

**Cause:** Invalid model endpoint or request ID.

**Example Response:**
```json
{
  "error": "Model not found"
}
```

**Fix:**
1. Verify the model endpoint is correct (e.g., `fal-ai/flux/dev` not `fal/flux/dev`)
2. Use `Search-FalModels.ps1` to find valid endpoints
3. For queue requests, verify the `request_id` is still valid

**Retry:** No — fix the endpoint.

---

### 422 — Unprocessable Entity

**Cause:** Valid JSON but invalid parameter values.

**Example Response:**
```json
{
  "detail": [
    {
      "loc": ["body", "num_images"],
      "msg": "ensure this value is less than or equal to 4",
      "type": "value_error.number.not_le"
    }
  ]
}
```

**Common Causes:**
- `num_images` exceeding model limit
- Invalid `image_size` preset for the model
- `strength` outside 0.0–1.0 range
- Missing `image_url` for image-to-video models
- Invalid image URL (not accessible or wrong format)

**Fix:** Check the model schema with `Get-ModelSchema.ps1 -ModelId "fal-ai/flux/dev" -InputOnly`
and correct the parameter values.

**Retry:** No — fix parameters.

---

### 429 — Too Many Requests

**Cause:** Rate limit exceeded.

**Example Response:**
```json
{
  "message": "Rate limit exceeded"
}
```

**Fix:** `Invoke-FalApi` automatically retries with exponential backoff (2s, 4s, 8s)
up to 3 attempts. If errors persist:
1. Reduce request frequency
2. Add delays between batch submissions: `Start-Sleep -Seconds 1`
3. Check your plan's rate limits at fal.ai dashboard

**Retry:** Yes — auto-retried by the module. Manual retry after 30s if exhausted.

---

### 500 — Internal Server Error

**Cause:** Unexpected server-side failure.

**Example Response:**
```json
{
  "error": "Internal server error"
}
```

**Fix:** Usually transient. Auto-retried by `Invoke-FalApi`.

**Retry:** Yes — auto-retried with exponential backoff (up to 3 attempts).

---

### 502 — Bad Gateway

**Cause:** Server infrastructure issue, typically during high load.

**Example Response:**
```
502 Bad Gateway
```

**Fix:** Transient. Auto-retried by `Invoke-FalApi`.

**Retry:** Yes — auto-retried. If persistent, the model may be temporarily down.

---

### 503 — Service Unavailable

**Cause:** Model is loading or temporarily unavailable.

**Example Response:**
```json
{
  "detail": "Model is currently loading, please try again in a few seconds"
}
```

**Fix:** Wait and retry. Cold-start models may take 10–30 seconds to load.

**Retry:** Yes — auto-retried. For cold starts, wait 15–30 seconds.

---

## fal.ai Error Response Formats

The API returns errors in several JSON shapes. `ConvertTo-FalError` handles all of them:

### Format 1: `detail` as string

```json
{
  "detail": "Invalid API key"
}
```

Extracted as: `"Invalid API key"`

### Format 2: `detail` as validation array

```json
{
  "detail": [
    {
      "loc": ["body", "prompt"],
      "msg": "field required",
      "type": "value_error.missing"
    },
    {
      "loc": ["body", "image_size"],
      "msg": "value is not a valid enumeration member",
      "type": "type_error.enum"
    }
  ]
}
```

Extracted as: `"field required; value is not a valid enumeration member"`

### Format 3: `error` field

```json
{
  "error": "Model not found"
}
```

Extracted as: `"Model not found"`

### Format 4: `message` field

```json
{
  "message": "Rate limit exceeded"
}
```

Extracted as: `"Rate limit exceeded"`

---

## Common Error Scenarios

### FAL_KEY Not Found

**Error:** `FAL_KEY not found. Set $env:FAL_KEY or add FAL_KEY=<key> to a .env file.`

**Source:** `Get-FalApiKey` in `FalAi.psm1`

**Fix:**
```powershell
# Option 1: Set environment variable
$env:FAL_KEY = "your-key-here"

# Option 2: Create .env file
"FAL_KEY=your-key-here" | Set-Content .env
```

---

### ImageUrl Required for Image-to-Video

**Error:** `--ImageUrl is required for image-to-video models.`

**Source:** `Invoke-FalGenerate.ps1`

**Fix:** Provide an image URL via `-ImageUrl`. Upload a local file first if needed:
```powershell
$url = (.\scripts\Upload-ToFalCDN.ps1 -FilePath ".\photo.jpg").Url
.\scripts\Invoke-FalGenerate.ps1 -Prompt "Animate this" `
    -Model "fal-ai/kling-video/v2.6/pro/image-to-video" `
    -ImageUrl $url -Queue
```

---

### Queue Submission Failed

**Error:** `Queue submission failed: <message>`

**Source:** `Wait-FalJob` in `FalAi.psm1`

**Cause:** The queue API did not return a `request_id`.

**Fix:**
1. Verify the model endpoint is correct
2. Check that the request body is valid for the model
3. Check API key permissions

---

### Job Timed Out

**Error:** `fal.ai job timed out after 300s. Request ID: <id>`

**Source:** `Wait-FalJob` in `FalAi.psm1`

**Cause:** Generation exceeded the default 300-second timeout.

**Fix:**
1. Increase timeout: use `-TimeoutSeconds 600` on the queue call
2. For video generation, 120+ seconds is normal
3. Check status manually: `.\scripts\Get-QueueStatus.ps1 -RequestId "<id>" -Model "<model>"`

---

### Job Failed

**Error:** `fal.ai job failed: <message>`

**Source:** `Wait-FalJob` in `FalAi.psm1`

**Cause:** The model returned a `FAILED` status during queue processing.

**Fix:**
1. Check the error message for details
2. Common causes: content safety violation, invalid input image, model overload
3. Retry with a different prompt or input

---

### CDN Upload Failed

**Error:** `CDN upload failed: <message>` or `Failed to obtain CDN upload token from fal.ai.`

**Source:** `Send-FalFile` in `FalAi.psm1`

**Fix:**
1. Verify the file exists and is under 100 MB
2. Check file extension is supported (jpg, jpeg, png, gif, webp, mp4, mov, mp3, wav)
3. Verify API key has upload permissions

---

## Retry Behavior Summary

| Status Code | Auto-Retry | Backoff | Max Attempts |
|-------------|-----------|---------|--------------|
| 400 | ❌ No | — | — |
| 401 | ❌ No | — | — |
| 403 | ❌ No | — | — |
| 404 | ❌ No | — | — |
| 422 | ❌ No | — | — |
| 429 | ✅ Yes | Exponential (2s, 4s, 8s) | 3 |
| 500 | ✅ Yes | Exponential (2s, 4s, 8s) | 3 |
| 502 | ✅ Yes | Exponential (2s, 4s, 8s) | 3 |
| 503 | ✅ Yes | Exponential (2s, 4s, 8s) | 3 |

The retry logic is implemented in `Invoke-FalApi` (lines 146–196 of `FalAi.psm1`).
Queue polling in `Wait-FalJob` uses a separate poll interval (default: 2 seconds)
with a configurable timeout (default: 300 seconds).
