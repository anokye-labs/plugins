---
name: pptx
description: "Use this skill any time a .pptx file is involved — as input, output, or both. This includes: creating slide decks, pitch decks, or presentations; reading or extracting text from .pptx files; editing or updating existing presentations; working with templates, layouts, speaker notes, or comments. Trigger whenever the user mentions \"deck,\" \"slides,\" \"presentation,\" or references a .pptx filename."
---

# PPTX Skill

## Quick Reference

| Task | Guide |
|------|-------|
| Read/analyze content | `python -m markitdown presentation.pptx` |
| Edit or create from template | Unpack → manipulate slides → pack |
| Create from scratch | Use `pptxgenjs` (`npm install -g pptxgenjs`) |

## Reading Content

```bash
python -m markitdown presentation.pptx    # Text extraction
python scripts/thumbnail.py presentation.pptx  # Visual overview
python scripts/office/unpack.py presentation.pptx unpacked/  # Raw XML
```

## Design Principles

**Don't create boring slides.** Every slide needs a visual element — image, chart, icon, or shape.

### Before Starting
- Pick a bold, content-informed color palette specific to THIS topic
- One color dominates (60-70%), 1-2 supporting tones, one accent
- Dark backgrounds for title + conclusion, light for content
- Commit to ONE visual motif and repeat it

### Layout Options
- Two-column (text left, illustration right)
- Icon + text rows
- 2×2 or 2×3 grid
- Half-bleed image with content overlay
- Large stat callouts (60-72pt numbers)

### Typography
- Slide title: 36-44pt bold
- Section header: 20-24pt bold
- Body text: 14-16pt
- Captions: 10-12pt muted
- 0.5" minimum margins

### Avoid
- Don't repeat the same layout across slides
- Don't center body text (left-align; center only titles)
- Don't default to blue — match the topic
- Don't create text-only slides
- NEVER use accent lines under titles (hallmark of AI-generated slides)

## QA (Required)

**Assume there are problems. Your job is to find them.**

### Content QA
```bash
python -m markitdown output.pptx
python -m markitdown output.pptx | grep -iE "xxxx|lorem|ipsum"
```

### Visual QA
Convert to images and inspect:
```bash
python scripts/office/soffice.py --headless --convert-to pdf output.pptx
pdftoppm -jpeg -r 150 output.pdf slide
```

Check for: overlapping elements, text overflow, low contrast, uneven gaps, leftover placeholders.

### Verification Loop
1. Generate → Convert to images → Inspect
2. List issues (if none, look again more critically)
3. Fix issues → Re-verify affected slides
4. Repeat until clean pass

## Dependencies

- `pip install "markitdown[pptx]"` — text extraction
- `npm install -g pptxgenjs` — creating from scratch
- LibreOffice — PDF conversion
- Poppler (`pdftoppm`) — PDF to images

## Attribution

From [anthropics/skills](https://github.com/anthropics/skills) `pptx` skill (Proprietary — see LICENSE.txt in source repo for terms).
