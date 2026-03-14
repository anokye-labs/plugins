#Requires -Version 5.1
<#
.SYNOPSIS
    Retrieve organization issue type IDs for use in GraphQL mutations.
.DESCRIPTION
    Queries the organization's issue types and returns them as a hashtable mapping
    type name to type ID.
.PARAMETER Owner
    Organization login name.
#>
[CmdletBinding()]
[OutputType([hashtable])]
param(
    [Parameter(Mandatory)]
    [string]$Owner
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\_Invoke-GraphQL.ps1"

$query = @"
query {
  organization(login: `"$Owner`") {
    issueTypes(first: 25) {
      nodes { id name }
    }
  }
}
"@

$result = Invoke-GraphQL -Query $query

$types = @{}
foreach ($type in $result.data.organization.issueTypes.nodes) {
    $types[$type.name] = $type.id
}

# Output as hashtable
$types

# Also display
$result.data.organization.issueTypes.nodes | Format-Table name, id
