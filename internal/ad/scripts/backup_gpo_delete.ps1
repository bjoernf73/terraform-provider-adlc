$serverParams = Get-ServerParams
try {
    Remove-GPO -Guid ([string]$payload.guid) @serverParams -ErrorAction Stop | Out-Null
}
catch {
    if (-not (Test-IsGPONotFound $_)) {
        throw
    }
}

[pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
