#Requires -Version 5.1
<#
.SYNOPSIS
    Shared PowerShell module for fal.ai API operations.
.DESCRIPTION
    Provides centralized functions for authentication, HTTP calls, file uploads,
    queue polling, and error handling against the fal.ai platform.
#>

# ─── Constants ───────────────────────────────────────────────────────────────
$script:FalSyncBaseUrl  = 'https://fal.run'
$script:FalQueueBaseUrl = 'https://queue.fal.run'
$script:FalTokenUrl     = 'https://rest.alpha.fal.ai/storage/auth/token?storage_type=fal-cdn-v3'
$script:FalSchemaUrl    = 'https://fal.ai/api/openapi/queue/openapi.json'
$script:MaxRetries      = 3

# ─── ConvertTo-FalError ──────────────────────────────────────────────────────
function ConvertTo-FalError {
    <#
    .SYNOPSIS
        Extracts a human-readable error message from fal.ai error responses.
    .PARAMETER Response
        The raw response body (string or object) from a fal.ai API call.
    .OUTPUTS
        [string] The extracted error message.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $Response
    )

    process {
        # If it's already a string, try to parse it
        if ($Response -is [string]) {
            try { $Response = $Response | ConvertFrom-Json } catch { return $Response }
        }

        # fal.ai returns errors in several shapes
        if ($Response.detail) {
            # {"detail": "..."} or {"detail": [{"msg": "..."}]}
            if ($Response.detail -is [string]) {
                return $Response.detail
            }
            if ($Response.detail -is [array] -and $Response.detail.Count -gt 0) {
                return ($Response.detail | ForEach-Object {
                    if ($_.msg) { $_.msg } else { $_ }
                }) -join '; '
            }
        }
        if ($Response.error) {
            return $Response.error
        }
        if ($Response.message) {
            return $Response.message
        }

        # Fallback
        return "Unknown fal.ai error: $($Response | ConvertTo-Json -Compress -Depth 3)"
    }
}

# ─── Get-FalApiKey ───────────────────────────────────────────────────────────
function Get-FalApiKey {
    <#
    .SYNOPSIS
        Loads the FAL_KEY from the environment or a .env file.
    .DESCRIPTION
        Checks $env:FAL_KEY first. If not set, looks for a .env file in the
        current directory and parses FAL_KEY=... from it.
    .OUTPUTS
        [string] The API key.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # 1. Environment variable
    if ($env:FAL_KEY) {
        return $env:FAL_KEY
    }

    # 2. .env file in current directory
    $envFile = Join-Path (Get-Location) '.env'
    if (Test-Path $envFile) {
        $lines = Get-Content $envFile -ErrorAction SilentlyContinue
        foreach ($line in $lines) {
            if ($line -match '^\s*FAL_KEY\s*=\s*(.+)$') {
                $key = $Matches[1].Trim().Trim('"').Trim("'")
                if ($key) { return $key }
            }
        }
    }

    throw 'FAL_KEY not found. Set $env:FAL_KEY or add FAL_KEY=<key> to a .env file.'
}

# ─── Invoke-FalApi ───────────────────────────────────────────────────────────
function Invoke-FalApi {
    <#
    .SYNOPSIS
        Centralized HTTP wrapper for fal.ai API calls with retry logic.
    .PARAMETER Method
        HTTP method (GET, POST, PUT, DELETE). Default: POST.
    .PARAMETER Endpoint
        The model path or full URL. E.g. "fal-ai/flux/dev".
    .PARAMETER Body
        Hashtable payload (will be serialized to JSON for POST/PUT).
    .PARAMETER BaseUrl
        Base URL. Default: https://fal.run.
    .PARAMETER FalKey
        API key. If omitted, retrieved via Get-FalApiKey.
    .PARAMETER RawUrl
        If set, Endpoint is treated as a full URL (BaseUrl is ignored).
    .OUTPUTS
        [PSCustomObject] Parsed JSON response.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('GET','POST','PUT','DELETE')]
        [string]$Method = 'POST',

        [Parameter(Mandatory)]
        [string]$Endpoint,

        [hashtable]$Body,

        [string]$BaseUrl = $script:FalSyncBaseUrl,

        [string]$FalKey,

        [switch]$RawUrl
    )

    if (-not $FalKey) { $FalKey = Get-FalApiKey }

    $url = if ($RawUrl) { $Endpoint } else { "$BaseUrl/$Endpoint" }

    $headers = @{
        'Authorization' = "Key $FalKey"
        'Content-Type'  = 'application/json'
    }

    $attempt = 0
    while ($true) {
        $attempt++
        try {
            $params = @{
                Uri             = $url
                Method          = $Method
                Headers         = $headers
                UseBasicParsing = $true
                ErrorAction     = 'Stop'
            }

            if ($Body -and $Method -in @('POST','PUT')) {
                $params.Body = $Body | ConvertTo-Json -Depth 10
            }

            $response = Invoke-RestMethod @params
            return $response
        }
        catch {
            $statusCode = 0
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }

            $retryable = ($statusCode -eq 429) -or ($statusCode -ge 500)

            if ($retryable -and $attempt -lt $script:MaxRetries) {
                $backoff = [math]::Pow(2, $attempt)
                Write-Warning "fal.ai request failed (HTTP $statusCode). Retry $attempt/$script:MaxRetries in ${backoff}s..."
                Start-Sleep -Seconds $backoff
                continue
            }

            # Try to extract a meaningful error from the response body
            $errorBody = $null
            try {
                if ($_.Exception.Response) {
                    $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                    $errorBody = $reader.ReadToEnd()
                    $reader.Close()
                }
            } catch {}

            if ($errorBody) {
                $msg = ConvertTo-FalError $errorBody
                throw "fal.ai API error (HTTP $statusCode): $msg"
            }
            throw $_
        }
    }
}

# ─── Send-FalFile ────────────────────────────────────────────────────────────
function Send-FalFile {
    <#
    .SYNOPSIS
        Uploads a local file to fal.ai CDN using the 2-step token flow.
    .DESCRIPTION
        Step 1: POST to storage/auth/token to get a CDN token and base_url.
        Step 2: POST the file bytes to {base_url}/files/upload.
    .PARAMETER FilePath
        Path to the local file.
    .PARAMETER FalKey
        API key. If omitted, retrieved via Get-FalApiKey.
    .OUTPUTS
        [string] The CDN access URL for the uploaded file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$FilePath,

        [string]$FalKey
    )

    if (-not $FalKey) { $FalKey = Get-FalApiKey }

    $fileName = Split-Path $FilePath -Leaf
    $ext = ($fileName -split '\.')[-1].ToLower()
    $contentType = switch ($ext) {
        'jpg'  { 'image/jpeg' }
        'jpeg' { 'image/jpeg' }
        'png'  { 'image/png' }
        'gif'  { 'image/gif' }
        'webp' { 'image/webp' }
        'mp4'  { 'video/mp4' }
        'mov'  { 'video/quicktime' }
        'mp3'  { 'audio/mpeg' }
        'wav'  { 'audio/wav' }
        default { 'application/octet-stream' }
    }

    # Step 1 — Get CDN token
    $tokenHeaders = @{
        'Authorization' = "Key $FalKey"
        'Content-Type'  = 'application/json'
    }
    $tokenResponse = Invoke-RestMethod -Uri $script:FalTokenUrl `
        -Method POST -Headers $tokenHeaders -Body '{}' -UseBasicParsing

    $cdnToken    = $tokenResponse.token
    $cdnTokenType = $tokenResponse.token_type
    $cdnBaseUrl  = $tokenResponse.base_url

    if (-not $cdnToken -or -not $cdnBaseUrl) {
        throw "Failed to obtain CDN upload token from fal.ai."
    }

    # Step 2 — Upload file
    $fileBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $FilePath).Path)
    $uploadHeaders = @{
        'Authorization'   = "$cdnTokenType $cdnToken"
        'Content-Type'    = $contentType
        'X-Fal-File-Name' = $fileName
    }
    $uploadResponse = Invoke-RestMethod -Uri "$cdnBaseUrl/files/upload" `
        -Method POST -Headers $uploadHeaders -Body $fileBytes -UseBasicParsing

    $accessUrl = $uploadResponse.access_url
    if (-not $accessUrl) {
        $msg = ConvertTo-FalError $uploadResponse
        throw "CDN upload failed: $msg"
    }

    return $accessUrl
}

# ─── Wait-FalJob ─────────────────────────────────────────────────────────────
function Wait-FalJob {
    <#
    .SYNOPSIS
        Submits a request to the fal.ai queue and polls until completion.
    .PARAMETER Model
        The model endpoint path (e.g. "fal-ai/flux/dev").
    .PARAMETER Body
        Hashtable payload to submit.
    .PARAMETER RequestId
        If provided, skips submission and polls an existing request.
    .PARAMETER TimeoutSeconds
        Maximum seconds to wait. Default: 300.
    .PARAMETER PollIntervalSeconds
        Seconds between status polls. Default: 2.
    .PARAMETER FalKey
        API key. If omitted, retrieved via Get-FalApiKey.
    .OUTPUTS
        [PSCustomObject] The final result from the queue.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Model,

        [hashtable]$Body,

        [string]$RequestId,

        [int]$TimeoutSeconds = 300,

        [int]$PollIntervalSeconds = 2,

        [string]$FalKey
    )

    if (-not $FalKey) { $FalKey = Get-FalApiKey }

    $queueBase = $script:FalQueueBaseUrl
    $headers = @{
        'Authorization' = "Key $FalKey"
        'Content-Type'  = 'application/json'
    }

    # Submit to queue if no RequestId provided
    if (-not $RequestId) {
        if (-not $Body) { throw 'Either -Body or -RequestId must be provided.' }

        $submitUrl = "$queueBase/$Model"
        $submitResponse = Invoke-RestMethod -Uri $submitUrl -Method POST `
            -Headers $headers -Body ($Body | ConvertTo-Json -Depth 10) -UseBasicParsing

        $RequestId = $submitResponse.request_id
        if (-not $RequestId) {
            $msg = ConvertTo-FalError $submitResponse
            throw "Queue submission failed: $msg"
        }
        Write-Verbose "Queued request: $RequestId"
    }

    # Poll for completion
    $statusUrl = "$queueBase/$Model/requests/$RequestId/status"
    $resultUrl = "$queueBase/$Model/requests/$RequestId"

    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        Start-Sleep -Seconds $PollIntervalSeconds
        $elapsed += $PollIntervalSeconds

        $status = Invoke-RestMethod -Uri $statusUrl -Method GET `
            -Headers $headers -UseBasicParsing

        switch ($status.status) {
            'COMPLETED' {
                $result = Invoke-RestMethod -Uri $resultUrl -Method GET `
                    -Headers $headers -UseBasicParsing
                return $result
            }
            'FAILED' {
                $msg = ConvertTo-FalError $status
                throw "fal.ai job failed: $msg"
            }
        }

        Write-Verbose "Status: $($status.status) (${elapsed}s / ${TimeoutSeconds}s)"
    }

    throw "fal.ai job timed out after ${TimeoutSeconds}s. Request ID: $RequestId"
}

# ─── Exports ─────────────────────────────────────────────────────────────────
Export-ModuleMember -Function @(
    'Get-FalApiKey'
    'Invoke-FalApi'
    'Send-FalFile'
    'Wait-FalJob'
    'ConvertTo-FalError'
)
