# fal-audio Usage Examples

Concrete PowerShell examples for all three audio scripts and common workflows.

---

## 1. Basic Text-to-Speech

Generate speech using the default model (MiniMax Speech 2.6 Turbo).

```powershell
.\scripts\Invoke-FalTextToSpeech.ps1 -Text "Hello, welcome to the Anokye system!"
```

**Expected Output:**
```
Generating speech with fal-ai/minimax/speech-2.6-turbo...
Audio: https://v3.fal.media/files/abc123/speech.mp3

AudioUrl : https://v3.fal.media/files/abc123/speech.mp3
Duration : 3.1
Model    : fal-ai/minimax/speech-2.6-turbo
Text     : Hello, welcome to the Anokye system!
```

---

## 2. High-Quality TTS with Custom Voice

Use the HD model with a specific voice preset.

```powershell
.\scripts\Invoke-FalTextToSpeech.ps1 `
    -Text "This is a high-quality narration for our documentary." `
    -Model "fal-ai/minimax/speech-2.6-hd" `
    -Voice "narrator_male"
```

---

## 3. TTS with ElevenLabs

Use ElevenLabs v3 for natural, expressive voices.

```powershell
.\scripts\Invoke-FalTextToSpeech.ps1 `
    -Text "Once upon a time, in a land far away..." `
    -Model "fal-ai/elevenlabs/eleven-v3" `
    -Voice "Rachel"
```

---

## 4. Save Audio to File

Generate speech and save directly to disk.

```powershell
.\scripts\Invoke-FalTextToSpeech.ps1 `
    -Text "Your order has been confirmed." `
    -OutputPath ".\output\confirmation.mp3"
```

**Expected Output:**
```
Generating speech with fal-ai/minimax/speech-2.6-turbo...
Audio: https://v3.fal.media/files/abc123/speech.mp3
Saved: .\output\confirmation.mp3

AudioUrl : https://v3.fal.media/files/abc123/speech.mp3
Duration : 1.8
Model    : fal-ai/minimax/speech-2.6-turbo
Text     : Your order has been confirmed.
```

---

## 5. Basic Speech-to-Text

Transcribe an audio file using the default Whisper model.

```powershell
.\scripts\Invoke-FalSpeechToText.ps1 -AudioUrl "https://example.com/interview.mp3"
```

**Expected Output:**
```
Transcribing with fal-ai/whisper...
Transcript: This is the full transcription of the audio file.

Text     : This is the full transcription of the audio file.
Chunks   : {2 chunks}
Model    : fal-ai/whisper
AudioUrl : https://example.com/interview.mp3
```

---

## 6. Transcribe with Language Hint

Improve accuracy by specifying the language.

```powershell
.\scripts\Invoke-FalSpeechToText.ps1 `
    -AudioUrl "https://example.com/spanish_audio.mp3" `
    -Language "es"
```

---

## 7. Transcribe with Speaker Diarization

Use ElevenLabs Scribe to identify who said what.

```powershell
.\scripts\Invoke-FalSpeechToText.ps1 `
    -AudioUrl "https://example.com/meeting.mp3" `
    -Model "fal-ai/elevenlabs/scribe"
```

---

## 8. Basic Music Generation

Generate music using the default model (MiniMax Music v2).

```powershell
.\scripts\Invoke-FalMusicGen.ps1 -Prompt "Upbeat jazz with piano and drums, 120 BPM"
```

**Expected Output:**
```
Generating music with fal-ai/minimax-music/v2...
Music: https://v3.fal.media/files/def456/music.mp3

AudioUrl : https://v3.fal.media/files/def456/music.mp3
Duration : 30.0
Model    : fal-ai/minimax-music/v2
Prompt   : Upbeat jazz with piano and drums, 120 BPM
```

---

## 9. Generate Orchestral Music with Lyria2

Use Google's Lyria2 for high-fidelity orchestral composition.

```powershell
.\scripts\Invoke-FalMusicGen.ps1 `
    -Prompt "Epic orchestral battle theme with brass and strings, dramatic" `
    -Model "fal-ai/lyria2" `
    -Duration 60
```

---

## 10. Generate Background Music

Generate instrumental background music for video content.

```powershell
.\scripts\Invoke-FalMusicGen.ps1 `
    -Prompt "Calm ambient background music, relaxing, minimal" `
    -Model "fal-ai/sonauto/v2" `
    -OutputFormat "wav"
```

---

## 11. Upload Audio and Transcribe

Upload a local audio file to fal.ai CDN, then transcribe it.

```powershell
# Step 1: Upload local audio
Import-Module .\scripts\FalAi.psm1
$audioUrl = Send-FalFile -FilePath ".\recordings\meeting.mp3"

# Step 2: Transcribe
$transcript = .\scripts\Invoke-FalSpeechToText.ps1 -AudioUrl $audioUrl
Write-Host $transcript.Text
```

---

## 12. TTS-to-Video Sync Workflow

Generate speech and pair it with a Kling video. This is a cross-skill workflow
using both `fal-audio` (for TTS) and the `fal-ai` skill (for `Invoke-FalVideoGen.ps1`).

```powershell
# Step 1: Generate speech synced for Kling
$speech = .\scripts\Invoke-FalTextToSpeech.ps1 `
    -Text "The future is now." `
    -Model "fal-ai/kling-video/v1/tts"

# Step 2: Generate video
$video = .\scripts\Invoke-FalVideoGen.ps1 `
    -Prompt "Futuristic cityscape at night, neon lights" `
    -Duration 5

Write-Host "Audio: $($speech.AudioUrl)"
Write-Host "Video: $($video.Video.Url)"
```

---

## 13. Voice Clone and TTS

Clone a voice sample and use it for TTS.

```powershell
# Step 1: Upload voice sample
Import-Module .\scripts\FalAi.psm1
$sampleUrl = Send-FalFile -FilePath ".\voice_sample.mp3"

# Step 2: Clone the voice
$cloneResult = Invoke-FalApi `
    -Method POST `
    -Endpoint "fal-ai/minimax/voice-clone" `
    -Body @{ audio_url = $sampleUrl }

$clonedVoiceId = $cloneResult.voice_id

# Step 3: Generate TTS with cloned voice
.\scripts\Invoke-FalTextToSpeech.ps1 `
    -Text "This voice was cloned from the audio sample." `
    -Voice $clonedVoiceId
```

---

## 14. Batch Transcription

Transcribe multiple audio files.

```powershell
$audioFiles = @(
    "https://example.com/clip1.mp3",
    "https://example.com/clip2.mp3",
    "https://example.com/clip3.mp3"
)

$transcripts = $audioFiles | ForEach-Object {
    .\scripts\Invoke-FalSpeechToText.ps1 -AudioUrl $_
}

$transcripts | ForEach-Object {
    Write-Host "--- Transcript ---"
    Write-Host $_.Text
}
```
