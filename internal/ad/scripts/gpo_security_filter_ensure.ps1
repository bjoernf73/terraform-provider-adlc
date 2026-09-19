$gpo = Resolve-GPOIdentity ([string]$payload.gpo)
$desired = @([array]$payload.principals | ForEach-Object { Resolve-GPOPermissionPrincipal ([string]$_) })
$desiredSids = @($desired | ForEach-Object { $_.sid })

# This resource owns only explicit GpoApply entries. Higher delegation levels such as
# GpoEdit are left alone, so administrators and owners keep their separate access.
foreach ($entry in @(Get-GPOPermissionEntries $gpo)) {
    if ($entry.Permission -eq 'GpoApply' -and $entry.Trustee.Sid.Value -notin $desiredSids) {
        $current = Resolve-GPOPermissionPrincipal $entry.Trustee.Sid.Value
        if ($current.sid -eq 'S-1-5-11') {
            Set-GPOPermissionLevel $gpo $current 'GpoRead'
        }
        else {
            Set-GPOPermissionLevel $gpo $current 'None'
        }
    }
}

foreach ($principal in $desired) {
    Set-GPOPermissionLevel $gpo $principal 'GpoApply'
}

[pscustomobject]@{
    exists          = $true
    gpo_guid        = $gpo.Id.ToString()
    gpo_dn          = "CN={$($gpo.Id.ToString())},CN=Policies,CN=System,$(Get-DomainDN)"
    principal_sids  = @($desired | ForEach-Object { $_.sid })
    matches         = $true
} | ConvertTo-Json -Compress
