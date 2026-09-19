$gpo = Resolve-GPOIdentity ([string]$payload.gpo)
$principal = Resolve-GPOPermissionPrincipal ([string]$payload.trustee)

Get-GPOPermissionResult $gpo $principal | ConvertTo-Json -Compress
