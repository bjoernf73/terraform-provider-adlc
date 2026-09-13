$serverParams = Get-ServerParams
$group = Resolve-ADPrincipal ([string]$payload.group)
$member = Resolve-ADPrincipal ([string]$payload.member)

if (-not (Test-GroupMembership $group.distinguishedName $member.distinguishedName)) {
    Add-ADGroupMember -Identity $group.distinguishedName -Members $member.distinguishedName @serverParams -ErrorAction Stop
}

Get-GroupMemberResult $group $member $true | ConvertTo-Json -Compress
