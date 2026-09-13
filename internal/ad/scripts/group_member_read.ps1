try {
    $group = Resolve-ADPrincipal ([string]$payload.group)
    $member = Resolve-ADPrincipal ([string]$payload.member)
}
catch {
    # A missing group or member means the membership cannot exist.
    [pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
    return
}

$isMember = Test-GroupMembership $group.distinguishedName $member.distinguishedName
Get-GroupMemberResult $group $member $isMember | ConvertTo-Json -Compress
