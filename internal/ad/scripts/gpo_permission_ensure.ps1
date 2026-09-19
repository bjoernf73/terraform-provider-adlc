$gpo = Resolve-GPOIdentity ([string]$payload.gpo)
$principal = Resolve-GPOPermissionPrincipal ([string]$payload.trustee)

Set-GPOPermissionLevel $gpo $principal ([string]$payload.permission)
Get-GPOPermissionResult $gpo $principal | ConvertTo-Json -Compress
