$targetDN = [string]$payload.target_dn
$serverParams = Get-ServerParams

try {
    $current = Get-GPInheritance -Target $targetDN @serverParams -ErrorAction Stop
    foreach ($link in @($current.GpoLinks)) {
        Remove-GPLink -Guid $link.GpoId -Target $targetDN @serverParams -ErrorAction Stop | Out-Null
    }
    Set-GPInheritance -Target $targetDN -IsBlocked No @serverParams -ErrorAction Stop | Out-Null
}
catch {
    if (-not (Test-IsGPOLinkTargetNotFound $_)) {
        throw
    }
}

[pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
