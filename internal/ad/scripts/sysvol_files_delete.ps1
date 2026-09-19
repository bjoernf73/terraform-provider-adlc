$root = Get-SysvolManagedRoot ([string]$payload.kind) ([string]$payload.relative_path)
if (Test-Path -LiteralPath $root -PathType Container) {
    foreach ($filePath in @($payload.previous_paths)) {
        Remove-SysvolManagedFile $root ([string]$filePath)
    }
}
[pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
