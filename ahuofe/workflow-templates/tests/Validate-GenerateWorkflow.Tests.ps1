BeforeAll {
    $script:workflowPath = Join-Path (Resolve-Path "$PSScriptRoot/..") 'ahuofe-generate.yml'
    $script:content = Get-Content $script:workflowPath -Raw
    $script:lines = Get-Content $script:workflowPath
}

Describe 'Generate Workflow' {

    Context 'Trigger configuration' {
        It 'Should use workflow_call trigger' {
            $script:content | Should -Match 'workflow_call:'
        }

        It 'Should have config_path input' {
            $script:content | Should -Match 'config_path:'
        }

        It 'Should have brand_path input' {
            $script:content | Should -Match 'brand_path:'
        }

        It 'Should mark config_path as required' {
            # Find the config_path block and check required: true follows
            $script:content | Should -Match '(?s)config_path:.*?required:\s*true'
        }

        It 'Should mark brand_path as required' {
            $script:content | Should -Match '(?s)brand_path:.*?required:\s*true'
        }
    }

    Context 'Secrets' {
        It 'Should require FAL_KEY secret' {
            $script:content | Should -Match 'FAL_KEY:'
        }

        It 'Should require ANTHROPIC_API_KEY secret' {
            $script:content | Should -Match 'ANTHROPIC_API_KEY:'
        }

        It 'Should have a secrets section under workflow_call' {
            $script:content | Should -Match '(?s)workflow_call:.*?secrets:'
        }
    }

    Context 'Permissions' {
        It 'Should have contents: write permission' {
            $script:content | Should -Match 'contents:\s*write'
        }

        It 'Should have pull-requests: write permission' {
            $script:content | Should -Match 'pull-requests:\s*write'
        }
    }

    Context 'Jobs' {
        It 'Should have a plan job' {
            $script:content | Should -Match '(?m)^\s{2}plan:'
        }

        It 'Should have a generate job' {
            $script:content | Should -Match '(?m)^\s{2}generate:'
        }

        It 'Should have a report job' {
            $script:content | Should -Match '(?m)^\s{2}report:'
        }

        It 'Should have an approval job' {
            $script:content | Should -Match '(?m)^\s{2}approval:'
        }
    }

    Context 'Plan job' {
        It 'Should output entities' {
            $script:content | Should -Match '(?s)outputs:.*entities:'
        }

        It 'Should output stage' {
            $script:content | Should -Match '(?s)outputs:.*stage:'
        }

        It 'Should run diff-brand for pull_request events' {
            $script:content | Should -Match 'diff-brand\.ts'
        }

        It 'Should run parse-comment for comment events' {
            $script:content | Should -Match 'parse-comment\.ts'
        }
    }

    Context 'Generate job' {
        It 'Should use Node.js 20' {
            $script:content | Should -Match 'node-version:\s*20'
        }

        It 'Should install pipeline dependencies with npm ci' {
            $script:content | Should -Match 'npm ci'
        }

        It 'Should run pipeline via npx tsx' {
            $script:content | Should -Match 'npx tsx'
        }

        It 'Should reference the pipeline index.ts entry point' {
            $script:content | Should -Match 'pipeline/src/index\.ts'
        }

        It 'Should pass --config flag to pipeline' {
            $script:content | Should -Match '--config\s+\$\{\{\s*inputs\.config_path\s*\}\}'
        }

        It 'Should pass --entity flag to pipeline' {
            $script:content | Should -Match '--entity'
        }

        It 'Should pass --stage flag to pipeline' {
            $script:content | Should -Match '--stage'
        }

        It 'Should use FAL_KEY environment variable' {
            $script:content | Should -Match 'FAL_KEY:\s*\$\{\{\s*secrets\.FAL_KEY\s*\}\}'
        }

        It 'Should use matrix strategy for entities' {
            $script:content | Should -Match 'matrix:'
            $script:content | Should -Match '(?s)entity:.*fromJson'
        }

        It 'Should upload artifacts after generation' {
            $script:content | Should -Match 'actions/upload-artifact@v4'
        }

        It 'Should use --ephemeral flag for fal.ai retention control' {
            $script:content | Should -Match '--ephemeral'
        }
    }

    Context 'Report job' {
        It 'Should download generation artifacts' {
            $script:content | Should -Match 'actions/download-artifact@v4'
        }

        It 'Should run prune-generations' {
            $script:content | Should -Match 'prune-generations\.ts'
        }

        It 'Should commit generated images' {
            $script:content | Should -Match 'git commit'
            $script:content | Should -Match 'git push'
        }

        It 'Should post results to PR' {
            $script:content | Should -Match 'post-results\.ts'
        }

        It 'Should configure bot git identity' {
            $script:content | Should -Match 'ahuofe\[bot\]'
        }
    }

    Context 'Plugin repo checkout' {
        It 'Should checkout anokye-labs/plugins repo' {
            $script:content | Should -Match 'repository:\s*anokye-labs/plugins'
        }

        It 'Should use sparse-checkout for ahuofe directory' {
            $script:content | Should -Match 'sparse-checkout:\s*ahuofe/'
        }

        It 'Should checkout plugin to _ahuofe_plugin path' {
            $script:content | Should -Match 'path:\s*_ahuofe_plugin'
        }
    }
}
