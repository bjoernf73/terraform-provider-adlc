$gpo = Resolve-GPOIdentity ([string]$payload.gpo)
$principal = Resolve-GPOPermissionPrincipal ([string]$payload.trustee)

Set-GPOPermissionLevel $gpo $principal 'None'
[pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
