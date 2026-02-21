#Requires -Version 5.1
<#
.SYNOPSIS
    Export PowerShell workflow steps to fal.ai native workflow JSON format.
.DESCRIPTION
    Converts a PowerShell step array (as used by New-FalWorkflow.ps1) into the
    fal.ai platform-native workflow JSON format, enabling interoperability with
    the fal.ai workflow editor UI.
.PARAMETER Name
    Workflow identifier (used as the JSON "name" field).
.PARAMETER Title
    Display title for the workflow.
.PARAMETER Steps
    Array of hashtables defining workflow steps.
    Each step: @{ name = 'step1'; model = 'fal-ai/flux/dev'; params = @{ prompt = '...' }; dependsOn = @() }
.PARAMETER Description
    Optional description for the workflow.
.PARAMETER OutputPath
    File path to save the JSON output. If omitted, JSON is written to stdout.
.EXAMPLE
    $steps = @(
        @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'A mountain' }; dependsOn = @() }
        @{ name = 'animate'; model = 'fal-ai/kling-video/v2.6/pro/image-to-video'; params = @{ prompt = 'Zoom in' }; dependsOn = @('generate') }
    )
    .\Export-FalWorkflowJson.ps1 -Name 'img-to-vid' -Title 'Image to Video' -Steps $steps
.EXAMPLE
    .\Export-FalWorkflowJson.ps1 -Name 'my-workflow' -Title 'My Workflow' -Steps $steps -OutputPath './workflow.json'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Name,

    [Parameter(Mandatory)]
    [string]$Title,

    [Parameter(Mandatory)]
    [hashtable[]]$Steps,

    [string]$Description,

    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

# ─── Helpers ─────────────────────────────────────────────────────────────────

function Get-NodeId {
    param([string]$StepName)
    return "node-$StepName"
}

function Get-ModelOutputType {
    <#
    .SYNOPSIS
        Returns a canonical output type string for a given fal.ai model name.
    .OUTPUTS
        'video'        — model produces video.url
        'single_image' — model produces image.url (single processed image)
        'image_array'  — model produces images[].url (default generation output)
    #>
    param([string]$Model)
    if ($Model -match 'video|veo') { return 'video' }
    if ($Model -match 'aura-sr|upscale') { return 'single_image' }
    return 'image_array'
}

function Get-OutputRef {
    <#
    .SYNOPSIS
        Returns the fal.ai node output reference string for a given model.
    #>
    param([string]$NodeId, [string]$Model)
    switch (Get-ModelOutputType $Model) {
        'video'        { return '$' + "$NodeId.video.url" }
        'single_image' { return '$' + "$NodeId.image.url" }
        default        { return '$' + "$NodeId.images.0.url" }
    }
}

function Get-OutputFieldKey {
    <#
    .SYNOPSIS
        Returns the media-type key (image / video) used in output and display fields.
    #>
    param([string]$Model)
    if ((Get-ModelOutputType $Model) -eq 'video') { return 'video' }
    return 'image'
}

function Get-ParamType {
    <#
    .SYNOPSIS
        Maps a PowerShell value type to a fal.ai schema type string.
    #>
    param($Value)
    if ($null -eq $Value) { return 'string' }
    switch ($Value.GetType().Name) {
        'Int32'   { return 'number' }
        'Int64'   { return 'number' }
        'Double'  { return 'number' }
        'Single'  { return 'number' }
        'Boolean' { return 'boolean' }
        default   { return 'string' }
    }
}

function ConvertTo-TitleCase {
    param([string]$Value)
    return (Get-Culture).TextInfo.ToTitleCase(($Value -replace '_', ' '))
}

# ─── Validate steps ──────────────────────────────────────────────────────────

foreach ($step in $Steps) {
    if (-not $step.ContainsKey('name') -or [string]::IsNullOrWhiteSpace($step['name'])) {
        throw "Each workflow step must have a 'name' field."
    }
    if (-not $step.ContainsKey('model') -or [string]::IsNullOrWhiteSpace($step['model'])) {
        throw "Step '$($step['name'])' is missing the required 'model' field."
    }
}

# ─── Build step map ──────────────────────────────────────────────────────────

$stepMap = @{}
foreach ($step in $Steps) {
    $stepMap[$step.name] = $step
}

# ─── Build nodes ─────────────────────────────────────────────────────────────

$nodes = [ordered]@{}

foreach ($step in $Steps) {
    $nodeId = Get-NodeId $step.name
    $model  = $step.model
    if ($step.ContainsKey('params') -and $null -ne $step.params) {
        $params = $step.params
    } else {
        $params = @{}
    }
    if ($step.ContainsKey('dependsOn') -and $null -ne $step.dependsOn) {
        $deps = @($step.dependsOn)
    } else {
        $deps = @()
    }

    # depends: steps with no dependsOn attach to "input"; others attach to node-{dep}
    if ($deps.Count -gt 0) {
        $nodeDepends = @($deps | ForEach-Object { Get-NodeId $_ })
    } else {
        $nodeDepends = @('input')
    }

    # input: explicit params become $input.{key}; auto-injected image_url comes from dep output
    $nodeInput = [ordered]@{}

    if ($deps.Count -gt 0 -and -not $params.ContainsKey('image_url')) {
        $lastDep     = $deps[-1]
        $lastDepNode = Get-NodeId $lastDep
        $lastModel   = $stepMap[$lastDep].model
        $nodeInput['image_url'] = Get-OutputRef $lastDepNode $lastModel
    }

    foreach ($key in $params.Keys) {
        $nodeInput[$key] = '$input.' + $key
    }

    $nodes[$nodeId] = [ordered]@{
        type    = 'run'
        id      = $nodeId
        depends = $nodeDepends
        app     = $model
        input   = $nodeInput
    }
}

# ─── Find leaf nodes (steps nothing else depends on) ─────────────────────────

$dependedUpon = [System.Collections.Generic.HashSet[string]]::new()
foreach ($step in $Steps) {
    if ($step.ContainsKey('dependsOn') -and $step.dependsOn) {
        foreach ($dep in $step.dependsOn) {
            [void]$dependedUpon.Add($dep)
        }
    }
}
$leafSteps = @($Steps | Where-Object { -not $dependedUpon.Contains($_.name) })

# ─── Build display output node ───────────────────────────────────────────────

$outputDepends = @($leafSteps | ForEach-Object { Get-NodeId $_.name })
$outputFields  = [ordered]@{}

foreach ($leaf in $leafSteps) {
    $leafNodeId = Get-NodeId $leaf.name
    $fieldKey   = Get-OutputFieldKey $leaf.model
    if ($leafSteps.Count -gt 1) { $fieldKey = $leaf.name + '_' + $fieldKey }
    $outputFields[$fieldKey] = Get-OutputRef $leafNodeId $leaf.model
}

$nodes['output'] = [ordered]@{
    type    = 'display'
    id      = 'output'
    depends = $outputDepends
    input   = [ordered]@{}
    fields  = $outputFields
}

# ─── Build workflow-level output map ─────────────────────────────────────────

$workflowOutput = [ordered]@{}
foreach ($leaf in $leafSteps) {
    $leafNodeId = Get-NodeId $leaf.name
    $fieldKey   = Get-OutputFieldKey $leaf.model
    if ($leafSteps.Count -gt 1) { $fieldKey = $leaf.name + '_' + $fieldKey }
    $workflowOutput[$fieldKey] = Get-OutputRef $leafNodeId $leaf.model
}

# ─── Build schema.input from all explicit params ─────────────────────────────

$schemaInput = [ordered]@{}
foreach ($step in $Steps) {
    $nodeId = Get-NodeId $step.name
    if ($step.ContainsKey('params') -and $null -ne $step.params) {
        $params = $step.params
    } else {
        $params = @{}
    }
    foreach ($key in $params.Keys) {
        if (-not $schemaInput.Contains($key)) {
            $schemaInput[$key] = [ordered]@{
                name     = $key
                label    = ConvertTo-TitleCase $key
                type     = Get-ParamType $params[$key]
                required = $true
                modelId  = $nodeId
            }
        }
    }
}

# ─── Build schema.output ─────────────────────────────────────────────────────

$schemaOutput = [ordered]@{}
foreach ($leaf in $leafSteps) {
    $fieldKey = Get-OutputFieldKey $leaf.model
    if ($leafSteps.Count -gt 1) { $fieldKey = $leaf.name + '_' + $fieldKey }
    $label = if ($fieldKey -match 'video') { 'Generated Video' } else { 'Generated Image' }
    $schemaOutput[$fieldKey] = [ordered]@{
        name  = $fieldKey
        label = $label
        type  = 'string'
    }
}

# ─── Assemble workflow JSON ───────────────────────────────────────────────────

$workflow = [ordered]@{
    name     = $Name
    title    = $Title
    contents = [ordered]@{
        name    = 'workflow'
        nodes   = $nodes
        output  = $workflowOutput
        schema  = [ordered]@{
            input  = $schemaInput
            output = $schemaOutput
        }
        version  = '1'
        metadata = [ordered]@{
            input       = [ordered]@{ position = [ordered]@{ x = 0; y = 0 } }
            description = if ($Description) { $Description } else { $Title }
        }
    }
    is_public     = $true
    user_id       = ''
    user_nickname = ''
    created_at    = ''
}

$json = $workflow | ConvertTo-Json -Depth 20

if ($OutputPath) {
    $json | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Host "Workflow JSON saved to: $OutputPath" -ForegroundColor Green
} else {
    $json
}
