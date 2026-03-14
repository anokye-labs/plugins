BeforeAll {
    $script:workflowPath = Join-Path (Resolve-Path "$PSScriptRoot/..") 'ahuofe-cleanup.yml'
    $script:content = Get-Content $script:workflowPath -Raw
    $script:lines = Get-Content $script:workflowPath
}

Describe 'Cleanup Workflow' {

    Context 'Trigger configuration' {
        It 'Should use workflow_call trigger' {
            $script:content | Should -Match 'workflow_call:'
        }

        It 'Should have config_path input' {
            $script:content | Should -Match 'config_path:'
        }

        It 'Should mark config_path as required' {
            $script:content | Should -Match '(?s)config_path:.*?required:\s*true'
        }
    }

    Context 'Merge condition' {
        It 'Should check that PR was merged' {
            $script:content | Should -Match 'github\.event\.pull_request\.merged\s*==\s*true'
        }
    }

    Context 'Cleanup job' {
        It 'Should have a cleanup job' {
            $script:content | Should -Match '(?m)^\s{2}cleanup:'
        }

        It 'Should run on ubuntu-latest' {
            $script:content | Should -Match 'runs-on:\s*ubuntu-latest'
        }
    }

    Context 'Prune generations step' {
        It 'Should run prune-generations action' {
            $script:content | Should -Match 'prune-generations\.ts'
        }

        It 'Should pass --config flag to prune' {
            $script:content | Should -Match '(?s)prune-generations\.ts.*--config'
        }

        It 'Should pass --generations flag to prune' {
            $script:content | Should -Match '(?s)prune-generations\.ts.*--generations'
        }
    }

    Context 'Build lineage step' {
        It 'Should run build-lineage action' {
            $script:content | Should -Match 'build-lineage\.ts'
        }

        It 'Should pass --generations flag to lineage builder' {
            $script:content | Should -Match '(?s)build-lineage\.ts.*--generations'
        }

        It 'Should pass --output flag to lineage builder' {
            $script:content | Should -Match '(?s)build-lineage\.ts.*--output'
        }
    }

    Context 'Branch deletion step' {
        It 'Should delete the merged PR branch' {
            $script:content | Should -Match 'git push origin --delete'
        }

        It 'Should guard against deleting main branch' {
            $script:content | Should -Match 'main'
        }

        It 'Should reference PR head ref for branch name' {
            $script:content | Should -Match 'github\.event\.pull_request\.head\.ref'
        }
    }

    Context 'Viewer deployment' {
        It 'Should deploy viewer to GitHub Pages' {
            $script:content | Should -Match 'actions/deploy-pages@v4'
        }

        It 'Should upload pages artifact' {
            $script:content | Should -Match 'actions/upload-pages-artifact@v3'
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
}
