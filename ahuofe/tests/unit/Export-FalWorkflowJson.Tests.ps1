BeforeAll {
    $script:exportScript = Resolve-Path "$PSScriptRoot/../../scripts/Export-FalWorkflowJson.ps1"
}

Describe 'Export-FalWorkflowJson' {

    Context 'Single-step workflow' {
        It 'Produces valid fal.ai workflow JSON with a run node and display node' {
            $steps = @(
                @{
                    name      = 'generate'
                    model     = 'fal-ai/flux/dev'
                    params    = @{ prompt = 'A mountain' }
                    dependsOn = @()
                }
            )
            $json   = & $script:exportScript -Name 'test-wf' -Title 'Test Workflow' -Steps $steps
            $result = $json | ConvertFrom-Json

            $result.name              | Should -Be 'test-wf'
            $result.title             | Should -Be 'Test Workflow'
            $result.is_public         | Should -Be $true
            $result.contents.version  | Should -Be '1'
        }

        It 'Creates node-generate with type run and correct app' {
            $steps = @(
                @{
                    name      = 'generate'
                    model     = 'fal-ai/flux/dev'
                    params    = @{ prompt = 'A castle' }
                    dependsOn = @()
                }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps
            $result = $json | ConvertFrom-Json

            $node = $result.contents.nodes.'node-generate'
            $node.type   | Should -Be 'run'
            $node.id     | Should -Be 'node-generate'
            $node.app    | Should -Be 'fal-ai/flux/dev'
        }

        It 'Step with no dependsOn depends on "input"' {
            $steps = @(
                @{
                    name      = 'generate'
                    model     = 'fal-ai/flux/dev'
                    params    = @{ prompt = 'A lake' }
                    dependsOn = @()
                }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps
            $result = $json | ConvertFrom-Json

            $node = $result.contents.nodes.'node-generate'
            $node.depends | Should -Contain 'input'
        }

        It 'Converts step params to $input.{key} references' {
            $steps = @(
                @{
                    name      = 'generate'
                    model     = 'fal-ai/flux/dev'
                    params    = @{ prompt = 'A lake'; image_size = 'landscape_16_9' }
                    dependsOn = @()
                }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps
            $result = $json | ConvertFrom-Json

            $node = $result.contents.nodes.'node-generate'
            $node.input.prompt     | Should -Be '$input.prompt'
            $node.input.image_size | Should -Be '$input.image_size'
        }

        It 'Generates schema.input entries from step params' {
            $steps = @(
                @{
                    name      = 'generate'
                    model     = 'fal-ai/flux/dev'
                    params    = @{ prompt = 'sunset' }
                    dependsOn = @()
                }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps
            $result = $json | ConvertFrom-Json

            $schema = $result.contents.schema.input
            $schema.prompt.name    | Should -Be 'prompt'
            $schema.prompt.type    | Should -Be 'string'
            $schema.prompt.modelId | Should -Be 'node-generate'
            $schema.prompt.required | Should -Be $true
        }

        It 'Generates schema.output with image key for image models' {
            $steps = @(
                @{
                    name      = 'generate'
                    model     = 'fal-ai/flux/dev'
                    params    = @{ prompt = 'forest' }
                    dependsOn = @()
                }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps
            $result = $json | ConvertFrom-Json

            $result.contents.schema.output.image.type  | Should -Be 'string'
            $result.contents.schema.output.image.label | Should -Be 'Generated Image'
        }

        It 'Creates display output node referencing the leaf step' {
            $steps = @(
                @{
                    name      = 'generate'
                    model     = 'fal-ai/flux/dev'
                    params    = @{ prompt = 'mountains' }
                    dependsOn = @()
                }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps
            $result = $json | ConvertFrom-Json

            $display = $result.contents.nodes.output
            $display.type             | Should -Be 'display'
            $display.id               | Should -Be 'output'
            $display.depends          | Should -Contain 'node-generate'
            $display.fields.image     | Should -Be '$node-generate.images.0.url'
        }

        It 'Sets workflow-level output to leaf step output ref' {
            $steps = @(
                @{
                    name      = 'generate'
                    model     = 'fal-ai/flux/dev'
                    params    = @{ prompt = 'mountains' }
                    dependsOn = @()
                }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps
            $result = $json | ConvertFrom-Json

            $result.contents.output.image | Should -Be '$node-generate.images.0.url'
        }
    }

    Context 'Multi-step workflow with dependsOn' {
        It 'Dependent step gets depends array with node-{dep} IDs' {
            $steps = @(
                @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'eagle' }; dependsOn = @() }
                @{ name = 'animate'; model = 'fal-ai/kling-video/v2.6/pro/image-to-video'; params = @{ prompt = 'fly' }; dependsOn = @('generate') }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps
            $result = $json | ConvertFrom-Json

            $result.contents.nodes.'node-animate'.depends | Should -Contain 'node-generate'
        }

        It 'Auto-injects image_url reference from image dep into dependent step' {
            $steps = @(
                @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'eagle' }; dependsOn = @() }
                @{ name = 'animate'; model = 'fal-ai/kling-video/v2.6/pro/image-to-video'; params = @{ prompt = 'fly' }; dependsOn = @('generate') }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps
            $result = $json | ConvertFrom-Json

            $result.contents.nodes.'node-animate'.input.image_url | Should -Be '$node-generate.images.0.url'
        }

        It 'Explicit image_url in params takes precedence over auto-injection' {
            $steps = @(
                @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'eagle' }; dependsOn = @() }
                @{ name = 'edit'; model = 'fal-ai/inpainting'; params = @{ image_url = 'https://example.com/custom.png'; prompt = 'fire' }; dependsOn = @('generate') }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps
            $result = $json | ConvertFrom-Json

            $result.contents.nodes.'node-edit'.input.image_url | Should -Be '$input.image_url'
        }

        It 'Only leaf step is referenced in display output node depends' {
            $steps = @(
                @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'eagle' }; dependsOn = @() }
                @{ name = 'animate'; model = 'fal-ai/kling-video/v2.6/pro/image-to-video'; params = @{ prompt = 'fly' }; dependsOn = @('generate') }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps
            $result = $json | ConvertFrom-Json

            $display = $result.contents.nodes.output
            $display.depends | Should -Contain 'node-animate'
            $display.depends | Should -Not -Contain 'node-generate'
        }

        It 'Uses video.url reference for video model leaf step' {
            $steps = @(
                @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'eagle' }; dependsOn = @() }
                @{ name = 'animate'; model = 'fal-ai/kling-video/v2.6/pro/image-to-video'; params = @{ prompt = 'fly' }; dependsOn = @('generate') }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps
            $result = $json | ConvertFrom-Json

            $result.contents.nodes.output.fields.video | Should -Be '$node-animate.video.url'
            $result.contents.output.video              | Should -Be '$node-animate.video.url'
        }

        It 'Generates video key in schema.output for video leaf steps' {
            $steps = @(
                @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'eagle' }; dependsOn = @() }
                @{ name = 'animate'; model = 'fal-ai/kling-video/v2.6/pro/image-to-video'; params = @{ prompt = 'fly' }; dependsOn = @('generate') }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps
            $result = $json | ConvertFrom-Json

            $result.contents.schema.output.video.label | Should -Be 'Generated Video'
        }

        It 'Uses image.url reference for upscale model' {
            $steps = @(
                @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'castle' }; dependsOn = @() }
                @{ name = 'upscale'; model = 'fal-ai/aura-sr'; params = @{}; dependsOn = @('generate') }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps
            $result = $json | ConvertFrom-Json

            $result.contents.nodes.'node-upscale'.input.image_url | Should -Be '$node-generate.images.0.url'
            $result.contents.nodes.output.fields.image            | Should -Be '$node-upscale.image.url'
        }

        It 'Handles steps with no params gracefully' {
            $steps = @(
                @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'castle' }; dependsOn = @() }
                @{ name = 'upscale'; model = 'fal-ai/aura-sr'; params = @{}; dependsOn = @('generate') }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps
            $result = $json | ConvertFrom-Json

            $result.contents.schema.input.PSObject.Properties.Name | Should -Not -Contain 'upscale'
        }
    }

    Context 'Optional parameters' {
        It 'Uses Description in metadata when provided' {
            $steps = @(
                @{ name = 'gen'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'x' }; dependsOn = @() }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps -Description 'My description'
            $result = $json | ConvertFrom-Json

            $result.contents.metadata.description | Should -Be 'My description'
        }

        It 'Falls back to Title for metadata description when Description omitted' {
            $steps = @(
                @{ name = 'gen'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'x' }; dependsOn = @() }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'My Title' -Steps $steps
            $result = $json | ConvertFrom-Json

            $result.contents.metadata.description | Should -Be 'My Title'
        }

        It 'Saves JSON to file when OutputPath is provided' {
            $steps = @(
                @{ name = 'gen'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'x' }; dependsOn = @() }
            )
            $tmpFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + '.json')
            try {
                & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps -OutputPath $tmpFile | Out-Null
                $tmpFile | Should -Exist
                $saved = Get-Content $tmpFile -Raw | ConvertFrom-Json
                $saved.name | Should -Be 'wf'
            }
            finally {
                if (Test-Path $tmpFile) { Remove-Item $tmpFile -Force }
            }
        }
    }

    Context 'Schema inference' {
        It 'Infers number type for numeric param values' {
            $steps = @(
                @{
                    name      = 'upscale'
                    model     = 'fal-ai/aura-sr'
                    params    = @{ scale = 2; strength = 0.85 }
                    dependsOn = @()
                }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps
            $result = $json | ConvertFrom-Json

            $result.contents.schema.input.scale.type    | Should -Be 'number'
            $result.contents.schema.input.strength.type | Should -Be 'number'
        }

        It 'Does not duplicate schema.input keys defined in multiple steps' {
            $steps = @(
                @{ name = 'step1'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'a' }; dependsOn = @() }
                @{ name = 'step2'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'b' }; dependsOn = @() }
            )
            $json   = & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps
            $result = $json | ConvertFrom-Json

            ($result.contents.schema.input.PSObject.Properties | Where-Object Name -eq 'prompt').Count | Should -Be 1
        }
    }

    Context 'Error handling' {
        It 'Throws when a step is missing the name field' {
            $steps = @(
                @{ model = 'fal-ai/flux/dev'; params = @{ prompt = 'x' } }
            )
            { & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps } | Should -Throw "*name*"
        }

        It 'Throws when a step is missing the model field' {
            $steps = @(
                @{ name = 'gen'; params = @{ prompt = 'x' } }
            )
            { & $script:exportScript -Name 'wf' -Title 'WF' -Steps $steps } | Should -Throw "*model*"
        }
    }
}
