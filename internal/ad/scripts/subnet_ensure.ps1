$serverParams = Get-ServerParams
$name = [string]$payload.name
$site = Get-ADSiteOrNull ([string]$payload.site)
if ($null -eq $site) { throw "Active Directory site '$($payload.site)' was not found" }

$subnet = Get-ADSubnetOrNull $name
if ($null -eq $subnet) {
    New-ADReplicationSubnet -Name $name -Site $site.DistinguishedName @serverParams -ErrorAction Stop | Out-Null
    $subnet = Get-ADSubnetOrNull $name
}
else {
    Set-ADReplicationSubnet -Identity $subnet.DistinguishedName -Site $site.DistinguishedName @serverParams -ErrorAction Stop
}

Set-ADTopologyTextProperties $subnet.DistinguishedName ([string]$payload.description) ([string]$payload.location)

Get-ADSubnetResult (Get-ADSubnetOrNull $name) | ConvertTo-Json -Compress
