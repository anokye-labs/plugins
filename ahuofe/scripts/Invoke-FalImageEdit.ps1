#Requires -Version 5.1
<#
.SYNOPSIS
    Edit images using fal.ai models with operation-based routing.
.DESCRIPTION
    Routes to the best fal.ai model based on the specified editing operation.
    Supports style transfer, object removal, background replacement,
    inpainting, and general edits. For the 'inpaint' operation, delegates
    to Invoke-FalInpainting.ps1 to avoid duplication.
.PARAMETER ImageUrl
    URL of the source image (required).
.PARAMETER Prompt
    Edit instruction describing the desired change (required).
.PARAMETER Operation
    The type of edit to perform:
      style      — Style transfer or artistic transform (default)
      remove     — Object/person removal without a mask
      background — Context-aware background replacement
      inpaint    — Precise mask-based region editing
      general    — Best overall editor for any edit
.PARAMETER MaskUrl
    URL of the mask image. Required when -Operation is 'inpaint'.
.PARAMETER Strength
    Edit strength (0.0–1.0). Default: 0.75.
    Subtle changes: 0.3–0.5. Dramatic changes: 0.7–0.9.
.PARAMETER Model
    Override the auto-selected model for the chosen operation.
.EXAMPLE
    .\Invoke-FalImageEdit.ps1 -ImageUrl "https://..." -Prompt "apply watercolor style"
.EXAMPLE
    .\Invoke-FalImageEdit.ps1 -ImageUrl "https://..." -Prompt "remove the car" -Operation remove
.EXAMPLE
    .\Invoke-FalImageEdit.ps1 -ImageUrl "https://..." -Prompt "mountain valley" -Operation background
.EXAMPLE
    .\Invoke-FalImageEdit.ps1 -ImageUrl "https://..." -MaskUrl "https://..." -Prompt "a red rose" -Operation inpaint
.EXAMPLE
    .\Invoke-FalImageEdit.ps1 -ImageUrl "https://..." -Prompt "enhance realism" -Operation general
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ImageUrl,

    [Parameter(Mandatory)]
    [string]$Prompt,

    [ValidateSet('style', 'remove', 'background', 'inpaint', 'general')]
    [string]$Operation = 'style',

    [string]$MaskUrl,

    [double]$Strength = 0.75,

    [string]$Model
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

# Operation → default model mapping
$operationModels = @{
    style      = 'fal-ai/flux/dev/image-to-image'
    remove     = 'fal-ai/bria/fibo-edit'
    background = 'fal-ai/flux-kontext'
    inpaint    = 'fal-ai/flux/dev/inpainting'
    general    = 'fal-ai/nano-banana-pro'
}

# Resolve model: explicit override takes precedence over operation default
$resolvedModel = if ($Model) { $Model } else { $operationModels[$Operation] }

# Validate inpaint requirement
if ($Operation -eq 'inpaint' -and -not $MaskUrl) {
    throw "-MaskUrl is required for the 'inpaint' operation."
}

Write-Host "Editing image with operation '$Operation' using $resolvedModel..." -ForegroundColor Cyan

# For inpaint, delegate to Invoke-FalInpainting.ps1 (no duplication)
if ($Operation -eq 'inpaint') {
    $inpaintScript = Join-Path $PSScriptRoot 'Invoke-FalInpainting.ps1'
    $result = & $inpaintScript `
        -ImageUrl $ImageUrl `
        -MaskUrl  $MaskUrl `
        -Prompt   $Prompt `
        -Model    $resolvedModel `
        -Strength $Strength
    $result | Add-Member -NotePropertyName Operation -NotePropertyValue $Operation -Force
    $result | Add-Member -NotePropertyName Model -NotePropertyValue $resolvedModel -Force
    return $result
}

# Build payload for non-inpaint operations
$body = @{
    image_url = $ImageUrl
    prompt    = $Prompt
    strength  = $Strength
}

# Execute via shared module
$apiResult = Invoke-FalApi -Method POST -Endpoint $resolvedModel -Body $body

# Build output
$output = [PSCustomObject]@{
    Images    = @()
    Seed      = $null
    Operation = $Operation
    Model     = $resolvedModel
}

if ($apiResult.images) {
    $output.Images = @($apiResult.images | ForEach-Object {
        [PSCustomObject]@{
            Url    = $_.url
            Width  = $_.width
            Height = $_.height
        }
    })
}

if ($apiResult.seed) { $output.Seed = $apiResult.seed }

# Display summary
foreach ($img in $output.Images) {
    Write-Host "Image: $($img.Url)" -ForegroundColor Green
}

$output
