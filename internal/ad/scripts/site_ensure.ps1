$serverParams = Get-ServerParams
$name = [string]$payload.name
$site = Get-ADSiteOrNull $name
if ($null -eq $site) {
    New-ADReplicationSite -Name $name @serverParams -ErrorAction Stop | Out-Null
    $site = Get-ADSiteOrNull $name
}

if ([string]::IsNullOrWhiteSpace([string]$payload.description)) {
    Set-ADReplicationSite -Identity $site.DistinguishedName -Clear Description @serverParams -ErrorAction Stop
}
else {
    Set-ADReplicationSite -Identity $site.DistinguishedName -Description ([string]$payload.description) @serverParams -ErrorAction Stop
}

Get-ADSiteResult (Get-ADSiteOrNull $name) | ConvertTo-Json -Compress
