BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:searchScript = Join-Path $script:repoRoot 'scripts' 'Search-FalModels.ps1'
    $script:schemaScript = Join-Path $script:repoRoot 'scripts' 'Get-ModelSchema.ps1'
    $script:modulePath = Join-Path $script:repoRoot 'scripts' 'FalAi.psm1'
    Import-Module $script:modulePath -Force
}

Describe 'E2E: Model Discovery' {
    BeforeEach {
        Mock Import-Module { } -ParameterFilter { "$Name" -like '*FalAi*' }
    }

    Context 'Search models by keyword' {
        It 'Should find models matching a keyword' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    data = @(
                        [PSCustomObject]@{ endpoint_id = 'fal-ai/flux/dev';     display_name = 'FLUX.1 [dev]';     category = 'text-to-image'; description = 'High-quality image generation' }
                        [PSCustomObject]@{ endpoint_id = 'fal-ai/flux/schnell'; display_name = 'FLUX.1 [schnell]'; category = 'text-to-image'; description = 'Fast image generation' }
                    )
                }
            }

            $env:FAL_KEY = 'test-key-123'
            try {
                $results = & $script:searchScript -Query 'flux'
                $results.Count | Should -Be 2
                $results[0].EndpointId | Should -Be 'fal-ai/flux/dev'
                $results[0].Name | Should -Be 'FLUX.1 [dev]'
                $results[1].EndpointId | Should -Be 'fal-ai/flux/schnell'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should return empty when no models match' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{ data = @() }
            }

            $env:FAL_KEY = 'test-key-123'
            try {
                $results = @(& $script:searchScript -Query 'nonexistent-model-xyz')
                $results.Count | Should -Be 0
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Filter by category' {
        It 'Should filter models by text-to-image category' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    data = @(
                        [PSCustomObject]@{ endpoint_id = 'fal-ai/flux/dev'; display_name = 'FLUX.1 [dev]'; category = 'text-to-image'; description = 'Image generation' }
                    )
                }
            }

            $env:FAL_KEY = 'test-key-123'
            try {
                $results = & $script:searchScript -Category 'text-to-image'
                $results.Count | Should -Be 1
                $results[0].Category | Should -Be 'text-to-image'
                Should -Invoke Invoke-RestMethod -ParameterFilter {
                    $Uri -like '*category=text-to-image*'
                }
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should filter models by video category' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    data = @(
                        [PSCustomObject]@{ endpoint_id = 'fal-ai/kling-video/v1/standard/text-to-video'; display_name = 'Kling Video'; category = 'text-to-video'; description = 'Video generation' }
                    )
                }
            }

            $env:FAL_KEY = 'test-key-123'
            try {
                $results = & $script:searchScript -Category 'text-to-video'
                $results.Count | Should -Be 1
                $results[0].Category | Should -Be 'text-to-video'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Model schema retrieval' {
        It 'Should retrieve input and output schema for a model' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    info = [PSCustomObject]@{
                        'x-fal-metadata' = [PSCustomObject]@{
                            category         = 'text-to-image'
                            playgroundUrl    = 'https://fal.ai/models/flux-dev'
                            documentationUrl = 'https://fal.ai/docs/flux-dev'
                        }
                    }
                    components = [PSCustomObject]@{
                        schemas = [PSCustomObject]@{
                            Input = [PSCustomObject]@{
                                required   = @('prompt')
                                properties = [PSCustomObject]@{
                                    prompt     = [PSCustomObject]@{ type = 'string';  description = 'The text prompt' }
                                    image_size = [PSCustomObject]@{ type = 'string';  description = 'Image size preset'; default = 'landscape_4_3' }
                                    seed       = [PSCustomObject]@{ type = 'integer'; description = 'Random seed' }
                                    num_images = [PSCustomObject]@{ type = 'integer'; description = 'Number of images'; default = 1 }
                                }
                            }
                            Output = [PSCustomObject]@{
                                properties = [PSCustomObject]@{
                                    images = [PSCustomObject]@{ type = 'array'; description = 'Generated images'; items = [PSCustomObject]@{ type = 'object' } }
                                    seed   = [PSCustomObject]@{ type = 'integer'; description = 'Seed used' }
                                }
                            }
                        }
                    }
                }
            }

            $env:FAL_KEY = 'test-key-123'
            try {
                $schema = & $script:schemaScript -ModelId 'fal-ai/flux/dev'
                $schema.ModelId | Should -Be 'fal-ai/flux/dev'
                $schema.InputSchema | Should -Not -BeNullOrEmpty
                $schema.OutputSchema | Should -Not -BeNullOrEmpty

                $promptField = $schema.InputSchema | Where-Object { $_.Name -eq 'prompt' }
                $promptField | Should -Not -BeNullOrEmpty
                $promptField.Required | Should -Be $true
                $promptField.Type | Should -Be 'string'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should retrieve only input schema when InputOnly is specified' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    info = [PSCustomObject]@{ 'x-fal-metadata' = @{} }
                    components = [PSCustomObject]@{
                        schemas = [PSCustomObject]@{
                            Input = [PSCustomObject]@{
                                required   = @('prompt')
                                properties = [PSCustomObject]@{
                                    prompt = [PSCustomObject]@{ type = 'string'; description = 'The prompt' }
                                }
                            }
                            Output = [PSCustomObject]@{
                                properties = [PSCustomObject]@{
                                    images = [PSCustomObject]@{ type = 'array'; description = 'Images' }
                                }
                            }
                        }
                    }
                }
            }

            $env:FAL_KEY = 'test-key-123'
            try {
                $schema = & $script:schemaScript -ModelId 'fal-ai/flux/dev' -InputOnly
                $schema.InputSchema | Should -Not -BeNullOrEmpty
                $schema.OutputSchema | Should -BeNullOrEmpty
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Model detail retrieval' {
        It 'Should include category and documentation URL in schema result' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    info = [PSCustomObject]@{
                        'x-fal-metadata' = [PSCustomObject]@{
                            category         = 'text-to-image'
                            playgroundUrl    = 'https://fal.ai/models/flux-pro'
                            documentationUrl = 'https://fal.ai/docs/flux-pro'
                        }
                    }
                    components = [PSCustomObject]@{
                        schemas = [PSCustomObject]@{
                            Input  = [PSCustomObject]@{ required = @(); properties = [PSCustomObject]@{} }
                            Output = [PSCustomObject]@{ properties = [PSCustomObject]@{} }
                        }
                    }
                }
            }

            $env:FAL_KEY = 'test-key-123'
            try {
                $schema = & $script:schemaScript -ModelId 'fal-ai/flux-pro/v1.1-ultra'
                $schema.Category | Should -Be 'text-to-image'
                $schema.Playground | Should -Be 'https://fal.ai/models/flux-pro'
                $schema.Docs | Should -Be 'https://fal.ai/docs/flux-pro'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should respect the Limit parameter in model search' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    data = @(
                        [PSCustomObject]@{ endpoint_id = 'fal-ai/flux/dev'; display_name = 'FLUX'; category = 'text-to-image'; description = 'Image gen' }
                    )
                }
            }

            $env:FAL_KEY = 'test-key-123'
            try {
                & $script:searchScript -Query 'flux' -Limit 5 | Out-Null
                Should -Invoke Invoke-RestMethod -ParameterFilter {
                    $Uri -like '*limit=5*'
                }
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }
}
