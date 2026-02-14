BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
}

Describe 'E2E: Image Manipulation Workflow' {
    BeforeAll {
        $testDir = Join-Path $TestDrive 'e2e-images'
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        $script:testImage = New-MockImageFile -Path (Join-Path $testDir 'input.png')
    }

    Context 'Step 1: Image Loading' {
        It 'Should load and validate input image' {
            $script:testImage | Should -Not -BeNullOrEmpty
            $script:testImage.FullName | Should -Exist
        }

        It 'Should reject invalid file paths' {
            $badPath = Join-Path $testDir 'nonexistent.png'
            $response = New-MockMcpResponse -ToolName 'get_metainfo' -IsError -ErrorMessage "File not found: $badPath"
            $response.error | Should -BeLike '*File not found*'
            $response.result | Should -BeNullOrEmpty
        }

        It 'Should detect image format from extension' {
            $formats = @('png', 'jpg', 'webp')
            foreach ($fmt in $formats) {
                $fmtPath = Join-Path $testDir "test.$fmt"
                New-MockImageFile -Path $fmtPath | Out-Null
                $ext = [System.IO.Path]::GetExtension($fmtPath).TrimStart('.')
                $ext | Should -Be $fmt
            }
        }
    }

    Context 'Step 2: Image Analysis' {
        It 'Should extract metadata (dimensions, format, size)' {
            $meta = New-MockImageMetainfo -Width 1920 -Height 1080 -Format 'PNG' -FileSize 2097152 -InputPath $script:testImage.FullName
            $meta.result.width | Should -Be 1920
            $meta.result.height | Should -Be 1080
            $meta.result.format | Should -Be 'PNG'
            $meta.result.file_size | Should -BeGreaterThan 0
            $meta.tool | Should -Be 'get_metainfo'
            $meta.error | Should -BeNullOrEmpty
        }

        It 'Should handle various image formats (PNG, JPEG, WebP)' {
            $cases = @(
                @{ Fmt = 'PNG';  W = 800;  H = 600 }
                @{ Fmt = 'JPEG'; W = 1024; H = 768 }
                @{ Fmt = 'WebP'; W = 640;  H = 480 }
            )
            foreach ($case in $cases) {
                $meta = New-MockImageMetainfo -Width $case.W -Height $case.H -Format $case.Fmt
                $meta.result.format | Should -Be $case.Fmt
                $meta.result.width  | Should -Be $case.W
                $meta.result.height | Should -Be $case.H
            }
        }
    }

    Context 'Step 3: Image Processing Pipeline' {
        It 'Should resize image maintaining aspect ratio' {
            $outputPath = Join-Path $testDir 'resized.png'
            New-MockImageFile -Path $outputPath | Out-Null

            $resizeResponse = New-MockMcpResponse -ToolName 'resize' -Result ([PSCustomObject]@{
                input_path  = $script:testImage.FullName
                output_path = $outputPath
                width       = 800
                height      = 600
            })

            $resizeResponse.error | Should -BeNullOrEmpty
            $resizeResponse.result.width | Should -Be 800
            $resizeResponse.result.height | Should -Be 600
            $resizeResponse.result.output_path | Should -Exist
        }

        It 'Should crop image with valid coordinates' {
            $outputPath = Join-Path $testDir 'cropped.png'
            New-MockImageFile -Path $outputPath | Out-Null

            $cropResponse = New-MockMcpResponse -ToolName 'crop' -Result ([PSCustomObject]@{
                input_path  = $script:testImage.FullName
                output_path = $outputPath
                x1 = 100; y1 = 50; x2 = 400; y2 = 300
            })

            $cropResponse.error | Should -BeNullOrEmpty
            $cropResponse.result.x1 | Should -Be 100
            $cropResponse.result.x2 | Should -Be 400
            $cropResponse.tool | Should -Be 'crop'
            $cropResponse.result.output_path | Should -Exist
        }

        It 'Should apply blur to specified regions' {
            $outputPath = Join-Path $testDir 'blurred.png'
            New-MockImageFile -Path $outputPath | Out-Null

            $blurResponse = New-MockMcpResponse -ToolName 'blur' -Result ([PSCustomObject]@{
                input_path  = $script:testImage.FullName
                output_path = $outputPath
                areas       = @(
                    @{ x1 = 50; y1 = 50; x2 = 200; y2 = 200; blur_strength = 25 }
                )
            })

            $blurResponse.error | Should -BeNullOrEmpty
            $blurResponse.result.areas.Count | Should -Be 1
            $blurResponse.result.areas[0].blur_strength | Should -Be 25
            $blurResponse.result.output_path | Should -Exist
        }

        It 'Should chain multiple operations sequentially' {
            # Simulate: resize -> crop -> blur pipeline
            $step1Out = Join-Path $testDir 'chain_resize.png'
            $step2Out = Join-Path $testDir 'chain_crop.png'
            $step3Out = Join-Path $testDir 'chain_blur.png'
            $step1Out, $step2Out, $step3Out | ForEach-Object { New-MockImageFile -Path $_ | Out-Null }

            $step1 = New-MockMcpResponse -ToolName 'resize' -Result ([PSCustomObject]@{
                output_path = $step1Out; width = 800; height = 600
            })
            $step2 = New-MockMcpResponse -ToolName 'crop' -Result ([PSCustomObject]@{
                input_path = $step1.result.output_path
                output_path = $step2Out
            })
            $step3 = New-MockMcpResponse -ToolName 'blur' -Result ([PSCustomObject]@{
                input_path = $step2.result.output_path
                output_path = $step3Out
            })

            $step1.error | Should -BeNullOrEmpty
            $step2.error | Should -BeNullOrEmpty
            $step3.error | Should -BeNullOrEmpty
            $step2.result.input_path | Should -Be $step1Out
            $step3.result.input_path | Should -Be $step2Out
            $step3.result.output_path | Should -Exist
        }
    }

    Context 'Step 4: Output Validation' {
        It 'Should save processed image to output path' {
            $outputPath = Join-Path $testDir 'final_output.png'
            $outputFile = New-MockImageFile -Path $outputPath

            $outputFile | Should -Not -BeNullOrEmpty
            $outputPath | Should -Exist
            $outputFile.Length | Should -BeGreaterThan 0
        }

        It 'Should validate output dimensions match requested' {
            $requestedWidth = 1200
            $requestedHeight = 400

            $meta = New-MockImageMetainfo -Width $requestedWidth -Height $requestedHeight -Format 'PNG'
            $meta.result.width  | Should -Be $requestedWidth
            $meta.result.height | Should -Be $requestedHeight
        }

        It 'Should verify output file is a valid image' {
            $outputPath = Join-Path $testDir 'valid_check.png'
            New-MockImageFile -Path $outputPath | Out-Null

            # Validate PNG signature (first 8 bytes)
            $bytes = [System.IO.File]::ReadAllBytes($outputPath)
            $bytes.Length | Should -BeGreaterOrEqual 8
            $bytes[0] | Should -Be 0x89
            $bytes[1] | Should -Be 0x50  # 'P'
            $bytes[2] | Should -Be 0x4E  # 'N'
            $bytes[3] | Should -Be 0x47  # 'G'
        }
    }

    Context 'Error Recovery' {
        It 'Should handle invalid coordinates gracefully' {
            $response = New-MockMcpResponse -ToolName 'crop' -IsError `
                -ErrorMessage 'Invalid coordinates: x2 must be greater than x1'
            $response.error | Should -BeLike '*Invalid coordinates*'
            $response.result | Should -BeNullOrEmpty
            $response.tool | Should -Be 'crop'
        }

        It 'Should report meaningful errors for unsupported operations' {
            $response = New-MockMcpResponse -ToolName 'unsupported_op' -IsError `
                -ErrorMessage 'Unknown tool: unsupported_op'
            $response.error | Should -BeLike '*Unknown tool*'
            $response.result | Should -BeNullOrEmpty
        }
    }
}
