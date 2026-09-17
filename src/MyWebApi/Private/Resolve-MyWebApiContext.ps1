function Get-MyWebApiContextProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object] $Context,
        [Parameter(Mandatory)][string] $Name
    )
    if ($Context -is [System.Collections.IDictionary]) {
        return $Context[$Name]
    }
    $property = $Context.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    return $null
}

function Set-MyWebApiContextProperty {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][object] $Context,
        [Parameter(Mandatory)][string] $Name,
        [AllowNull()][object] $Value
    )
    if (-not $PSCmdlet.ShouldProcess($Name, 'Update session property')) { return }
    if ($Context -is [System.Collections.IDictionary]) {
        $Context[$Name] = $Value
        return
    }
    $property = $Context.PSObject.Properties[$Name]
    if ($property) {
        $property.Value = $Value
    } else {
        $Context | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Resolve-MyWebApiContext {
    [CmdletBinding()]
    param([object] $Connection)

    $context = if ($null -ne $Connection) { $Connection } else { $script:MyWebApiContext }
    if ($null -eq $context) { throw 'Not connected. Call Connect-MyWebApi first, or pass a Connection returned by Connect-MyWebApi.' }
    if (-not (Get-MyWebApiContextProperty -Context $context -Name 'BaseUrl')) {
        throw 'The supplied Connection is not a valid MyWebApi session.'
    }
    return $context
}

function Assert-MyWebApiEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Value,
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][object] $Context
    )

    $uri = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri)) {
        throw "$Name must be an absolute HTTPS URI."
    }
    $allowLoopback = [bool](Get-MyWebApiContextProperty -Context $Context -Name 'AllowInsecureLoopback')
    $isLoopback = $uri.IsLoopback -or ($uri.Host -in @('localhost', '127.0.0.1', '::1'))
    if ($uri.Scheme -ne 'https' -and -not ($uri.Scheme -eq 'http' -and $allowLoopback -and $isLoopback)) {
        throw "$Name must use HTTPS. HTTP is allowed only for an explicitly enabled loopback test endpoint."
    }
    return $uri
}

function Get-MyWebApiTimeoutSeconds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object] $Context,
        [ValidateRange(1, 600)][int] $Default = 30
    )
    $value = Get-MyWebApiContextProperty -Context $Context -Name 'HttpTimeoutSeconds'
    if ($null -eq $value -or [int]$value -lt 1) { return $Default }
    return [Math]::Min([int]$value, 600)
}

function Get-MyWebApiOrigin {
    [CmdletBinding()]
    param([Parameter(Mandatory)][Uri] $Uri)
    return ('{0}://{1}' -f $Uri.Scheme, $Uri.Authority)
}

function Get-MyWebApiCancellationToken {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object] $Context)
    $source = Get-MyWebApiContextProperty -Context $Context -Name 'CancellationSource'
    if ($source) { return $source.Token }
    return [System.Threading.CancellationToken]::None
}

function Assert-MyWebApiNotCancelled {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object] $Context)
    $token = Get-MyWebApiCancellationToken -Context $Context
    if ($token.IsCancellationRequested) {
        throw [System.OperationCanceledException]::new('The WebAPI session operation was cancelled.')
    }
}


function Invoke-MyWebApiHttpJson {
    <#
    Sends one bounded HTTP request with a real linked CancellationToken. Invoke-RestMethod
    in PowerShell 7.4 exposes no cancellation token, so this helper owns HttpClient and
    links the per-session cancellation source with a hard operation deadline.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object] $Context,
        [Parameter(Mandatory)][ValidateSet('GET','POST','PATCH','PUT','DELETE','HEAD','OPTIONS')][string] $Method,
        [Parameter(Mandatory)][string] $Uri,
        [hashtable] $Headers,
        [object] $JsonBody,
        [hashtable] $FormBody
    )
    Assert-MyWebApiNotCancelled -Context $Context
    $timeout = Get-MyWebApiTimeoutSeconds -Context $Context
    $parentToken = Get-MyWebApiCancellationToken -Context $Context
    $linked = [System.Threading.CancellationTokenSource]::CreateLinkedTokenSource($parentToken)
    $linked.CancelAfter([TimeSpan]::FromSeconds($timeout))
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [System.Threading.Timeout]::InfiniteTimeSpan
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method), $Uri)
    try {
        if ($Headers) {
            foreach ($key in $Headers.Keys) {
                [void]$request.Headers.TryAddWithoutValidation([string]$key, [string]$Headers[$key])
            }
        }
        if ($null -ne $JsonBody) {
            $json = $JsonBody | ConvertTo-Json -Depth 20
            $request.Content = [System.Net.Http.StringContent]::new($json, [System.Text.Encoding]::UTF8, 'application/json')
        } elseif ($null -ne $FormBody) {
            $pairs = [System.Collections.Generic.List[System.Collections.Generic.KeyValuePair[string,string]]]::new()
            foreach ($key in $FormBody.Keys) {
                $pairs.Add([System.Collections.Generic.KeyValuePair[string,string]]::new([string]$key, [string]$FormBody[$key]))
            }
            $request.Content = [System.Net.Http.FormUrlEncodedContent]::new($pairs)
        }
        try {
            $response = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseContentRead, $linked.Token).GetAwaiter().GetResult()
            $raw = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        } catch [System.OperationCanceledException] {
            if ($parentToken.IsCancellationRequested) { throw }
            throw [System.TimeoutException]::new("HTTP $Method $Uri exceeded the $timeout second deadline.")
        }
        $status = [int]$response.StatusCode
        if ($status -lt 200 -or $status -ge 300) {
            $httpError = [System.Net.Http.HttpRequestException]::new("HTTP $status from $Method $Uri")
            $httpError.Data['StatusCode'] = $status
            $httpError.Data['ResponseBody'] = $raw
            throw $httpError
        }
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return ($raw | ConvertFrom-Json -Depth 100)
    } finally {
        $request.Dispose()
        $client.Dispose()
        $handler.Dispose()
        $linked.Dispose()
    }
}

