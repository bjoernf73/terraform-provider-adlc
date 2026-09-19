$gpo = Resolve-GPOIdentity ([string]$payload.gpo)

$principalSids = @(Get-GPOPermissionEntries $gpo | Where-Object {
    $_.Permission -eq 'GpoApply'
} | ForEach-Object { $_.Trustee.Sid.Value })
$expectedSids = @([array]$payload.principals | ForEach-Object {
    (Resolve-GPOPermissionPrincipal ([string]$_)).sid
})
$matches = (@($principalSids | Sort-Object) -join '|') -eq (@($expectedSids | Sort-Object) -join '|')

[pscustomobject]@{
    exists         = $true
    gpo_guid       = $gpo.Id.ToString()
    gpo_dn         = "CN={$($gpo.Id.ToString())},CN=Policies,CN=System,$(Get-DomainDN)"
    principal_sids = $principalSids
    matches        = $matches
} | ConvertTo-Json -Compress
