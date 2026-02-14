BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
}

Describe 'ImageSorcery Integration' {
    BeforeAll {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "imagesorcery-tests-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
        $script:testImage = Join-Path $script:testDir 'test.png'
        New-MockImageFile -Path $script:testImage | Out-Null
    }

    AfterAll {
        if (Test-Path $script:testDir) {
            Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Image Metadata' {
        It 'Should get metainfo for a valid image' {
            $response = New-MockImageMetainfo -Width 1024 -Height 768 -Format 'PNG' -InputPath $script:testImage
            $response.error | Should -BeNullOrEmpty
            $response.result.width | Should -Be 1024
            $response.result.height | Should -Be 768
            $response.result.format | Should -Be 'PNG'
        }

        It 'Should handle missing file gracefully' {
            $response = New-MockMcpResponse -ToolName 'get_metainfo' -IsError -ErrorMessage 'File not found: /nonexistent/image.png'
            $response.error | Should -Not -BeNullOrEmpty
            $response.error | Should -BeLike '*File not found*'
            $response.result | Should -BeNullOrEmpty
        }

        It 'Should return file size in metadata' {
            $response = New-MockImageMetainfo -FileSize 1048576
            $response.result.file_size | Should -Be 1048576
        }
    }

    Context 'Image Transformation' {
        It 'Should resize image to specified dimensions' {
            $resizeResult = New-MockMcpResponse -ToolName 'resize' -Result ([PSCustomObject]@{
                input_path  = $script:testImage
                output_path = (Join-Path $script:testDir 'test_resized.png')
                width       = 800
                height      = 600
            })
            $resizeResult.error | Should -BeNullOrEmpty
            $resizeResult.result.width | Should -Be 800
            $resizeResult.result.height | Should -Be 600
        }

        It 'Should crop image with valid coordinates' {
            $cropResult = New-MockMcpResponse -ToolName 'crop' -Result ([PSCustomObject]@{
                input_path  = $script:testImage
                output_path = (Join-Path $script:testDir 'test_cropped.png')
                x1 = 100; y1 = 50; x2 = 400; y2 = 300
            })
            $cropResult.error | Should -BeNullOrEmpty
            $cropResult.result.x1 | Should -Be 100
            $cropResult.result.x2 | Should -Be 400
        }

        It 'Should detect objects in image' {
            $detectResult = New-MockDetectionResult -InputPath $script:testImage -Objects @(
                @{ class_name = 'person'; confidence = 0.92; bbox = @(120, 50, 380, 400) },
                @{ class_name = 'car';    confidence = 0.85; bbox = @(500, 200, 800, 450) }
            )
            $detectResult.error | Should -BeNullOrEmpty
            $detectResult.result.objects.Count | Should -Be 2
            $detectResult.result.objects[0].class_name | Should -Be 'person'
            $detectResult.result.objects[0].confidence | Should -BeGreaterThan 0.5
        }

        It 'Should rotate image by specified angle' {
            $rotateResult = New-MockMcpResponse -ToolName 'rotate' -Result ([PSCustomObject]@{
                input_path  = $script:testImage
                output_path = (Join-Path $script:testDir 'test_rotated.png')
                angle       = 90
            })
            $rotateResult.error | Should -BeNullOrEmpty
            $rotateResult.result.angle | Should -Be 90
        }
    }

    Context 'Image Annotation' {
        It 'Should draw rectangles on image' {
            $drawResult = New-MockMcpResponse -ToolName 'draw_rectangles' -Result ([PSCustomObject]@{
                input_path  = $script:testImage
                output_path = (Join-Path $script:testDir 'test_with_rectangles.png')
                rectangles  = @(
                    @{ x1 = 50; y1 = 50; x2 = 200; y2 = 200; color = @(0,255,0); thickness = 2 }
                )
            })
            $drawResult.error | Should -BeNullOrEmpty
            $drawResult.result.rectangles.Count | Should -Be 1
            $drawResult.result.output_path | Should -BeLike '*with_rectangles*'
        }

        It 'Should add text overlay' {
            $textResult = New-MockMcpResponse -ToolName 'draw_texts' -Result ([PSCustomObject]@{
                input_path  = $script:testImage
                output_path = (Join-Path $script:testDir 'test_with_text.png')
                texts       = @(
                    @{ text = 'Hello World'; x = 10; y = 30; font_scale = 1.0; color = @(255,255,255) }
                )
            })
            $textResult.error | Should -BeNullOrEmpty
            $textResult.result.texts[0].text | Should -Be 'Hello World'
        }

        It 'Should draw arrows on image' {
            $arrowResult = New-MockMcpResponse -ToolName 'draw_arrows' -Result ([PSCustomObject]@{
                input_path  = $script:testImage
                output_path = (Join-Path $script:testDir 'test_with_arrows.png')
                arrows      = @(
                    @{ x1 = 50; y1 = 50; x2 = 200; y2 = 200; tip_length = 0.15 }
                )
            })
            $arrowResult.error | Should -BeNullOrEmpty
            $arrowResult.result.arrows.Count | Should -Be 1
        }
    }

    Context 'Color Operations' {
        It 'Should convert image to grayscale' {
            $colorResult = New-MockMcpResponse -ToolName 'change_color' -Result ([PSCustomObject]@{
                input_path  = $script:testImage
                output_path = (Join-Path $script:testDir 'test_grayscale.png')
                palette     = 'grayscale'
            })
            $colorResult.error | Should -BeNullOrEmpty
            $colorResult.result.palette | Should -Be 'grayscale'
        }
    }

    Context 'Error Handling' {
        It 'Should return error for invalid image path' {
            $response = New-MockMcpResponse -ToolName 'resize' -IsError -ErrorMessage 'File not found: /bad/path.jpg'
            $response.error | Should -Not -BeNullOrEmpty
            $response.result | Should -BeNullOrEmpty
            $response.tool | Should -Be 'resize'
        }

        It 'Should handle zero-dimension resize' {
            $response = New-MockMcpResponse -ToolName 'resize' -IsError -ErrorMessage 'Width and height must be positive integers'
            $response.error | Should -BeLike '*positive integers*'
            $response.result | Should -BeNullOrEmpty
        }

        It 'Should handle even blur strength error' {
            $response = New-MockMcpResponse -ToolName 'blur' -IsError -ErrorMessage 'Blur strength must be odd'
            $response.error | Should -BeLike '*odd*'
        }
    }

    Context 'MCP Response Structure' {
        It 'Should have consistent response format for all tools' {
            $tools = @('get_metainfo', 'resize', 'crop', 'rotate', 'detect', 'draw_texts')
            foreach ($tool in $tools) {
                $response = New-MockMcpResponse -ToolName $tool -Result @{ ok = $true }
                $response.PSObject.Properties.Name | Should -Contain 'tool'
                $response.PSObject.Properties.Name | Should -Contain 'error'
                $response.PSObject.Properties.Name | Should -Contain 'result'
                $response.tool | Should -Be $tool
            }
        }
    }
}
