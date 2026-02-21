<#
.SYNOPSIS
    Generate images or videos using fal.ai models.
.DESCRIPTION
    Converts a text prompt into images or videos via the fal.ai API.
    Supports both synchronous (fal.run) and queue-based (queue.fal.run) modes.
.PARAMETER Prompt
    The text description of the image/video to generate (required).
.PARAMETER Model
    The fal.ai model endpoint. Default: fal-ai/flux/dev.
.PARAMETER ImageSize
    Image size preset. Default: landscape_4_3.
.PARAMETER NumImages
    Number of images to generate. Default: 1.
.PARAMETER Seed
    Seed for reproducibility.
.PARAMETER ImageUrl
    Input image URL for image-to-image or image-to-video models.
.PARAMETER FilePath
    Local file to auto-upload to fal.ai CDN before generation. Automatically
    calls Send-FalFile and sets ImageUrl internally. Eliminates the manual
    upload step for image-to-image or image-to-video workflows.
    When both -FilePath and -ImageUrl are specified, -FilePath takes precedence.
.PARAMETER Strength
    Strength for img2img models (0.0-1.0).
.PARAMETER NumInferenceSteps
    Number of inference steps.
.PARAMETER GuidanceScale
    Classifier-free guidance scale.
.PARAMETER EnableSafetyChecker
    Enable the safety checker.
.PARAMETER Queue
    Use queue mode (submit, poll, retrieve) instead of synchronous.
.PARAMETER Async
    Submit to the queue and return the RequestId immediately without waiting
    for the job to complete. Useful for long-running video generation jobs.
    Use Get-QueueStatus.ps1 to check progress later.
.PARAMETER Lifecycle
    Expiration time in seconds for generated files on the fal.ai CDN.
    Passed through to the queue submission payload. Only meaningful when
    using -Queue or -Async mode.
.EXAMPLE
    .\Invoke-FalGenerate.ps1 -Prompt "A serene mountain landscape"
.EXAMPLE
    .\Invoke-FalGenerate.ps1 -Prompt "Ocean waves" -Model "fal-ai/flux/schnell" -Queue
.EXAMPLE
    .\Invoke-FalGenerate.ps1 -Prompt "Zoom in" -Model "fal-ai/kling-video/v2.6/pro/image-to-video" -ImageUrl "https://example.com/img.jpg" -Queue
.EXAMPLE
    .\Invoke-FalGenerate.ps1 -Prompt "Animate this photo" -Model "fal-ai/kling-video/v2.6/pro/image-to-video" -FilePath ".\photo.jpg" -Queue
.EXAMPLE
    $requestId = .\Invoke-FalGenerate.ps1 -Prompt "Epic battle" -Model "fal-ai/veo3.1" -Async
    # Returns immediately: "abc123-def456"
    # Check later: .\Get-QueueStatus.ps1 -RequestId $requestId -Model "fal-ai/veo3.1"
.EXAMPLE
    .\Invoke-FalGenerate.ps1 -Prompt "Sunset scene" -Model "fal-ai/flux/dev" -Lifecycle 3600 -Queue
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Prompt,

    [string]$Model = 'fal-ai/flux/dev',

    [string]$ImageSize = 'landscape_4_3',

    [int]$NumImages = 1,

    [int]$Seed,

    [string]$ImageUrl,

    [string]$FilePath,

    [double]$Strength,

    [int]$NumInferenceSteps,

    [double]$GuidanceScale,

    [switch]$EnableSafetyChecker,

    [switch]$Queue,

    [switch]$Async,

    [int]$Lifecycle
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

# Auto-upload local file if FilePath provided
if ($FilePath) {
    Write-Host "Uploading $FilePath to fal.ai CDN..." -ForegroundColor Cyan
    $ImageUrl = Send-FalFile -FilePath $FilePath
    Write-Host "Uploaded: $ImageUrl" -ForegroundColor DarkCyan
}

# Build payload
$body = @{ prompt = $Prompt }

# Determine model type and build payload accordingly
$isI2V = $Model -match 'image-to-video|i2v'
$isVideo = $Model -match 'video|veo|text-to-video'

if ($isI2V) {
    if (-not $ImageUrl) {
        throw '--ImageUrl is required for image-to-video models.'
    }
    $body.image_url = $ImageUrl
    if ($Prompt) { $body.prompt = $Prompt }
}
elseif (-not $isVideo) {
    # Image model — include size and count
    $body.image_size = $ImageSize
    $body.num_images = $NumImages
}

# Optional parameters
if ($PSBoundParameters.ContainsKey('Seed'))                { $body.seed = $Seed }
if ($PSBoundParameters.ContainsKey('Strength'))            { $body.strength = $Strength }
if ($PSBoundParameters.ContainsKey('NumInferenceSteps'))   { $body.num_inference_steps = $NumInferenceSteps }
if ($PSBoundParameters.ContainsKey('GuidanceScale'))       { $body.guidance_scale = $GuidanceScale }
if ($PSBoundParameters.ContainsKey('EnableSafetyChecker')) { $body.enable_safety_checker = $EnableSafetyChecker.IsPresent }
if ($ImageUrl -and -not $isI2V)                            { $body.image_url = $ImageUrl }
if ($PSBoundParameters.ContainsKey('Lifecycle'))           { $body.x_fal_lifecycle = $Lifecycle }

# Execute
if ($Async) {
    Write-Host "Submitting to queue (async): $Model..." -ForegroundColor Cyan
    $submitResult = Invoke-FalApi -Method POST -Endpoint $Model -Body $body -BaseUrl 'https://queue.fal.run'
    $requestId = $submitResult.request_id
    if (-not $requestId) {
        $msg = ConvertTo-FalError $submitResult
        throw "Queue submission failed: $msg"
    }
    return $requestId
}
elseif ($Queue) {
    Write-Host "Submitting to queue: $Model..." -ForegroundColor Cyan
    $result = Wait-FalJob -Model $Model -Body $body
}
else {
    Write-Host "Generating with $Model (sync)..." -ForegroundColor Cyan
    $result = Invoke-FalApi -Method POST -Endpoint $Model -Body $body
}

# Build output
$output = [PSCustomObject]@{
    Images = @()
    Seed   = $null
    Prompt = $Prompt
    Model  = $Model
    Video  = $null
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

if ($result.video) {
    $output.Video = [PSCustomObject]@{
        Url = $result.video.url
    }
}

if ($result.seed) { $output.Seed = $result.seed }

# Display summary
if ($output.Images.Count -gt 0) {
    foreach ($img in $output.Images) {
        Write-Host "Image: $($img.Url)" -ForegroundColor Green
    }
}
if ($output.Video) {
    Write-Host "Video: $($output.Video.Url)" -ForegroundColor Green
}

$output
