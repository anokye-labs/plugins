BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:ScriptPath = Resolve-Path "$PSScriptRoot/../../scripts/Measure-ImageQuality.ps1"
}

Describe 'Image Quality Evaluation' {
    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "imgqual-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
        $script:TestImage = Join-Path $script:TempDir 'test.png'
        New-MockImageFile -Path $script:TestImage | Out-Null
    }

    AfterAll {
        if (Test-Path $script:TempDir) {
            Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'When evaluating generated image quality' {
        It 'Should meet minimum quality thresholds' {
            $result = & $script:ScriptPath -ImagePath $script:TestImage
            $result.FileSize | Should -BeGreaterThan 0
            $result.Width | Should -Be 1
            $result.Height | Should -Be 1
        }
    }
}
