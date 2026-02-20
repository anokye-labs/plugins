<#
.SYNOPSIS
    Generate music from text prompts using fal.ai models.
.DESCRIPTION
    Submits a music generation request to fal.ai via the queue API and
    returns an audio URL. Supports MiniMax Music, Lyria2, ElevenLabs Music,
    Sonauto, Ace Step, and Beatoven.
.PARAMETER Prompt
    Text description of the music to generate (required).
.PARAMETER Model
    The fal.ai music model endpoint. Default: fal-ai/minimax-music/v2.
.PARAMETER Duration
    Target duration in seconds (model-dependent support).
.PARAMETER OutputFormat
    Audio output format (e.g., "mp3", "wav"). Model-dependent support.
.EXAMPLE
    .\Invoke-FalMusicGen.ps1 -Prompt "Upbeat jazz with piano and drums"
.EXAMPLE
    .\Invoke-FalMusicGen.ps1 -Prompt "Epic orchestral battle theme" -Model "fal-ai/lyria2" -Duration 30
.EXAMPLE
    .\Invoke-FalMusicGen.ps1 -Prompt "Chill lo-fi hip hop" -Model "fal-ai/sonauto/v2" -OutputFormat "wav"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Prompt,

    [string]$Model = 'fal-ai/minimax-music/v2',

    [int]$Duration,

    [string]$OutputFormat
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

# Build payload
$body = @{ prompt = $Prompt }
if ($PSBoundParameters.ContainsKey('Duration'))     { $body.duration      = $Duration }
if ($PSBoundParameters.ContainsKey('OutputFormat')) { $body.output_format = $OutputFormat }

# Execute via queue
Write-Host "Generating music with $Model..." -ForegroundColor Cyan
$result = Wait-FalJob -Model $Model -Body $body

# Build output
$output = [PSCustomObject]@{
    AudioUrl = $null
    Duration = $null
    Model    = $Model
    Prompt   = $Prompt
}

if ($result.audio) {
    $output.AudioUrl = $result.audio.url
    if ($result.audio.duration) { $output.Duration = $result.audio.duration }
}
elseif ($result.audio_url) {
    $output.AudioUrl = $result.audio_url
}

if ($output.AudioUrl) {
    Write-Host "Music: $($output.AudioUrl)" -ForegroundColor Green
}

$output
