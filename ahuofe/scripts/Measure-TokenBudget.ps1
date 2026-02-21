<#
.SYNOPSIS
    Estimates token counts for skill files and flags files over budget.
.DESCRIPTION
    Counts lines per file, estimates tokens using a rough heuristic
    (~1.3 tokens per word, ~10 words per line ≈ 13 tokens/line), and
    flags files exceeding the budget. SKILL.md files have a 500-line limit.
    Recurses into directories.
.PARAMETER Path
    File or directory to analyze (mandatory).
.PARAMETER MaxTokens
    Maximum token budget. Default is 6500 (500 lines × 13 tokens/line).
.PARAMETER MaxLines
    Maximum line budget. Default is 500.
.PARAMETER TokensPerLine
    Estimated tokens per line. Default is 13 (~10 words × 1.3 tokens/word).
.PARAMETER OutputFormat
    Output format: 'Table' (default) or 'JSON'.
.EXAMPLE
    .\Measure-TokenBudget.ps1 -Path .\skills\
.EXAMPLE
    .\Measure-TokenBudget.ps1 -Path .\skills\image-sorcery\SKILL.md -OutputFormat JSON
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ })]
    [string]$Path,

    [int]$MaxTokens = 6500,

    [int]$MaxLines = 500,

    [double]$TokensPerLine = 13.0,

    [ValidateSet('Table', 'JSON')]
    [string]$OutputFormat = 'Table'
)

function Measure-SingleFile {
    param(
        [string]$FilePath,
        [int]$MaxTokens,
        [int]$MaxLines,
        [double]$TokensPerLine
    )

    $content = Get-Content -Path $FilePath -ErrorAction SilentlyContinue
    $lineCount = if ($content) { $content.Count } else { 0 }

    $wordCount = 0
    if ($content) {
        foreach ($line in $content) {
            $words = ($line -split '\s+') | Where-Object { $_ -ne '' }
            $wordCount += $words.Count
        }
    }

    $estimatedTokens = [Math]::Ceiling($wordCount * 1.3)
    $estimatedByLine = [Math]::Ceiling($lineCount * $TokensPerLine)

    # Use actual word-based estimate when we have content, else line-based
    $tokenEstimate = if ($wordCount -gt 0) { $estimatedTokens } else { $estimatedByLine }

    $fileName = Split-Path -Leaf $FilePath
    $isSkillFile = $fileName -eq 'SKILL.md'

    # SKILL.md files use 500-line limit specifically
    $effectiveMaxLines = if ($isSkillFile) { 500 } else { $MaxLines }
    $effectiveMaxTokens = if ($isSkillFile) { [Math]::Ceiling(500 * $TokensPerLine) } else { $MaxTokens }

    $overBudget = ($lineCount -gt $effectiveMaxLines) -or ($tokenEstimate -gt $effectiveMaxTokens)

    return [PSCustomObject]@{
        File            = $FilePath
        Lines           = $lineCount
        Words           = $wordCount
        EstimatedTokens = $tokenEstimate
        MaxLines        = $effectiveMaxLines
        MaxTokens       = $effectiveMaxTokens
        OverBudget      = $overBudget
        IsSkillFile     = $isSkillFile
    }
}

# Collect files
$results = @()
$item = Get-Item $Path

if ($item.PSIsContainer) {
    $files = Get-ChildItem -Path $Path -Recurse -File -Include '*.md', '*.ps1', '*.psm1', '*.psd1', '*.txt', '*.yml', '*.yaml', '*.json'
    foreach ($file in $files) {
        $results += Measure-SingleFile -FilePath $file.FullName -MaxTokens $MaxTokens -MaxLines $MaxLines -TokensPerLine $TokensPerLine
    }
} else {
    $results += Measure-SingleFile -FilePath $item.FullName -MaxTokens $MaxTokens -MaxLines $MaxLines -TokensPerLine $TokensPerLine
}

if ($results.Count -eq 0) {
    Write-Warning "No files found to analyze at path: $Path"
    return
}

if ($OutputFormat -eq 'JSON') {
    $results | ConvertTo-Json -Depth 3
} else {
    $results | Format-Table -Property File, Lines, Words, EstimatedTokens, OverBudget -AutoSize
}
