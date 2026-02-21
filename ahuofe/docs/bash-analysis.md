# fal.ai Bash Scripts Analysis & PowerShell Conversion Plan

> **Issue:** #15 — Analyze existing fal.ai bash scripts  
> **Source:** `S:\fal-ai-community\skills\skills\claude.ai\`  
> **Date:** 2026-02-06

---

## Table of Contents

1. [fal-audio](#1-fal-audio)
2. [fal-generate](#2-fal-generate)
3. [fal-image-edit](#3-fal-image-edit)
4. [fal-platform](#4-fal-platform)
5. [fal-upscale](#5-fal-upscale)
6. [fal-workflow](#6-fal-workflow)
7. [Summary & Conversion Plan](#7-summary--conversion-plan)

---

## 1. fal-audio

### 1.1 speech-to-text.sh

| Field | Details |
|-------|---------|
| **Path** | `fal-audio/scripts/speech-to-text.sh` |
| **Purpose** | Transcribes audio from a URL using fal.ai STT models (Whisper, ElevenLabs Scribe). Returns JSON with transcription text. |
| **Lines** | 142 |

**fal.ai API Endpoints:**
- `POST https://fal.run/{MODEL}` — Synchronous inference (default model: `fal-ai/whisper`)

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--audio-url` | string | Yes | — | URL of audio file to transcribe |
| `--model` | string | No | `fal-ai/whisper` | STT model ID |
| `--language` | string | No | auto-detect | Language code (e.g., `es`) |
| `--add-fal-key` | flag | No | — | Interactive FAL_KEY setup |
| `FAL_KEY` | env var | Yes | — | API authentication key |

**Error Handling:**
- `set -e` for fail-fast
- Checks `FAL_KEY` is set → exits with message if missing
- Checks `--audio-url` is provided → exits if missing
- Grep-based JSON error detection: checks response for `"error"` key, extracts `"message"` or `"error"` field
- Temp directory cleanup via `trap 'rm -rf "$TEMP_DIR"' EXIT`

**PowerShell Conversion Plan:**
- `curl -s -X POST` → `Invoke-RestMethod -Method Post -Uri`
- `grep -o '"text":"[^"]*"' | cut -d'"' -f4` → `($response | ConvertFrom-Json).text`
- `source .env` → Parse `.env` with `Get-Content .env | ForEach-Object { ... }` or use a helper function
- `$FAL_KEY` → `$env:FAL_KEY`
- Heredoc payload (`cat <<EOF`) → PowerShell hashtable `@{ audio_url = $AudioUrl } | ConvertTo-Json`
- Argument parsing (`case/esac`) → `param()` block with `[Parameter]` attributes

---

### 1.2 text-to-speech.sh

| Field | Details |
|-------|---------|
| **Path** | `fal-audio/scripts/text-to-speech.sh` |
| **Purpose** | Converts text to speech audio using fal.ai TTS models. Returns JSON with audio URL. |
| **Lines** | 142 |

**fal.ai API Endpoints:**
- `POST https://fal.run/{MODEL}` — Synchronous inference (default model: `fal-ai/minimax/speech-2.6-turbo`)

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--text` | string | Yes | — | Text to convert to speech |
| `--model` | string | No | `fal-ai/minimax/speech-2.6-turbo` | TTS model ID |
| `--voice` | string | No | — | Voice ID (model-specific) |
| `--add-fal-key` | flag | No | — | Interactive FAL_KEY setup |
| `FAL_KEY` | env var | Yes | — | API authentication key |

**Error Handling:**
- Identical pattern to `speech-to-text.sh`: `set -e`, FAL_KEY check, required param check, grep-based error extraction, temp dir trap cleanup

**PowerShell Conversion Plan:**
- Same patterns as speech-to-text.sh
- Payload: `@{ text = $Text; voice = $Voice } | ConvertTo-Json`
- Audio URL extraction: `($response).url` or `($response).audio.url`

---

## 2. fal-generate

### 2.1 generate.sh

| Field | Details |
|-------|---------|
| **Path** | `fal-generate/scripts/generate.sh` |
| **Purpose** | **Core generation script** — generates images/videos via queue-based, async, or sync modes. Supports file upload, queue status checking, result retrieval, and cancellation. The most complex script. |
| **Lines** | 520 |

**fal.ai API Endpoints:**
- `POST https://queue.fal.run/{MODEL}` — Queue submit (default mode)
- `GET https://queue.fal.run/{MODEL}/requests/{REQUEST_ID}/status` — Check queue status
- `GET https://queue.fal.run/{MODEL}/requests/{REQUEST_ID}` — Get result
- `PUT https://queue.fal.run/{MODEL}/requests/{REQUEST_ID}/cancel` — Cancel request
- `POST https://fal.run/{MODEL}` — Synchronous inference (sync mode)
- `POST https://rest.alpha.fal.ai/storage/auth/token?storage_type=fal-cdn-v3` — Get CDN upload token
- `POST {base_url}/files/upload` — Upload file to CDN
- `GET https://fal.ai/api/openapi/queue/openapi.json?endpoint_id={MODEL}` — Schema lookup (via `--schema`)

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--prompt`, `-p` | string | Yes* | — | Text description (* for generate action) |
| `--model`, `-m` | string | No | `fal-ai/flux/dev` | Model ID |
| `--image-url` | string | No | — | Input image URL for I2V |
| `--file`, `--image` | path | No | — | Local file (auto-uploads to CDN) |
| `--size` | enum | No | `landscape_4_3` | `square`, `portrait`, `landscape` |
| `--num-images` | int | No | `1` | Number of images |
| `--async` | flag | No | — | Return request_id immediately |
| `--sync` | flag | No | — | Synchronous mode |
| `--logs` | flag | No | `false` | Show generation logs while polling |
| `--status ID` | string | No | — | Check queue status |
| `--result ID` | string | No | — | Get completed result |
| `--cancel ID` | string | No | — | Cancel queued request |
| `--poll-interval` | int | No | `2` | Seconds between polls |
| `--timeout` | int | No | `600` | Max wait seconds |
| `--lifecycle N` | int | No | — | Object expiration seconds |
| `--schema [MODEL]` | string | No | — | Get OpenAPI schema |
| `--add-fal-key` | flag | No | — | Interactive FAL_KEY setup |
| `FAL_KEY` | env var | Yes | — | API authentication key |

**Error Handling:**
- `set -e` for fail-fast
- FAL_KEY validation
- File existence check for `--file`
- CDN token acquisition error handling
- Upload error handling with grep-based JSON error detection
- Queue submit error handling
- Polling loop with timeout (`MAX_POLL_TIME=600`)
- FAILED status detection during polling
- Result retrieval error handling
- Consistent pattern: grep for `"error"` → extract `"message"` → stderr + exit 1

**PowerShell Conversion Plan:**
- **Queue polling loop:** `while` loop with `Start-Sleep -Seconds $PollInterval`
- **File upload (2-step):**
  1. `Invoke-RestMethod -Method Post -Uri $tokenEndpoint` → get token
  2. `Invoke-RestMethod -Method Post -Uri "$baseUrl/files/upload" -InFile $FilePath -ContentType $contentType`
- **Headers array:** `-Headers @{ Authorization = "Key $env:FAL_KEY"; 'Content-Type' = 'application/json' }`
- **Lifecycle header:** `'X-Fal-Object-Lifecycle-Preference' = '{"expiration_duration_seconds": N}'`
- **Model-conditional payload:** Use `switch` or `if/elseif` for I2V vs video vs image payloads
- **Content-type detection:** `switch ($extension) { '.jpg' { 'image/jpeg' } ... }`
- This script should be broken into multiple PowerShell functions: `Submit-FalJob`, `Get-FalJobStatus`, `Get-FalJobResult`, `Stop-FalJob`, `Send-FalFile`

---

### 2.2 get-schema.sh

| Field | Details |
|-------|---------|
| **Path** | `fal-generate/scripts/get-schema.sh` |
| **Purpose** | Fetches OpenAPI 3.0 schema for any fal.ai model. Can display input-only, output-only, or full schema. Uses embedded Python for rich formatting. |
| **Lines** | 217 |

**fal.ai API Endpoints:**
- `GET https://fal.ai/api/openapi/queue/openapi.json?endpoint_id={ENCODED_MODEL}` — OpenAPI schema

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--model`, `-m` | string | Yes | — | Model ID |
| `--input`, `-i` | flag | No | `false` | Show only input schema |
| `--output`, `-o` | flag | No | `false` | Show only output schema |
| `--json` | flag | No | `false` | Output raw JSON |
| `--add-fal-key` | flag | No | — | Interactive FAL_KEY setup |

**Error Handling:**
- Model required validation
- Grep-based error detection on API response
- Falls back gracefully if `python3` is not available (outputs raw JSON only)

**PowerShell Conversion Plan:**
- No auth header needed (public endpoint)
- `Invoke-RestMethod -Uri $schemaUrl` returns parsed JSON directly
- Python formatting logic → native PowerShell object traversal
- `[System.Uri]::EscapeDataString($Model)` for URL encoding vs `sed 's/\//%2F/g'`
- Schema parsing: `$response.components.schemas` → iterate properties with `Format-Table`

---

### 2.3 search-models.sh

| Field | Details |
|-------|---------|
| **Path** | `fal-generate/scripts/search-models.sh` |
| **Purpose** | Search and discover fal.ai models by keyword or category. Returns model list with IDs and categories. |
| **Lines** | 155 |

**fal.ai API Endpoints:**
- `GET https://api.fal.ai/v1/models?limit={N}&q={QUERY}&category={CATEGORY}` — Model search

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--query`, `-q` | string | No | — | Search keyword |
| `--category`, `-c` | string | No | — | Category filter |
| `--limit`, `-l` | int | No | `20` | Max results |
| `--add-fal-key` | flag | No | — | Interactive FAL_KEY setup |
| `FAL_KEY` | env var | Yes | — | API authentication key |

**Error Handling:**
- FAL_KEY validation
- Grep-based error detection
- Python3 optional for rich display

**PowerShell Conversion Plan:**
- Query string building: `$params = @{ limit = $Limit; q = $Query; category = $Category }` → build URI
- `Invoke-RestMethod -Headers @{ Authorization = "Key $env:FAL_KEY" }`
- Result display: `$response.data | Format-Table endpoint_id, display_name, category`

---

### 2.4 upload.sh

| Field | Details |
|-------|---------|
| **Path** | `fal-generate/scripts/upload.sh` |
| **Purpose** | Upload local files to fal.ai CDN via 2-step token+upload flow. Returns CDN URL. Supports images, videos, and audio. Max 100MB. |
| **Lines** | 217 |

**fal.ai API Endpoints:**
- `POST https://rest.alpha.fal.ai/storage/auth/token?storage_type=fal-cdn-v3` — Get CDN token
- `POST {base_url}/files/upload` — Upload file to CDN

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--file`, `-f` | path | Yes | — | Local file path |
| `--json` | flag | No | `false` | Output raw JSON response |
| `--add-fal-key` | flag | No | — | Interactive FAL_KEY setup |
| `FAL_KEY` | env var | Yes | — | API authentication key |

**Error Handling:**
- FAL_KEY validation
- File existence check
- File size check (>100MB rejected)
- CDN token error detection (checks for `"detail"` key)
- Upload error detection
- Access URL extraction validation

**PowerShell Conversion Plan:**
- File size: `(Get-Item $FilePath).Length`
- Content type: `switch` on file extension
- Token request: `Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Headers @{...}`
- File upload: `Invoke-RestMethod -Method Post -Uri "$baseUrl/files/upload" -InFile $FilePath -ContentType $contentType -Headers @{ Authorization = "$tokenType $token"; 'X-Fal-File-Name' = $fileName }`
- Default output: just the URL string; `--json` outputs full response
- `stat -f%z` / `stat -c%s` → `(Get-Item $path).Length`

---

## 3. fal-image-edit

### 3.1 edit-image.sh

| Field | Details |
|-------|---------|
| **Path** | `fal-image-edit/scripts/edit-image.sh` |
| **Purpose** | Edit images using AI: style transfer, object removal, background change, inpainting. Auto-selects model based on operation type. |
| **Lines** | 200 |

**fal.ai API Endpoints:**
- `POST https://fal.run/{MODEL}` — Synchronous inference, where MODEL is selected by operation:
  - `style` → `fal-ai/flux/dev/image-to-image`
  - `remove` → `bria/fibo-edit`
  - `background` → `fal-ai/flux-kontext`
  - `inpaint` → `fal-ai/flux/dev/inpainting`

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--image-url` | string | Yes | — | URL of image to edit |
| `--prompt` | string | Yes | — | Edit description |
| `--operation` | enum | No | `style` | `style`, `remove`, `background`, `inpaint` |
| `--mask-url` | string | Conditional | — | Required for `inpaint` operation |
| `--strength` | float | No | `0.75` | Edit strength (0.0–1.0) |
| `--add-fal-key` | flag | No | — | Interactive FAL_KEY setup |
| `FAL_KEY` | env var | Yes | — | API authentication key |

**Error Handling:**
- FAL_KEY, image-url, prompt required validation
- Mask URL required for inpainting operation
- Unknown operation validation
- Grep-based API error detection
- Temp dir cleanup

**PowerShell Conversion Plan:**
- Operation-to-model mapping: `$modelMap = @{ style = 'fal-ai/flux/dev/image-to-image'; remove = 'bria/fibo-edit'; ... }`
- Conditional payload construction based on operation type
- `[ValidateSet('style','remove','background','inpaint')]` for operation parameter

---

## 4. fal-platform

### 4.1 estimate-cost.sh

| Field | Details |
|-------|---------|
| **Path** | `fal-platform/scripts/estimate-cost.sh` |
| **Purpose** | Estimate costs for fal.ai operations by API calls or units. Fetches pricing data then calculates. Uses embedded Python for math. |
| **Lines** | 162 |

**fal.ai API Endpoints:**
- `GET https://api.fal.ai/v1/models/pricing?endpoint_id={ENCODED_MODEL}` — Get model pricing

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--model`, `-m` | string | Yes | — | Model ID |
| `--calls`, `-c` | int | Conditional | — | Number of API calls |
| `--units`, `-u` | int | Conditional | — | Number of billing units |
| `--json` | flag | No | `false` | Output raw JSON |
| `--add-fal-key` | flag | No | — | Delegates to `setup.sh` |
| `FAL_KEY` | env var | Yes | — | API authentication key |

**Error Handling:**
- FAL_KEY validation
- Model required
- Either `--calls` or `--units` required
- API error detection
- Python3 required for calculation (no fallback)

**PowerShell Conversion Plan:**
- Python math → native PowerShell arithmetic: `$estimatedCost = $unitPrice * $quantity`
- No Python dependency needed
- `--add-fal-key` delegation → call shared `Initialize-FalKey` function

---

### 4.2 pricing.sh

| Field | Details |
|-------|---------|
| **Path** | `fal-platform/scripts/pricing.sh` |
| **Purpose** | Get pricing information for one or more models, or all models in a category. Uses Python for display formatting. |
| **Lines** | 144 |

**fal.ai API Endpoints:**
- `GET https://api.fal.ai/v1/models/pricing?endpoint_id={ENCODED_MODELS}` — Pricing by model(s)
- `GET https://api.fal.ai/v1/models?category={CATEGORY}&include_pricing=true` — Pricing by category

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--model`, `-m` | string | Conditional | — | Model ID(s), comma-separated |
| `--category`, `-c` | string | Conditional | — | Category filter |
| `--json` | flag | No | `false` | Output raw JSON |
| `--add-fal-key` | flag | No | — | Delegates to `setup.sh` |
| `FAL_KEY` | env var | Yes | — | API authentication key |

**Error Handling:**
- FAL_KEY validation
- Either `--model` or `--category` required
- API error detection
- Python3 optional for display

**PowerShell Conversion Plan:**
- Comma-separated model encoding: `$Models -split ',' | ForEach-Object { [uri]::EscapeDataString($_) } -join '%2C'`
- Two different endpoints based on input → `if ($Model) { ... } else { ... }`

---

### 4.3 requests.sh

| Field | Details |
|-------|---------|
| **Path** | `fal-platform/scripts/requests.sh` |
| **Purpose** | List API requests by model/endpoint, or delete request payloads for cleanup. |
| **Lines** | 159 |

**fal.ai API Endpoints:**
- `GET https://api.fal.ai/v1/models/requests/by-endpoint?endpoint_id={MODEL}&limit={N}` — List requests
- `DELETE https://api.fal.ai/v1/models/requests/{REQUEST_ID}/payloads` — Delete request payloads

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--model`, `-m` | string | Conditional | — | Model ID (required for listing) |
| `--limit`, `-l` | int | No | `10` | Max results |
| `--delete`, `-d` | string | No | — | Request ID to delete payloads |
| `--json` | flag | No | `false` | Output raw JSON |
| `--add-fal-key` | flag | No | — | Delegates to `setup.sh` |
| `FAL_KEY` | env var | Yes | — | API authentication key |

**Error Handling:**
- FAL_KEY validation
- Model required for listing
- Delete error detection
- Python3 optional for display

**PowerShell Conversion Plan:**
- DELETE method: `Invoke-RestMethod -Method Delete -Uri $deleteUrl`
- Two modes (list vs delete) → use `ParameterSetName` or `switch`

---

### 4.4 setup.sh

| Field | Details |
|-------|---------|
| **Path** | `fal-platform/scripts/setup.sh` |
| **Purpose** | Manage FAL_KEY configuration. Add/update API key in `.env` file, show current config with masked key display. |
| **Lines** | 127 |

**fal.ai API Endpoints:**
- None — local configuration only

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--add-fal-key [KEY]` | string | No | — | Add/update FAL_KEY (interactive if no value) |
| `--show-config` | flag | No | — | Show current configuration |

**Error Handling:**
- Empty key validation
- Basic key format validation (regex check for `[a-zA-Z0-9_-]+`)
- Unknown option rejection (strict parsing, unlike other scripts)

**PowerShell Conversion Plan:**
- `.env` file manipulation → `Get-Content .env`, filter, add line
- Key masking: `$key.Substring(0,8) + '...' + $key.Substring($key.Length-4)`
- Interactive prompt: `Read-Host "Enter your fal.ai API key"`
- This becomes a shared module function: `Set-FalApiKey`, `Get-FalConfig`

---

### 4.5 usage.sh

| Field | Details |
|-------|---------|
| **Path** | `fal-platform/scripts/usage.sh` |
| **Purpose** | Check usage and billing. Supports filtering by model, date range, and timeframe aggregation. |
| **Lines** | 183 |

**fal.ai API Endpoints:**
- `GET https://api.fal.ai/v1/models/usage?expand=time_series,summary&endpoint_id={MODEL}&start={DATE}&end={DATE}&timeframe={TF}` — Usage data

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--model`, `-m` | string | No | — | Filter by model ID |
| `--start`, `-s` | date | No | — | Start date (ISO8601 or YYYY-MM-DD) |
| `--end`, `-e` | date | No | — | End date |
| `--timeframe`, `-t` | enum | No | — | `minute`, `hour`, `day`, `week`, `month` |
| `--json` | flag | No | `false` | Output raw JSON |
| `--add-fal-key` | flag | No | — | Delegates to `setup.sh` |
| `FAL_KEY` | env var | Yes | — | API authentication key |

**Error Handling:**
- FAL_KEY validation
- API error detection
- Python3 optional for display

**PowerShell Conversion Plan:**
- Query string building: accumulate parameters in hashtable, build URI
- Date parameters can use `[datetime]` type validation
- Usage summary display: `$response.summary | Format-List`

---

## 5. fal-upscale

### 5.1 upscale.sh

| Field | Details |
|-------|---------|
| **Path** | `fal-upscale/scripts/upscale.sh` |
| **Purpose** | Upscale images using AI models. Supports different models with conditional payloads (AuraSR has fixed 4x, others accept scale parameter). |
| **Lines** | 142 |

**fal.ai API Endpoints:**
- `POST https://fal.run/{MODEL}` — Synchronous inference (default model: `fal-ai/aura-sr`)

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--image-url` | string | Yes | — | URL of image to upscale |
| `--model` | string | No | `fal-ai/aura-sr` | Upscale model ID |
| `--scale` | int | No | `4` | Upscale factor (2 or 4) |
| `--add-fal-key` | flag | No | — | Interactive FAL_KEY setup |
| `FAL_KEY` | env var | Yes | — | API authentication key |

**Error Handling:**
- FAL_KEY and image-url validation
- Grep-based error detection
- Temp dir cleanup

**PowerShell Conversion Plan:**
- Model-conditional payload: `if ($Model -like '*aura-sr*') { @{ image_url = $ImageUrl } } else { @{ image_url = $ImageUrl; scale = $Scale } }`
- Simple and straightforward conversion

---

## 6. fal-workflow

### 6.1 create-workflow.sh

| Field | Details |
|-------|---------|
| **Path** | `fal-workflow/scripts/create-workflow.sh` |
| **Purpose** | Create workflow JSON definitions that chain multiple AI models together. Builds structured JSON with nodes, dependencies, and outputs. Uses Python for JSON manipulation. |
| **Lines** | 136 |

**fal.ai API Endpoints:**
- None directly — generates workflow JSON locally. Workflows are submitted via the fal.ai workflow API or MCP tool externally.

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--name` | string | Yes | — | Workflow name (slug) |
| `--title` | string | No | same as name | Display title |
| `--description` | string | No | — | Workflow description |
| `--nodes` | JSON | Yes | — | JSON array of node definitions |
| `--outputs` | JSON | Yes | — | JSON object for output mappings |

**Error Handling:**
- Name, nodes, outputs required validation
- Unknown option strict rejection (exits on unknown flags)
- Python3 fallback: outputs basic structure without node processing
- Temp dir cleanup

**PowerShell Conversion Plan:**
- JSON construction: build PowerShell objects with `[PSCustomObject]@{...}` → `ConvertTo-Json -Depth 10`
- Node processing: iterate array, add dependencies, build nodes hashtable
- No API calls needed — pure JSON construction
- `--nodes` JSON input → `$Nodes | ConvertFrom-Json` for parsing

---

## 7. Summary & Conversion Plan

### 7.1 Common API Patterns

All scripts share these patterns:

| Pattern | Bash Implementation | PowerShell Equivalent |
|---------|--------------------|-----------------------|
| **Base endpoints** | `https://fal.run/{MODEL}` (sync), `https://queue.fal.run/{MODEL}` (queue), `https://api.fal.ai/v1/` (platform) | Same URLs |
| **Authentication** | `Authorization: Key $FAL_KEY` header | `-Headers @{ Authorization = "Key $env:FAL_KEY" }` |
| **HTTP client** | `curl -s -X POST/GET/PUT/DELETE` | `Invoke-RestMethod -Method Post/Get/Put/Delete` |
| **JSON payload** | Heredoc `cat <<EOF` with string interpolation | `@{ key = $value } \| ConvertTo-Json` |
| **JSON parsing** | `grep -o` + `cut -d'"'` (fragile) | `ConvertFrom-Json` (native, robust) |
| **Error detection** | `grep -q '"error"'` then extract message | `if ($response.error) { throw $response.message }` |
| **Status output** | `echo "message" >&2` (stderr) | `Write-Host` or `Write-Verbose` |
| **JSON output** | `echo "$RESPONSE"` (stdout) | `Write-Output $response` or return object |
| **Env loading** | `source .env` | Custom `.env` parser or `$env:FAL_KEY` |
| **Temp files** | `mktemp -d` + `trap cleanup EXIT` | `[System.IO.Path]::GetTempPath()` + `try/finally` |

### 7.2 Shared Authentication Approach

All 14 scripts use the same auth pattern:
1. **Check for `--add-fal-key` flag first** — before any other parsing
2. **Load `.env` file** — `source .env` to set FAL_KEY
3. **Validate `$FAL_KEY`** — exit with setup instructions if missing
4. **Send as header** — `Authorization: Key $FAL_KEY`

**PowerShell module approach:**
```powershell
# Shared function in module
function Get-FalApiKey {
    if ($env:FAL_KEY) { return $env:FAL_KEY }
    $envFile = Join-Path (Get-Location) '.env'
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^FAL_KEY=(.+)$') { $env:FAL_KEY = $Matches[1] }
        }
    }
    if (-not $env:FAL_KEY) {
        throw "FAL_KEY not set. Run Set-FalApiKey or set `$env:FAL_KEY"
    }
    return $env:FAL_KEY
}
```

### 7.3 Recommended PowerShell Module Structure

```
src/
└── modules/
    └── FalAi/
        ├── FalAi.psd1                    # Module manifest
        ├── FalAi.psm1                    # Module loader
        ├── Private/
        │   ├── Get-FalApiKey.ps1         # Shared auth (from setup.sh)
        │   ├── Invoke-FalApi.ps1         # Shared HTTP wrapper
        │   ├── Send-FalFile.ps1          # CDN upload (from upload.sh)
        │   └── ConvertTo-FalPayload.ps1  # JSON payload builder
        ├── Public/
        │   ├── # Generation (from generate.sh — split into focused functions)
        │   ├── Submit-FalGeneration.ps1   # Queue submit
        │   ├── Get-FalJobStatus.ps1       # Queue status check
        │   ├── Get-FalJobResult.ps1       # Queue result retrieval
        │   ├── Stop-FalJob.ps1            # Queue cancel
        │   ├── Invoke-FalGeneration.ps1   # Sync generation
        │   │
        │   ├── # Audio (from speech-to-text.sh, text-to-speech.sh)
        │   ├── ConvertTo-FalSpeech.ps1    # TTS
        │   ├── ConvertFrom-FalSpeech.ps1  # STT
        │   │
        │   ├── # Image editing (from edit-image.sh)
        │   ├── Edit-FalImage.ps1          # All operations
        │   │
        │   ├── # Upscale (from upscale.sh)
        │   ├── Resize-FalImage.ps1        # Upscale
        │   │
        │   ├── # Platform (from platform scripts)
        │   ├── Get-FalModelPricing.ps1    # pricing.sh
        │   ├── Get-FalUsage.ps1           # usage.sh
        │   ├── Get-FalCostEstimate.ps1    # estimate-cost.sh
        │   ├── Get-FalRequests.ps1        # requests.sh (list)
        │   ├── Remove-FalRequestData.ps1  # requests.sh (delete)
        │   │
        │   ├── # Discovery (from search-models.sh, get-schema.sh)
        │   ├── Search-FalModel.ps1        # Model search
        │   ├── Get-FalModelSchema.ps1     # OpenAPI schema
        │   │
        │   ├── # Workflow (from create-workflow.sh)
        │   ├── New-FalWorkflow.ps1        # Workflow creation
        │   │
        │   ├── # Configuration (from setup.sh)
        │   ├── Set-FalApiKey.ps1          # Key management
        │   └── Get-FalConfig.ps1          # Show config
        └── Tests/
            └── ...
```

### 7.4 Key Conversion Advantages (Bash → PowerShell)

| Bash Weakness | PowerShell Strength |
|---------------|---------------------|
| JSON parsing via `grep/cut` (fragile, breaks on nested JSON) | `ConvertFrom-Json` returns native objects |
| Heredoc payload construction (no escaping) | `ConvertTo-Json` handles escaping automatically |
| Python3 dependency for math/formatting | Native PowerShell arithmetic and `Format-*` cmdlets |
| `source .env` (Unix-only) | Cross-platform `.env` parser |
| `stat -f%z` vs `stat -c%s` (macOS vs Linux) | `(Get-Item $path).Length` (universal) |
| Complex `sed` URL encoding | `[uri]::EscapeDataString()` |
| `case/esac` argument parsing | `param()` with validation attributes |
| stderr/stdout separation via `>&2` | `Write-Host`/`Write-Verbose` vs `Write-Output` |

### 7.5 API Endpoint Inventory

| Base URL | Used By | Purpose |
|----------|---------|---------|
| `https://fal.run/{MODEL}` | generate (sync), audio, image-edit, upscale | Synchronous inference |
| `https://queue.fal.run/{MODEL}` | generate (queue) | Queue-based inference |
| `https://rest.alpha.fal.ai/storage/auth/token` | generate, upload | CDN upload token |
| `{dynamic_base_url}/files/upload` | generate, upload | CDN file upload |
| `https://api.fal.ai/v1/models` | search-models | Model search |
| `https://api.fal.ai/v1/models/pricing` | pricing, estimate-cost | Model pricing |
| `https://api.fal.ai/v1/models/usage` | usage | Usage/billing data |
| `https://api.fal.ai/v1/models/requests/by-endpoint` | requests | Request listing |
| `https://api.fal.ai/v1/models/requests/{ID}/payloads` | requests | Request cleanup |
| `https://fal.ai/api/openapi/queue/openapi.json` | get-schema, generate | OpenAPI schema |

### 7.6 Prioritized Conversion Order

| Priority | Script(s) | Reason |
|----------|-----------|--------|
| **1 — Critical** | `setup.sh` | Foundation — all scripts depend on FAL_KEY management |
| **2 — Critical** | `upload.sh` | Shared dependency — generate.sh embeds upload logic |
| **3 — Critical** | `generate.sh` | Core functionality — most complex, most used |
| **4 — High** | `text-to-speech.sh`, `speech-to-text.sh` | Simple, independent, high user value |
| **5 — High** | `edit-image.sh` | Simple, independent, high user value |
| **6 — High** | `upscale.sh` | Simple, independent, high user value |
| **7 — Medium** | `search-models.sh`, `get-schema.sh` | Discovery tools, useful but not generation-critical |
| **8 — Medium** | `pricing.sh`, `usage.sh`, `estimate-cost.sh` | Platform management, lower priority |
| **9 — Low** | `requests.sh` | Admin/cleanup utility |
| **10 — Low** | `create-workflow.sh` | Complex JSON generation, may be better served by TypeScript/MCP |

### 7.7 Shared Infrastructure to Build First

Before converting individual scripts, build these shared components:

1. **`Invoke-FalApi`** — Centralized HTTP wrapper with auth, error handling, retry logic
2. **`Get-FalApiKey`** — Key loading from env var or `.env` file
3. **`Send-FalFile`** — 2-step CDN upload (token → upload)
4. **`Wait-FalJob`** — Queue polling with timeout, status display, log streaming
5. **Error handling middleware** — Consistent `try/catch` with fal.ai error message extraction

These 5 shared components eliminate ~60% of duplicated code across all 14 scripts.
