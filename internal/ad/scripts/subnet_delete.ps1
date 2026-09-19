$subnet = Get-ADSubnetOrNull ([string]$payload.name)
if ($null -ne $subnet) {
    $serverParams = Get-ServerParams
    Remove-ADReplicationSubnet -Identity $subnet.DistinguishedName -Confirm:$false @serverParams -ErrorAction Stop
}
[pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
