BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/TestHelper.psm1" -Force
    $script:ScriptPath = Resolve-Path "$PSScriptRoot/../../scripts/Measure-VideoQuality.ps1"
}

Describe 'Video Quality Evaluation' {
    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "vidqual-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

        # Create a minimal test video file (mp4 header stub)
        $script:TestVideo = Join-Path $script:TempDir 'test-clip.mp4'
        [System.IO.File]::WriteAllBytes($script:TestVideo, [byte[]]@(
            0x00, 0x00, 0x00, 0x1C, 0x66, 0x74, 0x79, 0x70,  # ftyp box
            0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00,
            0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32,
            0x6D, 0x70, 0x34, 0x31
        ))
    }

    AfterAll {
        if (Test-Path $script:TempDir) {
            Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'When measuring video metadata without ffprobe' {
        It 'Should return file-based metadata for a video file' {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'ffprobe' }

            $result = & $script:ScriptPath -VideoPath $script:TestVideo
            $result.FilePath | Should -Not -BeNullOrEmpty
            $result.FileSize | Should -BeGreaterThan 0
            $result.MetadataSource | Should -Be 'file-only'
        }

        It 'Should report unknown resolution without ffprobe' {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'ffprobe' }

            $result = & $script:ScriptPath -VideoPath $script:TestVideo
            $result.Resolution | Should -Be 'unknown'
            $result.Width | Should -Be -1
            $result.Height | Should -Be -1
        }
    }

    Context 'Temporal consistency metrics' {
        It 'Should return placeholder temporal consistency value' {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'ffprobe' }

            $result = & $script:ScriptPath -VideoPath $script:TestVideo
            $result.TemporalConsistency | Should -Be -1
            $result.TemporalNote | Should -Match 'placeholder'
        }

        It 'Should return placeholder optical flow value' {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'ffprobe' }

            $result = & $script:ScriptPath -VideoPath $script:TestVideo
            $result.OpticalFlow | Should -Be -1
            $result.OpticalFlowNote | Should -Match 'OpenCV'
        }
    }

    Context 'Frame-by-frame quality' {
        It 'Should detect video file extension' {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'ffprobe' }

            $result = & $script:ScriptPath -VideoPath $script:TestVideo
            $result.Extension | Should -Be 'MP4'
        }

        It 'Should output JSON when requested' {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'ffprobe' }

            $json = & $script:ScriptPath -VideoPath $script:TestVideo -OutputFormat JSON
            $parsed = $json | ConvertFrom-Json
            $parsed.FilePath | Should -Not -BeNullOrEmpty
            $parsed.Extension | Should -Be 'MP4'
        }
    }
}
