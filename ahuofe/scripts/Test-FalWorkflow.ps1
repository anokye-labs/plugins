<#
.SYNOPSIS
    Validate a fal.ai workflow definition without executing it.
.DESCRIPTION
    Checks a workflow definition for structural errors, invalid model names,
    dependency graph issues (cycles, missing refs), and parameter problems.
    Returns a validation result object with errors and warnings.
.PARAMETER Steps
    Array of step hashtables in the same format accepted by New-FalWorkflow.ps1.
.PARAMETER Path
    Path to a JSON file containing a workflow definition with a Steps array.
.PARAMETER DryRun
    When specified, performs full validation including dependency resolution
    and parameter checks but makes no API calls. This is the default mode.
.EXAMPLE
    $steps = @(
        @{ name = 'gen'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'A cat' }; dependsOn = @() }
        @{ name = 'up'; model = 'fal-ai/aura-sr'; params = @{}; dependsOn = @('gen') }
    )
    .\Test-FalWorkflow.ps1 -Steps $steps
.EXAMPLE
    .\Test-FalWorkflow.ps1 -Path '.\my-workflow.json'
.OUTPUTS
    PSCustomObject with Valid (bool), Errors (string[]), Warnings (string[]),
    StepCount (int), and ExecutionOrder (string[]).
#>
[CmdletBinding(DefaultParameterSetName = 'Inline')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Inline')]
    [hashtable[]]$Steps,

    [Parameter(Mandatory, ParameterSetName = 'File')]
    [ValidateScript({ Test-Path $_ })]
    [string]$Path,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# ─── Known models and their required parameters ─────────────────────────────
$KnownModels = @{
    'fal-ai/flux/dev'                                = @{ required = @('prompt') }
    'fal-ai/flux/schnell'                            = @{ required = @('prompt') }
    'fal-ai/flux-pro/v1.1-ultra'                     = @{ required = @('prompt') }
    'fal-ai/aura-sr'                                 = @{ required = @('image_url') }
    'fal-ai/inpainting'                              = @{ required = @('image_url', 'mask_url', 'prompt') }
    'fal-ai/kling-video/v2.6/pro/image-to-video'     = @{ required = @('image_url') }
    'fal-ai/kling-video/v2.6/pro/text-to-video'      = @{ required = @('prompt') }
    'fal-ai/veo3.1'                                  = @{ required = @('prompt') }
}

# Parameters that are auto-injected by the workflow engine from prior step output
$AutoInjectedParams = @('image_url')

# ─── Load steps from file if needed ─────────────────────────────────────────
if ($PSCmdlet.ParameterSetName -eq 'File') {
    $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
    $Steps = @()
    $stepsData = if ($json.Steps) { $json.Steps } else { $json }
    foreach ($s in $stepsData) {
        $ht = @{
            name      = $s.name
            model     = $s.model
            params    = @{}
            dependsOn = @()
        }
        if ($s.params) {
            $s.params.PSObject.Properties | ForEach-Object { $ht.params[$_.Name] = $_.Value }
        }
        if ($s.dependsOn) { $ht.dependsOn = @($s.dependsOn) }
        $Steps += $ht
    }
}

# ─── Validation state ───────────────────────────────────────────────────────
$errors   = [System.Collections.ArrayList]::new()
$warnings = [System.Collections.ArrayList]::new()

# ─── 1. Validate step structure ─────────────────────────────────────────────
if ($Steps.Count -eq 0) {
    [void]$errors.Add('Workflow has no steps.')
}

$stepNames = @{}
foreach ($step in $Steps) {
    # Required fields
    if (-not $step.name) {
        [void]$errors.Add("A step is missing the required 'name' field.")
        continue
    }
    if (-not $step.model) {
        [void]$errors.Add("Step '$($step.name)': missing required 'model' field.")
    }

    # Duplicate names
    if ($stepNames.ContainsKey($step.name)) {
        [void]$errors.Add("Duplicate step name: '$($step.name)'.")
    }
    $stepNames[$step.name] = $true

    # Model validation
    if ($step.model -and -not $KnownModels.ContainsKey($step.model)) {
        [void]$warnings.Add("Step '$($step.name)': model '$($step.model)' is not in the known models list. It may still work if the endpoint is valid.")
    }
}

# ─── 2. Validate dependencies ───────────────────────────────────────────────
foreach ($step in $Steps) {
    if (-not $step.name) { continue }
    $deps = $step.dependsOn
    if (-not $deps) { continue }

    foreach ($dep in $deps) {
        if (-not $stepNames.ContainsKey($dep)) {
            [void]$errors.Add("Step '$($step.name)' depends on unknown step '$dep'.")
        }
        if ($dep -eq $step.name) {
            [void]$errors.Add("Step '$($step.name)' depends on itself.")
        }
    }
}

# ─── 3. Check for circular dependencies via topological sort ────────────────
$executionOrder = @()

if ($errors.Count -eq 0) {
    $stepMap = @{}
    foreach ($step in $Steps) { $stepMap[$step.name] = $step }

    $visited  = @{}
    $visiting = @{}
    $order    = [System.Collections.ArrayList]::new()
    $hasCycle = $false

    function Test-Visit {
        param([string]$Name)
        if ($visiting[$Name]) {
            [void]$errors.Add("Circular dependency detected at step '$Name'.")
            $script:hasCycle = $true
            return
        }
        if ($visited[$Name]) { return }

        $visiting[$Name] = $true
        $deps = $stepMap[$Name].dependsOn
        if ($deps) {
            foreach ($d in $deps) {
                if ($stepMap.ContainsKey($d)) { Test-Visit $d }
            }
        }
        $visiting[$Name] = $false
        $visited[$Name] = $true
        [void]$order.Add($Name)
    }

    foreach ($step in $Steps) {
        if (-not $hasCycle) { Test-Visit $step.name }
    }

    if (-not $hasCycle) {
        $executionOrder = $order.ToArray()
    }
}

# ─── 4. Validate parameters against model requirements ──────────────────────
foreach ($step in $Steps) {
    if (-not $step.name -or -not $step.model) { continue }
    if (-not $KnownModels.ContainsKey($step.model)) { continue }

    $modelInfo = $KnownModels[$step.model]
    $stepParams = if ($step.params) { $step.params.Keys } else { @() }
    $hasDeps = $step.dependsOn -and $step.dependsOn.Count -gt 0

    foreach ($req in $modelInfo.required) {
        $provided = $stepParams -contains $req
        $autoInjectable = ($AutoInjectedParams -contains $req) -and $hasDeps

        if (-not $provided -and -not $autoInjectable) {
            [void]$errors.Add("Step '$($step.name)': missing required parameter '$req' for model '$($step.model)'.")
        }
    }
}

# ─── 5. Chain compatibility warnings ────────────────────────────────────────
$videoModels = @(
    'fal-ai/kling-video/v2.6/pro/image-to-video'
    'fal-ai/kling-video/v2.6/pro/text-to-video'
    'fal-ai/veo3.1'
)

foreach ($step in $Steps) {
    if (-not $step.dependsOn) { continue }
    foreach ($dep in $step.dependsOn) {
        $depStep = $Steps | Where-Object { $_.name -eq $dep }
        if ($depStep -and ($depStep.model -in $videoModels)) {
            $targetNeedsImage = $KnownModels[$step.model].required -contains 'image_url'
            if ($targetNeedsImage) {
                [void]$warnings.Add("Step '$($step.name)' depends on video step '$dep'. Video output cannot chain to image-based steps.")
            }
        }
    }
}

# ─── Build result ────────────────────────────────────────────────────────────
$result = [PSCustomObject]@{
    Valid          = $errors.Count -eq 0
    Errors         = $errors.ToArray()
    Warnings       = $warnings.ToArray()
    StepCount      = $Steps.Count
    ExecutionOrder = $executionOrder
}

if ($result.Valid) {
    Write-Host "✅ Workflow is valid ($($result.StepCount) steps)" -ForegroundColor Green
    if ($result.Warnings.Count -gt 0) {
        foreach ($w in $result.Warnings) {
            Write-Host "  ⚠ $w" -ForegroundColor Yellow
        }
    }
    Write-Host "  Execution order: $($result.ExecutionOrder -join ' → ')" -ForegroundColor Cyan
}
else {
    Write-Host "❌ Workflow validation failed ($($result.Errors.Count) errors)" -ForegroundColor Red
    foreach ($e in $result.Errors) {
        Write-Host "  ✗ $e" -ForegroundColor Red
    }
    if ($result.Warnings.Count -gt 0) {
        foreach ($w in $result.Warnings) {
            Write-Host "  ⚠ $w" -ForegroundColor Yellow
        }
    }
}

$result
