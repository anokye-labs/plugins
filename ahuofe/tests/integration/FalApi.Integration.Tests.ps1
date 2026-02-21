BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/FalAi.psm1" -Force
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
}

Describe 'fal.ai API Integration' {

    BeforeEach {
        $script:savedKey = $env:FAL_KEY
        $env:FAL_KEY = 'integration-test-key'
    }
    AfterEach {
        $env:FAL_KEY = $script:savedKey
    }

    Context 'Invoke-FalApi POST' {
        It 'Sends POST with JSON body and returns parsed response' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/int.png'; width = 1024; height = 768 })
                }
            } -ModuleName FalAi

            $result = Invoke-FalApi -Method POST -Endpoint 'fal-ai/flux/dev' -Body @{ prompt = 'hello' }
            $result.images[0].url | Should -Be 'https://fal.ai/int.png'

            Should -Invoke Invoke-RestMethod -ModuleName FalAi -Times 1 -ParameterFilter {
                $Method -eq 'POST' -and
                $Uri -eq 'https://fal.run/fal-ai/flux/dev' -and
                $Headers['Authorization'] -eq 'Key integration-test-key' -and
                $Body -match '"prompt"'
            }
        }
    }

    Context 'Invoke-FalApi GET' {
        It 'Sends GET request without body' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{ status = 'ok' }
            } -ModuleName FalAi

            $result = Invoke-FalApi -Method GET -Endpoint 'fal-ai/flux/dev'
            $result.status | Should -Be 'ok'

            Should -Invoke Invoke-RestMethod -ModuleName FalAi -Times 1 -ParameterFilter {
                $Method -eq 'GET' -and $Uri -eq 'https://fal.run/fal-ai/flux/dev'
            }
        }
    }

    Context 'Retry logic' {
        It 'Retries on 500 error then succeeds' {
            $script:retryCount = 0
            Mock Invoke-RestMethod {
                $script:retryCount++
                if ($script:retryCount -le 1) {
                    $ex = [System.Exception]::new('Server error')
                    $resp = [PSCustomObject]@{ StatusCode = [int]500 }
                    $ex | Add-Member -NotePropertyName 'Response' -NotePropertyValue $resp
                    throw $ex
                }
                return [PSCustomObject]@{ ok = $true }
            } -ModuleName FalAi

            Mock Start-Sleep {} -ModuleName FalAi

            $result = Invoke-FalApi -Method GET -Endpoint 'fal-ai/test'
            $result.ok | Should -Be $true
            $script:retryCount | Should -BeGreaterOrEqual 2
        }
    }

    Context 'ConvertTo-FalError' {
        It 'Extracts detail string' {
            $result = ConvertTo-FalError ([PSCustomObject]@{ detail = 'Invalid key' })
            $result | Should -Be 'Invalid key'
        }

        It 'Extracts detail array with msg fields' {
            $response = [PSCustomObject]@{
                detail = @(
                    [PSCustomObject]@{ msg = 'field required' }
                    [PSCustomObject]@{ msg = 'bad format' }
                )
            }
            $result = ConvertTo-FalError $response
            $result | Should -Match 'field required'
            $result | Should -Match 'bad format'
        }

        It 'Extracts error field' {
            $result = ConvertTo-FalError ([PSCustomObject]@{ error = 'Not found' })
            $result | Should -Be 'Not found'
        }

        It 'Extracts message field' {
            $result = ConvertTo-FalError ([PSCustomObject]@{ message = 'Rate limited' })
            $result | Should -Be 'Rate limited'
        }

        It 'Parses JSON string' {
            $result = ConvertTo-FalError '{"detail":"Bad request"}'
            $result | Should -Be 'Bad request'
        }

        It 'Falls back for unknown format' {
            $result = ConvertTo-FalError ([PSCustomObject]@{ foo = 'bar' })
            $result | Should -Match 'Unknown fal.ai error'
        }
    }
}
