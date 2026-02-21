<#
.SYNOPSIS
    Get the input/output schema for a fal.ai model.
.DESCRIPTION
    Fetches the OpenAPI schema for a fal.ai model and extracts the input
    parameters and output fields. Useful for discovering what parameters
    a model accepts before calling it.
.PARAMETER ModelId
    The fal.ai model endpoint ID (e.g., 'fal-ai/flux/dev').
.PARAMETER InputOnly
    Show only the input schema.
.PARAMETER OutputOnly
    Show only the output schema.
.EXAMPLE
    .\Get-ModelSchema.ps1 -ModelId "fal-ai/flux/dev"
.EXAMPLE
    .\Get-ModelSchema.ps1 -ModelId "fal-ai/flux-pro/v1.1-ultra" -InputOnly
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ModelId,

    [switch]$InputOnly,

    [switch]$OutputOnly
)

$ErrorActionPreference = 'Stop'

# Load shared module
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

$encodedModel = [uri]::EscapeDataString($ModelId)
$url = "https://fal.ai/api/openapi/queue/openapi.json?endpoint_id=$encodedModel"

Write-Host "Fetching schema for $ModelId..." -ForegroundColor Cyan

$response = Invoke-RestMethod -Uri $url -Method GET -UseBasicParsing

# Extract metadata
$info = $response.info
$metadata = if ($info.'x-fal-metadata') { $info.'x-fal-metadata' } else { @{} }

# Find input/output schemas
$schemas = $response.components.schemas
$inputSchema  = $null
$outputSchema = $null

if ($schemas) {
    $schemas.PSObject.Properties | ForEach-Object {
        if ($_.Name -match 'Input' -and $_.Name -ne 'QueueStatus') {
            $inputSchema = $_.Value
        }
        elseif ($_.Name -match 'Output' -and $_.Name -ne 'QueueStatus') {
            $outputSchema = $_.Value
        }
    }
}

# Build structured output
$result = [PSCustomObject]@{
    ModelId      = $ModelId
    Category     = $metadata.category
    Playground   = $metadata.playgroundUrl
    Docs         = $metadata.documentationUrl
    InputSchema  = $null
    OutputSchema = $null
}

if ($inputSchema -and -not $OutputOnly) {
    $props = $inputSchema.properties
    $required = @($inputSchema.required)
    $inputFields = @()

    if ($props) {
        $props.PSObject.Properties | ForEach-Object {
            $prop = $_.Value
            $propType = if ($prop.type) { $prop.type } elseif ($prop.enum) { "enum" } else { "any" }
            $inputFields += [PSCustomObject]@{
                Name        = $_.Name
                Type        = $propType
                Required    = ($_.Name -in $required)
                Default     = $prop.default
                Description = $prop.description
                Enum        = $prop.enum
            }
        }
    }
    $result.InputSchema = $inputFields
}

if ($outputSchema -and -not $InputOnly) {
    $props = $outputSchema.properties
    $outputFields = @()

    if ($props) {
        $props.PSObject.Properties | ForEach-Object {
            $prop = $_.Value
            $propType = if ($prop.type) { $prop.type } else { "any" }
            if ($propType -eq 'array' -and $prop.items) {
                $itemType = if ($prop.items.type) { $prop.items.type }
                            elseif ($prop.items.'$ref') { ($prop.items.'$ref' -split '/')[-1] }
                            else { 'any' }
                $propType = "array<$itemType>"
            }
            $outputFields += [PSCustomObject]@{
                Name        = $_.Name
                Type        = $propType
                Description = $prop.description
            }
        }
    }
    $result.OutputSchema = $outputFields
}

# Display summary
if ($result.InputSchema -and -not $OutputOnly) {
    Write-Host "`nInput Parameters:" -ForegroundColor Green
    $result.InputSchema | Format-Table Name, Type, Required, Default -AutoSize | Out-Host
}

if ($result.OutputSchema -and -not $InputOnly) {
    Write-Host "`nOutput Fields:" -ForegroundColor Green
    $result.OutputSchema | Format-Table Name, Type -AutoSize | Out-Host
}

$result
