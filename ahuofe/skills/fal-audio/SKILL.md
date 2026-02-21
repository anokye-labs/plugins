---
name: fal-audio
description: >
  Generate speech, transcribe audio, and create music using fal.ai audio models.
  Use when the user says "convert text to speech", "generate voice", "TTS",
  "transcribe audio", "speech to text", "STT", "generate music", "text to music",
  "create soundtrack", or "clone voice".
metadata:
  author: anokye-labs
  version: "1.0.0"
---

# fal-audio Skill

Generate and process audio using state-of-the-art AI models on [fal.ai](https://fal.ai).
Covers text-to-speech (TTS), speech-to-text (STT), and music/audio generation.

All scripts share the `scripts/FalAi.psm1` module for authentication, HTTP calls,
and queue polling. For auth, queue, and error handling details see the **fal-ai** skill.

For **image and video** generation use the **fal-ai** skill.
For **multi-step media workflows** use the **media-agents** skill.

---

## Available Scripts

| Script                        | Purpose                                        |
|-------------------------------|------------------------------------------------|
| `Invoke-FalTextToSpeech.ps1`  | Convert text to speech, return audio URL       |
| `Invoke-FalSpeechToText.ps1`  | Transcribe audio URL to text                   |
| `Invoke-FalMusicGen.ps1`      | Generate music from a text prompt              |

---

## Quick Start

### Text-to-Speech

```powershell
.\scripts\Invoke-FalTextToSpeech.ps1 -Text "Hello, world!"
# Returns: PSCustomObject with .AudioUrl, .Duration, .Model, .Text
```

### Speech-to-Text

```powershell
.\scripts\Invoke-FalSpeechToText.ps1 -AudioUrl "https://example.com/audio.mp3"
# Returns: PSCustomObject with .Text, .Chunks, .Model, .AudioUrl
```

### Music Generation

```powershell
.\scripts\Invoke-FalMusicGen.ps1 -Prompt "Upbeat jazz with piano and drums"
# Returns: PSCustomObject with .AudioUrl, .Duration, .Model, .Prompt
```

---

## Supported Models

### Text-to-Speech (TTS)

| Model | Endpoint | Notes |
|-------|----------|-------|
| MiniMax Speech 2.6 Turbo | `fal-ai/minimax/speech-2.6-turbo` | Fast (default) |
| MiniMax Speech 2.6 HD | `fal-ai/minimax/speech-2.6-hd` | Best quality |
| ElevenLabs v3 | `fal-ai/elevenlabs/eleven-v3` | Natural voices |
| Chatterbox | `fal-ai/chatterbox/multilingual` | Multi-language |
| Kling TTS | `fal-ai/kling-video/v1/tts` | For video sync |

### Speech-to-Text (STT)

| Model | Endpoint | Notes |
|-------|----------|-------|
| Whisper | `fal-ai/whisper` | General transcription (default) |
| ElevenLabs Scribe | `fal-ai/elevenlabs/scribe` | Speaker diarization |

### Music Generation

| Model | Endpoint | Notes |
|-------|----------|-------|
| MiniMax Music v2 | `fal-ai/minimax-music/v2` | Best quality (default) |
| Lyria2 | `fal-ai/lyria2` | Google's model |
| ElevenLabs Music | `fal-ai/elevenlabs/music` | Song generation |
| Sonauto v2 | `fal-ai/sonauto/v2` | Instrumental |
| Ace Step | `fal-ai/ace-step` | Short clips |
| Beatoven | `fal-ai/beatoven` | Background music |

### Voice Clone

| Model | Endpoint | Notes |
|-------|----------|-------|
| MiniMax Voice Clone | `fal-ai/minimax/voice-clone` | Clone from audio sample |

---

## Script Parameters Reference

### Invoke-FalTextToSpeech.ps1

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Text` | string | *(required)* | Text to synthesize |
| `-Model` | string | `fal-ai/minimax/speech-2.6-turbo` | TTS model endpoint |
| `-Voice` | string | — | Voice identifier (model-specific) |
| `-OutputPath` | string | — | Save audio to this local path |

### Invoke-FalSpeechToText.ps1

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-AudioUrl` | string | *(required)* | URL of audio file to transcribe |
| `-Model` | string | `fal-ai/whisper` | STT model endpoint |
| `-Language` | string | auto | Language code (e.g., `en`, `es`) |

### Invoke-FalMusicGen.ps1

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Prompt` | string | *(required)* | Text description of the music |
| `-Model` | string | `fal-ai/minimax-music/v2` | Music model endpoint |
| `-Duration` | int | — | Target duration in seconds |
| `-OutputFormat` | string | — | Output format (`mp3`, `wav`) |

---

## Output Format

### TTS / Music Generation

```json
{
  "AudioUrl": "https://v3.fal.media/files/.../audio.mp3",
  "Duration": 4.2,
  "Model": "fal-ai/minimax/speech-2.6-turbo",
  "Text": "Hello, world!"
}
```

### Speech-to-Text

```json
{
  "Text": "Hello, this is a test transcription.",
  "Chunks": [
    { "Text": "Hello, this is", "Timestamp": [0.0, 2.5] },
    { "Text": "a test transcription.", "Timestamp": [2.5, 4.0] }
  ],
  "Model": "fal-ai/whisper",
  "AudioUrl": "https://example.com/audio.mp3"
}
```

---

## Presenting Results

**Audio (TTS / Music):**
```
[Listen to audio](https://v3.fal.media/files/.../audio.mp3)
• Model: fal-ai/minimax/speech-2.6-turbo | Duration: 4.2s
```

**Transcript (STT):**
```
> "Hello, this is a test transcription."
• Model: fal-ai/whisper | Source: https://example.com/audio.mp3
```

---

## References

- [MODELS.md](references/MODELS.md) — Audio model catalog with input/output schemas
- [EXAMPLES.md](references/EXAMPLES.md) — Usage patterns and full examples
