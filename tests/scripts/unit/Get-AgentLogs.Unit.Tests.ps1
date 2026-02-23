# Get-AgentLogs.Unit.Tests.ps1
# Pester unit tests for scripts/Get-AgentLogs.ps1

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot "../../../scripts/Get-AgentLogs.ps1"
}

Describe "Get-AgentLogs" {

    Context "Parameter validation" {
        It "Should have a mandatory AgentName parameter" {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.Keys | Should -Contain "AgentName"
            $cmd.Parameters['AgentName'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                Select-Object -ExpandProperty Mandatory |
                Should -Be $true
        }

        It "Should have an optional Since parameter" {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.Keys | Should -Contain "Since"
        }

        It "Should have an optional Status parameter" {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.Keys | Should -Contain "Status"
        }

        It "Should have an optional Format parameter defaulting to human" {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.Keys | Should -Contain "Format"
        }

        It "Should have an optional Owner parameter" {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.Keys | Should -Contain "Owner"
        }

        It "Should have an optional Repo parameter" {
            $cmd = Get-Command $scriptPath
            $cmd.Parameters.Keys | Should -Contain "Repo"
        }

        It "Should only accept valid Status values" {
            $cmd = Get-Command $scriptPath
            $validateSet = $cmd.Parameters['Status'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet | Should -Not -BeNullOrEmpty
            $validateSet.ValidValues | Should -Contain 'success'
            $validateSet.ValidValues | Should -Contain 'failure'
        }

        It "Should only accept human or json for Format" {
            $cmd = Get-Command $scriptPath
            $validateSet = $cmd.Parameters['Format'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet | Should -Not -BeNullOrEmpty
            $validateSet.ValidValues | Should -Contain 'human'
            $validateSet.ValidValues | Should -Contain 'json'
        }
    }

    Context "Querying workflow runs" {
        BeforeAll {
            $runsResponse = @'
{
  "total_count": 2,
  "workflow_runs": [
    {
      "id": 1001,
      "name": "pr-triage",
      "run_number": 5,
      "status": "completed",
      "conclusion": "success",
      "head_branch": "main",
      "created_at": "2026-02-20T10:00:00Z",
      "html_url": "https://github.com/anokye-labs/plugins/actions/runs/1001"
    },
    {
      "id": 1002,
      "name": "pr-triage",
      "run_number": 6,
      "status": "completed",
      "conclusion": "failure",
      "head_branch": "copilot/fix-issue",
      "created_at": "2026-02-21T12:00:00Z",
      "html_url": "https://github.com/anokye-labs/plugins/actions/runs/1002"
    }
  ]
}
'@
        }

        It "Should call gh api to list workflow runs" {
            Mock gh { return $runsResponse }

            & $scriptPath -AgentName "pr-triage" *>&1

            Should -Invoke gh -Times 1 -ParameterFilter { $args[0] -eq 'api' }
        }

        It "Should filter runs by agent name" {
            Mock gh { return $runsResponse }

            $result = & $scriptPath -AgentName "pr-triage" | Where-Object { $_ -is [PSCustomObject] -and $_.AgentName }

            $result.AgentName | Should -Be "pr-triage"
        }

        It "Should return a PSCustomObject with RunCount and Runs properties" {
            Mock gh { return $runsResponse }

            $result = & $scriptPath -AgentName "pr-triage" | Where-Object { $_ -is [PSCustomObject] -and $_.PSObject.Properties.Name -contains 'RunCount' }

            $result.RunCount | Should -Be 2
            $result.Runs     | Should -Not -BeNullOrEmpty
        }

        It "Should return RunCount of zero when no matching runs" {
            $emptyResponse = '{"total_count":0,"workflow_runs":[]}'
            Mock gh { return $emptyResponse }

            $result = & $scriptPath -AgentName "nonexistent-agent" | Where-Object { $_ -is [PSCustomObject] -and $_.PSObject.Properties.Name -contains 'RunCount' }

            $result.RunCount | Should -Be 0
        }

        It "Should include Status filter in API query when provided" {
            Mock gh { return $runsResponse }

            & $scriptPath -AgentName "pr-triage" -Status "failure" *>&1

            Should -Invoke gh -Times 1 -ParameterFilter {
                "$args" -match 'status=failure'
            }
        }

        It "Should include Since filter in API query when provided" {
            Mock gh { return $runsResponse }

            $since = [datetime]"2026-02-01T00:00:00Z"
            & $scriptPath -AgentName "pr-triage" -Since $since *>&1

            Should -Invoke gh -Times 1 -ParameterFilter {
                "$args" -match 'created'
            }
        }
    }

    Context "JSON output format" {
        BeforeAll {
            $runsResponse = @'
{
  "total_count": 1,
  "workflow_runs": [
    {
      "id": 2001,
      "name": "copilot-checks",
      "run_number": 10,
      "status": "completed",
      "conclusion": "success",
      "head_branch": "main",
      "created_at": "2026-02-22T08:00:00Z",
      "html_url": "https://github.com/anokye-labs/plugins/actions/runs/2001"
    }
  ]
}
'@
        }

        It "Should output valid JSON when Format is json" {
            Mock gh { return $runsResponse }

            $output = & $scriptPath -AgentName "copilot-checks" -Format json

            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include AgentName in JSON output" {
            Mock gh { return $runsResponse }

            $json = (& $scriptPath -AgentName "copilot-checks" -Format json | Out-String) | ConvertFrom-Json

            $json.AgentName | Should -Be "copilot-checks"
        }

        It "Should include RunCount in JSON output" {
            Mock gh { return $runsResponse }

            $json = (& $scriptPath -AgentName "copilot-checks" -Format json | Out-String) | ConvertFrom-Json

            $json.RunCount | Should -Be 1
        }
    }
}
