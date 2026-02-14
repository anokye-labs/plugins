# Getting Started

Set up the Copilot Media Plugins extension and generate your first image.

## Prerequisites

| Requirement | Minimum Version | Notes |
|-------------|----------------|-------|
| PowerShell | 7.0+ | `pwsh --version` to check |
| Git | 2.30+ | For cloning the repository |
| GitHub Copilot | Active subscription | Extension host |
| fal.ai API Key | — | Sign up at [fal.ai](https://fal.ai) |

## Installation

### 1. Clone the Repository

```powershell
git clone https://github.com/anokye-labs/copilot-media-plugins.git
cd copilot-media-plugins
```

### 2. Configure Your fal.ai API Key

Set the API key as an environment variable:

```powershell
# PowerShell — current session
$env:FAL_KEY = "your-api-key-here"

# PowerShell — persist across sessions (user scope)
[System.Environment]::SetEnvironmentVariable("FAL_KEY", "your-api-key-here", "User")
```

### 3. Verify Setup

```powershell
# Confirm PowerShell version
pwsh --version

# Confirm API key is set
if ($env:FAL_KEY) { Write-Output "FAL_KEY is configured" } else { Write-Warning "FAL_KEY is not set" }
```

## First Media Generation

Generate a simple image using the fal.ai skill through GitHub Copilot:

### Step 1: Open GitHub Copilot Chat

In your editor or terminal, open a Copilot Chat session with the media plugins extension enabled.

### Step 2: Request an Image

Type a prompt like:

```
Generate an image of a mountain landscape at sunset using flux-dev
```

### Step 3: Review the Output

The extension will:
1. Send your prompt to fal.ai's Flux Dev model
2. Return the generated image URL
3. Optionally download the image to your workspace

### Step 4: Iterate

Refine your prompt or adjust parameters:

```
Generate the same scene but with 30 inference steps and guidance scale 7.5
```

## Troubleshooting

### "FAL_KEY is not set" Error

Ensure the environment variable is set in the current session:

```powershell
$env:FAL_KEY = "your-api-key-here"
```

If using a `.env` file, confirm the extension reads from it.

### PowerShell Version Too Old

Install PowerShell 7+:

```powershell
# Windows (via winget)
winget install Microsoft.PowerShell

# macOS
brew install powershell/tap/powershell

# Linux (Ubuntu)
sudo apt-get install -y powershell
```

### Network/Proxy Issues

If behind a corporate proxy:

```powershell
$env:HTTPS_PROXY = "http://proxy.example.com:8080"
```

### Rate Limiting

fal.ai enforces rate limits. If you receive 429 errors:
- Wait and retry — the extension uses exponential backoff automatically
- Check your [fal.ai dashboard](https://fal.ai/dashboard) for usage and limits

## Next Steps

- [Image Generation](image-generation.md) — explore models and parameters
- [Image Processing](image-processing.md) — resize, crop, and transform images
- [Workflows](workflows.md) — build multi-step media pipelines
