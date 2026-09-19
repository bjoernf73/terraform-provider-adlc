$root = Get-SysvolManagedRoot ([string]$payload.kind) ([string]$payload.relative_path)
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    [pscustomobject]@{ exists = $false; matches = $false } | ConvertTo-Json -Compress
    return
}
Get-SysvolFilesResult $root $payload.files | ConvertTo-Json -Compress
