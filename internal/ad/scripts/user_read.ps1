$domainDN = Get-DomainDN
$user = Get-UserOrNull ([string]$payload.guid)

if ($null -eq $user) {
    [pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
    return
}

Get-UserResult $user $domainDN | ConvertTo-Json -Compress
