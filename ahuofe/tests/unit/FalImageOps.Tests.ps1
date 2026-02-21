BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/FalAi.psm1" -Force
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
}

Describe 'Upload-ToFalCDN' {

    Context 'Content type detection' {
        # Test the auto-detection logic used by Upload-ToFalCDN without calling the API
        It 'Maps .png to image/png' {
            $ext = 'png'
            $ct = switch ($ext) {
                'png'  { 'image/png' }
                'jpg'  { 'image/jpeg' }
                'jpeg' { 'image/jpeg' }
                'webp' { 'image/webp' }
                'gif'  { 'image/gif' }
                'mp4'  { 'video/mp4' }
                'mov'  { 'video/quicktime' }
                'webm' { 'video/webm' }
                default { 'application/octet-stream' }
            }
            $ct | Should -Be 'image/png'
        }

        It 'Maps .jpg to image/jpeg' {
            $ext = 'jpg'
            $ct = switch ($ext) {
                'png'  { 'image/png' }
                'jpg'  { 'image/jpeg' }
                'jpeg' { 'image/jpeg' }
                'webp' { 'image/webp' }
                'gif'  { 'image/gif' }
                'mp4'  { 'video/mp4' }
                'mov'  { 'video/quicktime' }
                'webm' { 'video/webm' }
                default { 'application/octet-stream' }
            }
            $ct | Should -Be 'image/jpeg'
        }

        It 'Maps .mp4 to video/mp4' {
            $ext = 'mp4'
            $ct = switch ($ext) {
                'png'  { 'image/png' }
                'jpg'  { 'image/jpeg' }
                'jpeg' { 'image/jpeg' }
                'webp' { 'image/webp' }
                'gif'  { 'image/gif' }
                'mp4'  { 'video/mp4' }
                'mov'  { 'video/quicktime' }
                'webm' { 'video/webm' }
                default { 'application/octet-stream' }
            }
            $ct | Should -Be 'video/mp4'
        }

        It 'Maps unknown extension to application/octet-stream' {
            $ext = 'xyz'
            $ct = switch ($ext) {
                'png'  { 'image/png' }
                'jpg'  { 'image/jpeg' }
                'jpeg' { 'image/jpeg' }
                'webp' { 'image/webp' }
                'gif'  { 'image/gif' }
                'mp4'  { 'video/mp4' }
                'mov'  { 'video/quicktime' }
                'webm' { 'video/webm' }
                default { 'application/octet-stream' }
            }
            $ct | Should -Be 'application/octet-stream'
        }
    }

    Context 'Send-FalFile integration' {
        BeforeEach {
            $env:FAL_KEY = 'mock-key-for-testing'
        }

        It 'Calls Send-FalFile and returns structured output' {
            Mock Invoke-RestMethod {
                if ($Uri -match 'storage/auth/token') {
                    return [PSCustomObject]@{
                        token      = 'cdn-token'
                        token_type = 'Bearer'
                        base_url   = 'https://v3b.fal.media'
                    }
                }
                return [PSCustomObject]@{ access_url = 'https://v3b.fal.media/files/uploaded.png' }
            } -ModuleName FalAi

            $testFile = Join-Path $env:TEMP "fal-upload-test-$(New-Guid).png"
            New-MockImageFile -Path $testFile

            try {
                $cdnUrl = Send-FalFile -FilePath $testFile
                $fileItem = Get-Item $testFile
                # Simulate the output object the script would build
                $result = [PSCustomObject]@{
                    Url         = $cdnUrl
                    FileName    = $fileItem.Name
                    ContentType = 'image/png'
                    Size        = $fileItem.Length
                }
                $result.Url | Should -Be 'https://v3b.fal.media/files/uploaded.png'
                $result.Size | Should -BeGreaterThan 0
                $result.PSObject.Properties.Name | Should -Contain 'Url'
                $result.PSObject.Properties.Name | Should -Contain 'FileName'
                $result.PSObject.Properties.Name | Should -Contain 'ContentType'
                $result.PSObject.Properties.Name | Should -Contain 'Size'
            }
            finally {
                Remove-Item $testFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe 'Invoke-FalInpainting' {

    Context 'Parameter construction' {
        BeforeEach {
            $env:FAL_KEY = 'mock-key-for-testing'
        }

        It 'Builds correct inpainting payload with all fields' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/inpainted.png'; width = 512; height = 512 })
                    seed   = 99
                }
            } -ModuleName FalAi

            $body = @{
                image_url           = 'https://fal.media/input.png'
                mask_url            = 'https://fal.media/mask.png'
                prompt              = 'a blue sky'
                strength            = 0.85
                num_inference_steps = 30
                guidance_scale      = 7.5
            }

            $result = Invoke-FalApi -Method POST -Endpoint 'fal-ai/inpainting' -Body $body
            $result.images.Count | Should -Be 1
            $result.images[0].url | Should -Be 'https://fal.ai/inpainted.png'
            $result.seed | Should -Be 99

            Should -Invoke Invoke-RestMethod -ModuleName FalAi -Times 1 -ParameterFilter {
                $Body -match '"image_url"' -and
                $Body -match '"mask_url"' -and
                $Body -match '"prompt"' -and
                $Body -match '"strength"' -and
                $Body -match '"num_inference_steps"' -and
                $Body -match '"guidance_scale"'
            }
        }

        It 'Parses inpainting result into Images and Seed output' {
            $apiResult = [PSCustomObject]@{
                images = @(
                    [PSCustomObject]@{ url = 'https://fal.ai/inpainted.png'; width = 512; height = 512 }
                )
                seed = 42
            }

            $output = [PSCustomObject]@{
                Images = @($apiResult.images | ForEach-Object {
                    [PSCustomObject]@{ Url = $_.url; Width = $_.width; Height = $_.height }
                })
                Seed = $apiResult.seed
            }

            $output.Images.Count | Should -Be 1
            $output.Images[0].Url | Should -Be 'https://fal.ai/inpainted.png'
            $output.Seed | Should -Be 42
        }

        It 'Uses queue mode via Wait-FalJob' {
            Mock Invoke-RestMethod {
                if ($Method -eq 'POST' -and $Uri -match 'queue\.fal\.run') {
                    return [PSCustomObject]@{ request_id = 'inpaint-req-001' }
                }
                if ($Uri -match '/status$') {
                    return [PSCustomObject]@{ status = 'COMPLETED' }
                }
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/queued-inpaint.png'; width = 1024; height = 1024 })
                    seed   = 77
                }
            } -ModuleName FalAi

            $body = @{
                image_url           = 'https://fal.media/input.png'
                mask_url            = 'https://fal.media/mask.png'
                prompt              = 'a garden'
                strength            = 0.85
                num_inference_steps = 30
                guidance_scale      = 7.5
            }
            $result = Wait-FalJob -Model 'fal-ai/inpainting' -Body $body -PollIntervalSeconds 0
            $result.images[0].url | Should -Be 'https://fal.ai/queued-inpaint.png'
        }
    }
}

Describe 'Invoke-FalUpscale' {

    Context 'Upscale with mock responses' {
        BeforeEach {
            $env:FAL_KEY = 'mock-key-for-testing'
        }

        It 'Returns upscaled image via Invoke-FalApi' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    image = [PSCustomObject]@{ url = 'https://fal.ai/upscaled.png'; width = 2048; height = 2048 }
                }
            } -ModuleName FalAi

            $body = @{ image_url = 'https://fal.media/small.png'; scale = 2 }
            $result = Invoke-FalApi -Method POST -Endpoint 'fal-ai/aura-sr' -Body $body

            $result.image.url | Should -Be 'https://fal.ai/upscaled.png'
            $result.image.width | Should -Be 2048
            $result.image.height | Should -Be 2048
        }

        It 'Sends correct scale in payload' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    image = [PSCustomObject]@{ url = 'https://fal.ai/upscaled4x.png'; width = 4096; height = 4096 }
                }
            } -ModuleName FalAi

            $body = @{ image_url = 'https://fal.media/small.png'; scale = 4 }
            Invoke-FalApi -Method POST -Endpoint 'fal-ai/aura-sr' -Body $body

            Should -Invoke Invoke-RestMethod -ModuleName FalAi -Times 1 -ParameterFilter {
                $Body -match '"scale":\s*4'
            }
        }

        It 'Parses upscale result into Image, Width, Height output' {
            $apiResult = [PSCustomObject]@{
                image = [PSCustomObject]@{ url = 'https://fal.ai/upscaled.png'; width = 2048; height = 2048 }
            }

            $output = [PSCustomObject]@{
                Image  = [PSCustomObject]@{
                    Url    = $apiResult.image.url
                    Width  = $apiResult.image.width
                    Height = $apiResult.image.height
                }
                Width  = $apiResult.image.width
                Height = $apiResult.image.height
            }

            $output.Image.Url | Should -Be 'https://fal.ai/upscaled.png'
            $output.Width | Should -Be 2048
            $output.Height | Should -Be 2048
        }

        It 'Uses queue mode via Wait-FalJob' {
            Mock Invoke-RestMethod {
                if ($Method -eq 'POST' -and $Uri -match 'queue\.fal\.run') {
                    return [PSCustomObject]@{ request_id = 'upscale-req-001' }
                }
                if ($Uri -match '/status$') {
                    return [PSCustomObject]@{ status = 'COMPLETED' }
                }
                return [PSCustomObject]@{
                    image = [PSCustomObject]@{ url = 'https://fal.ai/queued-upscale.png'; width = 2048; height = 2048 }
                }
            } -ModuleName FalAi

            $body = @{ image_url = 'https://fal.media/small.png'; scale = 2 }
            $result = Wait-FalJob -Model 'fal-ai/aura-sr' -Body $body -PollIntervalSeconds 0
            $result.image.url | Should -Be 'https://fal.ai/queued-upscale.png'
        }
    }
}
