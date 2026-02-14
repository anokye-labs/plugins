# Queue Management — fal.ai Reference

Patterns for managing fal.ai queue-based and synchronous inference,
including polling, timeouts, batching, and cost considerations.

---

## 1. Queue vs Synchronous Inference

fal.ai supports two execution modes. Choose based on latency requirements
and task complexity.

### Decision Matrix

| Criteria | Synchronous | Queue-Based |
|----------|-------------|-------------|
| Expected latency | < 30 seconds | > 30 seconds |
| Model complexity | Fast models (flux-dev, SDXL) | Slow models (flux-pro, video) |
| Output size | Single image | Multiple images or video |
| User experience | Interactive (user is waiting) | Background (progress updates OK) |
| Timeout risk | Low | High (use queue to avoid HTTP timeout) |
| Cost | Same | Same (queue doesn't add cost) |

### When to Use Synchronous

- Simple text-to-image with fast models
- Image transformations (resize, crop, enhance)
- Single-output generation under 30 seconds
- When you need the result immediately for the next pipeline step

### When to Use Queue

- Video generation (typically 30s–5min)
- High-resolution or high-step-count image generation
- Batch generation (multiple outputs from one request)
- Any operation that might exceed HTTP timeout limits
- When you want progress updates during generation

---

## 2. Queue Submission

### Submitting a Job

```typescript
import { fal } from "@fal-ai/client";

const { request_id } = await fal.queue.submit("fal-ai/flux-pro", {
  input: {
    prompt: "Product photography of wireless headphones",
    image_size: { width: 1920, height: 1080 },
    num_inference_steps: 50,
    seed: 42
  }
});

// request_id is your handle for polling, cancellation, and result retrieval
console.log(`Submitted: ${request_id}`);
```

### Job Lifecycle

```
SUBMITTED → IN_QUEUE → IN_PROGRESS → COMPLETED
                                    → FAILED
```

| State | Meaning |
|-------|---------|
| `IN_QUEUE` | Waiting for a GPU worker |
| `IN_PROGRESS` | Actively generating |
| `COMPLETED` | Output ready for retrieval |
| `FAILED` | Generation failed (check error) |

---

## 3. Polling Strategies

### Fixed Interval Polling

Simple approach for predictable workloads.

```
Poll every 2 seconds until complete or timeout.

Timeline:
  0s  → submit
  2s  → poll (IN_QUEUE)
  4s  → poll (IN_QUEUE)
  6s  → poll (IN_PROGRESS)
  8s  → poll (IN_PROGRESS)
  10s → poll (COMPLETED) ✅
```

**Best for:** Short jobs (< 30s), simple workflows.
**Drawback:** Wastes API calls on long jobs.

### Exponential Backoff Polling

Reduces API calls for long-running jobs.

```
Poll 1: wait 1s
Poll 2: wait 2s
Poll 3: wait 4s
Poll 4: wait 8s
Poll 5: wait 16s
...cap at 30s between polls

Timeline:
  0s  → submit
  1s  → poll (IN_QUEUE)
  3s  → poll (IN_QUEUE)
  7s  → poll (IN_PROGRESS)
  15s → poll (IN_PROGRESS)
  31s → poll (IN_PROGRESS)
  61s → poll (COMPLETED) ✅
```

**Best for:** Video generation, batch jobs, any operation > 30s.
**Drawback:** Slower to detect completion on fast jobs.

### Adaptive Polling

Start with fixed interval, switch to backoff if job takes longer
than expected.

```
Phase 1 (first 10s): Poll every 2s
Phase 2 (10s–60s):   Poll with exponential backoff (cap 10s)
Phase 3 (60s+):      Poll every 30s
```

**Best for:** Mixed workloads where you don't know the duration upfront.

### Recommended Defaults

| Job Type | Strategy | Initial Interval | Max Interval | Timeout |
|----------|----------|-------------------|-------------|---------|
| Image (fast model) | Fixed 2s | 2s | 2s | 60s |
| Image (quality model) | Adaptive | 2s | 10s | 120s |
| Video | Exponential backoff | 2s | 30s | 300s |
| Batch images | Exponential backoff | 5s | 30s | 180s |

---

## 4. Timeout Handling and Cancellation

### Setting Timeouts

Every queue job must have a timeout. Never poll indefinitely.

```
Timeout defaults:
  Image generation: 60 seconds
  Video generation: 300 seconds (5 minutes)
  Batch generation: 180 seconds (3 minutes)
  Enhancement/upscale: 120 seconds (2 minutes)
```

### Timeout Actions

When a job exceeds its timeout:

1. **Cancel the job** if the API supports it
2. **Log the timeout** with job details (model, parameters, elapsed time)
3. **Check for partial results** — some APIs return what was generated
4. **Report to user** with suggestion to retry or use a faster model

```
⏱️ Generation timed out after 300s
   Model: fal-ai/minimax-video
   Status at timeout: IN_PROGRESS (65% complete)
   
   Options:
   1. Wait longer (extend timeout to 600s)
   2. Retry with a shorter video duration
   3. Cancel and try a different model
```

### Cancellation

```typescript
// Cancel a queued job
await fal.queue.cancel("fal-ai/flux-pro", {
  requestId: request_id
});
```

**When to cancel:**
- User explicitly cancels
- Timeout exceeded
- Upstream failure makes the result unnecessary
- Circuit breaker opens

---

## 5. Batch Queue Management

Managing multiple jobs in flight simultaneously.

### Submission Pattern

```
Task: Generate 4 social media variants

Submit all jobs:
  job-1 → facebook_cover  (820×312)   → request_id_1
  job-2 → instagram_post  (1080×1080) → request_id_2
  job-3 → twitter_header  (1500×500)  → request_id_3
  job-4 → linkedin_banner (1584×396)  → request_id_4

Track in a job table:
  | Job | Request ID | Status | Submitted | Elapsed |
  |-----|-----------|--------|-----------|---------|
  | job-1 | req_abc | IN_PROGRESS | 18:42:00 | 5s |
  | job-2 | req_def | IN_QUEUE | 18:42:01 | 4s |
  | job-3 | req_ghi | IN_PROGRESS | 18:42:01 | 4s |
  | job-4 | req_jkl | IN_QUEUE | 18:42:02 | 3s |
```

### Polling Multiple Jobs

Poll all active jobs in each cycle rather than polling one at a time:

```
Poll cycle 1:
  Check job-1 → IN_PROGRESS
  Check job-2 → IN_QUEUE
  Check job-3 → COMPLETED ✅ (retrieve result)
  Check job-4 → IN_QUEUE

Poll cycle 2:
  Check job-1 → COMPLETED ✅ (retrieve result)
  Check job-2 → IN_PROGRESS
  Check job-4 → IN_PROGRESS

Poll cycle 3:
  Check job-2 → COMPLETED ✅ (retrieve result)
  Check job-4 → COMPLETED ✅ (retrieve result)

All done → aggregate results
```

### Concurrency Limits

Respect fal.ai concurrency limits to avoid rate limiting:

| Plan | Max Concurrent Jobs | Recommendation |
|------|-------------------|----------------|
| Free | 2 | Submit 2, queue rest |
| Pro | 5 | Submit 5, queue rest |
| Enterprise | 20+ | Submit all |

If you exceed concurrency limits, queue additional jobs locally and submit
as slots become available.

### Failure in Batch

When one job in a batch fails:

1. Let remaining jobs continue — don't cancel the batch
2. Mark the failed job and record the error
3. After all jobs complete (or fail), report aggregate status
4. Offer to retry only failed jobs

---

## 6. Status Reporting During Long-Running Jobs

Keep the user informed during extended operations.

### Progress Update Format

```
🔄 Generating social media kit...

  [✅] facebook_cover.webp  — completed (3.2s)
  [🔄] instagram_post.webp  — generating... (45%)
  [⏳] twitter_header.webp   — queued
  [⏳] linkedin_banner.webp  — queued

  Elapsed: 12s | Estimated remaining: 25s
```

### Update Frequency

| Job Duration | Update Interval |
|-------------|----------------|
| < 10s | No updates (too fast) |
| 10s–30s | Update every 5s |
| 30s–120s | Update every 10s |
| > 120s | Update every 30s |

### Completion Report

```
✅ Social media kit complete (4 of 4 variants)

  | Variant | Dimensions | Size | Time |
  |---------|-----------|------|------|
  | facebook_cover.webp | 820×312 | 45KB | 4.1s |
  | instagram_post.webp | 1080×1080 | 112KB | 8.3s |
  | twitter_header.webp | 1500×500 | 67KB | 5.7s |
  | linkedin_banner.webp | 1584×396 | 58KB | 6.2s |

  Total time: 24.3s | Total size: 282KB
  Output: output/social-kit/
```

---

## 7. Cost Implications

### Queue vs Sync Cost

Queue submission and synchronous inference have the **same cost** per
inference. The queue itself doesn't add charges — you pay only for GPU
time consumed.

### Cost Optimization Strategies

| Strategy | Impact | Trade-off |
|----------|--------|-----------|
| Use faster models (flux-dev vs flux-pro) | ~50% cost reduction | Lower quality |
| Reduce inference steps | ~30% cost reduction | Lower quality |
| Generate at smaller size, upscale after | ~40% cost reduction | Slight quality loss |
| Batch similar requests | No cost change | Better throughput |
| Cancel timed-out jobs promptly | Saves partial GPU time | May lose progress |
| Cache results (same prompt + seed) | 100% savings on repeat | Storage cost |

### Cost Tracking

Log cost metadata with every generation:

```json
{
  "job_id": "req_abc123",
  "model": "fal-ai/flux-pro",
  "duration_seconds": 4.2,
  "estimated_cost_usd": 0.012,
  "dimensions": "1920x1080",
  "inference_steps": 50
}
```

Track cumulative cost per workflow to stay within budgets.
