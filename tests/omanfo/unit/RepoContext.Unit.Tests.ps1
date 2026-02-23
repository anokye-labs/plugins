# RepoContext.Unit.Tests.ps1
# Pester tests for Get-RepoContext caching script

BeforeAll {
    $scriptsPath = Join-Path $PSScriptRoot "../../../omanfo/skills/okyerema/scripts"
    $scriptPath  = Join-Path $scriptsPath "Get-RepoContext.ps1"

    $mockResponse = @'
{
  "data": {
    "repository": {
      "id": "R_kgDOABCDEF",
      "name": "test-repo",
      "owner": { "login": "test-org" }
    }
  }
}
'@
}

Describe "Get-RepoContext" {

    It "Should exist at the expected path" {
        Test-Path $scriptPath | Should -Be $true
    }

    It "Should have optional Owner parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Owner"
        $cmd.Parameters['Owner'].Attributes.Mandatory | Should -Be $false
    }

    It "Should have optional Repo parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Repo"
        $cmd.Parameters['Repo'].Attributes.Mandatory | Should -Be $false
    }

    It "Should have Force switch parameter" {
        $cmd = Get-Command $scriptPath
        $cmd.Parameters.Keys | Should -Contain "Force"
    }

    It "Should return PSCustomObject with Owner, Repo, NodeId" {
        Mock gh {
            $global:LASTEXITCODE = 0
            return $mockResponse
        } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        $result | Should -BeOfType [PSCustomObject]
        $result.PSObject.Properties.Name | Should -Contain "Owner"
        $result.PSObject.Properties.Name | Should -Contain "Repo"
        $result.PSObject.Properties.Name | Should -Contain "NodeId"
    }

    It "Should return correct Owner value from API response" {
        Mock gh {
            $global:LASTEXITCODE = 0
            return $mockResponse
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath -Owner "test-org" -Repo "test-repo"

        $result.Owner  | Should -Be "test-org"
        $result.Repo   | Should -Be "test-repo"
        $result.NodeId | Should -Be "R_kgDOABCDEF"
    }

    It "Should query repository via GraphQL" {
        Mock gh {
            $global:LASTEXITCODE = 0
            return $mockResponse
        } -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }

        { & $scriptPath -Owner "test-org" -Repo "test-repo" *>&1 } | Should -Not -Throw

        Should -Invoke gh -Times 1 -ParameterFilter { $args[0] -eq 'api' -and $args[1] -eq 'graphql' }
    }

    It "Should throw when API call fails" {
        Mock gh {
            $global:LASTEXITCODE = 1
            return "API error"
        } -ParameterFilter { $args[0] -eq 'api' }

        { & $scriptPath -Owner "test-org" -Repo "test-repo" } | Should -Throw
    }

    It "Should throw when Owner and Repo cannot be resolved" {
        Mock git {
            return $null
        } -ParameterFilter { $args[0] -eq 'remote' }

        { & $scriptPath } | Should -Throw "*Could not determine Owner and Repo*"
    }

    It "Should auto-detect Owner and Repo from git remote" {
        Mock git {
            return "https://github.com/auto-owner/auto-repo.git"
        } -ParameterFilter { $args[0] -eq 'remote' -and $args[1] -eq 'get-url' }

        $autoResponse = @'
{
  "data": {
    "repository": {
      "id": "R_auto123",
      "name": "auto-repo",
      "owner": { "login": "auto-owner" }
    }
  }
}
'@
        Mock gh {
            $global:LASTEXITCODE = 0
            return $autoResponse
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath

        $result.Owner  | Should -Be "auto-owner"
        $result.Repo   | Should -Be "auto-repo"
        $result.NodeId | Should -Be "R_auto123"
    }

    It "Should auto-detect from SSH remote URL" {
        Mock git {
            return "git@github.com:ssh-owner/ssh-repo.git"
        } -ParameterFilter { $args[0] -eq 'remote' -and $args[1] -eq 'get-url' }

        $sshResponse = @'
{
  "data": {
    "repository": {
      "id": "R_ssh456",
      "name": "ssh-repo",
      "owner": { "login": "ssh-owner" }
    }
  }
}
'@
        Mock gh {
            $global:LASTEXITCODE = 0
            return $sshResponse
        } -ParameterFilter { $args[0] -eq 'api' }

        $result = & $scriptPath

        $result.Owner | Should -Be "ssh-owner"
        $result.Repo  | Should -Be "ssh-repo"
    }

    It "Should cache result and avoid repeated API calls on subsequent invocations" {
        # Dot-source without parameters to load the function definition only
        . $scriptPath

        # Reset the cache so this test starts fresh
        $script:_repoContextCache = $null

        Mock gh {
            $global:LASTEXITCODE = 0
            return $mockResponse
        } -ParameterFilter { $args[0] -eq 'api' }

        # First call populates the cache
        $first = Get-RepoContext -Owner "test-org" -Repo "test-repo"

        # Second call should return the cached result without hitting the API again
        $second = Get-RepoContext -Owner "test-org" -Repo "test-repo"

        $second.NodeId | Should -Be $first.NodeId
        Should -Invoke gh -Times 1 -ParameterFilter { $args[0] -eq 'api' }
    }

    It "Should bypass cache when -Force is specified" {
        # Dot-source without parameters to load the function definition only
        . $scriptPath

        # Reset cache so this test starts fresh
        $script:_repoContextCache = $null

        Mock gh {
            $global:LASTEXITCODE = 0
            return $mockResponse
        } -ParameterFilter { $args[0] -eq 'api' }

        # First call populates the cache
        Get-RepoContext -Owner "test-org" -Repo "test-repo" | Out-Null

        # Second call with -Force must re-query the API
        Get-RepoContext -Owner "test-org" -Repo "test-repo" -Force | Out-Null

        Should -Invoke gh -Times 2 -ParameterFilter { $args[0] -eq 'api' }
    }
}
