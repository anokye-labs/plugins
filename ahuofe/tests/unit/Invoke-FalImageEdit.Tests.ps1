BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/FalAi.psm1" -Force
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:editScript = Resolve-Path "$PSScriptRoot/../../scripts/Invoke-FalImageEdit.ps1"
}

Describe 'Invoke-FalImageEdit' {

    BeforeEach {
        $script:savedKey = $env:FAL_KEY
        $env:FAL_KEY = 'test-key'
        Mock Import-Module {} -ParameterFilter { $Name -and "$Name" -match 'FalAi' }
    }
    AfterEach {
        $env:FAL_KEY = $script:savedKey
    }

    Context 'Operation routing — style (default)' {
        It 'Routes style operation to flux/dev/image-to-image' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/styled.png'; width = 1024; height = 1024 })
                    seed   = 11
                }
            } -ModuleName FalAi

            $result = & $script:editScript `
                -ImageUrl 'https://fal.media/photo.jpg' `
                -Prompt   'apply watercolor style'

            $result.Operation | Should -Be 'style'
            $result.Model     | Should -Be 'fal-ai/flux/dev/image-to-image'
            $result.Images.Count | Should -Be 1
            $result.Images[0].Url | Should -Be 'https://fal.ai/styled.png'
        }

        It 'Passes image_url, prompt, and strength in payload' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/out.png'; width = 512; height = 512 })
                    seed   = 5
                }
            } -ModuleName FalAi

            & $script:editScript `
                -ImageUrl  'https://fal.media/src.png' `
                -Prompt    'oil painting' `
                -Strength  0.8

            Should -Invoke Invoke-RestMethod -ModuleName FalAi -Times 1 -ParameterFilter {
                $Body -match '"image_url"' -and
                $Body -match '"prompt"' -and
                $Body -match '"strength"'
            }
        }
    }

    Context 'Operation routing — remove' {
        It 'Routes remove operation to bria/fibo-edit' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/removed.png'; width = 800; height = 600 })
                    seed   = 22
                }
            } -ModuleName FalAi

            $result = & $script:editScript `
                -ImageUrl  'https://fal.media/photo.jpg' `
                -Prompt    'remove the car' `
                -Operation remove

            $result.Operation | Should -Be 'remove'
            $result.Model     | Should -Be 'fal-ai/bria/fibo-edit'
        }
    }

    Context 'Operation routing — background' {
        It 'Routes background operation to flux-kontext' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/bg.png'; width = 1024; height = 768 })
                    seed   = 33
                }
            } -ModuleName FalAi

            $result = & $script:editScript `
                -ImageUrl  'https://fal.media/portrait.jpg' `
                -Prompt    'replace background with forest' `
                -Operation background

            $result.Operation | Should -Be 'background'
            $result.Model     | Should -Be 'fal-ai/flux-kontext'
        }
    }

    Context 'Operation routing — general' {
        It 'Routes general operation to nano-banana-pro' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/general.png'; width = 1024; height = 1024 })
                    seed   = 44
                }
            } -ModuleName FalAi

            $result = & $script:editScript `
                -ImageUrl  'https://fal.media/photo.jpg' `
                -Prompt    'enhance this photo' `
                -Operation general

            $result.Operation | Should -Be 'general'
            $result.Model     | Should -Be 'fal-ai/nano-banana-pro'
        }
    }

    Context 'Operation routing — inpaint' {
        It 'Throws when inpaint is used without -MaskUrl' {
            { & $script:editScript `
                -ImageUrl  'https://fal.media/photo.jpg' `
                -Prompt    'fill with flowers' `
                -Operation inpaint
            } | Should -Throw '*MaskUrl*'
        }

        It 'Returns Operation and Model properties for inpaint' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/inpainted.png'; width = 1024; height = 1024 })
                    seed   = 55
                }
            } -ModuleName FalAi

            $result = & $script:editScript `
                -ImageUrl  'https://fal.media/photo.jpg' `
                -MaskUrl   'https://fal.media/mask.png' `
                -Prompt    'a red rose' `
                -Operation inpaint

            $result.Operation | Should -Be 'inpaint'
            $result.Model     | Should -Be 'fal-ai/flux/dev/inpainting'
            $result.Images.Count | Should -Be 1
            $result.Images[0].Url | Should -Be 'https://fal.ai/inpainted.png'
        }
    }

    Context 'Model override' {
        It 'Respects -Model parameter over operation default' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/override.png'; width = 512; height = 512 })
                    seed   = 99
                }
            } -ModuleName FalAi

            $result = & $script:editScript `
                -ImageUrl  'https://fal.media/photo.jpg' `
                -Prompt    'dramatic edit' `
                -Operation style `
                -Model     'fal-ai/nano-banana-pro'

            $result.Model | Should -Be 'fal-ai/nano-banana-pro'

            Should -Invoke Invoke-RestMethod -ModuleName FalAi -Times 1 -ParameterFilter {
                $Uri -match 'nano-banana-pro'
            }
        }
    }

    Context 'Output structure' {
        It 'Returns PSCustomObject with Images, Seed, Operation, Model' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/result.png'; width = 1024; height = 1024 })
                    seed   = 77
                }
            } -ModuleName FalAi

            $result = & $script:editScript `
                -ImageUrl 'https://fal.media/photo.jpg' `
                -Prompt   'artistic transform'

            $result | Should -BeOfType 'PSCustomObject'
            $result.Images    | Should -Not -BeNullOrEmpty
            $result.Seed      | Should -Be 77
            $result.Operation | Should -Not -BeNullOrEmpty
            $result.Model     | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Mandatory parameters' {
        It 'Has ImageUrl marked as mandatory' {
            $cmd = Get-Command $script:editScript
            $attr = $cmd.Parameters['ImageUrl'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $attr.Mandatory | Should -BeTrue
        }

        It 'Has Prompt marked as mandatory' {
            $cmd = Get-Command $script:editScript
            $attr = $cmd.Parameters['Prompt'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $attr.Mandatory | Should -BeTrue
        }

        It 'Operation defaults to style' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/def.png'; width = 512; height = 512 })
                    seed   = 1
                }
            } -ModuleName FalAi

            $result = & $script:editScript `
                -ImageUrl 'https://fal.media/photo.jpg' `
                -Prompt   'some edit'

            $result.Operation | Should -Be 'style'
        }

        It 'Strength defaults to 0.75' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    images = @([PSCustomObject]@{ url = 'https://fal.ai/def2.png'; width = 512; height = 512 })
                    seed   = 2
                }
            } -ModuleName FalAi

            & $script:editScript `
                -ImageUrl 'https://fal.media/photo.jpg' `
                -Prompt   'some edit'

            Should -Invoke Invoke-RestMethod -ModuleName FalAi -Times 1 -ParameterFilter {
                $Body -match '"strength"\s*:\s*0\.75'
            }
        }
    }
}
