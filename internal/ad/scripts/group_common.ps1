# Group helpers. Requires common.ps1.
function Get-GroupResult($Group, [string]$DomainDN) {
    return [pscustomobject]@{
        exists             = $true
        name               = $Group.Name
        sam_account_name   = $Group.SamAccountName
        description        = $Group.Description
        category           = [string]$Group.GroupCategory
        scope              = [string]$Group.GroupScope
        path               = Convert-DNToPath (Get-ParentDN $Group.DistinguishedName) $DomainDN
        container_dn       = Get-ParentDN $Group.DistinguishedName
        distinguished_name = $Group.DistinguishedName
        guid               = [string]$Group.ObjectGUID
        sid                = [string]$Group.SID
    }
}

function Get-GroupByIdentity([string]$Identity) {
    $serverParams = Get-ServerParams
    return Get-ADGroup -Identity $Identity -Properties Description, DistinguishedName, Name, SamAccountName, GroupCategory, GroupScope, ObjectGUID, SID @serverParams -ErrorAction Stop
}

function Get-GroupOrNull([string]$Identity) {
    try {
        return Get-GroupByIdentity $Identity
    }
    catch {
        if (Test-IsIdentityNotFound $_) {
            return $null
        }

        throw
    }
}
