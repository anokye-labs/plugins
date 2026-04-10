@{
    Severity = @('Error', 'Warning')
    Rules = @{
        PSUseConsistentIndentation = @{ Enable = $true; IndentationSize = 4 }
        PSUseConsistentWhitespace = @{ Enable = $true }
        PSPlaceOpenBrace = @{ Enable = $true; OnSameLine = $true }
        PSPlaceCloseBrace = @{ Enable = $true }
    }
}