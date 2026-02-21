BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:ScriptPath = Join-Path $PSScriptRoot '..\..\scripts\Measure-ImageQuality.ps1'
}

Describe 'Measure-ImageQuality' {
    BeforeAll {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "imgquality-tests-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
        $script:testImage = Join-Path $script:testDir 'test.png'
        New-MockImageFile -Path $script:testImage | Out-Null
    }

    AfterAll {
        if (Test-Path $script:testDir) {
            Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'File-based metrics' {
        It 'Should return valid dimensions for a PNG file' {
            $result = & $script:ScriptPath -ImagePath $script:testImage
            $result.Width | Should -Be 1
            $result.Height | Should -Be 1
        }

        It 'Should return file size greater than zero' {
            $result = & $script:ScriptPath -ImagePath $script:testImage
            $result.FileSize | Should -BeGreaterThan 0
        }

        It 'Should compute aspect ratio' {
            $result = & $script:ScriptPath -ImagePath $script:testImage
            $result.AspectRatio | Should -Be 1.0
        }

        It 'Should return color depth' {
            $result = & $script:ScriptPath -ImagePath $script:testImage
            $result.ColorDepth | Should -BeGreaterThan 0
        }
    }

    Context 'Statistical metrics' {
        It 'Should compute mean brightness' {
            $result = & $script:ScriptPath -ImagePath $script:testImage
            $result.MeanBrightness | Should -BeOfType [double]
            $result.MeanBrightness | Should -BeGreaterOrEqual 0
        }

        It 'Should compute contrast (standard deviation)' {
            $result = & $script:ScriptPath -ImagePath $script:testImage
            $result.Contrast | Should -BeOfType [double]
            $result.Contrast | Should -BeGreaterOrEqual 0
        }

        It 'Should compute entropy' {
            $result = & $script:ScriptPath -ImagePath $script:testImage
            $result.Entropy | Should -BeOfType [double]
            $result.Entropy | Should -BeGreaterOrEqual 0
        }
    }

    Context 'SSIM comparison' {
        It 'Should return SSIM of 1.0 when comparing image to itself' {
            $result = & $script:ScriptPath -ImagePath $script:testImage -ReferenceImagePath $script:testImage
            $result.SSIM | Should -Be 1.0
        }

        It 'Should return SSIM of -1 when no reference provided' {
            $result = & $script:ScriptPath -ImagePath $script:testImage
            $result.SSIM | Should -Be -1
        }
    }

    Context 'CLIP score placeholder' {
        It 'Should return -1 for CLIP score' {
            $result = & $script:ScriptPath -ImagePath $script:testImage -Prompt 'test prompt'
            $result.CLIPScore | Should -Be -1
            $result.CLIPNote | Should -BeLike '*CLIP*'
        }
    }

    Context 'Threshold comparison' {
        It 'Should evaluate threshold checks' {
            $result = & $script:ScriptPath -ImagePath $script:testImage -Threshold @{ Width = 1 }
            $result.Thresholds | Should -Not -BeNullOrEmpty
            $result.Thresholds['Width'].Pass | Should -Be $true
        }
    }

    Context 'JSON output' {
        It 'Should return valid JSON when OutputFormat is JSON' {
            $json = & $script:ScriptPath -ImagePath $script:testImage -OutputFormat JSON
            $parsed = $json | ConvertFrom-Json
            $parsed.Width | Should -Be 1
            $parsed.Height | Should -Be 1
        }
    }
}
