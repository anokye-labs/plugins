# Evaluation Framework

Measure and track quality metrics across the media generation pipeline.

## Directory Structure

```
tests/evaluation/
├── README.md                       # This file
├── ImageQuality.Tests.ps1          # Image quality evaluation (CLIP, SSIM, brightness, contrast)
├── VideoQuality.Tests.ps1          # Video quality evaluation (temporal consistency, frame quality)
├── PerformanceBaseline.Tests.ps1   # API performance baselines (P50/P95/P99 latency)
├── CostTracking.Tests.ps1          # API cost tracking and budget alerts
└── TokenBudget.Tests.ps1           # Skill file token/line budget validation
```

## Running Evaluation Tests

```powershell
# Run all evaluation tests
Invoke-Pester ./tests/evaluation/ -Output Detailed

# Run a specific evaluation suite
Invoke-Pester ./tests/evaluation/VideoQuality.Tests.ps1 -Output Detailed

# Run with code coverage
Invoke-Pester ./tests/evaluation/ -CodeCoverage ./scripts/Measure-*.ps1
```

## Quality Thresholds

Thresholds are defined in `tests/fixtures/quality-thresholds.json` and cover:

| Category    | Metric                | Threshold        |
|-------------|-----------------------|------------------|
| Image       | SSIM                  | ≥ 0.7            |
| Image       | CLIP score            | ≥ 0.2            |
| Image       | Brightness            | 0.05 – 0.95      |
| Image       | Contrast              | ≥ 0.02           |
| Image       | Entropy               | ≥ 1.0            |
| Video       | Min FPS               | ≥ 12             |
| Video       | Duration              | 0.5 – 300 s      |
| Video       | T-SSIM (temporal)     | Placeholder      |
| Performance | Generation time       | ≤ 120 s          |
| Performance | Queue wait            | ≤ 300 s          |
| Token       | Skill file max lines  | 500              |
| Token       | Skill file max tokens | 6500             |

## Metrics Covered

- **Image Quality**: CLIP score (prompt alignment), SSIM (structural similarity), brightness, contrast, entropy
- **Video Quality**: Temporal consistency (T-SSIM), frame-by-frame quality, resolution, frame rate
- **Performance**: P50/P95/P99 latency, queue wait times, standard deviation
- **Cost**: Per-request cost, daily/monthly projections, per-model breakdown, budget alerts
- **Token Budget**: Line counts, estimated token counts, SKILL.md-specific limits
