# Plugin Evaluations

Test scenarios to validate the Ahuofe media plugin after installation. Each evaluation is a self-contained test that can be run independently.

## Running Evaluations

Evaluations are markdown files with structured test steps. They are designed to be executed by a human or agent in a Copilot chat session.

### Quick Validation

```powershell
# Test fal.ai connectivity
& ahuofe\scripts\Test-FalConnection.ps1

# Test ImageSorcery (optional)
& ahuofe\scripts\Test-ImageSorcery.ps1
```

### Full Evaluation

Work through each `.eval.md` file in order:

| # | Evaluation | Tests | Priority |
|---|------------|-------|----------|
| 1 | [install-verify](01-install-verify.eval.md) | Installation & file structure | 🔴 Critical |
| 2 | [connectivity](02-connectivity.eval.md) | API key & connectivity checks | 🔴 Critical |
| 3 | [text-to-image](03-text-to-image.eval.md) | Image generation from text prompts | 🔴 Critical |
| 4 | [image-processing](04-image-processing.eval.md) | Local image processing via ImageSorcery | 🟡 Important |
| 5 | [video-generation](05-video-generation.eval.md) | Text-to-video and image-to-video | 🟡 Important |
| 6 | [model-discovery](06-model-discovery.eval.md) | Model search and schema retrieval | 🟢 Nice-to-have |
| 7 | [end-to-end](07-end-to-end.eval.md) | Full workflow: generate → process → deliver | 🔴 Critical |

### Pass Criteria

- **Critical** evaluations must all pass for the plugin to be considered functional
- **Important** evaluations should pass for production use
- **Nice-to-have** evaluations test edge cases and advanced features

### Environment

Each evaluation assumes:
- Plugin is installed in a test repository
- `FAL_KEY` environment variable is set (or `.env` file exists)
- PowerShell 7+ is available
- ImageSorcery MCP server running (for eval 4 only)
