---
name: xlsx
description: "Use this skill any time a spreadsheet file is the primary input or output. This means any task where the user wants to: open, read, edit, or fix an existing .xlsx, .xlsm, .csv, or .tsv file; create a new spreadsheet from scratch or from other data sources; or convert between tabular file formats. Trigger when the user references a spreadsheet file by name or path."
---

# XLSX Creation, Editing, and Analysis

## Critical Rule: Use Formulas, Not Hardcoded Values

**Always use Excel formulas instead of calculating in Python and hardcoding results.**

```python
# ❌ WRONG
total = df['Sales'].sum()
sheet['B10'] = total

# ✅ CORRECT
sheet['B10'] = '=SUM(B2:B9)'
```

## Quick Reference

| Task | Tool |
|------|------|
| Data analysis | pandas |
| Formulas & formatting | openpyxl |
| Formula recalculation | `python scripts/recalc.py output.xlsx` |

## Common Workflow

1. Choose tool (pandas for data, openpyxl for formulas/formatting)
2. Create/Load workbook
3. Modify data, formulas, formatting
4. Save
5. **Recalculate formulas** (mandatory): `python scripts/recalc.py output.xlsx`
6. Verify and fix any errors from recalc output

## Creating Excel Files (openpyxl)

```python
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment

wb = Workbook()
sheet = wb.active
sheet['A1'] = 'Revenue'
sheet['B2'] = '=SUM(A1:A10)'
sheet['A1'].font = Font(bold=True)
sheet.column_dimensions['A'].width = 20
wb.save('output.xlsx')
```

## Reading Data (pandas)

```python
import pandas as pd
df = pd.read_excel('file.xlsx')
all_sheets = pd.read_excel('file.xlsx', sheet_name=None)
```

## Financial Model Standards

### Color Coding
- **Blue text**: Hardcoded inputs
- **Black text**: ALL formulas and calculations
- **Green text**: Links from other worksheets
- **Red text**: External links
- **Yellow background**: Key assumptions needing attention

### Number Formatting
- Years as text strings ("2024" not "2,024")
- Currency: `$#,##0` with units in headers
- Zeros display as "-"
- Percentages: `0.0%`
- Negatives: parentheses `(123)` not `-123`

## Formula Verification Checklist

- [ ] Test 2-3 sample references before building full model
- [ ] Confirm column mapping (column 64 = BL, not BK)
- [ ] Row offset: DataFrame row 5 = Excel row 6
- [ ] Handle NaN with `pd.notna()`
- [ ] Check for #DIV/0!, #REF!, #VALUE! errors after recalc

## Attribution

From [anthropics/skills](https://github.com/anthropics/skills) `xlsx` skill (Proprietary — see LICENSE.txt in source repo for terms).
