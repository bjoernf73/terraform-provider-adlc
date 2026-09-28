# Group Policy Object helpers for the read-only data source. Requires common.ps1.
Import-Module GroupPolicy -ErrorAction Stop

# $Identity is a GUID or a GPO display name, exactly as the caller wrote it.
function Get-GPOByIdentity([string]$Identity) {
    $serverParams = Get-ServerParams
    $parsed = [guid]::Empty
    if ([guid]::TryParse($Identity, [ref]$parsed)) {
        return Get-GPO -Guid $parsed @serverParams -ErrorAction Stop
    }

    return Get-GPO -Name $Identity @serverParams -ErrorAction Stop
}

function Get-GPOResult($Gpo, [string]$DomainDN) {
    return [pscustomobject]@{
        guid = $Gpo.Id.ToString()
        name = $Gpo.DisplayName
        # $Gpo.Path's GUID casing depends on the parameter set that resolved it; build the
        # DN from $Gpo.Id, which Get-GPO always renders the same way.
        distinguished_name      = "CN={$($Gpo.Id.ToString())},CN=Policies,CN=System,$DomainDN"
        domain                  = $Gpo.DomainName
        status                  = $Gpo.GpoStatus.ToString()
        description             = $Gpo.Description
        creation_time           = if ($null -ne $Gpo.CreationTime) { $Gpo.CreationTime.ToString('o') } else { $null }
        modification_time       = if ($null -ne $Gpo.ModificationTime) { $Gpo.ModificationTime.ToString('o') } else { $null }
        computer_ad_version     = [int64]$Gpo.Computer.DSVersion
        computer_sysvol_version = [int64]$Gpo.Computer.SysvolVersion
        user_ad_version         = [int64]$Gpo.User.DSVersion
        user_sysvol_version     = [int64]$Gpo.User.SysvolVersion
    }
}
