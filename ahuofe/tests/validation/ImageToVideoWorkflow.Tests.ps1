BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:i2vScript = Join-Path $script:repoRoot 'scripts' 'Invoke-FalImageToVideo.ps1'
    $script:t2vScript = Join-Path $script:repoRoot 'scripts' 'Invoke-FalVideoGen.ps1'
    $script:modulePath = Join-Path $script:repoRoot 'scripts' 'FalAi.psm1'
    Import-Module $script:modulePath -Force

    $script:qualityThresholds = Get-Content (Get-TestFixturePath 'quality-thresholds.json') -Raw | ConvertFrom-Json
}

Describe 'Validation: Image-to-Video Workflow' {
    BeforeEach {
        Mock Import-Module { } -ParameterFilter { "$Name" -like '*FalAi*' }
    }

    Context 'Basic image-to-video generation' {
        It 'Should generate a video from an image URL' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST' -and $Uri -like '*queue*') {
                    return [PSCustomObject]@{ request_id = 'req-i2v-001' }
                }
                if ($Method -eq 'GET' -and $Uri -like '*status*') {
                    return [PSCustomObject]@{ status = 'COMPLETED' }
                }
                return [PSCustomObject]@{
                    video = [PSCustomObject]@{
                        url    = 'https://fal.ai/output/video-001.mp4'
                        width  = 1280
                        height = 720
                    }
                }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:i2vScript -ImageUrl 'https://example.com/photo.jpg'
                $result.Video | Should -Not -BeNullOrEmpty
                $result.Video.Url | Should -Be 'https://fal.ai/output/video-001.mp4'
                $result.ImageUrl | Should -Be 'https://example.com/photo.jpg'
                $result.Model | Should -Be 'fal-ai/kling-video/v2.6/pro/image-to-video'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should generate video with custom prompt and duration' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST' -and $Uri -like '*queue*') {
                    return [PSCustomObject]@{ request_id = 'req-i2v-002' }
                }
                if ($Method -eq 'GET' -and $Uri -like '*status*') {
                    return [PSCustomObject]@{ status = 'COMPLETED' }
                }
                return [PSCustomObject]@{
                    video = [PSCustomObject]@{
                        url    = 'https://fal.ai/output/video-002.mp4'
                        width  = 1280
                        height = 720
                    }
                }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:i2vScript -ImageUrl 'https://example.com/scene.jpg' `
                    -Prompt 'Zoom in slowly' -Duration 10
                $result.Video.Url | Should -BeLike 'https://fal.ai/*'
                $result.Duration | Should -Be 10
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Video model variants' {
        It 'Should generate with a different video model' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST' -and $Uri -like '*queue*') {
                    return [PSCustomObject]@{ request_id = 'req-i2v-model' }
                }
                if ($Method -eq 'GET' -and $Uri -like '*status*') {
                    return [PSCustomObject]@{ status = 'COMPLETED' }
                }
                return [PSCustomObject]@{
                    video = [PSCustomObject]@{
                        url    = 'https://fal.ai/output/alt-model.mp4'
                        width  = 1920
                        height = 1080
                    }
                }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:i2vScript -ImageUrl 'https://example.com/photo.jpg' `
                    -Model 'fal-ai/kling-video/v1/standard/image-to-video'
                $result.Model | Should -Be 'fal-ai/kling-video/v1/standard/image-to-video'
                $result.Video | Should -Not -BeNullOrEmpty
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Queue-based processing' {
        It 'Should poll through queue states before completing' {
            $script:pollCount = 0
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST' -and $Uri -like '*queue*') {
                    return [PSCustomObject]@{ request_id = 'req-i2v-queue' }
                }
                if ($Method -eq 'GET' -and $Uri -like '*status*') {
                    $script:pollCount++
                    $s = switch ($script:pollCount) {
                        1 { 'IN_QUEUE' }
                        2 { 'IN_PROGRESS' }
                        default { 'COMPLETED' }
                    }
                    return [PSCustomObject]@{
                        status         = $s
                        queue_position = if ($script:pollCount -eq 1) { 2 } else { $null }
                    }
                }
                return [PSCustomObject]@{
                    video = [PSCustomObject]@{
                        url    = 'https://fal.ai/output/queued-video.mp4'
                        width  = 1280
                        height = 720
                    }
                }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:i2vScript -ImageUrl 'https://example.com/input.jpg'
                $result.Video | Should -Not -BeNullOrEmpty
                $result.Video.Url | Should -BeLike '*queued-video*'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Error scenarios' {
        It 'Should throw when FAL_KEY is not set' {
            $savedKey = $env:FAL_KEY
            Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue
            try {
                { & $script:i2vScript -ImageUrl 'https://example.com/photo.jpg' } |
                    Should -Throw '*FAL_KEY*'
            }
            finally {
                if ($savedKey) { $env:FAL_KEY = $savedKey }
            }
        }

        It 'Should throw on API error for invalid image' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new(
                    'The remote server returned an error: (422) Unprocessable Entity.')
            } -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                { & $script:i2vScript -ImageUrl 'https://example.com/not-an-image.txt' } |
                    Should -Throw
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should throw on job timeout' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST') {
                    return [PSCustomObject]@{ request_id = 'req-i2v-timeout' }
                }
                return [PSCustomObject]@{ status = 'IN_QUEUE'; queue_position = 99 }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $body = @{ image_url = 'https://example.com/photo.jpg'; duration = 5 }
                { Wait-FalJob -Model 'fal-ai/kling-video/v2.6/pro/image-to-video' `
                    -Body $body -TimeoutSeconds 4 -PollIntervalSeconds 2 } |
                    Should -Throw '*timed out*'
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }
    }

    Context 'Text-to-video via Invoke-FalVideoGen' {
        It 'Should generate video from text prompt' {
            Mock Invoke-RestMethod {
                param($Uri, $Method)
                if ($Method -eq 'POST' -and $Uri -like '*queue*') {
                    return [PSCustomObject]@{ request_id = 'req-t2v-001' }
                }
                if ($Method -eq 'GET' -and $Uri -like '*status*') {
                    return [PSCustomObject]@{ status = 'COMPLETED' }
                }
                return [PSCustomObject]@{
                    video = [PSCustomObject]@{
                        url    = 'https://fal.ai/output/t2v-001.mp4'
                        width  = 1280
                        height = 720
                    }
                }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $env:FAL_KEY = 'test-key-123'
            try {
                $result = & $script:t2vScript -Prompt 'Ocean waves crashing on rocky cliffs'
                $result.Video | Should -Not -BeNullOrEmpty
                $result.Video.Url | Should -BeLike 'https://fal.ai/*'
                $result.Prompt | Should -Be 'Ocean waves crashing on rocky cliffs'
                $result.Model | Should -Be 'fal-ai/kling-video/v2.6/pro/text-to-video'
                $result.Duration | Should -Be 5
            }
            finally { Remove-Item Env:\FAL_KEY -ErrorAction SilentlyContinue }
        }

        It 'Should validate video thresholds from fixture config' {
            $videoThresholds = $script:qualityThresholds.video
            $videoThresholds.min_duration_seconds | Should -BeGreaterThan 0
            $videoThresholds.max_duration_seconds | Should -BeGreaterThan $videoThresholds.min_duration_seconds
            $videoThresholds.min_fps | Should -BeGreaterOrEqual 12
            $videoThresholds.min_resolution.width | Should -BeGreaterOrEqual 256
        }
    }
}
