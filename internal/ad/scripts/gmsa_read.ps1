$domainDN = Get-DomainDN
$gmsa = Get-GmsaOrNull ([string]$payload.guid)

if ($null -eq $gmsa) {
    [pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
    return
}

Get-GmsaResult $gmsa $domainDN | ConvertTo-Json -Compress -Depth 5
