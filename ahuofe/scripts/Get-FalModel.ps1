<#
.SYNOPSIS
    Retrieves model information and OpenAPI schema from fal.ai.
.DESCRIPTION
    Fetches the OpenAPI schema for a given fal.ai model, returning metadata,
    input parameters, and output fields.
.PARAMETER ModelId
    The fal.ai model endpoint, e.g. "fal-ai/flux/dev".
.PARAMETER InputOnly
    Show only the input schema.
.PARAMETER OutputOnly
    Show only the output schema.
.EXAMPLE
    .\Get-FalModel.ps1 -ModelId "fal-ai/flux/dev"
.EXAMPLE
    .\Get-FalModel.ps1 -ModelId "fal-ai/kling-video/v2.6/pro/image-to-video" -InputOnly
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

$encodedModel = $ModelId -replace '/', '%2F'
$schemaUrl = "https://fal.ai/api/openapi/queue/openapi.json?endpoint_id=$encodedModel"

Write-Host "Fetching schema for $ModelId..." -ForegroundColor Cyan

$response = Invoke-RestMethod -Uri $schemaUrl -Method GET `
    -Headers @{ 'Content-Type' = 'application/json' } -UseBasicParsing -ErrorAction Stop

# Extract metadata
$info = $response.info
$metadata = if ($info.'x-fal-metadata') { $info.'x-fal-metadata' } else { @{} }
$schemas  = if ($response.components.schemas) { $response.components.schemas } else { @{} }

# Find input/output schemas
$inputSchema  = $null
$outputSchema = $null

foreach ($name in $schemas.PSObject.Properties.Name) {
    $schema = $schemas.$name
    if ($name -match 'Input' -and $name -ne 'QueueStatus') {
        $inputSchema = $schema
    }
    elseif ($name -match 'Output' -and $name -ne 'QueueStatus') {
        $outputSchema = $schema
    }
}

# Build result
$result = [PSCustomObject]@{
    ModelId       = $ModelId
    Category      = $metadata.category
    PlaygroundUrl = $metadata.playgroundUrl
    DocsUrl       = $metadata.documentationUrl
    InputSchema   = $null
    OutputSchema  = $null
    RawSchema     = $response
}

# Parse input parameters
if ($inputSchema -and -not $OutputOnly) {
    $props    = $inputSchema.properties
    $required = @($inputSchema.required)

    $inputParams = @()
    if ($props) {
        foreach ($propName in $props.PSObject.Properties.Name) {
            $prop = $props.$propName
            $inputParams += [PSCustomObject]@{
                Name        = $propName
                Type        = $prop.type
                Required    = $propName -in $required
                Default     = $prop.default
                Description = $prop.description
                Enum        = $prop.enum
            }
        }
    }
    $result.InputSchema = $inputParams
}

# Parse output fields
if ($outputSchema -and -not $InputOnly) {
    $props = $outputSchema.properties
    $outputFields = @()
    if ($props) {
        foreach ($propName in $props.PSObject.Properties.Name) {
            $prop = $props.$propName
            $outputFields += [PSCustomObject]@{
                Name = $propName
                Type = $prop.type
            }
        }
    }
    $result.OutputSchema = $outputFields
}

# Display summary
Write-Host ''
Write-Host "Model: $ModelId" -ForegroundColor White
if ($result.Category) { Write-Host "Category: $($result.Category)" }
if ($result.PlaygroundUrl) { Write-Host "Playground: $($result.PlaygroundUrl)" }

if ($result.InputSchema -and -not $OutputOnly) {
    Write-Host ''
    Write-Host 'Input Parameters' -ForegroundColor Yellow
    Write-Host ('-' * 40)
    foreach ($p in $result.InputSchema) {
        $req = if ($p.Required) { '*' } else { ' ' }
        $def = if ($null -ne $p.Default) { " (default: $($p.Default))" } else { '' }
        Write-Host "  $req $($p.Name): $($p.Type)$def"
    }
}

if ($result.OutputSchema -and -not $InputOnly) {
    Write-Host ''
    Write-Host 'Output Fields' -ForegroundColor Yellow
    Write-Host ('-' * 40)
    foreach ($f in $result.OutputSchema) {
        Write-Host "  $($f.Name): $($f.Type)"
    }
}

$result
