BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:generateScript = Join-Path $script:repoRoot 'scripts' 'Invoke-FalGenerate.ps1'
    $script:workflowScript = Join-Path $script:repoRoot 'scripts' 'New-FalWorkflow.ps1'
    $script:modulePath = Join-Path $script:repoRoot 'scripts' 'FalAi.psm1'
    Import-Module $script:modulePath -Force
}

Describe 'E2E: Combined fal.ai + ImageSorcery Workflow' {
    BeforeAll {
        $script:testDir = Join-Path $TestDrive 'combined-workflow'
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
    }

    BeforeEach {
        Mock Import-Module { } -ParameterFilter { "$Name" -like '*FalAi*' }
    }

    Context 'Generate image then detect objects' {
        It 'Should generate an image and detect objects in the result' {
            # Step 1: Mock fal.ai generation
            $generatedUrl = 'https://fal.ai/output/scene-001.png'
            $genResponse = New-MockFalApiResponse -ImageUrl $generatedUrl -Width 1024 -Height 768 -Prompt 'A park with dogs'

            $genResponse.images.Count | Should -Be 1
            $genResponse.images[0].url | Should -Be $generatedUrl

            # Step 2: Mock ImageSorcery detection on the generated image
            $detectionResult = New-MockDetectionResult -InputPath $generatedUrl -Objects @(
                @{ class_name = 'dog'; confidence = 0.95; bbox = @(100, 200, 400, 500) }
                @{ class_name = 'person'; confidence = 0.88; bbox = @(500, 100, 700, 600) }
            )

            $detectionResult.error | Should -BeNullOrEmpty
            $detectionResult.result.objects.Count | Should -Be 2
            $detectionResult.result.objects[0].class_name | Should -Be 'dog'
            $detectionResult.result.objects[0].confidence | Should -BeGreaterThan 0.9
        }

        It 'Should handle detection with no objects found' {
            $genResponse = New-MockFalApiResponse -Prompt 'An empty white canvas'

            $detectionResult = New-MockDetectionResult -InputPath $genResponse.images[0].url -Objects @()
            $detectionResult.error | Should -BeNullOrEmpty
            $detectionResult.result.objects.Count | Should -Be 0
        }
    }

    Context 'Generate image then resize/crop' {
        It 'Should generate and resize the result' {
            $genResponse = New-MockFalApiResponse -Width 1024 -Height 1024 -Prompt 'A portrait'

            # Mock resize of the generated image
            $resizedPath = Join-Path $script:testDir 'resized_gen.png'
            New-MockImageFile -Path $resizedPath | Out-Null

            $resizeResponse = New-MockMcpResponse -ToolName 'resize' -Result ([PSCustomObject]@{
                input_path  = $genResponse.images[0].url
                output_path = $resizedPath
                width       = 512
                height      = 512
            })

            $resizeResponse.error | Should -BeNullOrEmpty
            $resizeResponse.result.width | Should -Be 512
            $resizeResponse.result.height | Should -Be 512
            $resizeResponse.result.output_path | Should -Exist
        }

        It 'Should generate and crop a region of interest' {
            $genResponse = New-MockFalApiResponse -Width 1024 -Height 768 -Prompt 'A landscape with a house'

            $croppedPath = Join-Path $script:testDir 'cropped_gen.png'
            New-MockImageFile -Path $croppedPath | Out-Null

            $cropResponse = New-MockMcpResponse -ToolName 'crop' -Result ([PSCustomObject]@{
                input_path  = $genResponse.images[0].url
                output_path = $croppedPath
                x1 = 200; y1 = 100; x2 = 800; y2 = 500
            })

            $cropResponse.error | Should -BeNullOrEmpty
            $cropResponse.result.output_path | Should -Exist
            ($cropResponse.result.x2 - $cropResponse.result.x1) | Should -Be 600
        }
    }

    Context 'Generate image then add text overlay' {
        It 'Should generate and overlay text on the result' {
            $genResponse = New-MockFalApiResponse -Width 1024 -Height 1024 -Prompt 'A motivational background'

            $overlayPath = Join-Path $script:testDir 'text_overlay.png'
            New-MockImageFile -Path $overlayPath | Out-Null

            $textResponse = New-MockMcpResponse -ToolName 'draw_texts' -Result ([PSCustomObject]@{
                input_path  = $genResponse.images[0].url
                output_path = $overlayPath
                texts       = @(
                    @{ text = 'DREAM BIG'; x = 100; y = 500; font_scale = 3.0; color = @(255, 255, 255) }
                )
            })

            $textResponse.error | Should -BeNullOrEmpty
            $textResponse.result.texts.Count | Should -Be 1
            $textResponse.result.texts[0].text | Should -Be 'DREAM BIG'
            $textResponse.result.output_path | Should -Exist
        }

        It 'Should generate and overlay multiple text elements' {
            $genResponse = New-MockFalApiResponse -Prompt 'A banner background'

            $overlayPath = Join-Path $script:testDir 'multi_text.png'
            New-MockImageFile -Path $overlayPath | Out-Null

            $textResponse = New-MockMcpResponse -ToolName 'draw_texts' -Result ([PSCustomObject]@{
                input_path  = $genResponse.images[0].url
                output_path = $overlayPath
                texts       = @(
                    @{ text = 'SUMMER SALE'; x = 100; y = 200 }
                    @{ text = '50% OFF';     x = 100; y = 400 }
                )
            })

            $textResponse.error | Should -BeNullOrEmpty
            $textResponse.result.texts.Count | Should -Be 2
        }
    }

    Context 'Multi-step pipeline end-to-end' {
        It 'Should execute generate → resize → detect → annotate pipeline' {
            # Step 1: Generate
            $genResponse = New-MockFalApiResponse -Width 1024 -Height 1024 -Prompt 'A busy street scene'

            # Step 2: Resize
            $resizedPath = Join-Path $script:testDir 'pipeline_resized.png'
            New-MockImageFile -Path $resizedPath | Out-Null
            $step2 = New-MockMcpResponse -ToolName 'resize' -Result ([PSCustomObject]@{
                input_path = $genResponse.images[0].url; output_path = $resizedPath; width = 640; height = 640
            })

            # Step 3: Detect objects
            $step3 = New-MockDetectionResult -InputPath $resizedPath -Objects @(
                @{ class_name = 'car'; confidence = 0.91; bbox = @(50, 300, 300, 500) }
                @{ class_name = 'person'; confidence = 0.87; bbox = @(350, 200, 450, 550) }
            )

            # Step 4: Draw bounding boxes
            $annotatedPath = Join-Path $script:testDir 'pipeline_annotated.png'
            New-MockImageFile -Path $annotatedPath | Out-Null
            $step4 = New-MockMcpResponse -ToolName 'draw_rectangles' -Result ([PSCustomObject]@{
                input_path  = $resizedPath
                output_path = $annotatedPath
                rectangles  = @(
                    @{ x1 = 50; y1 = 300; x2 = 300; y2 = 500; color = @(0, 255, 0) }
                    @{ x1 = 350; y1 = 200; x2 = 450; y2 = 550; color = @(0, 255, 0) }
                )
            })

            # Validate pipeline chain
            $genResponse.images[0].url | Should -Not -BeNullOrEmpty
            $step2.error | Should -BeNullOrEmpty
            $step3.result.objects.Count | Should -Be 2
            $step4.error | Should -BeNullOrEmpty
            $step4.result.output_path | Should -Exist
            $step4.result.rectangles.Count | Should -Be 2
        }

        It 'Should pass outputs between workflow steps via New-FalWorkflow' {
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Headers, $Body)
                if ($Uri -like '*flux/dev*') {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/output/wf-img.png'; width = 1024; height = 1024 })
                        seed   = 42
                    }
                }
                # Queue submission for video step
                if ($Method -eq 'POST' -and $Uri -like '*queue*') {
                    return [PSCustomObject]@{ request_id = 'req-wf-001' }
                }
                # Queue status poll
                if ($Method -eq 'GET' -and $Uri -like '*status*') {
                    return [PSCustomObject]@{ status = 'COMPLETED' }
                }
                # Queue result retrieval
                if ($Method -eq 'GET') {
                    return [PSCustomObject]@{
                        video = [PSCustomObject]@{ url = 'https://fal.ai/output/wf-vid.mp4' }
                    }
                }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $steps = @(
                    @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'A mountain' }; dependsOn = @() }
                    @{ name = 'animate';  model = 'fal-ai/kling-video/v2.6/pro/image-to-video'; params = @{ prompt = 'Zoom in slowly' }; dependsOn = @('generate') }
                )
                $result = & $script:workflowScript -Name 'img-to-vid' -Steps $steps
                $result.WorkflowName | Should -Be 'img-to-vid'
                $result.Steps.Count | Should -Be 2
                $result.Steps[0].Status | Should -Be 'Completed'
                $result.Steps[1].Status | Should -Be 'Completed'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should handle pipeline step failure gracefully' {
            $genResponse = New-MockFalApiResponse -Prompt 'A test image'

            $errorResponse = New-MockMcpResponse -ToolName 'resize' -IsError `
                -ErrorMessage 'Out of memory: image too large to process'

            $genResponse.images.Count | Should -Be 1
            $errorResponse.error | Should -BeLike '*Out of memory*'
            $errorResponse.result | Should -BeNullOrEmpty
        }
    }
}
