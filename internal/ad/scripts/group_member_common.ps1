# Group membership helpers. Requires common.ps1.

function Test-GroupMembership([string]$GroupDN, [string]$MemberDN) {
    $serverParams = Get-ServerParams

    # The member attribute is read directly because Get-ADGroupMember fails on
    # foreign security principals and on members from other domains.
    $group = Get-ADGroup -Identity $GroupDN -Properties member @serverParams -ErrorAction Stop
    return (@($group.member) -contains $MemberDN)
}

function Get-GroupMemberResult($Group, $Member, [bool]$Exists) {
    return [pscustomobject]@{
        exists       = $Exists
        group_dn     = [string]$Group.distinguishedName
        group_guid   = [string]$Group.objectGUID
        member_dn    = [string]$Member.distinguishedName
        member_guid  = [string]$Member.objectGUID
        member_sid   = [string]$Member.objectSid
        member_class = [string]$Member.objectClass
    }
}
