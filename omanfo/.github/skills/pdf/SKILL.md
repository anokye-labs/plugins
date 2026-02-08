---
name: pdf
description: Use this skill whenever the user wants to do anything with PDF files. This includes reading or extracting text/tables from PDFs, combining or merging multiple PDFs into one, splitting PDFs apart, rotating pages, adding watermarks, creating new PDFs, filling PDF forms, encrypting/decrypting PDFs, extracting images, and OCR on scanned PDFs to make them searchable. If the user mentions a .pdf file or asks to produce one, use this skill.
---

# PDF Processing Guide

## Quick Start

```python
from pypdf import PdfReader, PdfWriter

reader = PdfReader("document.pdf")
print(f"Pages: {len(reader.pages)}")

text = ""
for page in reader.pages:
    text += page.extract_text()
```

## Quick Reference

| Task | Best Tool | Key Code |
|------|-----------|----------|
| Merge PDFs | pypdf | `writer.add_page(page)` |
| Split PDFs | pypdf | One page per file |
| Extract text | pdfplumber | `page.extract_text()` |
| Extract tables | pdfplumber | `page.extract_tables()` |
| Create PDFs | reportlab | Canvas or Platypus |
| OCR scanned PDFs | pytesseract | Convert to image first |
| Command line merge | qpdf | `qpdf --empty --pages ...` |

## Python Libraries

### pypdf — Merge, Split, Rotate, Encrypt

```python
from pypdf import PdfWriter, PdfReader

# Merge
writer = PdfWriter()
for pdf_file in ["doc1.pdf", "doc2.pdf"]:
    for page in PdfReader(pdf_file).pages:
        writer.add_page(page)
with open("merged.pdf", "wb") as f:
    writer.write(f)

# Split
reader = PdfReader("input.pdf")
for i, page in enumerate(reader.pages):
    w = PdfWriter()
    w.add_page(page)
    with open(f"page_{i+1}.pdf", "wb") as f:
        w.write(f)

# Rotate
page = PdfReader("input.pdf").pages[0]
page.rotate(90)

# Encrypt
writer.encrypt("userpassword", "ownerpassword")
```

### pdfplumber — Text and Table Extraction

```python
import pdfplumber

with pdfplumber.open("document.pdf") as pdf:
    for page in pdf.pages:
        text = page.extract_text()
        tables = page.extract_tables()
```

### reportlab — Create PDFs

```python
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas

c = canvas.Canvas("hello.pdf", pagesize=letter)
c.drawString(100, 700, "Hello World!")
c.save()
```

**IMPORTANT**: Never use Unicode subscript/superscript characters in ReportLab — use `<sub>` and `<super>` tags in Paragraph objects.

## Command-Line Tools

```bash
# pdftotext (poppler-utils)
pdftotext -layout input.pdf output.txt

# qpdf
qpdf --empty --pages file1.pdf file2.pdf -- merged.pdf
qpdf input.pdf --pages . 1-5 -- pages1-5.pdf
```

## Common Tasks

### OCR Scanned PDFs
```python
import pytesseract
from pdf2image import convert_from_path

images = convert_from_path('scanned.pdf')
for image in images:
    text = pytesseract.image_to_string(image)
```

### Add Watermark
```python
watermark = PdfReader("watermark.pdf").pages[0]
for page in PdfReader("document.pdf").pages:
    page.merge_page(watermark)
```

### Extract Images
```bash
pdfimages -j input.pdf output_prefix
```

## Attribution

From [anthropics/skills](https://github.com/anthropics/skills) `pdf` skill (Proprietary — see LICENSE.txt in source repo for terms).
