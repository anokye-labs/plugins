BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/FalAi.psm1" -Force
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:generateScript = Resolve-Path "$PSScriptRoot/../../scripts/Invoke-FalGenerate.ps1"
}

Describe 'Invoke-FalGenerate' {

    BeforeEach {
        $script:savedKey = $env:FAL_KEY
        $env:FAL_KEY = 'test-key'
        # Prevent the script from re-importing the module (which clears mocks)
        Mock Import-Module {} -ParameterFilter { $Name -and "$Name" -match 'FalAi' }
    }
    AfterEach {
        $env:FAL_KEY = $script:savedKey
    }

    Context 'Sync image generation with default model (flux/dev)' {
        It 'Returns a PSCustomObject with Images array' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/gen.png'; width = 1024; height = 768 })
                    seed   = 42
                }
            } -ModuleName FalAi

            $result = & $script:generateScript -Prompt 'a sunset'
            $result | Should -BeOfType 'PSCustomObject'
            $result.Images.Count | Should -Be 1
            $result.Images[0].Url | Should -Be 'https://fal.ai/gen.png'
            $result.Seed | Should -Be 42
            $result.Model | Should -Be 'fal-ai/flux/dev'
        }
    }

    Context 'Sync generation with schnell model' {
        It 'Passes the schnell model endpoint' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/schnell.png'; width = 512; height = 512 })
                    seed   = 7
                }
            } -ModuleName FalAi

            $result = & $script:generateScript -Prompt 'fast image' -Model 'fal-ai/flux/schnell'
            $result.Model | Should -Be 'fal-ai/flux/schnell'
            $result.Images[0].Url | Should -Be 'https://fal.ai/schnell.png'

            Should -Invoke Invoke-RestMethod -ModuleName FalAi -Times 1 -ParameterFilter {
                $Uri -match 'fal-ai/flux/schnell'
            }
        }
    }

    Context 'Queue mode' {
        It 'Uses Wait-FalJob when -Queue is specified' {
            Mock Invoke-RestMethod {
                if ($Method -eq 'POST' -and $Uri -match 'queue\.fal\.run') {
                    return [PSCustomObject]@{ request_id = 'gen-q-001' }
                }
                if ($Uri -match '/status$') {
                    return [PSCustomObject]@{ status = 'COMPLETED' }
                }
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/queued.png'; width = 1024; height = 1024 })
                    seed   = 99
                }
            } -ModuleName FalAi

            $result = & $script:generateScript -Prompt 'queued prompt' -Queue
            $result.Images[0].Url | Should -Be 'https://fal.ai/queued.png'
            $result.Seed | Should -Be 99
        }
    }

    Context 'Error handling' {
        It 'Throws when FAL_KEY is not set' {
            $env:FAL_KEY = $null
            Push-Location $env:TEMP
            try {
                $envFile = Join-Path $env:TEMP '.env'
                if (Test-Path $envFile) { Remove-Item $envFile -Force }
                { & $script:generateScript -Prompt 'should fail' } | Should -Throw '*FAL_KEY*'
            }
            finally {
                Pop-Location
            }
        }
    }

    Context '-FilePath auto-upload' {
        It 'Calls Send-FalFile and uses the returned URL as ImageUrl' {
            $tmpFile = Join-Path ([System.IO.Path]::GetTempPath()) 'test-upload.png'
            New-MockImageFile -Path $tmpFile | Out-Null
            try {
                Mock Send-FalFile { return 'https://cdn.fal.ai/uploaded.png' }
                Mock Invoke-RestMethod {
                    return [PSCustomObject]@{
                        images = @([PSCustomObject]@{ url = 'https://fal.ai/out.png'; width = 1024; height = 768 })
                        seed   = 1
                    }
                } -ModuleName FalAi

                $result = & $script:generateScript -Prompt 'animate' -FilePath $tmpFile
                $result.Images[0].Url | Should -Be 'https://fal.ai/out.png'

                Should -Invoke Send-FalFile -Times 1 -ParameterFilter {
                    $FilePath -eq $tmpFile
                }
            }
            finally {
                if (Test-Path $tmpFile) { Remove-Item $tmpFile -Force }
            }
        }
    }

    Context '-Async non-blocking queue submission' {
        It 'Returns the RequestId string immediately without polling' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{ request_id = 'async-req-001' }
            } -ModuleName FalAi

            $requestId = & $script:generateScript -Prompt 'async job' -Async
            $requestId | Should -Be 'async-req-001'

            Should -Invoke Invoke-RestMethod -ModuleName FalAi -Times 1 -ParameterFilter {
                $Uri -match 'queue\.fal\.run' -and $Method -eq 'POST'
            }
        }
    }

    Context '-Lifecycle CDN expiration' {
        It 'Includes x_fal_lifecycle in the request body' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/ttl.png'; width = 512; height = 512 })
                    seed   = 5
                }
            } -ModuleName FalAi

            & $script:generateScript -Prompt 'expiring image' -Lifecycle 3600 | Out-Null

            Should -Invoke Invoke-RestMethod -ModuleName FalAi -Times 1 -ParameterFilter {
                $Body -and ($Body | ConvertFrom-Json).x_fal_lifecycle -eq 3600
            }
        }
    }
}
