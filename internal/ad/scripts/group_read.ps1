$domainDN = Get-DomainDN
$group = Get-GroupOrNull ([string]$payload.guid)

if ($null -eq $group) {
    [pscustomobject]@{
        exists = $false
    } | ConvertTo-Json -Compress
    return
}

Get-GroupResult $group $domainDN | ConvertTo-Json -Compress
