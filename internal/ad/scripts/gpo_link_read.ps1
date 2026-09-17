$targetDN = [string]$payload.target_dn

try {
    Get-GPOLinksResult -TargetDN $targetDN | ConvertTo-Json -Compress -Depth 5
}
catch {
    if (Test-IsGPOLinkTargetNotFound $_) {
        [pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
    }
    else {
        throw
    }
}
