$serverParams = Get-ServerParams
$name = [string]$payload.name
$site = Get-ADSiteOrNull $name
if ($null -eq $site) {
    New-ADReplicationSite -Name $name @serverParams -ErrorAction Stop | Out-Null
    $site = Get-ADSiteOrNull $name
}

Set-ADTopologyTextProperties $site.DistinguishedName ([string]$payload.description) ([string]$payload.location)

Get-ADSiteResult (Get-ADSiteOrNull $name) | ConvertTo-Json -Compress
