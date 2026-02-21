<#
.SYNOPSIS
    Convert text to speech using fal.ai TTS models.
.DESCRIPTION
    Sends a text-to-speech request to fal.ai via the queue API and returns
    an audio URL. Supports multiple TTS models including MiniMax, ElevenLabs,
    Chatterbox, and Kling TTS.
.PARAMETER Text
    The text to convert to speech (required).
.PARAMETER Model
    The fal.ai TTS model endpoint. Default: fal-ai/minimax/speech-2.6-turbo.
.PARAMETER Voice
    Voice identifier for the selected model (model-specific).
.PARAMETER OutputPath
    Optional local file path to save the downloaded audio.
.EXAMPLE
    .\Invoke-FalTextToSpeech.ps1 -Text "Hello, world!"
.EXAMPLE
    .\Invoke-FalTextToSpeech.ps1 -Text "Welcome back!" -Model "fal-ai/elevenlabs/eleven-v3" -Voice "Rachel"
.EXAMPLE
    .\Invoke-FalTextToSpeech.ps1 -Text "Save this audio" -OutputPath ".\output\speech.mp3"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Text,

    [string]$Model = 'fal-ai/minimax/speech-2.6-turbo',

    [string]$Voice,

    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

# Build payload
$body = @{ text = $Text }
if ($PSBoundParameters.ContainsKey('Voice') -and $Voice) { $body.voice_id = $Voice }

# Execute via queue
Write-Host "Generating speech with $Model..." -ForegroundColor Cyan
$result = Wait-FalJob -Model $Model -Body $body

# Build output
$output = [PSCustomObject]@{
    AudioUrl = $null
    Duration = $null
    Model    = $Model
    Text     = $Text
}

if ($result.audio) {
    $output.AudioUrl = $result.audio.url
    if ($result.audio.duration) { $output.Duration = $result.audio.duration }
}
elseif ($result.audio_url) {
    $output.AudioUrl = $result.audio_url
}

# Download if OutputPath specified
if ($OutputPath -and $output.AudioUrl) {
    Invoke-WebRequest -Uri $output.AudioUrl -OutFile $OutputPath -UseBasicParsing
    Write-Host "Saved: $OutputPath" -ForegroundColor Green
}

if ($output.AudioUrl) {
    Write-Host "Audio: $($output.AudioUrl)" -ForegroundColor Green
}

$output
