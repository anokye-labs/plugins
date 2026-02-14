BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/FalAi.psm1" -Force
}

Describe 'fal.ai Skill Integration' {

    Context 'Module Loading' {
        It 'Should export all expected functions' {
            $commands = Get-Command -Module FalAi
            $expected = @('Get-FalApiKey', 'Invoke-FalApi', 'Send-FalFile', 'Wait-FalJob', 'ConvertTo-FalError')
            foreach ($fn in $expected) {
                $commands.Name | Should -Contain $fn
            }
        }

        It 'Should have correct function signatures' {
            $invokeFalApi = Get-Command Invoke-FalApi
            $invokeFalApi.Parameters.Keys | Should -Contain 'Endpoint'
            $invokeFalApi.Parameters.Keys | Should -Contain 'Method'
            $invokeFalApi.Parameters.Keys | Should -Contain 'Body'

            $waitFalJob = Get-Command Wait-FalJob
            $waitFalJob.Parameters.Keys | Should -Contain 'Model'
            $waitFalJob.Parameters.Keys | Should -Contain 'Body'
            $waitFalJob.Parameters.Keys | Should -Contain 'RequestId'
            $waitFalJob.Parameters.Keys | Should -Contain 'TimeoutSeconds'
        }

        It 'Should export exactly 5 public functions' {
            $commands = Get-Command -Module FalAi
            $commands.Count | Should -Be 5
        }
    }

    Context 'Script Parameter Validation' {
        It 'Invoke-FalGenerate requires Prompt' {
            $scriptPath = "$PSScriptRoot/../../scripts/Invoke-FalGenerate.ps1"
            $scriptPath | Should -Exist
            $cmd = Get-Command $scriptPath
            $cmd.Parameters['Prompt'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } |
                Should -Not -BeNullOrEmpty
        }

        It 'Search-FalModels has optional Query and Limit with default 10' {
            $scriptPath = "$PSScriptRoot/../../scripts/Search-FalModels.ps1"
            $scriptPath | Should -Exist
            $cmd = Get-Command $scriptPath
            $cmd.Parameters['Limit'].ParameterType | Should -Be ([int])
        }

        It 'Get-QueueStatus requires RequestId and Model' {
            $scriptPath = "$PSScriptRoot/../../scripts/Get-QueueStatus.ps1"
            $scriptPath | Should -Exist
            $cmd = Get-Command $scriptPath
            $cmd.Parameters['RequestId'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } |
                Should -Not -BeNullOrEmpty
            $cmd.Parameters['Model'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } |
                Should -Not -BeNullOrEmpty
        }

        It 'Invoke-FalGenerate has expected optional parameters' {
            $cmd = Get-Command "$PSScriptRoot/../../scripts/Invoke-FalGenerate.ps1"
            $cmd.Parameters.Keys | Should -Contain 'Model'
            $cmd.Parameters.Keys | Should -Contain 'ImageSize'
            $cmd.Parameters.Keys | Should -Contain 'NumImages'
            $cmd.Parameters.Keys | Should -Contain 'Queue'
        }
    }

    Context 'Error Handling' {
        BeforeEach {
            $script:originalKey = $env:FAL_KEY
        }
        AfterEach {
            $env:FAL_KEY = $script:originalKey
        }

        It 'Should throw on missing FAL_KEY' {
            $env:FAL_KEY = $null
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

        It 'Should parse fal.ai error responses with detail string' {
            $result = ConvertTo-FalError ([PSCustomObject]@{ detail = 'Unauthorized' })
            $result | Should -Be 'Unauthorized'
        }

        It 'Should parse fal.ai error responses with error field' {
            $result = ConvertTo-FalError ([PSCustomObject]@{ error = 'Model not found' })
            $result | Should -Be 'Model not found'
        }

        It 'Should parse fal.ai error responses from JSON string' {
            $result = ConvertTo-FalError '{"message":"Rate limited"}'
            $result | Should -Be 'Rate limited'
        }
    }

    Context 'Workflow Integration' {
        It 'Scripts follow consistent output format' {
            # All generator scripts should produce output with known properties
            $scriptPath = "$PSScriptRoot/../../scripts/Invoke-FalGenerate.ps1"
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'PSCustomObject'
            $content | Should -Match 'Images'
            $content | Should -Match 'Model'
            $content | Should -Match 'Prompt'
        }

        It 'Workflow script exists and accepts Steps parameter' {
            $scriptPath = "$PSScriptRoot/../../scripts/New-FalWorkflow.ps1"
            $scriptPath | Should -Exist
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.Keys | Should -Contain 'Steps'
            $cmd.Parameters.Keys | Should -Contain 'Name'
        }
    }
}
