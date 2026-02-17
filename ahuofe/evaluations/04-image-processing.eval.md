# Evaluation 4: Local Image Processing

**Priority:** 🟡 Important  
**Time:** 5 minutes  
**Prerequisites:** Installed plugin, ImageSorcery MCP server running

## Objective

Verify local image processing via ImageSorcery MCP works correctly.

## Test Steps

### 4.1 ImageSorcery Connection

**Action:** Test the ImageSorcery MCP connection.

```powershell
& ahuofe\scripts\Test-ImageSorcery.ps1
```

**Expected:**
- [ ] Script reports MCP server is reachable
- [ ] Available tools are listed
- [ ] No connection errors

### 4.2 Copilot Image Processing

**Action:** In a Copilot chat session with an image available, ask:

> "Resize this image to 512x512 pixels"

**Expected:**
- [ ] Copilot uses the image-sorcery skill
- [ ] ImageSorcery MCP tool is invoked
- [ ] Processed image result is returned

### 4.3 Copilot OCR

**Action:** In a Copilot chat session with a text-containing image, ask:

> "Extract the text from this image using OCR"

**Expected:**
- [ ] Copilot uses the image-sorcery skill
- [ ] OCR is performed on the image
- [ ] Extracted text is displayed

### 4.4 Generate Then Process

**Action:** In a Copilot chat session, ask:

> "Generate an image of a business card, then crop it to just the text area"

**Expected:**
- [ ] Copilot uses fal-ai skill to generate, then image-sorcery to process
- [ ] Multi-step workflow completes
- [ ] Both generation and processing results are shown

## Pass/Fail

- **PASS:** Step 4.1 succeeds and at least one of 4.2–4.4 succeeds
- **FAIL:** Step 4.1 fails or none of 4.2–4.4 succeed
