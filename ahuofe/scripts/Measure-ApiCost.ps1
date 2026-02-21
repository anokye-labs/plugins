<#
.SYNOPSIS
    Analyze fal.ai API costs and project monthly spending, or estimate pre-execution costs.
.DESCRIPTION
    Two operating modes:
    1. Post-hoc analysis: pass -UsageData (from Get-FalUsage.ps1) to calculate
       per-request costs, project monthly cost, and raise budget alerts.
    2. Pre-execution estimation: pass -ModelId and -Quantity to estimate cost
       before running a job, using live pricing from Get-FalPricing.ps1.
.PARAMETER UsageData
    A PSCustomObject from Get-FalUsage.ps1 containing TotalCost,
    TotalRequests, ByEndpoint, StartDate, and EndDate.
.PARAMETER ModelId
    Model endpoint for pre-execution estimation, e.g. "fal-ai/flux/dev".
.PARAMETER Quantity
    Number of requests to estimate cost for (pre-execution mode).
.PARAMETER Unit
    Pricing unit override for estimation. Defaults to the unit from the pricing API.
.PARAMETER BudgetLimit
    Optional monthly budget limit in USD. Warns if projected cost exceeds it.
.PARAMETER OutputPath
    Optional path to write JSON results.
.EXAMPLE
    $usage = .\Get-FalUsage.ps1 -Days 30
    .\Measure-ApiCost.ps1 -UsageData $usage -BudgetLimit 50
.EXAMPLE
    .\Measure-ApiCost.ps1 -UsageData $usage -OutputPath cost-report.json
.EXAMPLE
    .\Measure-ApiCost.ps1 -ModelId "fal-ai/flux/dev" -Quantity 100
#>
[CmdletBinding(DefaultParameterSetName = 'PostHoc')]
param(
    [Parameter(Mandatory, ParameterSetName = 'PostHoc')]
    [PSCustomObject]$UsageData,

    [Parameter(Mandatory, ParameterSetName = 'Estimate')]
    [string]$ModelId,

    [Parameter(Mandatory, ParameterSetName = 'Estimate')]
    [int]$Quantity,

    [Parameter(ParameterSetName = 'Estimate')]
    [string]$Unit,

    [double]$BudgetLimit,

    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

# Load shared module (needed for estimation mode)
$modulePath = Join-Path $PSScriptRoot 'FalAi.psm1'
Import-Module $modulePath -Force

# ─── Pre-execution estimation mode ──────────────────────────────────────────
if ($PSCmdlet.ParameterSetName -eq 'Estimate') {
    Write-Host "Estimating cost for $Quantity request(s) to '$ModelId'..." -ForegroundColor Cyan

    # Fetch live pricing directly via the API
    $pricingResponse = Invoke-FalApi -Method GET -Endpoint 'https://api.fal.ai/v1/models/pricing' -RawUrl

    $pricingItems = if ($pricingResponse -is [array]) {
        $pricingResponse
    } elseif ($pricingResponse.models) {
        $pricingResponse.models
    } elseif ($pricingResponse.data) {
        $pricingResponse.data
    } elseif ($pricingResponse.pricing) {
        $pricingResponse.pricing
    } else {
        @($pricingResponse)
    }

    $match = $pricingItems | Where-Object {
        ($_.model_id -or $_.id -or $_.endpoint_id) -and
        ($_.model_id -eq $ModelId -or $_.id -eq $ModelId -or $_.endpoint_id -eq $ModelId)
    } | Select-Object -First 1

    $pricePerUnit = 0
    $resolvedUnit = if ($Unit) { $Unit } else { 'request' }

    if ($match) {
        $pricePerUnit  = [double]($match.price ?? $match.cost ?? 0)
        if (-not $Unit -and $match.unit) { $resolvedUnit = $match.unit }
    } else {
        Write-Warning "No pricing found for '$ModelId'. EstimatedCost will be 0."
    }

    $estimatedCost = [math]::Round($pricePerUnit * $Quantity, 6)

    $output = [PSCustomObject]@{
        ModelId       = $ModelId
        Quantity      = $Quantity
        Unit          = $resolvedUnit
        PricePerUnit  = $pricePerUnit
        EstimatedCost = $estimatedCost
    }

    Write-Host "`nCost Estimate:" -ForegroundColor Green
    Write-Host "  Model:          $ModelId" -ForegroundColor White
    Write-Host "  Quantity:       $Quantity" -ForegroundColor White
    Write-Host "  Price Per Unit: `$$pricePerUnit per $resolvedUnit" -ForegroundColor White
    Write-Host "  Estimated Cost: `$$estimatedCost" -ForegroundColor White

    if ($OutputPath) {
        $output | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath -Encoding UTF8
        Write-Host "Results written to $OutputPath" -ForegroundColor Green
    }

    return $output
}

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
