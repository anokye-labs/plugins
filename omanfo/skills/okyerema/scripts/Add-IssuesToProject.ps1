#Requires -Version 5.1
<#
.SYNOPSIS
    Bulk add issues to a GitHub Projects V2 board with optional custom field values.

.DESCRIPTION
    Adds one or more issues to a GitHub Project V2, optionally setting custom field
    values such as Status or Priority on each added item.

.PARAMETER Owner
    Repository owner (organization).

.PARAMETER Repo
    Repository name.

.PARAMETER ProjectNumber
    GitHub Project V2 number.

.PARAMETER IssueNumbers
    Array of issue numbers to add to the project.

.PARAMETER FieldValues
    Hashtable of custom field names to values (e.g. @{ "Status" = "In Progress" }).

.PARAMETER RetryAttempts
    Number of retry attempts for GraphQL calls. Default is 3.

.PARAMETER RetryDelayMs
    Delay in milliseconds between retries. Default is 1000.
#>
[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$ProjectNumber,
    [Parameter(Mandatory)][int[]]$IssueNumbers,
    [hashtable]$FieldValues = @{},  # e.g. @{ "Status" = "In Progress"; "Priority" = "High" }
    [int]$RetryAttempts = 3,
    [int]$RetryDelayMs = 1000
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\_Invoke-GraphQL.ps1"

Write-Host "=== Adding Issues to Project ===" -ForegroundColor Cyan
Write-Host "Organization: $Owner" -ForegroundColor Gray
Write-Host "Repository: $Repo" -ForegroundColor Gray
Write-Host "Project Number: $ProjectNumber" -ForegroundColor Gray
Write-Host "Issues: #$($IssueNumbers -join ', #')" -ForegroundColor Gray
Write-Host ""

# Step 1: Get project ID and field information
Write-Host "[1/4] Fetching project details..." -ForegroundColor Yellow

$projectQuery = @"
query {
  organization(login: `"$Owner`") {
    projectV2(number: $ProjectNumber) {
      id
      title
      fields(first: 50) {
        nodes {
          ... on ProjectV2Field {
            id
            name
            dataType
          }
          ... on ProjectV2SingleSelectField {
            id
            name
            dataType
            options {
              id
              name
            }
          }
        }
      }
    }
  }
}
"@

$projectResult = Invoke-GraphQL -Query $projectQuery -MaxAttempts $RetryAttempts -RetryDelayMs $RetryDelayMs
$project = $projectResult.data.organization.projectV2

if (-not $project) {
    Write-Error "Project #$ProjectNumber not found in organization '$Owner'"
    exit 1
}

$projectId = $project.id
$projectTitle = $project.title
Write-Host "  ✓ Project: $projectTitle ($projectId)" -ForegroundColor Green

# Build field mapping if field values are provided
$fieldMap = @{}
if ($FieldValues.Count -gt 0) {
    Write-Host "  → Building field mapping for $($FieldValues.Count) fields..." -ForegroundColor Gray
    
    foreach ($fieldName in $FieldValues.Keys) {
        $field = $project.fields.nodes | Where-Object { $_.name -eq $fieldName } | Select-Object -First 1
        
        if (-not $field) {
            Write-Warning "  ⚠ Field '$fieldName' not found in project. Skipping."
            continue
        }
        
        $fieldValue = $FieldValues[$fieldName]
        $fieldMap[$fieldName] = @{
            Id = $field.id
            DataType = $field.dataType
            Value = $fieldValue
        }
        
        # For single-select fields, resolve option ID
        if ($field.dataType -eq "SINGLE_SELECT") {
            $option = $field.options | Where-Object { $_.name -eq $fieldValue } | Select-Object -First 1
            if ($option) {
                $fieldMap[$fieldName].OptionId = $option.id
                Write-Host "    • $fieldName = $fieldValue (option: $($option.id))" -ForegroundColor Gray
            } else {
                Write-Warning "  ⚠ Option '$fieldValue' not found for field '$fieldName'. Skipping."
                $fieldMap.Remove($fieldName)
            }
        } else {
            Write-Host "    • $fieldName = $fieldValue ($($field.dataType))" -ForegroundColor Gray
        }
    }
}

# Step 2: Get issue IDs
Write-Host "`n[2/4] Fetching issue IDs..." -ForegroundColor Yellow

$issueIds = @()
foreach ($num in $IssueNumbers) {
    $issueQuery = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    issue(number: $num) {
      id
      title
    }
  }
}
"@
    
    try {
        $issueResult = Invoke-GraphQL -Query $issueQuery -MaxAttempts $RetryAttempts -RetryDelayMs $RetryDelayMs
        $issue = $issueResult.data.repository.issue
        
        if (-not $issue) {
            Write-Warning "  ⚠ Issue #$num not found. Skipping."
            continue
        }
        
        $issueIds += [PSCustomObject]@{
            Number = $num
            Id = $issue.id
            Title = $issue.title
        }
        Write-Host "  ✓ #$num - $($issue.title)" -ForegroundColor Gray
    }
    catch {
        Write-Warning "  ⚠ Failed to fetch issue #${num}: $($_.Exception.Message)"
    }
}

if ($issueIds.Count -eq 0) {
    Write-Error "No valid issues found to add to project"
    exit 1
}

Write-Host "  → Found $($issueIds.Count) valid issue(s)" -ForegroundColor Green

# Step 3: Add issues to project
Write-Host "`n[3/4] Adding issues to project..." -ForegroundColor Yellow

$addedItems = @()
$addFailures = @()

foreach ($issue in $issueIds) {
    $addMutation = @"
mutation {
  addProjectV2ItemById(input: {
    projectId: `"$projectId`"
    contentId: `"$($issue.Id)`"
  }) {
    item {
      id
    }
  }
}
"@
    
    try {
        $addResult = Invoke-GraphQL -Query $addMutation -MaxAttempts $RetryAttempts -RetryDelayMs $RetryDelayMs
        $itemId = $addResult.data.addProjectV2ItemById.item.id
        
        $addedItems += [PSCustomObject]@{
            Number = $issue.Number
            Title = $issue.Title
            ItemId = $itemId
        }
        
        Write-Host "  ✓ Added #$($issue.Number) to project (item: $itemId)" -ForegroundColor Green
        
        # Rate limiting - pause between additions
        Start-Sleep -Milliseconds 500
    }
    catch {
        Write-Warning "  ⚠ Failed to add issue #$($issue.Number): $($_.Exception.Message)"
        $addFailures += [PSCustomObject]@{
            Number = $issue.Number
            Error = $_.Exception.Message
        }
    }
}

Write-Host "  → Added $($addedItems.Count)/$($issueIds.Count) issue(s)" -ForegroundColor Green

# Step 4: Set custom field values
if ($fieldMap.Count -gt 0 -and $addedItems.Count -gt 0) {
    Write-Host "`n[4/4] Setting custom field values..." -ForegroundColor Yellow
    
    $fieldUpdateCount = 0
    $fieldUpdateFailures = @()
    
    foreach ($item in $addedItems) {
        foreach ($fieldName in $fieldMap.Keys) {
            $field = $fieldMap[$fieldName]
            
            # Build the value part of the mutation based on data type
            $valueClause = switch ($field.DataType) {
                "SINGLE_SELECT" { "singleSelectOptionId: `"$($field.OptionId)`"" }
                "TEXT" { 
                    $escapedValue = $field.Value.Replace('\', '\\').Replace('"', '\"')
                    "text: `"$escapedValue`"" 
                }
                "NUMBER" { "number: $($field.Value)" }
                "DATE" { "date: `"$($field.Value)`"" }
                default {
                    Write-Warning "  ⚠ Unsupported field type: $($field.DataType) for field '$fieldName'"
                    continue
                }
            }
            
            $updateMutation = @"
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: `"$projectId`"
    itemId: `"$($item.ItemId)`"
    fieldId: `"$($field.Id)`"
    value: { $valueClause }
  }) {
    projectV2Item { id }
  }
}
"@
            
            try {
                Invoke-GraphQL -Query $updateMutation -MaxAttempts $RetryAttempts -RetryDelayMs $RetryDelayMs | Out-Null
                $fieldUpdateCount++
                Write-Host "  ✓ Set $fieldName = $($field.Value) for #$($item.Number)" -ForegroundColor Gray
                Start-Sleep -Milliseconds 300
            }
            catch {
                Write-Warning "  ⚠ Failed to set $fieldName for #$($item.Number): $($_.Exception.Message)"
                $fieldUpdateFailures += [PSCustomObject]@{
                    IssueNumber = $item.Number
                    FieldName = $fieldName
                    Error = $_.Exception.Message
                }
            }
        }
    }
    
    Write-Host "  → Updated $fieldUpdateCount field value(s) ($($fieldUpdateFailures.Count) failure(s))" -ForegroundColor Green
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Project: $projectTitle" -ForegroundColor Gray
Write-Host "Successfully added: $($addedItems.Count) issue(s)" -ForegroundColor Green

if ($addedItems.Count -gt 0) {
    Write-Host "Issues: #$($addedItems.Number -join ', #')" -ForegroundColor Gray
}

if ($addFailures.Count -gt 0) {
    Write-Host "Failed to add: $($addFailures.Count) issue(s)" -ForegroundColor Yellow
    Write-Host "Issues: #$($addFailures.Number -join ', #')" -ForegroundColor Gray
}

if ($fieldMap.Count -gt 0) {
    Write-Host "Custom fields set: $($fieldMap.Count) field(s)" -ForegroundColor Gray
}

# Return results
[PSCustomObject]@{
    ProjectId = $projectId
    ProjectTitle = $projectTitle
    AddedCount = $addedItems.Count
    FailedCount = $addFailures.Count
    AddedIssues = $addedItems.Number
    FailedIssues = $addFailures.Number
    FailedIssueDetails = $addFailures
    FieldsSet = $fieldMap.Keys
    FieldUpdateFailures = if ($fieldUpdateFailures) { $fieldUpdateFailures } else { @() }
}
