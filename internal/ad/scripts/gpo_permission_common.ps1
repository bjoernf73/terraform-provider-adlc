# GPO permission helpers. Requires common.ps1 and gpo_link_common.ps1.
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module GroupPolicy -ErrorAction Stop

function Resolve-GPOPermissionPrincipal([string]$Identity) {
    if ($Identity -ieq 'Authenticated Users' -or $Identity -eq 'S-1-5-11') {
        return [pscustomobject]@{
            sid         = 'S-1-5-11'
            target_name = 'Authenticated Users'
            target_type = 'Group'
        }
    }

    $principal = Resolve-ADPrincipal $Identity
    $objectClass = [string]$principal.ObjectClass
    $targetType = switch ($objectClass) {
        'group' { 'Group'; break }
        'computer' { 'Computer'; break }
        default { 'User' }
    }

    return [pscustomobject]@{
        sid         = [string]$principal.ObjectSid
        target_name = [string]$principal.SamAccountName
        target_type = $targetType
    }
}

function Get-GPOPermissionEntries($Gpo) {
    $serverParams = Get-ServerParams
    return @(Get-GPPermission -Guid $Gpo.Id -All @serverParams -ErrorAction Stop)
}

function Get-GPOPermissionResult($Gpo, $Principal) {
    $entry = @(Get-GPOPermissionEntries $Gpo | Where-Object {
        $_.Trustee.Sid.Value -eq $Principal.sid
    } | Select-Object -First 1)

    if ($entry.Count -eq 0) {
        return [pscustomobject]@{
            exists      = $false
            gpo_guid    = $Gpo.Id.ToString()
            gpo_dn      = "CN={$($Gpo.Id.ToString())},CN=Policies,CN=System,$(Get-DomainDN)"
            trustee_sid = $Principal.sid
            permission  = $null
        }
    }

    return [pscustomobject]@{
        exists      = $true
        gpo_guid    = $Gpo.Id.ToString()
        gpo_dn      = "CN={$($Gpo.Id.ToString())},CN=Policies,CN=System,$(Get-DomainDN)"
        trustee_sid = $Principal.sid
        permission  = [string]$entry[0].Permission
    }
}

function Set-GPOPermissionLevel($Gpo, $Principal, [string]$Permission) {
    $serverParams = Get-ServerParams
    Set-GPPermission -Guid $Gpo.Id -TargetName $Principal.target_name -TargetType $Principal.target_type -PermissionLevel $Permission -Replace @serverParams -ErrorAction Stop | Out-Null
}
