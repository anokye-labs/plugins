BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/FalAi.psm1" -Force
}

Describe 'Get-FalRequests' {

    BeforeEach {
        $script:savedKey = $env:FAL_KEY
        $env:FAL_KEY = 'mock-key-for-testing'
        Mock Import-Module {} -ParameterFilter { $Name -and "$Name" -match 'FalAi' }
    }

    AfterEach {
        $env:FAL_KEY = $script:savedKey
    }

    Context 'Lists requests' {
        It 'Returns structured request objects' {
            Mock Invoke-RestMethod {
                return @(
                    [PSCustomObject]@{ request_id = 'req-001'; endpoint_id = 'fal-ai/flux/dev'; status = 'COMPLETED'; created_at = '2025-01-01T00:00:00Z' }
                    [PSCustomObject]@{ request_id = 'req-002'; endpoint_id = 'fal-ai/flux/dev'; status = 'IN_QUEUE';   created_at = '2025-01-02T00:00:00Z' }
                )
            } -ModuleName FalAi

            $result = & "$PSScriptRoot/../../scripts/Get-FalRequests.ps1"
            $result.Count         | Should -Be 2
            $result[0].RequestId  | Should -Be 'req-001'
            $result[0].EndpointId | Should -Be 'fal-ai/flux/dev'
            $result[0].Status     | Should -Be 'COMPLETED'
        }

        It 'Passes ModelId as query parameter' {
            Mock Invoke-RestMethod {
                return @(
                    [PSCustomObject]@{ request_id = 'req-003'; endpoint_id = 'fal-ai/veo3.1'; status = 'COMPLETED'; created_at = '2025-01-01T00:00:00Z' }
                )
            } -ModuleName FalAi

            $result = & "$PSScriptRoot/../../scripts/Get-FalRequests.ps1" -ModelId 'fal-ai/veo3.1'
            $result.Count | Should -Be 1

            Should -Invoke Invoke-RestMethod -ModuleName FalAi -Times 1 -ParameterFilter {
                $Uri -match 'endpoint_id'
            }
        }

        It 'Returns empty array when no requests found' {
            Mock Invoke-RestMethod {
                return @()
            } -ModuleName FalAi

            $result = & "$PSScriptRoot/../../scripts/Get-FalRequests.ps1"
            $result.Count | Should -Be 0
        }

        It 'Unwraps .requests property from response' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    requests = @(
                        [PSCustomObject]@{ request_id = 'req-004'; endpoint_id = 'fal-ai/flux/dev'; status = 'COMPLETED'; created_at = '2025-01-01T00:00:00Z' }
                    )
                }
            } -ModuleName FalAi

            $result = & "$PSScriptRoot/../../scripts/Get-FalRequests.ps1"
            $result.Count | Should -Be 1
        }
    }

    Context 'Deletes request payloads' {
        It 'Calls DELETE endpoint for given request ID and returns success object' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{ success = $true }
            } -ModuleName FalAi

            $result = & "$PSScriptRoot/../../scripts/Get-FalRequests.ps1" -Delete 'req-abc123'
            $result.RequestId | Should -Be 'req-abc123'
            $result.Action    | Should -Be 'PayloadsDeleted'
            $result.Success   | Should -Be $true

            Should -Invoke Invoke-RestMethod -ModuleName FalAi -Times 1 -ParameterFilter {
                $Method -eq 'DELETE' -and $Uri -match 'req-abc123'
            }
        }

        It 'URL-encodes the Delete request ID in the DELETE endpoint path' {
            $global:capturedDeleteUri = $null
            Mock Invoke-RestMethod {
                $global:capturedDeleteUri = $Uri
                return [PSCustomObject]@{ success = $true }
            } -ModuleName FalAi

            $result = & "$PSScriptRoot/../../scripts/Get-FalRequests.ps1" -Delete 'req/with spaces&special=chars'
            $result.RequestId | Should -Be 'req/with spaces&special=chars'
            $result.Success   | Should -Be $true

            $global:capturedDeleteUri.AbsoluteUri | Should -Match 'req%2Fwith%20spaces%26special%3Dchars'
            Remove-Variable -Name capturedDeleteUri -Scope Global -ErrorAction SilentlyContinue
        }
    }
}
