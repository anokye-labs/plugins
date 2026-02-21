BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/FalAi.psm1" -Force
}

Describe 'Invoke-FalVideoGen' {
    BeforeAll {
        $script:scriptPath = "$PSScriptRoot/../../scripts/Invoke-FalVideoGen.ps1"
    }

    BeforeEach {
        $env:FAL_KEY = 'mock-key-video-test'
    }

    It 'Builds correct payload with default parameters' {
        Mock Wait-FalJob {
            param($Model, $Body)
            # Validate payload structure
            $Body.prompt       | Should -Be 'A sunset timelapse'
            $Body.duration     | Should -Be 5
            $Body.aspect_ratio | Should -Be '16:9'
            return [PSCustomObject]@{
                video = [PSCustomObject]@{ url = 'https://fal.ai/video.mp4'; width = 1920; height = 1080 }
            }
        }

        $result = & $script:scriptPath -Prompt 'A sunset timelapse'
        $result.Video.Url | Should -Be 'https://fal.ai/video.mp4'
        $result.Duration  | Should -Be 5
        $result.Model     | Should -Be 'fal-ai/kling-video/v2.6/pro/text-to-video'
    }

    It 'Passes custom duration and aspect ratio' {
        Mock Wait-FalJob {
            param($Model, $Body)
            $Body.duration     | Should -Be 10
            $Body.aspect_ratio | Should -Be '9:16'
            return [PSCustomObject]@{
                video = [PSCustomObject]@{ url = 'https://fal.ai/vid2.mp4'; width = 1080; height = 1920 }
            }
        }

        $result = & $script:scriptPath -Prompt 'Dancing cat' -Duration 10 -AspectRatio '9:16'
        $result.Width  | Should -Be 1080
        $result.Height | Should -Be 1920
    }
}

Describe 'Invoke-FalImageToVideo' {
    BeforeAll {
        $script:scriptPath = "$PSScriptRoot/../../scripts/Invoke-FalImageToVideo.ps1"
    }

    BeforeEach {
        $env:FAL_KEY = 'mock-key-i2v-test'
    }

    It 'Sends image_url without prompt when prompt is omitted' {
        Mock Wait-FalJob {
            param($Model, $Body)
            $Body.image_url | Should -Be 'https://example.com/photo.jpg'
            $Body.duration  | Should -Be 5
            $Body.Keys      | Should -Not -Contain 'prompt'
            return [PSCustomObject]@{
                video = [PSCustomObject]@{ url = 'https://fal.ai/i2v.mp4'; width = 1280; height = 720 }
            }
        }

        $result = & $script:scriptPath -ImageUrl 'https://example.com/photo.jpg'
        $result.Video.Url | Should -Be 'https://fal.ai/i2v.mp4'
        $result.ImageUrl  | Should -Be 'https://example.com/photo.jpg'
    }

    It 'Includes prompt when provided' {
        Mock Wait-FalJob {
            param($Model, $Body)
            $Body.image_url | Should -Be 'https://example.com/img.png'
            $Body.prompt    | Should -Be 'Zoom in slowly'
            return [PSCustomObject]@{
                video = [PSCustomObject]@{ url = 'https://fal.ai/i2v2.mp4' }
            }
        }

        $result = & $script:scriptPath -ImageUrl 'https://example.com/img.png' -Prompt 'Zoom in slowly'
        $result.Video.Url | Should -Be 'https://fal.ai/i2v2.mp4'
    }

    It 'Uses custom model and duration' {
        Mock Wait-FalJob {
            param($Model, $Body)
            $Model          | Should -Be 'fal-ai/custom-i2v'
            $Body.duration  | Should -Be 15
            return [PSCustomObject]@{
                video = [PSCustomObject]@{ url = 'https://fal.ai/custom.mp4' }
            }
        }

        $result = & $script:scriptPath -ImageUrl 'https://example.com/x.jpg' -Model 'fal-ai/custom-i2v' -Duration 15
        $result.Model | Should -Be 'fal-ai/custom-i2v'
    }
}

Describe 'New-FalWorkflow' {
    BeforeAll {
        $script:scriptPath = "$PSScriptRoot/../../scripts/New-FalWorkflow.ps1"
    }

    BeforeEach {
        $env:FAL_KEY = 'mock-key-workflow-test'
    }

    It 'Executes single-step workflow' {
        Mock Invoke-FalApi {
            return [PSCustomObject]@{
                images = @([PSCustomObject]@{ url = 'https://fal.ai/img.png'; width = 1024; height = 768 })
                seed   = 42
            }
        }

        $steps = @(
            @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'A mountain' }; dependsOn = @() }
        )
        $result = & $script:scriptPath -Name 'single-step' -Steps $steps

        $result.WorkflowName | Should -Be 'single-step'
        $result.Steps.Count  | Should -Be 1
        $result.Steps[0].Status | Should -Be 'Completed'
    }

    It 'Resolves dependencies and passes outputs between steps' {
        $callIndex = 0
        Mock Invoke-FalApi {
            param($Method, $Endpoint, $Body)
            $script:callIndex++
            return [PSCustomObject]@{
                images = @([PSCustomObject]@{ url = "https://fal.ai/step$($script:callIndex).png" })
            }
        }
        Mock Wait-FalJob {
            param($Model, $Body)
            # Should receive image_url from step 1
            $Body.image_url | Should -Be 'https://fal.ai/step1.png'
            return [PSCustomObject]@{
                video = [PSCustomObject]@{ url = 'https://fal.ai/final.mp4' }
            }
        }

        $steps = @(
            @{ name = 'generate'; model = 'fal-ai/flux/dev'; params = @{ prompt = 'A cat' }; dependsOn = @() }
            @{ name = 'animate'; model = 'fal-ai/kling-video/v2.6/pro/image-to-video'; params = @{ prompt = 'Pan right' }; dependsOn = @('generate') }
        )
        $result = & $script:scriptPath -Name 'img-to-vid' -Steps $steps

        $result.Steps.Count | Should -Be 2
        $result.Steps[0].StepName | Should -Be 'generate'
        $result.Steps[1].StepName | Should -Be 'animate'
        $result.Steps[1].Status   | Should -Be 'Completed'
    }

    It 'Detects circular dependencies and throws' {
        $steps = @(
            @{ name = 'a'; model = 'fal-ai/flux/dev'; params = @{}; dependsOn = @('b') }
            @{ name = 'b'; model = 'fal-ai/flux/dev'; params = @{}; dependsOn = @('a') }
        )
        { & $script:scriptPath -Name 'circular' -Steps $steps } | Should -Throw '*Circular dependency*'
    }
}
