$gpo = Resolve-GPOIdentity ([string]$payload.gpo)

foreach ($identity in @($payload.principals)) {
    $principal = Resolve-GPOPermissionPrincipal ([string]$identity)
    if ($principal.sid -ne 'S-1-5-11') {
        Set-GPOPermissionLevel $gpo $principal 'None'
    }
}

# Restore the conventional GPO default on resource deletion.
$authenticatedUsers = Resolve-GPOPermissionPrincipal 'Authenticated Users'
Set-GPOPermissionLevel $gpo $authenticatedUsers 'GpoApply'

[pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
