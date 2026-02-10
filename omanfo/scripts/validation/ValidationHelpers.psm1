<#
.SYNOPSIS
    Common helper functions for validation scripts.

.DESCRIPTION
    Shared utilities used across validation scripts to ensure consistency.
#>

function Get-FeatureNameFromScript {
    <#
    .SYNOPSIS
        Maps a script name to a feature name.
    
    .DESCRIPTION
        Uses naming patterns to determine which feature a script belongs to.
    
    .PARAMETER ScriptName
        The base name of the script (without .ps1 extension)
    
    .EXAMPLE
        Get-FeatureNameFromScript -ScriptName "Get-IssueTypeIds"
        Returns: "issue-types"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ScriptName
    )
    
    $featureName = switch -Regex ($ScriptName) {
        # Issue type operations - querying, managing organization issue types
        'IssueType' { 'issue-types'; break }
        # Hierarchy operations - parent-child relationships, sub-issues
        'Hierarchy|SubIssue|Parent' { 'hierarchy'; break }
        # GitHub Projects V2 integration
        'Project' { 'projects'; break }
        # Pull request review operations - threads, comments, resolution
        'PR|Review|Thread' { 'pr-reviews'; break }
        # Label management operations
        'Label' { 'labels'; break }
        # Health monitoring and status reporting
        'Sitrep|Health' { 'end-to-end'; break }
        # Issue creation with typed GraphQL mutations
        'New-IssueWithType' { 'create-issues'; break }
        # Default: use script name as feature name
        default { $ScriptName.ToLower(); break }
    }
    
    return $featureName
}

function Get-FeatureNameFromEval {
    <#
    .SYNOPSIS
        Extracts feature name from an evaluation filename.
    
    .DESCRIPTION
        Parses evaluation filenames with pattern NN-feature-name.eval.md
    
    .PARAMETER EvalFileName
        The evaluation filename
    
    .EXAMPLE
        Get-FeatureNameFromEval -EvalFileName "01-install-verify.eval.md"
        Returns: "install-verify"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$EvalFileName
    )
    
    if ($EvalFileName -match '^\d+-(.+)\.eval\.md$') {
        return $matches[1]
    }
    
    return $null
}

function Build-FeatureMap {
    <#
    .SYNOPSIS
        Builds a feature coverage map from scripts and evaluations.
    
    .DESCRIPTION
        Creates a hashtable mapping features to their scripts and evaluations.
    
    .PARAMETER ScriptPath
        Path to the scripts directory
    
    .PARAMETER EvalPath
        Path to the evaluations directory
    
    .OUTPUTS
        Hashtable with feature names as keys, containing Scripts and Evaluations arrays
    
    .EXAMPLE
        $features = Build-FeatureMap -ScriptPath "./scripts" -EvalPath "./evaluations"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory)]
        [string]$EvalPath
    )
    
    $features = @{}
    
    # Map scripts to features
    $scripts = Get-ChildItem $ScriptPath -Filter "*.ps1" -File -ErrorAction SilentlyContinue
    foreach ($script in $scripts) {
        $featureName = Get-FeatureNameFromScript -ScriptName $script.BaseName
        
        if (-not $features.ContainsKey($featureName)) {
            $features[$featureName] = @{
                Scripts = [System.Collections.ArrayList]::new()
                Evaluations = [System.Collections.ArrayList]::new()
            }
        }
        
        [void]$features[$featureName].Scripts.Add($script.Name)
    }
    
    # Map evaluations to features
    $evals = Get-ChildItem $EvalPath -Filter "*.eval.md" -File -ErrorAction SilentlyContinue
    foreach ($eval in $evals) {
        $featureName = Get-FeatureNameFromEval -EvalFileName $eval.Name
        
        if ($featureName) {
            if (-not $features.ContainsKey($featureName)) {
                $features[$featureName] = @{
                    Scripts = [System.Collections.ArrayList]::new()
                    Evaluations = [System.Collections.ArrayList]::new()
                }
            }
            
            [void]$features[$featureName].Evaluations.Add($eval.Name)
        }
    }
    
    return $features
}

# Export functions
Export-ModuleMember -Function Get-FeatureNameFromScript, Get-FeatureNameFromEval, Build-FeatureMap
