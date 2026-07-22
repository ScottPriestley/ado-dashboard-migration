# Shared helpers for ADO dashboard migration scripts. Dot-source from each script.

function Get-AdoAuthHeader {
    param([Parameter(Mandatory)][string]$EnvVarName)
    $pat = [Environment]::GetEnvironmentVariable($EnvVarName)
    if ([string]::IsNullOrWhiteSpace($pat)) {
        throw "PAT not found. Set it for this session first:  `$env:$EnvVarName = '<pat>'"
    }
    $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
    return @{ Authorization = "Basic $b64" }
}

function Invoke-Ado {
    param(
        [Parameter(Mandatory)][hashtable]$Headers,
        [Parameter(Mandatory)][string]$Uri,
        [string]$Method = 'GET',
        [object]$Body = $null
    )
    $args = @{ Uri = $Uri; Method = $Method; Headers = $Headers; ContentType = 'application/json' }
    if ($null -ne $Body) { $args.Body = ($Body | ConvertTo-Json -Depth 50) }
    try {
        return Invoke-RestMethod @args
    }
    catch {
        $status = $_.Exception.Response.StatusCode.value__
        if ($status -eq 302 -or $status -eq 401 -or $status -eq 203) {
            throw "Auth failed calling $Uri — check the PAT (scope, expiry, correct org)."
        }
        # Invoke-RestMethod puts the API's JSON error body in ErrorDetails.Message, not
        # Exception.Message. Fold it in so callers can pattern-match on things like TF237018.
        $detail = $_.ErrorDetails.Message
        if ($detail) { throw "ADO API error calling $Uri`: $detail" }
        throw
    }
}

# Every GUID-shaped token found anywhere in a widget's settings/artifact strings.
function Get-GuidsInText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    return ([regex]::Matches($Text, '[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}') |
        ForEach-Object { $_.Value.ToLowerInvariant() } | Sort-Object -Unique)
}

function UrlEnc { param([string]$s) [uri]::EscapeDataString($s) }
