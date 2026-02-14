<#
.SYNOPSIS
    Measure fal.ai API performance with latency percentiles.
.DESCRIPTION
    Runs N iterations of image generation against a fal.ai model and
    calculates P50, P95, P99 latency, mean, and standard deviation.
    Falls back to realistic mock data when FAL_KEY is not set.
.PARAMETER Model
    The fal.ai model endpoint. Default: fal-ai/flux/dev.
.PARAMETER Prompt
    Test prompt to use. Default: 'A simple test image of a blue square'.
.PARAMETER Iterations
    Number of iterations to run. Default: 5.
.PARAMETER OutputPath
    Optional path to write JSON results.
.EXAMPLE
    .\Measure-ApiPerformance.ps1
.EXAMPLE
    .\Measure-ApiPerformance.ps1 -Model 'fal-ai/flux/schnell' -Iterations 10 -OutputPath results.json
#>
[CmdletBinding()]
param(
    [string]$Model = 'fal-ai/flux/dev',

    [string]$Prompt = 'A simple test image of a blue square',

    [ValidateRange(1, 100)]
    [int]$Iterations = 5,

    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

# ─── Percentile calculation ──────────────────────────────────────────────────
function Get-Percentile {
    param(
        [double[]]$Values,
        [double]$Percentile
    )
    $sorted = $Values | Sort-Object
    $index = [math]::Ceiling($Percentile / 100.0 * $sorted.Count) - 1
    $index = [math]::Max(0, [math]::Min($index, $sorted.Count - 1))
    return $sorted[$index]
}

function Get-StdDev {
    param([double[]]$Values)
    if ($Values.Count -le 1) { return 0.0 }
    $mean = ($Values | Measure-Object -Average).Average
    $sumSq = ($Values | ForEach-Object { [math]::Pow($_ - $mean, 2) } | Measure-Object -Sum).Sum
    return [math]::Sqrt($sumSq / ($Values.Count - 1))
}

# ─── Check for API key ──────────────────────────────────────────────────────
$useMock = $false
try {
    $null = Get-FalApiKey
} catch {
    $useMock = $true
    Write-Warning 'FAL_KEY not set — generating mock timing data.'
}

# ─── Run iterations ─────────────────────────────────────────────────────────
$timings = @()
$queueWaits = @()
$random = [System.Random]::new(42)

for ($i = 1; $i -le $Iterations; $i++) {
    Write-Host "Iteration $i/$Iterations..." -ForegroundColor Cyan

    if ($useMock) {
        # Mock: realistic latency distribution (log-normal-ish)
        $baseSec = 2.5 + $random.NextDouble() * 3.0
        $jitter  = [math]::Pow($random.NextDouble(), 2) * 4.0
        $totalMs = ($baseSec + $jitter) * 1000.0

        $queueMs = 200.0 + $random.NextDouble() * 800.0
        $timings += $totalMs
        $queueWaits += $queueMs
    }
    else {
        $body = @{ prompt = $Prompt; image_size = 'square'; num_images = 1 }
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $null = Invoke-FalApi -Method POST -Endpoint $Model -Body $body
        $sw.Stop()
        $timings += $sw.Elapsed.TotalMilliseconds

        # Queue mode measurement
        $qSw = [System.Diagnostics.Stopwatch]::StartNew()
        $null = Wait-FalJob -Model $Model -Body $body -PollIntervalSeconds 1
        $qSw.Stop()
        $queueWaits += $qSw.Elapsed.TotalMilliseconds
    }
}

# ─── Calculate statistics ───────────────────────────────────────────────────
$mean   = ($timings | Measure-Object -Average).Average
$stddev = Get-StdDev -Values $timings
$p50    = Get-Percentile -Values $timings -Percentile 50
$p95    = Get-Percentile -Values $timings -Percentile 95
$p99    = Get-Percentile -Values $timings -Percentile 99

$queueMean = ($queueWaits | Measure-Object -Average).Average
$queueP50  = Get-Percentile -Values $queueWaits -Percentile 50
$queueP95  = Get-Percentile -Values $queueWaits -Percentile 95

$output = [PSCustomObject]@{
    Model         = $Model
    Iterations    = $Iterations
    MockMode      = $useMock
    Latency       = [PSCustomObject]@{
        MeanMs   = [math]::Round($mean, 2)
        StdDevMs = [math]::Round($stddev, 2)
        P50Ms    = [math]::Round($p50, 2)
        P95Ms    = [math]::Round($p95, 2)
        P99Ms    = [math]::Round($p99, 2)
    }
    QueueWait     = [PSCustomObject]@{
        MeanMs = [math]::Round($queueMean, 2)
        P50Ms  = [math]::Round($queueP50, 2)
        P95Ms  = [math]::Round($queueP95, 2)
    }
    IndividualMs  = @($timings | ForEach-Object { [math]::Round($_, 2) })
    QueueWaitMs   = @($queueWaits | ForEach-Object { [math]::Round($_, 2) })
}

# ─── Display ────────────────────────────────────────────────────────────────
Write-Host "`nPerformance Results ($Model):" -ForegroundColor Green
Write-Host "  Mean:   $($output.Latency.MeanMs) ms" -ForegroundColor White
Write-Host "  StdDev: $($output.Latency.StdDevMs) ms" -ForegroundColor White
Write-Host "  P50:    $($output.Latency.P50Ms) ms" -ForegroundColor White
Write-Host "  P95:    $($output.Latency.P95Ms) ms" -ForegroundColor White
Write-Host "  P99:    $($output.Latency.P99Ms) ms" -ForegroundColor White
Write-Host "  Queue Mean: $($output.QueueWait.MeanMs) ms" -ForegroundColor White

if ($OutputPath) {
    $output | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Host "`nResults written to $OutputPath" -ForegroundColor Green
}

$output
