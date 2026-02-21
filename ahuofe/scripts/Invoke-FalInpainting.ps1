<#
.SYNOPSIS
    Edit regions of an image using fal.ai inpainting.
.DESCRIPTION
    Applies inpainting to masked regions of an image using a text prompt.
    Supports both synchronous and queue-based modes.
.PARAMETER ImageUrl
    URL of the source image (required).
.PARAMETER MaskUrl
    URL of the mask image — white regions are inpainted (required).
.PARAMETER Prompt
    Text description of what to paint in the masked area (required).
.PARAMETER Model
    The fal.ai inpainting model endpoint. Default: fal-ai/inpainting.
.PARAMETER Strength
    Inpainting strength (0.0–1.0). Default: 0.85.
.PARAMETER NumInferenceSteps
    Number of denoising steps. Default: 30.
.PARAMETER GuidanceScale
    Classifier-free guidance scale. Default: 7.5.
.PARAMETER Queue
    Use queue mode (submit, poll, retrieve) instead of synchronous.
.EXAMPLE
    .\Invoke-FalInpainting.ps1 -ImageUrl "https://..." -MaskUrl "https://..." -Prompt "a red rose"
.EXAMPLE
    .\Invoke-FalInpainting.ps1 -ImageUrl "https://..." -MaskUrl "https://..." -Prompt "blue sky" -Queue
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ImageUrl,

    [Parameter(Mandatory)]
    [string]$MaskUrl,

    [Parameter(Mandatory)]
    [string]$Prompt,

    [string]$Model = 'fal-ai/inpainting',

    [double]$Strength = 0.85,

    [int]$NumInferenceSteps = 30,

    [double]$GuidanceScale = 7.5,

    [switch]$Queue
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

# Build payload
$body = @{
    image_url            = $ImageUrl
    mask_url             = $MaskUrl
    prompt               = $Prompt
    strength             = $Strength
    num_inference_steps  = $NumInferenceSteps
    guidance_scale       = $GuidanceScale
}

# Execute
if ($Queue) {
    Write-Host "Submitting inpainting to queue: $Model..." -ForegroundColor Cyan
    $result = Wait-FalJob -Model $Model -Body $body
}
else {
    Write-Host "Inpainting with $Model (sync)..." -ForegroundColor Cyan
    $result = Invoke-FalApi -Method POST -Endpoint $Model -Body $body
}

# Build output
$output = [PSCustomObject]@{
    Images = @()
    Seed   = $null
}

if ($result.images) {
    $output.Images = @($result.images | ForEach-Object {
        [PSCustomObject]@{
            Url    = $_.url
            Width  = $_.width
            Height = $_.height
        }
    })
}

if ($result.seed) { $output.Seed = $result.seed }

# Display summary
foreach ($img in $output.Images) {
    Write-Host "Image: $($img.Url)" -ForegroundColor Green
}

$output
