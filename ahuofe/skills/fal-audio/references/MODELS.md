# fal-audio Model Reference

Audio model catalog covering text-to-speech, speech-to-text, and music generation.

---

## Text-to-Speech (TTS) Models

### MiniMax Speech 2.6 Turbo

Fast, production-ready TTS. **Default TTS model.**

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/minimax/speech-2.6-turbo` |
| **Mode** | Queue |
| **Speed** | ~2–5 seconds |
| **Cost Tier** | Low |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `text` | string | ✅ | — | Text to synthesize |
| `voice_id` | string | | model default | Voice preset identifier (model-specific; omit to use the model's default voice) |

**Output Format:**

```json
{
  "audio": { "url": "https://v3.fal.media/files/.../audio.mp3", "duration": 4.2 }
}
```

**Script:** `Invoke-FalTextToSpeech.ps1`

---

### MiniMax Speech 2.6 HD

Highest-quality TTS from MiniMax. Best for production audio.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/minimax/speech-2.6-hd` |
| **Mode** | Queue |
| **Speed** | ~5–10 seconds |
| **Cost Tier** | Medium |

**Input Parameters:** Same as MiniMax Speech 2.6 Turbo.

**Key Differences:**
- Higher audio fidelity and naturalness
- Better prosody and intonation
- Slower and slightly more expensive than Turbo

---

### ElevenLabs v3

Natural-sounding voices with excellent emotional range.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/elevenlabs/eleven-v3` |
| **Mode** | Queue |
| **Speed** | ~3–8 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `text` | string | ✅ | — | Text to synthesize |
| `voice_id` | string | | — | ElevenLabs voice ID |

**Key Features:**
- Wide selection of pre-built voices
- High emotional expressiveness
- Good for narration and character dialogue

---

### Chatterbox Multilingual

Multi-language TTS supporting a broad range of languages.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/chatterbox/multilingual` |
| **Mode** | Queue |
| **Speed** | ~3–8 seconds |
| **Cost Tier** | Low |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `text` | string | ✅ | — | Text to synthesize |
| `voice_id` | string | | — | Voice identifier |

**Key Features:**
- Broad language support
- Consistent voice quality across languages

---

### Kling TTS

TTS optimized for synchronization with Kling video generation.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/kling-video/v1/tts` |
| **Mode** | Queue |
| **Speed** | ~3–8 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `text` | string | ✅ | — | Text to synthesize |
| `voice_id` | string | | — | Voice identifier |

**Key Features:**
- Designed to match Kling video timing
- Use when generating voice-over for Kling videos

---

## Speech-to-Text (STT) Models

### Whisper

Industry-standard speech-to-text from OpenAI. **Default STT model.**

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/whisper` |
| **Mode** | Sync or Queue |
| **Speed** | ~5–30 seconds (depends on audio length) |
| **Cost Tier** | Low |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `audio_url` | string | ✅ | — | URL of audio file to transcribe |
| `language` | string | | auto | Language code (e.g., `en`, `es`) |
| `task` | string | | `transcribe` | `transcribe` or `translate` |
| `chunk_level` | string | | `segment` | `segment` or `word` |

**Output Format:**

```json
{
  "text": "Hello, this is a test transcription.",
  "chunks": [
    { "timestamp": [0.0, 2.5], "text": "Hello, this is" },
    { "timestamp": [2.5, 4.0], "text": "a test transcription." }
  ]
}
```

**Script:** `Invoke-FalSpeechToText.ps1`

---

### ElevenLabs Scribe

Advanced STT with speaker diarization.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/elevenlabs/scribe` |
| **Mode** | Queue |
| **Speed** | ~10–60 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `audio_url` | string | ✅ | — | URL of audio file to transcribe |
| `language` | string | | auto | Language code |

**Key Features:**
- Speaker diarization (who said what)
- Accurate timestamps per speaker
- Good for meetings and interviews

**Output Format:**

```json
{
  "text": "Full transcript text",
  "chunks": [
    { "text": "Hello everyone.", "timestamp": [0.0, 1.5], "speaker": "speaker_0" }
  ]
}
```

---

## Music Generation Models

### MiniMax Music v2

High-quality music generation. **Default music model.**

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/minimax-music/v2` |
| **Mode** | Queue |
| **Speed** | ~15–60 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Text description of the music |
| `duration` | integer | | — | Target duration in seconds |

**Output Format:**

```json
{
  "audio": { "url": "https://v3.fal.media/files/.../music.mp3", "duration": 30.0 }
}
```

**Script:** `Invoke-FalMusicGen.ps1`

---

### Lyria2

Google's music generation model with high fidelity.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/lyria2` |
| **Mode** | Queue |
| **Speed** | ~30–90 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Text description of the music |

**Key Features:**
- High audio fidelity
- Good for orchestral and complex compositions
- Google DeepMind model

---

### ElevenLabs Music

Song generation with vocals.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/elevenlabs/music` |
| **Mode** | Queue |
| **Speed** | ~30–90 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Description of the song |

**Key Features:**
- Generates complete songs with vocals
- Good for pop, rock, and commercial styles

---

### Sonauto v2

Instrumental music generation.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/sonauto/v2` |
| **Mode** | Queue |
| **Speed** | ~20–60 seconds |
| **Cost Tier** | Low |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | ✅ | — | Description of the music |
| `output_format` | string | | `mp3` | Output format (`mp3`, `wav`) |

**Key Features:**
- Instrumental focus (no vocals)
- Good for background music and soundtracks
- Supports output format selection

---

### Ace Step

Short audio clip generation.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/ace-step` |
| **Mode** | Queue |
| **Speed** | ~10–30 seconds |
| **Cost Tier** | Low |

**Key Features:**
- Fast generation for short clips
- Good for sound effects and transitions

---

### Beatoven

Background music generation optimized for content creators.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/beatoven` |
| **Mode** | Queue |
| **Speed** | ~15–45 seconds |
| **Cost Tier** | Low |

**Key Features:**
- Designed for background music use cases
- Mood-based generation

---

## Voice Clone

### MiniMax Voice Clone

Clone a voice from an audio sample.

| Property | Value |
|----------|-------|
| **Endpoint** | `fal-ai/minimax/voice-clone` |
| **Mode** | Queue |
| **Speed** | ~10–30 seconds |
| **Cost Tier** | Medium |

**Input Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `audio_url` | string | ✅ | — | URL of the source voice audio sample |

**Output Format:**

```json
{
  "voice_id": "cloned-voice-abc123"
}
```

**Usage:** Use the returned `voice_id` with `Invoke-FalTextToSpeech.ps1 -Voice <id>`.

---

## Model Selection Guide

| I want to... | Use this model | Why |
|--------------|---------------|-----|
| Generate speech quickly | `fal-ai/minimax/speech-2.6-turbo` | Fast, low cost (default) |
| Generate high-quality speech | `fal-ai/minimax/speech-2.6-hd` | Best TTS quality |
| Natural expressive voices | `fal-ai/elevenlabs/eleven-v3` | Wide voice selection |
| Multi-language TTS | `fal-ai/chatterbox/multilingual` | Broad language support |
| Sync audio with Kling video | `fal-ai/kling-video/v1/tts` | Optimized for Kling |
| Transcribe audio | `fal-ai/whisper` | Industry standard (default) |
| Transcribe with speaker IDs | `fal-ai/elevenlabs/scribe` | Speaker diarization |
| Generate music | `fal-ai/minimax-music/v2` | Best quality (default) |
| Generate orchestral music | `fal-ai/lyria2` | Google's model |
| Generate songs with vocals | `fal-ai/elevenlabs/music` | Song generation |
| Background/instrumental music | `fal-ai/sonauto/v2` | Instrumental focus |
| Clone a voice | `fal-ai/minimax/voice-clone` | Voice cloning |
