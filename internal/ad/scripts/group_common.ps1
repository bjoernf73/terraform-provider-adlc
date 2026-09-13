# Group helpers. Requires common.ps1.
function Get-GroupResult($Group, [string]$DomainDN) {
    $containerDN = Get-ParentDN $Group.DistinguishedName

    # Lets the provider keep the configured spelling of path when it resolves to the
    # same container; a DN and a slash path can denote the same place.
    $pathMatch = $false
    if ($null -ne $payload.path) {
        $pathMatch = ((Convert-PathToDN ([string]$payload.path) $DomainDN) -eq $containerDN)
    }

    return [pscustomobject]@{
        exists             = $true
        name               = $Group.Name
        sam_account_name   = $Group.SamAccountName
        description        = $Group.Description
        category           = [string]$Group.GroupCategory
        scope              = [string]$Group.GroupScope
        path               = Convert-DNToPath $containerDN $DomainDN
        path_match         = $pathMatch
        container_dn       = $containerDN
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
