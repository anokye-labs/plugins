# Monitoring — Agent Observability Reference

Structured logging, performance metrics, health checks, dashboards,
and alerting for multi-agent media pipelines.

---

## 1. Structured Logging Format

All agent logs use JSON format for machine-readable processing.

### Log Entry Schema

```json
{
  "timestamp": "2026-02-06T18:42:15.123Z",
  "level": "info",
  "agent_id": "generator-1",
  "workflow_id": "hero-image-20260206-1842",
  "action": "generate",
  "status": "success",
  "duration_ms": 4200,
  "metadata": {
    "model": "fal-ai/flux-pro",
    "dimensions": "1920x1080",
    "output_path": "output/hero_base.png",
    "file_size_bytes": 245000
  }
}
```

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | ISO 8601 | When the event occurred |
| `level` | string | `debug`, `info`, `warn`, `error`, `fatal` |
| `agent_id` | string | Unique identifier for the agent instance |
| `workflow_id` | string | Groups all logs for a single workflow run |
| `action` | string | What the agent is doing |
| `status` | string | `started`, `success`, `failed`, `retrying` |
| `duration_ms` | number | Time spent on this action (null if in-progress) |

### Log Levels

| Level | When to Use |
|-------|------------|
| `debug` | Internal state, parameter values, checkpoint reads |
| `info` | Normal operations: job submitted, step completed, result saved |
| `warn` | Recoverable issues: retry triggered, quality below threshold |
| `error` | Failed operations: API error, timeout, validation failure |
| `fatal` | Unrecoverable: auth failure, corrupt checkpoint, crash |

### Action Values

Standard action names for consistent querying:

| Action | Description |
|--------|-------------|
| `workflow.start` | Workflow initiated |
| `workflow.complete` | Workflow finished (check status) |
| `step.start` | Pipeline step began |
| `step.complete` | Pipeline step finished |
| `generate` | Image/video generation |
| `enhance` | Image enhancement |
| `resize` | Image resize/conversion |
| `validate` | Quality validation |
| `queue.submit` | Job submitted to fal.ai queue |
| `queue.poll` | Polling for job status |
| `queue.complete` | Queue job finished |
| `retry` | Retrying a failed operation |
| `checkpoint.save` | Checkpoint written to disk |
| `checkpoint.load` | Checkpoint read from disk |
| `error` | Error occurred |

---

## 2. Performance Metrics

### Key Metrics

| Metric | Unit | Description | Target |
|--------|------|-------------|--------|
| `generation_latency` | ms | Time from API call to result | < 10,000ms (fast), < 60,000ms (quality) |
| `pipeline_latency` | ms | Total time for full workflow | < 30,000ms (simple), < 120,000ms (complex) |
| `throughput` | ops/min | Operations completed per minute | > 10 for batch |
| `error_rate` | % | Failed operations / total operations | < 5% |
| `retry_rate` | % | Retried operations / total operations | < 10% |
| `quality_score` | 0–1 | Average output quality score | > 0.85 |
| `cost_per_image` | USD | Average generation cost per output | < $0.05 |
| `queue_wait_time` | ms | Time in fal.ai queue before processing | < 5,000ms |
| `checkpoint_size` | bytes | Size of checkpoint data written | < 1MB |

### Metric Collection Points

```
User Request
  │
  ├─ [metric] pipeline_latency.start
  │
  ├─ Step 1: Generate
  │   ├─ [metric] generation_latency.start
  │   ├─ [metric] queue_wait_time (if queued)
  │   ├─ [metric] generation_latency.end
  │   └─ [metric] cost_per_image
  │
  ├─ Step 2: Enhance
  │   ├─ [metric] step_latency.start
  │   └─ [metric] step_latency.end
  │
  ├─ Step 3: Validate
  │   ├─ [metric] quality_score
  │   └─ [metric] validation_pass (bool)
  │
  └─ [metric] pipeline_latency.end
```

### Metric Storage Format

```json
{
  "workflow_id": "hero-image-20260206-1842",
  "timestamp": "2026-02-06T18:42:30Z",
  "metrics": {
    "pipeline_latency_ms": 24300,
    "generation_latency_ms": 4200,
    "enhancement_latency_ms": 1800,
    "validation_latency_ms": 500,
    "total_cost_usd": 0.012,
    "quality_score": 0.92,
    "error_count": 0,
    "retry_count": 0,
    "output_count": 3,
    "total_output_size_bytes": 282000
  }
}
```

---

## 3. Health Check Patterns

### Agent Health Check

Each agent should support a health check that verifies:

| Check | What It Verifies | Failure Action |
|-------|-----------------|----------------|
| API connectivity | Can reach fal.ai API | Alert, circuit breaker |
| Authentication | API key is valid | Fatal error, stop agent |
| Disk space | Output directory writable, >100MB free | Warn, clean old outputs |
| Model availability | Target model accepts requests | Warn, suggest alternative |
| Tool access | ImageSorcery MCP responsive | Warn, skip processing steps |

### Health Check Response Format

```json
{
  "agent_id": "generator-1",
  "timestamp": "2026-02-06T18:42:00Z",
  "status": "healthy",
  "checks": [
    { "name": "fal_api", "status": "pass", "latency_ms": 150 },
    { "name": "auth", "status": "pass" },
    { "name": "disk_space", "status": "pass", "free_mb": 4200 },
    { "name": "model", "status": "pass", "model": "fal-ai/flux-pro" },
    { "name": "imagesorcery", "status": "pass", "latency_ms": 20 }
  ]
}
```

### Health Status Values

| Status | Meaning | Action |
|--------|---------|--------|
| `healthy` | All checks pass | Normal operation |
| `degraded` | Non-critical check failed | Warn, continue with limitations |
| `unhealthy` | Critical check failed | Stop, alert, attempt recovery |

### Periodic Health Checks

Run health checks:
- **On agent startup** — before accepting work
- **Every 5 minutes** during idle periods
- **Before each workflow** — verify readiness
- **After errors** — check if the service recovered

---

## 4. Dashboard Design

### Overview Dashboard

```
┌─────────────────────────────────────────────────────┐
│  Media Agent Pipeline Dashboard                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│  Active Workflows: 3    Agents: 8/8 healthy          │
│  Queue Depth: 12        Avg Latency: 8.2s            │
│                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐ │
│  │ Throughput   │  │ Error Rate  │  │ Quality      │ │
│  │ 42 ops/min   │  │ 2.1%        │  │ 0.91 avg     │ │
│  │ ▁▂▃▅▇█▇▅▃▂  │  │ ▁▁▁▂▁▁▁▃▁▁ │  │ ▇▇▇▆▇▇▇▅▇▇ │ │
│  └─────────────┘  └─────────────┘  └──────────────┘ │
│                                                      │
│  Recent Workflows                                    │
│  ┌────────────────────────────────────────────────┐  │
│  │ ID           │ Status │ Duration │ Outputs │ $  │  │
│  │ hero-img-001 │ ✅ Done │ 24.3s    │ 3       │.01│  │
│  │ social-kit   │ 🔄 Run │ 12.1s    │ 1/4     │.00│  │
│  │ batch-resize │ ✅ Done │ 8.7s     │ 12      │.00│  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  Agent Status                                        │
│  ┌────────────────────────────────────────────────┐  │
│  │ generator-1  │ 🟢 idle    │ 42 jobs │ 0 errs  │  │
│  │ generator-2  │ 🔵 working │ 38 jobs │ 1 err   │  │
│  │ processor-1  │ 🟢 idle    │ 85 jobs │ 0 errs  │  │
│  │ validator-1  │ 🔵 working │ 120 jobs│ 2 errs  │  │
│  └────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Key Dashboard Panels

| Panel | Shows | Data Source |
|-------|-------|-------------|
| Throughput over time | Operations per minute, 1h window | Metric logs |
| Error rate trend | % failed ops, 1h window | Error logs |
| Quality distribution | Histogram of quality scores | Validation logs |
| Latency percentiles | p50, p90, p99 generation time | Metric logs |
| Cost accumulation | Cumulative $ per hour/day | Cost logs |
| Agent status grid | Health status per agent | Health checks |
| Active workflows | Current pipeline state | Workflow logs |
| Queue depth | Jobs waiting in fal.ai queue | Queue logs |

### Multi-Agent Pipeline View

For coordinated fleet operations, show pipeline progress:

```
Workflow: social-kit-20260206

  ┌──────────┐    ┌──────────┐    ┌──────────┐
  │ Generate │───▶│ Process  │───▶│ Validate │
  │ 4 jobs   │    │ 4 jobs   │    │ 4 jobs   │
  │ ██████░░ │    │ ████░░░░ │    │ ░░░░░░░░ │
  │ 2/4 done │    │ 1/4 done │    │ 0/4 done │
  └──────────┘    └──────────┘    └──────────┘

  Timeline: ────────────▶ 45s elapsed / ~90s estimated
```

---

## 5. Alert Thresholds and Escalation

### Alert Levels

| Level | Condition | Action |
|-------|-----------|--------|
| **Info** | Workflow completed successfully | Log only |
| **Warning** | Error rate > 5% in 10min window | Notify channel |
| **Critical** | Error rate > 20% OR agent unhealthy | Page on-call |
| **Emergency** | All agents unhealthy OR auth failure | Immediate escalation |

### Specific Alert Rules

| Alert | Threshold | Window | Severity |
|-------|-----------|--------|----------|
| High error rate | > 5% failures | 10 minutes | Warning |
| Very high error rate | > 20% failures | 5 minutes | Critical |
| Slow generation | p90 latency > 30s | 10 minutes | Warning |
| Very slow generation | p90 latency > 60s | 5 minutes | Critical |
| Quality degradation | Avg score < 0.80 | 1 hour | Warning |
| Cost spike | Hourly cost > 2× baseline | 1 hour | Warning |
| Agent down | Health check failed | Immediate | Critical |
| Queue backup | Queue depth > 50 | 5 minutes | Warning |
| Disk space low | < 500MB free | Periodic | Warning |
| Auth failure | 401 from fal.ai | Immediate | Emergency |

### Escalation Path

```
Level 1 — Automated
  ├─ Retry failed operations
  ├─ Circuit breaker for repeated failures
  └─ Switch to fallback model

Level 2 — Notification
  ├─ Post to monitoring channel
  ├─ Create incident ticket
  └─ Log detailed diagnostics

Level 3 — Human Intervention
  ├─ Page on-call engineer
  ├─ Provide runbook link
  └─ Include recent error logs and metrics
```

### Runbook References

Each alert should link to a runbook with:
1. **What triggered the alert** — metric, threshold, current value
2. **Impact assessment** — what's affected, severity
3. **Diagnostic steps** — commands to run, logs to check
4. **Resolution steps** — how to fix common causes
5. **Escalation** — who to contact if resolution fails
