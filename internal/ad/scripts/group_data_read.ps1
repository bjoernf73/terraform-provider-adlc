$domainDN = Get-DomainDN
$group = Get-GroupOrNull ([string]$payload.identity)

if ($null -eq $group) {
    throw "group '$([string]$payload.identity)' not found"
}

Get-GroupResult $group $domainDN | ConvertTo-Json -Compress
