# Error Handling — Comprehensive Reference

Strategies for handling every category of failure in media agent workflows.

---

## 1. Error Categories

| Category | Examples | Strategy |
|----------|----------|----------|
| **Transient** | Rate limits, network timeout, 503 | Retry with backoff |
| **Quality** | Low confidence, wrong dimensions | Re-generate with adjusted params |
| **Partial** | 3 of 5 images succeed | Return partial + report failures |
| **Permanent** | Invalid API key, 400 bad request | Fail fast with clear message |

---

## 2. Transient Errors

API rate limits, network timeouts, and temporary service outages.

### Retry with Exponential Backoff

```
Attempt 1: immediate
Attempt 2: wait 1s  (±25% jitter)
Attempt 3: wait 2s  (±25% jitter)
Attempt 4: wait 4s  (±25% jitter)
Attempt 5: wait 8s  (±25% jitter)
```

### Jitter Calculation

Add random jitter to prevent thundering herd:

```powershell
$baseDelay = [math]::Pow(2, $attempt - 2)  # 1, 2, 4, 8
$jitter = $baseDelay * (Get-Random -Minimum -0.25 -Maximum 0.25)
$delay = $baseDelay + $jitter
Start-Sleep -Seconds $delay
```

### Retryable HTTP Status Codes

| Code | Meaning | Retry? |
|------|---------|--------|
| 408 | Request Timeout | Yes |
| 429 | Too Many Requests | Yes (respect Retry-After header) |
| 500 | Internal Server Error | Yes |
| 502 | Bad Gateway | Yes |
| 503 | Service Unavailable | Yes |
| 504 | Gateway Timeout | Yes |

### After All Retries Exhausted

1. Log the final error with full context (URL, status, attempt count)
2. Preserve all completed checkpoints
3. Report to user with actionable guidance:

```
❌ fal.ai API unavailable after 5 attempts (503 Service Unavailable)
   Last attempt: 2026-02-06T18:42:15Z
   Suggestion: Try again in a few minutes, or use a different model.
   Completed work preserved in output/.checkpoint.json
```

---

## 3. Quality Failures

Generated output doesn't meet specified thresholds.

### Detection

Run validation after every generation step:

| Check | Tool | Threshold |
|-------|------|-----------|
| Content match | `detect` | Confidence > 0.8 for expected objects |
| Dimensions | `get_metainfo` | Must match request ±1px |
| Artifacts | `detect` | No unexpected objects with confidence > 0.5 |
| Text legibility | `ocr` | Expected text detected with confidence > 0.7 |
| File size | File system | Under specified limit |

### Re-Generation Strategy

```
Attempt 1: Original parameters
  ↓ quality check fails
Attempt 2: Increase quality setting, change seed
  ↓ quality check fails
Attempt 3: Return best result with quality warning
```

Maximum 2 re-generation attempts. On final failure:

```
⚠️ Generated image quality below threshold (0.72, required 0.85)
   Best attempt saved to: output/hero_best_effort.png
   Quality scores: [0.68, 0.72, 0.71]
   Options:
   1. Accept this result
   2. Try a different model (flux-dev → flux-pro)
   3. Adjust the prompt for better results
```

### Parameter Adjustments Between Retries

| Retry | Adjustment |
|-------|-----------|
| 1st retry | Change seed, increase inference steps by 25% |
| 2nd retry | Change seed again, switch to higher-quality model variant |

---

## 4. Partial Failures

Some operations succeed while others fail within a batch.

### Handling Rules

1. **Never discard successful results** because one step failed
2. **Report each step's status** individually
3. **Offer to retry only failed steps** — don't re-run successes
4. **Checkpoint ensures no rework** — completed outputs persist

### Reporting Format

```
Media Generation Results:

✅ facebook_cover.webp  — 820×312, 45KB
✅ instagram_post.webp  — 1080×1080, 112KB
❌ twitter_header.webp  — Generation failed: model timeout after 60s
✅ linkedin_banner.webp — 1584×396, 58KB

3 of 4 variants created successfully.
Failed: twitter_header.webp (timeout)
Retry failed items? [yes/no]
```

### Partial Failure in Pipelines

When a step fails mid-pipeline:

```
Pipeline: generate → enhance → resize → validate

[✅] generate  → output/base.png
[✅] enhance   → output/base_enhanced.png
[❌] resize    → Failed: out of memory for 8K output
[⏭️] validate  → Skipped (depends on resize)

Checkpoint saved. Resume from 'resize' step with adjusted parameters?
```

### Aggregation with Partial Results

When aggregating across agents:

```json
{
  "workflow_id": "social-kit-20260206",
  "total": 4,
  "succeeded": 3,
  "failed": 1,
  "results": [
    { "agent": "gen-1", "status": "done", "output": "facebook_cover.webp" },
    { "agent": "gen-2", "status": "done", "output": "instagram_post.webp" },
    { "agent": "gen-3", "status": "failed", "error": "timeout", "retryable": true },
    { "agent": "gen-4", "status": "done", "output": "linkedin_banner.webp" }
  ]
}
```

---

## 5. Permanent Failures

Non-retryable errors that require user intervention.

### Identification

| Error | Code | Why Permanent |
|-------|------|--------------|
| Invalid API key | 401 | Credentials are wrong; retrying won't help |
| Bad request | 400 | Input is malformed; must fix before retrying |
| Model not found | 404 | Model ID is wrong or deprecated |
| Unsupported format | 415 | Input format not accepted by the API |
| Quota exceeded | 402 | Billing limit reached; requires account action |
| Content policy | 451 | Prompt violates content policy; must change prompt |

### Handling

1. **Do not retry** — return immediately
2. **Provide clear error message** with the root cause
3. **Suggest corrective action**
4. **Preserve all completed work**

```
❌ Authentication failed (401 Unauthorized)
   The FAL_KEY environment variable is missing or invalid.
   
   To fix:
   1. Verify your fal.ai API key at https://fal.ai/dashboard/keys
   2. Set it: $env:FAL_KEY = "your-key-here"
   3. Re-run the workflow
   
   Completed work preserved in output/.checkpoint.json
```

### Permanent vs Transient Heuristic

```
Is the HTTP status 4xx?
  ├─ 408 (Timeout) → Transient (retry)
  ├─ 429 (Rate Limit) → Transient (retry with backoff)
  └─ All other 4xx → Permanent (fail fast)

Is the HTTP status 5xx?
  └─ All 5xx → Transient (retry)

Is it a network error (DNS, connection refused)?
  └─ Transient (retry)

Is it a validation error (wrong dimensions, bad format)?
  └─ Permanent (fail fast, fix input)
```

---

## 6. Circuit Breaker Pattern

Prevent wasting resources when a service is consistently failing.

### States

```
CLOSED (normal) ──failures exceed threshold──▶ OPEN (blocking)
     ▲                                              │
     │                                        timeout expires
     │                                              │
     └───────────probe succeeds──────── HALF-OPEN (testing)
```

### Implementation

```
Circuit Breaker State:
  failure_count: 0
  state: CLOSED
  last_failure: null
  threshold: 5 failures in 60 seconds
  cooldown: 30 seconds

On each API call:
  if state == OPEN:
    if now - last_failure > cooldown:
      state = HALF-OPEN  (allow one probe request)
    else:
      return error immediately (don't call API)

  if state == HALF-OPEN:
    make one API call
    if success: state = CLOSED, failure_count = 0
    if failure: state = OPEN, last_failure = now

  if state == CLOSED:
    make API call
    if failure:
      failure_count++
      if failure_count >= threshold:
        state = OPEN
        last_failure = now
```

### When to Use

- Calling fal.ai APIs that may have outages
- Any external service with known reliability issues
- Batch operations where early failure detection saves cost

### When NOT to Use

- One-off operations (just use simple retry)
- Local operations (file system, ImageSorcery)
- Operations where every attempt matters (user-initiated single generation)

---

## 7. Error Reporting Format

All errors should be reported as structured JSON for machine-readable
processing, with a human-friendly message for display.

### Error Object Schema

```json
{
  "error": {
    "code": "FAL_TIMEOUT",
    "category": "transient",
    "message": "fal.ai generation timed out after 60 seconds",
    "details": {
      "model": "fal-ai/flux-pro",
      "endpoint": "https://fal.run/fal-ai/flux-pro",
      "http_status": 504,
      "attempts": 5,
      "total_wait_seconds": 15
    },
    "timestamp": "2026-02-06T18:42:15Z",
    "agent_id": "generator-1",
    "workflow_id": "hero-image-20260206-1842",
    "retryable": true,
    "suggestion": "Try again in a few minutes or use flux-dev for faster generation."
  }
}
```

### Error Codes

| Code | Category | Description |
|------|----------|-------------|
| `FAL_TIMEOUT` | transient | API call timed out |
| `FAL_RATE_LIMIT` | transient | Rate limit exceeded (429) |
| `FAL_UNAVAILABLE` | transient | Service unavailable (503) |
| `FAL_AUTH` | permanent | Authentication failed (401) |
| `FAL_BAD_REQUEST` | permanent | Invalid request parameters (400) |
| `FAL_MODEL_NOT_FOUND` | permanent | Model ID not found (404) |
| `FAL_CONTENT_POLICY` | permanent | Content policy violation (451) |
| `FAL_QUOTA` | permanent | Billing quota exceeded (402) |
| `QUALITY_BELOW_THRESHOLD` | quality | Output quality below minimum |
| `DIMENSION_MISMATCH` | quality | Output dimensions don't match request |
| `FILE_SIZE_EXCEEDED` | quality | Output file too large |
| `AGENT_TIMEOUT` | transient | Agent did not complete within deadline |
| `PARTIAL_FAILURE` | partial | Some operations failed in batch |
