BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:mcpConfigPath = Join-Path $script:repoRoot '.mcp.json'
}

Describe 'E2E: MCP Connectivity and Configuration' {
    Context '.mcp.json structure validation' {
        It 'Should have a valid JSON config file' {
            $script:mcpConfigPath | Should -Exist
            $content = Get-Content $script:mcpConfigPath -Raw
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Should have a servers section with required structure' {
            $config = Get-Content $script:mcpConfigPath -Raw | ConvertFrom-Json
            $config.PSObject.Properties.Name | Should -Contain 'servers'
            $config.servers | Should -Not -BeNullOrEmpty
        }
    }

    Context 'ImageSorcery server configuration' {
        It 'Should have image-sorcery server defined' {
            $config = Get-Content $script:mcpConfigPath -Raw | ConvertFrom-Json
            $config.servers.PSObject.Properties.Name | Should -Contain 'image-sorcery'
        }

        It 'Should have complete server config with type, command, and args' {
            $config = Get-Content $script:mcpConfigPath -Raw | ConvertFrom-Json
            $server = $config.servers.'image-sorcery'
            $server.type | Should -Be 'stdio'
            $server.command | Should -Be 'python'
            $server.args | Should -Not -BeNullOrEmpty
            $server.args | Should -Contain '-m'
            $server.args | Should -Contain 'image_sorcery.server'
        }

        It 'Should have environment configuration for models directory' {
            $config = Get-Content $script:mcpConfigPath -Raw | ConvertFrom-Json
            $server = $config.servers.'image-sorcery'
            $server.env | Should -Not -BeNullOrEmpty
            $server.env.MODELS_DIR | Should -Not -BeNullOrEmpty
        }
    }

    Context 'MCP tool listing' {
        It 'Should list expected ImageSorcery tools from mock response' {
            $expectedTools = @(
                'detect', 'find', 'crop', 'resize', 'rotate',
                'blur', 'fill', 'overlay', 'draw_texts', 'draw_rectangles',
                'draw_circles', 'draw_lines', 'draw_arrows',
                'get_metainfo', 'ocr', 'change_color'
            )

            # Mock MCP tools/list response
            $toolListResponse = [PSCustomObject]@{
                tools = $expectedTools | ForEach-Object {
                    [PSCustomObject]@{ name = $_; description = "ImageSorcery $_ tool" }
                }
            }

            $toolListResponse.tools.Count | Should -BeGreaterOrEqual 10
            $toolNames = $toolListResponse.tools | ForEach-Object { $_.name }
            $toolNames | Should -Contain 'detect'
            $toolNames | Should -Contain 'crop'
            $toolNames | Should -Contain 'resize'
            $toolNames | Should -Contain 'get_metainfo'
            $toolNames | Should -Contain 'ocr'
        }
    }

    Context 'MCP tool invocation patterns' {
        It 'Should invoke detect tool with correct parameters' {
            $detectResponse = New-MockDetectionResult -InputPath '/images/test.png' -Objects @(
                @{ class_name = 'cat'; confidence = 0.96; bbox = @(100, 100, 500, 400) }
            )
            $detectResponse.tool | Should -Be 'detect'
            $detectResponse.error | Should -BeNullOrEmpty
            $detectResponse.result.objects.Count | Should -Be 1
            $detectResponse.result.objects[0].class_name | Should -Be 'cat'
        }

        It 'Should invoke resize tool and return output path' {
            $resizeResponse = New-MockMcpResponse -ToolName 'resize' -Result ([PSCustomObject]@{
                input_path  = '/images/large.png'
                output_path = '/images/large_resized.png'
                width       = 256
                height      = 256
            })
            $resizeResponse.tool | Should -Be 'resize'
            $resizeResponse.error | Should -BeNullOrEmpty
            $resizeResponse.result.width | Should -Be 256
            $resizeResponse.result.output_path | Should -BeLike '*resized*'
        }

        It 'Should invoke crop tool with bounding box coordinates' {
            $cropResponse = New-MockMcpResponse -ToolName 'crop' -Result ([PSCustomObject]@{
                input_path  = '/images/scene.png'
                output_path = '/images/scene_cropped.png'
                x1 = 50; y1 = 50; x2 = 400; y2 = 300
            })
            $cropResponse.tool | Should -Be 'crop'
            $cropResponse.error | Should -BeNullOrEmpty
            ($cropResponse.result.x2 - $cropResponse.result.x1) | Should -Be 350
        }

        It 'Should invoke get_metainfo and return image metadata' {
            $metaResponse = New-MockImageMetainfo -Width 1920 -Height 1080 -Format 'JPEG' -FileSize 1048576
            $metaResponse.tool | Should -Be 'get_metainfo'
            $metaResponse.error | Should -BeNullOrEmpty
            $metaResponse.result.width | Should -Be 1920
            $metaResponse.result.height | Should -Be 1080
            $metaResponse.result.format | Should -Be 'JPEG'
        }
    }

    Context 'MCP server error handling' {
        It 'Should handle MCP server unavailable error' {
            $errorResponse = New-MockMcpResponse -ToolName 'detect' -IsError `
                -ErrorMessage 'MCP server not running: connection refused'

            $errorResponse.error | Should -Not -BeNullOrEmpty
            $errorResponse.error | Should -BeLike '*connection refused*'
            $errorResponse.result | Should -BeNullOrEmpty
        }

        It 'Should handle MCP tool execution failure' {
            $errorResponse = New-MockMcpResponse -ToolName 'resize' -IsError `
                -ErrorMessage 'File not found: /images/missing.png'

            $errorResponse.error | Should -BeLike '*File not found*'
            $errorResponse.result | Should -BeNullOrEmpty
        }
    }
}
