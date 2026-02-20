BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/FalAi.psm1" -Force
    $script:ttsScript  = Resolve-Path "$PSScriptRoot/../../scripts/Invoke-FalTextToSpeech.ps1"
    $script:sttScript  = Resolve-Path "$PSScriptRoot/../../scripts/Invoke-FalSpeechToText.ps1"
    $script:musicScript = Resolve-Path "$PSScriptRoot/../../scripts/Invoke-FalMusicGen.ps1"
}

Describe 'Invoke-FalTextToSpeech' {

    BeforeEach {
        $script:savedKey = $env:FAL_KEY
        $env:FAL_KEY = 'test-key-tts'
        Mock Import-Module {} -ParameterFilter { $Name -and "$Name" -match 'FalAi' }
    }
    AfterEach {
        $env:FAL_KEY = $script:savedKey
    }

    Context 'Default model and audio.url response' {
        It 'Returns PSCustomObject with AudioUrl from result.audio.url' {
            Mock Wait-FalJob {
                param($Model, $Body)
                return [PSCustomObject]@{
                    audio = [PSCustomObject]@{ url = 'https://fal.ai/speech.mp3'; duration = 3.1 }
                }
            }

            $result = & $script:ttsScript -Text 'Hello, world!'
            $result | Should -BeOfType 'PSCustomObject'
            $result.AudioUrl | Should -Be 'https://fal.ai/speech.mp3'
            $result.Duration | Should -Be 3.1
            $result.Model    | Should -Be 'fal-ai/minimax/speech-2.6-turbo'
            $result.Text     | Should -Be 'Hello, world!'
        }
    }

    Context 'Fallback to result.audio_url' {
        It 'Populates AudioUrl from audio_url field when audio object is absent' {
            Mock Wait-FalJob {
                return [PSCustomObject]@{ audio_url = 'https://fal.ai/fallback.mp3' }
            }

            $result = & $script:ttsScript -Text 'Fallback test'
            $result.AudioUrl | Should -Be 'https://fal.ai/fallback.mp3'
        }
    }

    Context 'Custom model and voice' {
        It 'Passes voice_id in payload when -Voice is provided' {
            Mock Wait-FalJob {
                param($Model, $Body)
                $Model         | Should -Be 'fal-ai/elevenlabs/eleven-v3'
                $Body.voice_id | Should -Be 'Rachel'
                $Body.text     | Should -Be 'Hi there'
                return [PSCustomObject]@{
                    audio = [PSCustomObject]@{ url = 'https://fal.ai/eleven.mp3' }
                }
            }

            $result = & $script:ttsScript -Text 'Hi there' -Model 'fal-ai/elevenlabs/eleven-v3' -Voice 'Rachel'
            $result.Model    | Should -Be 'fal-ai/elevenlabs/eleven-v3'
            $result.AudioUrl | Should -Be 'https://fal.ai/eleven.mp3'
        }
    }

    Context 'Error handling' {
        It 'Throws when FAL_KEY is not set' {
            $env:FAL_KEY = $null
            $tmpDir = [System.IO.Path]::GetTempPath()
            Push-Location $tmpDir
            try {
                $envFile = Join-Path $tmpDir '.env'
                if (Test-Path $envFile) { Remove-Item $envFile -Force }
                { & $script:ttsScript -Text 'should fail' } | Should -Throw '*FAL_KEY*'
            }
            finally {
                Pop-Location
            }
        }
    }
}

Describe 'Invoke-FalSpeechToText' {

    BeforeEach {
        $script:savedKey = $env:FAL_KEY
        $env:FAL_KEY = 'test-key-stt'
        Mock Import-Module {} -ParameterFilter { $Name -and "$Name" -match 'FalAi' }
    }
    AfterEach {
        $env:FAL_KEY = $script:savedKey
    }

    Context 'Default Whisper model' {
        It 'Returns transcript text and chunks' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{
                    text   = 'Hello world'
                    chunks = @(
                        [PSCustomObject]@{ text = 'Hello world'; timestamp = @(0.0, 1.5) }
                    )
                }
            } -ModuleName FalAi

            $result = & $script:sttScript -AudioUrl 'https://example.com/audio.mp3'
            $result | Should -BeOfType 'PSCustomObject'
            $result.Text     | Should -Be 'Hello world'
            $result.Model    | Should -Be 'fal-ai/whisper'
            $result.AudioUrl | Should -Be 'https://example.com/audio.mp3'
            $result.Chunks.Count | Should -Be 1
            $result.Chunks[0].Text | Should -Be 'Hello world'
        }
    }

    Context 'Language parameter' {
        It 'Includes language in payload when -Language is specified' {
            Mock Invoke-RestMethod {
                param($Uri, $Body)
                $bodyObj = $Body | ConvertFrom-Json
                $bodyObj.language | Should -Be 'es'
                return [PSCustomObject]@{ text = 'Hola mundo'; chunks = @() }
            } -ModuleName FalAi

            $result = & $script:sttScript -AudioUrl 'https://example.com/es.mp3' -Language 'es'
            $result.Text | Should -Be 'Hola mundo'
        }
    }

    Context 'Custom STT model' {
        It 'Calls the specified model endpoint' {
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Match 'elevenlabs/scribe'
                return [PSCustomObject]@{ text = 'Scribe output'; chunks = @() }
            } -ModuleName FalAi

            $result = & $script:sttScript `
                -AudioUrl 'https://example.com/meeting.mp3' `
                -Model 'fal-ai/elevenlabs/scribe'
            $result.Model | Should -Be 'fal-ai/elevenlabs/scribe'
            $result.Text  | Should -Be 'Scribe output'
        }
    }

    Context 'Empty chunks' {
        It 'Returns empty Chunks array when result has no chunks' {
            Mock Invoke-RestMethod {
                return [PSCustomObject]@{ text = 'No chunks here' }
            } -ModuleName FalAi

            $result = & $script:sttScript -AudioUrl 'https://example.com/audio.mp3'
            $result.Chunks.Count | Should -Be 0
        }
    }
}

Describe 'Invoke-FalMusicGen' {

    BeforeEach {
        $script:savedKey = $env:FAL_KEY
        $env:FAL_KEY = 'test-key-music'
        Mock Import-Module {} -ParameterFilter { $Name -and "$Name" -match 'FalAi' }
    }
    AfterEach {
        $env:FAL_KEY = $script:savedKey
    }

    Context 'Default model' {
        It 'Returns PSCustomObject with AudioUrl from result.audio.url' {
            Mock Wait-FalJob {
                param($Model, $Body)
                $Model      | Should -Be 'fal-ai/minimax-music/v2'
                $Body.prompt | Should -Be 'Jazz piano'
                return [PSCustomObject]@{
                    audio = [PSCustomObject]@{ url = 'https://fal.ai/music.mp3'; duration = 30.0 }
                }
            }

            $result = & $script:musicScript -Prompt 'Jazz piano'
            $result | Should -BeOfType 'PSCustomObject'
            $result.AudioUrl | Should -Be 'https://fal.ai/music.mp3'
            $result.Duration | Should -Be 30.0
            $result.Model    | Should -Be 'fal-ai/minimax-music/v2'
            $result.Prompt   | Should -Be 'Jazz piano'
        }
    }

    Context 'Fallback to result.audio_url' {
        It 'Populates AudioUrl from audio_url field when audio object is absent' {
            Mock Wait-FalJob {
                return [PSCustomObject]@{ audio_url = 'https://fal.ai/music_fallback.mp3' }
            }

            $result = & $script:musicScript -Prompt 'Ambient'
            $result.AudioUrl | Should -Be 'https://fal.ai/music_fallback.mp3'
        }
    }

    Context 'Custom model with Duration and OutputFormat' {
        It 'Passes duration and output_format in payload when provided' {
            Mock Wait-FalJob {
                param($Model, $Body)
                $Model               | Should -Be 'fal-ai/sonauto/v2'
                $Body.duration       | Should -Be 60
                $Body.output_format  | Should -Be 'wav'
                return [PSCustomObject]@{
                    audio = [PSCustomObject]@{ url = 'https://fal.ai/sonauto.wav' }
                }
            }

            $result = & $script:musicScript `
                -Prompt 'Calm ambient' `
                -Model 'fal-ai/sonauto/v2' `
                -Duration 60 `
                -OutputFormat 'wav'
            $result.Model    | Should -Be 'fal-ai/sonauto/v2'
            $result.AudioUrl | Should -Be 'https://fal.ai/sonauto.wav'
        }
    }

    Context 'Optional parameters not sent when absent' {
        It 'Does not include duration or output_format when not specified' {
            Mock Wait-FalJob {
                param($Model, $Body)
                $Body.Keys | Should -Not -Contain 'duration'
                $Body.Keys | Should -Not -Contain 'output_format'
                return [PSCustomObject]@{
                    audio = [PSCustomObject]@{ url = 'https://fal.ai/noextra.mp3' }
                }
            }

            $result = & $script:musicScript -Prompt 'Simple music'
            $result.AudioUrl | Should -Be 'https://fal.ai/noextra.mp3'
        }
    }
}
