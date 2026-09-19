$site = Get-ADSiteOrNull ([string]$payload.name)
if ($null -ne $site) {
    $serverParams = Get-ServerParams
    Remove-ADReplicationSite -Identity $site.DistinguishedName -Confirm:$false @serverParams -ErrorAction Stop
}
[pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
