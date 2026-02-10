---
name: docx
description: "Use this skill whenever the user wants to create, read, edit, or manipulate Word documents (.docx files). Triggers include: any mention of \"Word doc\", \"word document\", \".docx\", or requests to produce professional documents with formatting like tables of contents, headings, page numbers, or letterheads. Also use when extracting content from .docx files, working with tracked changes or comments, or converting content into a polished Word document."
---

# DOCX Creation, Editing, and Analysis

A .docx file is a ZIP archive containing XML files.

## Quick Reference

| Task | Approach |
|------|----------|
| Read/analyze content | `pandoc` or unpack for raw XML |
| Create new document | Use `docx-js` (`npm install -g docx`) |
| Edit existing document | Unpack → edit XML → repack |

## Creating New Documents (docx-js)

```javascript
const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
        ImageRun, Header, Footer, HeadingLevel, PageBreak } = require('docx');

const doc = new Document({ sections: [{ children: [/* content */] }] });
Packer.toBuffer(doc).then(buffer => fs.writeFileSync("doc.docx", buffer));
```

### Critical Rules
- **Set page size explicitly** — defaults to A4; use 12240×15840 DXA for US Letter
- **Never use `\n`** — use separate Paragraph elements
- **Never use unicode bullets** — use `LevelFormat.BULLET` with numbering config
- **PageBreak must be in Paragraph** — standalone creates invalid XML
- **ImageRun requires `type`** — always specify png/jpg/etc
- **Tables need dual widths** — `columnWidths` AND cell `width`, both must match
- **Always use `WidthType.DXA`** — never `PERCENTAGE` (breaks in Google Docs)
- **Use `ShadingType.CLEAR`** — never SOLID for table shading

### Validation
```bash
python scripts/office/validate.py doc.docx
```

## Editing Existing Documents

### Step 1: Unpack
```bash
python scripts/office/unpack.py document.docx unpacked/
```

### Step 2: Edit XML
Edit files in `unpacked/word/`. Use smart quotes (`&#x201C;`, `&#x201D;`, `&#x2019;`).

**Tracked Changes:**
```xml
<w:ins w:id="1" w:author="Claude" w:date="2025-01-01T00:00:00Z">
  <w:r><w:t>inserted text</w:t></w:r>
</w:ins>
<w:del w:id="2" w:author="Claude" w:date="2025-01-01T00:00:00Z">
  <w:r><w:delText>deleted text</w:delText></w:r>
</w:del>
```

### Step 3: Pack
```bash
python scripts/office/pack.py unpacked/ output.docx --original document.docx
```

## Reading Content

```bash
pandoc --track-changes=all document.docx -o output.md
python scripts/office/unpack.py document.docx unpacked/
```

## Attribution

From [anthropics/skills](https://github.com/anthropics/skills) `docx` skill (Proprietary — see LICENSE.txt in source repo for terms).
