$domainDN = Get-DomainDN
$user = Get-UserOrNull ([string]$payload.identity)

if ($null -eq $user) {
    throw "user '$([string]$payload.identity)' not found"
}

Get-UserResult $user $domainDN | ConvertTo-Json -Compress
