BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/FalAi.psm1" -Force
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
}

Describe 'FalAi Module' {

    Context 'Module loads correctly' {
        It 'Exports all expected functions' {
            $commands = Get-Command -Module FalAi
            $commands.Name | Should -Contain 'Get-FalApiKey'
            $commands.Name | Should -Contain 'Invoke-FalApi'
            $commands.Name | Should -Contain 'Send-FalFile'
            $commands.Name | Should -Contain 'Wait-FalJob'
            $commands.Name | Should -Contain 'ConvertTo-FalError'
        }
    }

    Context 'Get-FalApiKey' {
        BeforeEach {
            $originalKey = $env:FAL_KEY
        }
        AfterEach {
            $env:FAL_KEY = $originalKey
        }

        It 'Returns the key from $env:FAL_KEY' {
            $env:FAL_KEY = 'test-key-12345'
            $result = Get-FalApiKey
            $result | Should -Be 'test-key-12345'
        }

        It 'Throws when FAL_KEY is not set and no .env file exists' {
            $env:FAL_KEY = $null
            # Run in a temp directory with no .env
            Push-Location $env:TEMP
            try {
                $envFile = Join-Path $env:TEMP '.env'
                if (Test-Path $envFile) { Remove-Item $envFile -Force }
                { Get-FalApiKey } | Should -Throw '*FAL_KEY not found*'
            }
            finally {
                Pop-Location
            }
        }

        It 'Reads from .env file when $env:FAL_KEY is not set' {
            $env:FAL_KEY = $null
            $tempDir = Join-Path $env:TEMP "fal-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            'FAL_KEY=env-file-key-999' | Set-Content (Join-Path $tempDir '.env')
            Push-Location $tempDir
            try {
                $result = Get-FalApiKey
                $result | Should -Be 'env-file-key-999'
            }
            finally {
                Pop-Location
                Remove-Item $tempDir -Recurse -Force
            }
        }

        It 'Strips quotes from .env value' {
            $env:FAL_KEY = $null
            $tempDir = Join-Path $env:TEMP "fal-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            'FAL_KEY="quoted-key-value"' | Set-Content (Join-Path $tempDir '.env')
            Push-Location $tempDir
            try {
                $result = Get-FalApiKey
                $result | Should -Be 'quoted-key-value'
            }
            finally {
                Pop-Location
                Remove-Item $tempDir -Recurse -Force
            }
        }
    }

    Context 'ConvertTo-FalError' {
        It 'Extracts detail string' {
            $response = [PSCustomObject]@{ detail = 'Invalid API key' }
            $result = ConvertTo-FalError $response
            $result | Should -Be 'Invalid API key'
        }

        It 'Extracts detail array with msg fields' {
            $response = [PSCustomObject]@{
                detail = @(
                    [PSCustomObject]@{ msg = 'field required'; type = 'value_error' }
                    [PSCustomObject]@{ msg = 'invalid format'; type = 'type_error' }
                )
            }
            $result = ConvertTo-FalError $response
            $result | Should -Match 'field required'
            $result | Should -Match 'invalid format'
        }

        It 'Extracts error field' {
            $response = [PSCustomObject]@{ error = 'Model not found' }
            $result = ConvertTo-FalError $response
            $result | Should -Be 'Model not found'
        }

        It 'Extracts message field' {
            $response = [PSCustomObject]@{ message = 'Rate limit exceeded' }
            $result = ConvertTo-FalError $response
            $result | Should -Be 'Rate limit exceeded'
        }

        It 'Parses JSON string input' {
            $json = '{"detail":"Bad request"}'
            $result = ConvertTo-FalError $json
            $result | Should -Be 'Bad request'
        }

        It 'Returns fallback for unknown format' {
            $response = [PSCustomObject]@{ foo = 'bar' }
            $result = ConvertTo-FalError $response
            $result | Should -Match 'Unknown fal.ai error'
        }
    }

    Context 'Invoke-FalApi' {
        BeforeEach {
            $env:FAL_KEY = 'mock-key-for-testing'
        }

        It 'Calls Invoke-RestMethod with correct headers and URL' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{ images = @(@{ url = 'https://fal.ai/test.png' }) }
            } -ModuleName FalAi

            $result = Invoke-FalApi -Method GET -Endpoint 'fal-ai/flux/dev'
            $result.images[0].url | Should -Be 'https://fal.ai/test.png'

            Should -Invoke Invoke-RestMethod -ModuleName FalAi -Times 1 -ParameterFilter {
                $Uri -eq 'https://fal.run/fal-ai/flux/dev' -and
                $Method -eq 'GET' -and
                $Headers['Authorization'] -eq 'Key mock-key-for-testing'
            }
        }

        It 'Sends JSON body for POST requests' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{ request_id = 'abc123' }
            } -ModuleName FalAi

            $body = @{ prompt = 'test'; image_size = 'square' }
            Invoke-FalApi -Method POST -Endpoint 'fal-ai/flux/dev' -Body $body

            Should -Invoke Invoke-RestMethod -ModuleName FalAi -Times 1 -ParameterFilter {
                $null -ne $Body -and $Body -match '"prompt"'
            }
        }

        It 'Uses RawUrl when specified' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{ status = 'ok' }
            } -ModuleName FalAi

            Invoke-FalApi -Method GET -Endpoint 'https://custom.api.com/test' -RawUrl

            Should -Invoke Invoke-RestMethod -ModuleName FalAi -Times 1 -ParameterFilter {
                $Uri -eq 'https://custom.api.com/test'
            }
        }
    }

    Context 'Send-FalFile' {
        BeforeEach {
            $env:FAL_KEY = 'mock-key-for-testing'
        }

        It 'Completes 2-step upload flow and returns URL' {
            # Mock step 1: token request
            Mock Invoke-RestMethod {
                if ($Uri -match 'storage/auth/token') {
                    return [PSCustomObject]@{
                        token      = 'cdn-token-123'
                        token_type = 'Bearer'
                        base_url   = 'https://v3b.fal.media'
                    }
                }
                # Mock step 2: file upload
                if ($Uri -match 'files/upload') {
                    return [PSCustomObject]@{
                        access_url = 'https://v3b.fal.media/files/test/image.png'
                    }
                }
            } -ModuleName FalAi

            $testFile = Join-Path $env:TEMP "fal-test-upload-$([guid]::NewGuid().ToString('N').Substring(0,8)).png"
            New-MockImageFile -Path $testFile

            try {
                $result = Send-FalFile -FilePath $testFile
                $result | Should -Be 'https://v3b.fal.media/files/test/image.png'
            }
            finally {
                Remove-Item $testFile -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Wait-FalJob' {
        BeforeEach {
            $env:FAL_KEY = 'mock-key-for-testing'
        }

        It 'Submits to queue, polls, and returns result' {
            $callCount = 0
            Mock Invoke-RestMethod {
                if ($Method -eq 'POST') {
                    return [PSCustomObject]@{ request_id = 'req-001' }
                }
                if ($Uri -match '/status$') {
                    $script:callCount++
                    if ($script:callCount -ge 2) {
                        return [PSCustomObject]@{ status = 'COMPLETED' }
                    }
                    return [PSCustomObject]@{ status = 'IN_PROGRESS' }
                }
                # Result fetch
                return [PSCustomObject]@{
                    images = @(@{ url = 'https://fal.ai/result.png'; width = 1024; height = 768 })
                }
            } -ModuleName FalAi

            $body = @{ prompt = 'test' }
            $result = Wait-FalJob -Model 'fal-ai/flux/dev' -Body $body -PollIntervalSeconds 0

            $result.images[0].url | Should -Be 'https://fal.ai/result.png'
        }

        It 'Throws on failed job' {
            Mock Invoke-RestMethod {
                if ($Method -eq 'POST') {
                    return [PSCustomObject]@{ request_id = 'req-fail' }
                }
                return [PSCustomObject]@{ status = 'FAILED'; error = 'GPU out of memory' }
            } -ModuleName FalAi

            { Wait-FalJob -Model 'fal-ai/flux/dev' -Body @{ prompt = 'x' } -PollIntervalSeconds 0 } |
                Should -Throw '*failed*'
        }
    }
}
