# Evaluation 6: Model Discovery

**Priority:** 🟢 Nice-to-have  
**Time:** 3 minutes  
**Prerequisites:** Installed plugin, `FAL_KEY` set

## Objective

Verify model search and schema retrieval work correctly.

## Test Steps

### 6.1 Search Models

**Action:** Search for available models.

```powershell
$models = & ahuofe\scripts\Search-FalModels.ps1 -Query "flux"
$models | Select-Object -First 5
```

**Expected:**
- [ ] Returns a list of models matching "flux"
- [ ] Each result includes model ID and description
- [ ] Results include known models like `fal-ai/flux/dev`

### 6.2 Get Model Details

**Action:** Retrieve details for a specific model.

```powershell
$model = & ahuofe\scripts\Get-FalModel.ps1 -ModelId "fal-ai/flux/dev"
$model
```

**Expected:**
- [ ] Returns model information
- [ ] Includes input parameters and output fields

### 6.3 Get Model Schema

**Action:** Retrieve the input/output schema.

```powershell
$schema = & ahuofe\scripts\Get-ModelSchema.ps1 -ModelId "fal-ai/flux/dev"
$schema
```

**Expected:**
- [ ] Returns structured schema
- [ ] Input schema includes `prompt` parameter
- [ ] Output schema includes image result fields

### 6.4 Copilot Model Discovery

**Action:** In a Copilot chat session, ask:

> "What fal.ai models are available for image generation?"

**Expected:**
- [ ] Copilot uses the fal-ai skill
- [ ] Lists available models with descriptions
- [ ] Recommends models appropriate for the use case

## Pass/Fail

- **PASS:** Steps 6.1 and 6.2 succeed
- **FAIL:** Both fail
