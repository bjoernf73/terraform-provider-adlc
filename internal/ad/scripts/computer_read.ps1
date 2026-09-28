$domainDN = Get-DomainDN
$computer = Get-ComputerOrNull ([string]$payload.guid)

if ($null -eq $computer) {
    [pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
    return
}

Get-ComputerResult $computer $domainDN | ConvertTo-Json -Compress -Depth 5
