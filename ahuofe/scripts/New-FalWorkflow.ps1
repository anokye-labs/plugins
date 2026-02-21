<#
.SYNOPSIS
    Create and execute multi-step fal.ai workflows.
.DESCRIPTION
    Runs a sequence of fal.ai model invocations in dependency order,
    passing outputs between steps. Each step can reference the output
    of a previous step via the dependsOn array.
.PARAMETER Name
    Name for the workflow (required).
.PARAMETER Steps
    Array of hashtables defining workflow steps (required).
    Each step: @{ name = 'step1'; model = 'fal-ai/flux/dev'; params = @{ prompt = '...' }; dependsOn = @() }
.PARAMETER Description
    Optional description for the workflow.
.EXAMPLE
    $steps = @(
        @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'A mountain' }; dependsOn = @() }
        @{ name = 'animate'; model = 'fal-ai/kling-video/v2.6/pro/image-to-video'; params = @{ prompt = 'Zoom in' }; dependsOn = @('generate') }
    )
    .\New-FalWorkflow.ps1 -Name 'img-to-vid' -Steps $steps
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Name,

    [Parameter(Mandatory)]
    [hashtable[]]$Steps,

    [string]$Description
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

# ─── Validate steps ──────────────────────────────────────────────────────────
foreach ($step in $Steps) {
    if (-not $step.ContainsKey('name') -or [string]::IsNullOrWhiteSpace($step['name'])) {
        throw "Each workflow step must have a 'name' field. Example: @{ name = 'step1'; model = 'fal-ai/flux/dev'; params = @{ prompt = '...' } }"
    }
    if (-not $step.ContainsKey('model') -or [string]::IsNullOrWhiteSpace($step['model'])) {
        throw "Step '$($step['name'] ?? '(unnamed)')' is missing the required 'model' field."
    }
}

# ─── Resolve execution order via topological sort ────────────────────────────
function Resolve-StepOrder {
    param([hashtable[]]$Steps)

    $stepMap = @{}
    foreach ($step in $Steps) {
        $stepMap[$step.name] = $step
    }

    $visited  = @{}
    $visiting = @{}
    $order    = [System.Collections.ArrayList]::new()

    function Visit($name) {
        if ($visiting[$name]) {
            throw "Circular dependency detected at step '$name'."
        }
        if ($visited[$name]) { return }

        $visiting[$name] = $true
        $deps = $stepMap[$name].dependsOn
        if ($deps) {
            foreach ($dep in $deps) {
                if (-not $stepMap.ContainsKey($dep)) {
                    throw "Step '$name' depends on unknown step '$dep'."
                }
                Visit $dep
            }
        }
        $visiting[$name] = $false
        $visited[$name] = $true
        [void]$order.Add($name)
    }

    foreach ($step in $Steps) {
        Visit $step.name
    }

    return $order
}

# ─── Execute workflow ────────────────────────────────────────────────────────
Write-Host "Running workflow: $Name ($($Steps.Count) steps)..." -ForegroundColor Cyan

$executionOrder = Resolve-StepOrder -Steps $Steps

$stepMap = @{}
foreach ($step in $Steps) {
    $stepMap[$step.name] = $step
}

$stepResults = @{}
$outputSteps = [System.Collections.ArrayList]::new()

foreach ($stepName in $executionOrder) {
    $step = $stepMap[$stepName]
    $model = $step.model
    $body = if ($step.params) { $step.params.Clone() } else { @{} }

    # Pass output from dependencies: inject image_url from prior step
    $deps = $step.dependsOn
    if ($deps -and $deps.Count -gt 0) {
        $lastDep = $deps[-1]
        $priorResult = $stepResults[$lastDep]
        if ($priorResult) {
            # If prior step produced images, pass first image URL
            if ($priorResult.images -and $priorResult.images.Count -gt 0) {
                if (-not $body.ContainsKey('image_url')) {
                    $body['image_url'] = $priorResult.images[0].url
                }
            }
            # If prior step produced video, pass video URL
            elseif ($priorResult.video -and $priorResult.video.url) {
                if (-not $body.ContainsKey('image_url')) {
                    $body['image_url'] = $priorResult.video.url
                }
            }
        }
    }

    Write-Host "  Step '$stepName': $model..." -ForegroundColor Yellow

    $stepOutput = [PSCustomObject]@{
        StepName = $stepName
        Model    = $model
        Status   = 'Running'
        Output   = $null
    }

    try {
        # Video models always use queue
        $isVideo = $model -match 'video|veo'
        if ($isVideo) {
            $result = Wait-FalJob -Model $model -Body $body
        }
        else {
            $result = Invoke-FalApi -Method POST -Endpoint $model -Body $body
        }

        $stepResults[$stepName] = $result
        $stepOutput.Status = 'Completed'
        $stepOutput.Output = $result
        Write-Host "  Step '$stepName': Completed" -ForegroundColor Green
    }
    catch {
        $stepOutput.Status = 'Failed'
        $stepOutput.Output = $_.Exception.Message
        Write-Host "  Step '$stepName': Failed — $($_.Exception.Message)" -ForegroundColor Red
        throw
    }

    [void]$outputSteps.Add($stepOutput)
}

# Build workflow output
$output = [PSCustomObject]@{
    WorkflowName = $Name
    Description  = $Description
    Steps        = $outputSteps.ToArray()
}

Write-Host "Workflow '$Name' completed." -ForegroundColor Green

$output
