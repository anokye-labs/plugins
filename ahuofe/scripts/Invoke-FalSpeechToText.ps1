<#
.SYNOPSIS
    Transcribe audio to text using fal.ai STT models.
.DESCRIPTION
    Sends an audio URL to a fal.ai speech-to-text model and returns
    the transcription. Supports Whisper and ElevenLabs Scribe.
.PARAMETER AudioUrl
    URL of the audio file to transcribe (required).
.PARAMETER Model
    The fal.ai STT model endpoint. Default: fal-ai/whisper.
.PARAMETER Language
    Language code for transcription (e.g., "en", "es"). Default: auto-detect.
.EXAMPLE
    .\Invoke-FalSpeechToText.ps1 -AudioUrl "https://example.com/audio.mp3"
.EXAMPLE
    .\Invoke-FalSpeechToText.ps1 -AudioUrl "https://example.com/audio.mp3" -Language "es"
.EXAMPLE
    .\Invoke-FalSpeechToText.ps1 -AudioUrl "https://example.com/interview.mp3" -Model "fal-ai/elevenlabs/scribe"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AudioUrl,

    [string]$Model = 'fal-ai/whisper',

    [string]$Language
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

# Build payload
$body = @{ audio_url = $AudioUrl }
if ($PSBoundParameters.ContainsKey('Language') -and $Language) { $body.language = $Language }

# Execute
Write-Host "Transcribing with $Model..." -ForegroundColor Cyan
$result = Invoke-FalApi -Method POST -Endpoint $Model -Body $body

# Build output
$output = [PSCustomObject]@{
    Text     = $result.text
    Chunks   = @()
    Model    = $Model
    AudioUrl = $AudioUrl
}

if ($result.chunks) {
    $output.Chunks = @($result.chunks | ForEach-Object {
        [PSCustomObject]@{
            Text      = $_.text
            Timestamp = $_.timestamp
        }
    })
}

if ($output.Text) {
    Write-Host "Transcript: $($output.Text)" -ForegroundColor Green
}

$output
