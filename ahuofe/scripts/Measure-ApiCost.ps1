<#
.SYNOPSIS
    Analyze fal.ai API costs and project monthly spending.
.DESCRIPTION
    Parses usage data (from Get-FalUsage output), calculates per-request
    costs, projects monthly cost, and raises budget alerts.
.PARAMETER UsageData
    A PSCustomObject from Get-FalUsage.ps1 containing TotalCost,
    TotalRequests, ByEndpoint, StartDate, and EndDate.
.PARAMETER BudgetLimit
    Optional monthly budget limit in USD. Warns if projected cost exceeds it.
.PARAMETER OutputPath
    Optional path to write JSON results.
.EXAMPLE
    $usage = .\Get-FalUsage.ps1 -Days 30
    .\Measure-ApiCost.ps1 -UsageData $usage -BudgetLimit 50
.EXAMPLE
    .\Measure-ApiCost.ps1 -UsageData $usage -OutputPath cost-report.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [PSCustomObject]$UsageData,

    [double]$BudgetLimit,

    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

# ─── Validate required fields ───────────────────────────────────────────────
$requiredFields = @('StartDate', 'EndDate', 'TotalCost', 'TotalRequests')
foreach ($field in $requiredFields) {
    if (-not $UsageData.PSObject.Properties[$field] -or [string]::IsNullOrWhiteSpace($UsageData.$field)) {
        throw "UsageData is missing required field '$field'. Pass output from Get-FalUsage.ps1."
    }
}

# ─── Parse date range ───────────────────────────────────────────────────────
$startDate = [datetime]::Parse($UsageData.StartDate)
$endDate   = [datetime]::Parse($UsageData.EndDate)
$daysCovered = [math]::Max(1, ($endDate - $startDate).TotalDays)

$totalCost    = [double]($UsageData.TotalCost ?? 0)
$totalRequests = [int]($UsageData.TotalRequests ?? 0)

# ─── Per-request cost ───────────────────────────────────────────────────────
$costPerRequest = if ($totalRequests -gt 0) {
    [math]::Round($totalCost / $totalRequests, 6)
} else { 0 }

# ─── Monthly projection (30 days) ──────────────────────────────────────────
$dailyCost       = $totalCost / $daysCovered
$projectedMonthly = [math]::Round($dailyCost * 30, 2)

# ─── Per-model breakdown ───────────────────────────────────────────────────
$modelBreakdown = @()
if ($UsageData.ByEndpoint) {
    $modelBreakdown = @($UsageData.ByEndpoint | ForEach-Object {
        $perReq = if ($_.Quantity -gt 0) {
            [math]::Round($_.Cost / $_.Quantity, 6)
        } else { 0 }
        [PSCustomObject]@{
            EndpointId     = $_.EndpointId
            Cost           = [math]::Round($_.Cost, 4)
            Requests       = [int]$_.Quantity
            CostPerRequest = $perReq
        }
    })
}

# ─── Budget alert ───────────────────────────────────────────────────────────
$alertStatus = 'OK'
$alertMessage = $null

if ($PSBoundParameters.ContainsKey('BudgetLimit') -and $BudgetLimit -gt 0) {
    if ($projectedMonthly -gt $BudgetLimit) {
        $alertStatus = 'EXCEEDED'
        $alertMessage = "Projected monthly cost `$$projectedMonthly exceeds budget limit `$$BudgetLimit"
        Write-Warning $alertMessage
    }
    elseif ($projectedMonthly -gt ($BudgetLimit * 0.8)) {
        $alertStatus = 'WARNING'
        $alertMessage = "Projected monthly cost `$$projectedMonthly is above 80% of budget limit `$$BudgetLimit"
        Write-Warning $alertMessage
    }
}

# ─── Build output ───────────────────────────────────────────────────────────
$output = [PSCustomObject]@{
    Period           = [PSCustomObject]@{
        StartDate  = $UsageData.StartDate
        EndDate    = $UsageData.EndDate
        DaysCovered = [math]::Round($daysCovered, 1)
    }
    TotalCost        = [math]::Round($totalCost, 4)
    TotalRequests    = $totalRequests
    CostPerRequest   = $costPerRequest
    DailyCost        = [math]::Round($dailyCost, 4)
    ProjectedMonthly = $projectedMonthly
    ModelBreakdown   = $modelBreakdown
    BudgetAlert      = [PSCustomObject]@{
        Status       = $alertStatus
        BudgetLimit  = if ($PSBoundParameters.ContainsKey('BudgetLimit')) { $BudgetLimit } else { $null }
        Message      = $alertMessage
    }
}

# ─── Display ────────────────────────────────────────────────────────────────
Write-Host "`nCost Analysis ($($UsageData.StartDate) to $($UsageData.EndDate)):" -ForegroundColor Green
Write-Host "  Total Cost:         `$$($output.TotalCost)" -ForegroundColor White
Write-Host "  Total Requests:     $($output.TotalRequests)" -ForegroundColor White
Write-Host "  Cost Per Request:   `$$($output.CostPerRequest)" -ForegroundColor White
Write-Host "  Daily Cost:         `$$($output.DailyCost)" -ForegroundColor White
Write-Host "  Projected Monthly:  `$$($output.ProjectedMonthly)" -ForegroundColor White

if ($alertStatus -ne 'OK') {
    $color = if ($alertStatus -eq 'EXCEEDED') { 'Red' } else { 'Yellow' }
    Write-Host "  Budget Alert:       $alertStatus" -ForegroundColor $color
}

if ($modelBreakdown.Count -gt 0) {
    Write-Host "`nPer-Model Breakdown:" -ForegroundColor Green
    $modelBreakdown | Format-Table EndpointId, Cost, Requests, CostPerRequest -AutoSize | Out-Host
}

if ($OutputPath) {
    $output | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Host "Results written to $OutputPath" -ForegroundColor Green
}

$output
