$domainDN = Get-DomainDN
$computer = Get-ComputerOrNull ([string]$payload.identity)

if ($null -eq $computer) {
    throw "computer '$([string]$payload.identity)' not found"
}

Get-ComputerResult $computer $domainDN | ConvertTo-Json -Compress -Depth 5
