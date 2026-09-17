$serverParams = Get-ServerParams
$gpo = $null
try {
    $gpo = Get-GPO -Guid ([string]$payload.guid) @serverParams -ErrorAction Stop
}
catch {
    if (Test-IsGPONotFound $_) {
        $gpo = $null
    }
    else {
        throw
    }
}

Get-BackupGPOResult -Gpo $gpo | ConvertTo-Json -Compress
