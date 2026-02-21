BeforeAll {
    $scriptRoot = "$PSScriptRoot/../../scripts"
    Import-Module "$scriptRoot/FalAi.psm1" -Force

    # Set a fake API key for all tests
    $env:FAL_KEY = 'test-key-discovery'
}

AfterAll {
    $env:FAL_KEY = $null
}

Describe 'Search-FalModels' {
    BeforeAll {
        $script:searchScript = "$PSScriptRoot/../../scripts/Search-FalModels.ps1"
    }

    It 'Returns models matching a query' {
        Mock Invoke-RestMethod {
            return @{
                data = @(
                    @{ endpoint_id = 'fal-ai/flux/dev'; display_name = 'Flux Dev'; category = 'text-to-image'; description = 'Fast image gen' }
                    @{ endpoint_id = 'fal-ai/flux/schnell'; display_name = 'Flux Schnell'; category = 'text-to-image'; description = 'Ultra fast' }
                )
            }
        }

        $result = & $script:searchScript -Query 'flux' -Limit 5

        $result | Should -HaveCount 2
        $result[0].EndpointId | Should -Be 'fal-ai/flux/dev'
        $result[0].Name | Should -Be 'Flux Dev'
        $result[1].EndpointId | Should -Be 'fal-ai/flux/schnell'

        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Uri -like '*api.fal.ai/v1/models*' -and $Uri -like '*q=flux*' -and $Uri -like '*limit=5*'
        }
    }

    It 'Returns empty array when no models found' {
        Mock Invoke-RestMethod { return @{ data = @() } }

        $result = & $script:searchScript -Query 'nonexistent'

        $result | Should -HaveCount 0
    }

    It 'Includes category filter in request' {
        Mock Invoke-RestMethod { return @{ data = @() } }

        & $script:searchScript -Category 'text-to-video' | Out-Null

        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Uri -like '*category=text-to-video*'
        }
    }
}

Describe 'Get-ModelSchema' {
    BeforeAll {
        $script:schemaScript = "$PSScriptRoot/../../scripts/Get-ModelSchema.ps1"
    }

    It 'Returns input and output schema for a model' {
        Mock Invoke-RestMethod {
            return @{
                info = @{
                    'x-fal-metadata' = @{
                        category = 'text-to-image'
                        playgroundUrl = 'https://fal.ai/models/flux'
                    }
                }
                components = @{
                    schemas = [PSCustomObject]@{
                        'FluxInput' = @{
                            properties = [PSCustomObject]@{
                                prompt = @{ type = 'string'; description = 'Text prompt' }
                                seed   = @{ type = 'integer'; description = 'Random seed'; default = $null }
                            }
                            required = @('prompt')
                        }
                        'FluxOutput' = @{
                            properties = [PSCustomObject]@{
                                images = @{ type = 'array'; items = @{ type = 'object' }; description = 'Generated images' }
                                seed   = @{ type = 'integer'; description = 'Seed used' }
                            }
                        }
                    }
                }
            }
        }

        $result = & $script:schemaScript -ModelId 'fal-ai/flux/dev'

        $result.ModelId | Should -Be 'fal-ai/flux/dev'
        $result.Category | Should -Be 'text-to-image'
        $result.InputSchema | Should -Not -BeNullOrEmpty
        $result.OutputSchema | Should -Not -BeNullOrEmpty

        $promptField = $result.InputSchema | Where-Object Name -eq 'prompt'
        $promptField.Required | Should -BeTrue
        $promptField.Type | Should -Be 'string'
    }

    It 'Fetches schema from correct URL with encoded model ID' {
        Mock Invoke-RestMethod {
            return @{ info = @{}; components = @{ schemas = [PSCustomObject]@{} } }
        }

        & $script:schemaScript -ModelId 'fal-ai/flux-pro/v1.1-ultra' | Out-Null

        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Uri -like '*openapi.json*endpoint_id=fal-ai*flux-pro*'
        }
    }
}

Describe 'Get-QueueStatus' {
    BeforeAll {
        $script:queueScript = "$PSScriptRoot/../../scripts/Get-QueueStatus.ps1"
    }

    It 'Returns queue status for a request' {
        Mock Invoke-RestMethod {
            return @{
                status         = 'IN_QUEUE'
                queue_position = 3
                response_url   = 'https://queue.fal.run/fal-ai/flux/dev/requests/req-123'
                logs           = @()
            }
        }

        $result = & $script:queueScript -RequestId 'req-123' -Model 'fal-ai/flux/dev'

        $result.RequestId | Should -Be 'req-123'
        $result.Model | Should -Be 'fal-ai/flux/dev'
        $result.Status | Should -Be 'IN_QUEUE'
        $result.QueuePosition | Should -Be 3

        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Uri -eq 'https://queue.fal.run/fal-ai/flux/dev/requests/req-123/status'
        }
    }

    It 'Handles COMPLETED status' {
        Mock Invoke-RestMethod {
            return @{
                status         = 'COMPLETED'
                queue_position = $null
                response_url   = 'https://queue.fal.run/fal-ai/flux/dev/requests/req-456'
                logs           = @(@{ message = 'Done'; level = 'info' })
            }
        }

        $result = & $script:queueScript -RequestId 'req-456' -Model 'fal-ai/flux/dev'

        $result.Status | Should -Be 'COMPLETED'
        $result.Logs | Should -HaveCount 1
    }
}

Describe 'Get-FalUsage' {
    BeforeAll {
        $script:usageScript = "$PSScriptRoot/../../scripts/Get-FalUsage.ps1"
    }

    It 'Returns usage summary with endpoint breakdown' {
        Mock Invoke-RestMethod {
            return @{
                summary = @{
                    total_cost     = 1.2345
                    total_requests = 42
                }
                time_series = @(
                    @{
                        results = @(
                            @{ endpoint_id = 'fal-ai/flux/dev'; cost = 0.5; quantity = 20 }
                            @{ endpoint_id = 'fal-ai/flux/schnell'; cost = 0.3; quantity = 15 }
                        )
                    }
                    @{
                        results = @(
                            @{ endpoint_id = 'fal-ai/flux/dev'; cost = 0.4345; quantity = 7 }
                        )
                    }
                )
            }
        }

        $result = & $script:usageScript -Days 7

        $result.TotalCost | Should -Be 1.2345
        $result.TotalRequests | Should -Be 42
        $result.ByEndpoint | Should -HaveCount 2

        $fluxDev = $result.ByEndpoint | Where-Object EndpointId -eq 'fal-ai/flux/dev'
        $fluxDev.Cost | Should -BeGreaterThan 0.9
        $fluxDev.Quantity | Should -Be 27

        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Uri -like '*api.fal.ai/v1/models/usage*' -and $Uri -like '*expand=*'
        }
    }

    It 'Includes model filter in request URL' {
        Mock Invoke-RestMethod {
            return @{ summary = @{}; time_series = @() }
        }

        & $script:usageScript -Model 'fal-ai/flux/dev' | Out-Null

        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Uri -like '*endpoint_id=fal-ai*flux*dev*'
        }
    }
}
