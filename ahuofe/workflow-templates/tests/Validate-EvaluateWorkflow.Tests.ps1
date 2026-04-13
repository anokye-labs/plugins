BeforeAll {
    $script:workflowPath = Join-Path (Resolve-Path "$PSScriptRoot/..") 'ahuofe-evaluate.yml'
    $script:content = Get-Content $script:workflowPath -Raw
    $script:lines = Get-Content $script:workflowPath
}

Describe 'Evaluate Workflow' {

    Context 'Trigger configuration' {
        It 'Should use workflow_call trigger' {
            $script:content | Should -Match 'workflow_call:'
        }

        It 'Should have entity input' {
            $script:content | Should -Match 'entity:'
        }

        It 'Should mark entity as required' {
            $script:content | Should -Match '(?s)entity:.*?required:\s*true'
        }

        It 'Should have config_path input' {
            $script:content | Should -Match 'config_path:'
        }

        It 'Should have pr_number input' {
            $script:content | Should -Match 'pr_number:'
        }
    }

    Context 'Secrets' {
        It 'Should require ANTHROPIC_API_KEY for vision evaluation' {
            $script:content | Should -Match 'ANTHROPIC_API_KEY:'
        }
    }

    Context 'Outputs' {
        It 'Should output drift_score' {
            $script:content | Should -Match 'drift_score:'
        }

        It 'Should define drift_score in workflow outputs' {
            $script:content | Should -Match '(?s)outputs:.*drift_score:'
        }
    }

    Context 'Evaluate job' {
        It 'Should have an evaluate job' {
            $script:content | Should -Match '(?m)^\s{2}evaluate:'
        }

        It 'Should run on ubuntu-latest' {
            $script:content | Should -Match 'runs-on:\s*ubuntu-latest'
        }
    }

    Context 'Drift evaluation step' {
        It 'Should invoke evaluate-drift.ts' {
            $script:content | Should -Match 'evaluate-drift\.ts'
        }

        It 'Should pass --entity flag' {
            $script:content | Should -Match '(?s)evaluate-drift\.ts.*--entity'
        }

        It 'Should pass --config flag' {
            $script:content | Should -Match '(?s)evaluate-drift\.ts.*--config'
        }

        It 'Should use ANTHROPIC_API_KEY environment variable' {
            $script:content | Should -Match 'ANTHROPIC_API_KEY:\s*\$\{\{\s*secrets\.ANTHROPIC_API_KEY\s*\}\}'
        }

        It 'Should write drift_score to GITHUB_OUTPUT' {
            $script:content | Should -Match 'GITHUB_OUTPUT'
        }
    }

    Context 'PR comment step' {
        It 'Should post drift score as PR comment' {
            $script:content | Should -Match 'gh pr comment'
        }

        It 'Should reference the drift score in the comment' {
            $script:content | Should -Match 'drift_score'
        }

        It 'Should use GITHUB_TOKEN for PR API access' {
            $script:content | Should -Match 'GITHUB_TOKEN'
        }
    }

    Context 'Node.js setup' {
        It 'Should use Node.js 20' {
            $script:content | Should -Match 'node-version:\s*20'
        }

        It 'Should install pipeline dependencies' {
            $script:content | Should -Match 'npm ci'
        }
    }

    Context 'Plugin repo checkout' {
        It 'Should checkout anokye-labs/plugins repo' {
            $script:content | Should -Match 'repository:\s*anokye-labs/plugins'
        }

        It 'Should use sparse-checkout for ahuofe directory' {
            $script:content | Should -Match 'sparse-checkout:\s*ahuofe/'
        }
    }

    Context 'Permissions' {
        It 'Should have pull-requests: write permission for commenting' {
            $script:content | Should -Match 'pull-requests:\s*write'
        }
    }
}
