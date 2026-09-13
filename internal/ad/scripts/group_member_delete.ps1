$serverParams = Get-ServerParams

try {
    $group = Resolve-ADPrincipal ([string]$payload.group)
    $member = Resolve-ADPrincipal ([string]$payload.member)
}
catch {
    [pscustomobject]@{ deleted = $false; exists = $false } | ConvertTo-Json -Compress
    return
}

$removed = $false
if (Test-GroupMembership $group.distinguishedName $member.distinguishedName) {
    Remove-ADGroupMember -Identity $group.distinguishedName -Members $member.distinguishedName -Confirm:$false @serverParams -ErrorAction Stop
    $removed = $true
}

[pscustomobject]@{ deleted = $removed; exists = $false } | ConvertTo-Json -Compress
